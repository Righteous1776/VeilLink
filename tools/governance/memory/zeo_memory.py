#!/usr/bin/env python3
"""ZeoStudio portable, explicit, reviewable project memory / sleep consolidation.

Standard library only. No hidden service, no account connection, no unattended background work.
The numbered banks are local SQLite-backed records and portable Markdown/JSON exports.
"""
from __future__ import annotations
import argparse, datetime as dt, hashlib, json, os, re, secrets, sqlite3, sys, textwrap
from pathlib import Path

VERSION='1.5.0'
BANKS={
 'M00':'governance-reference',
 'M01':'standing-instructions',
 'M02':'task-continuity',
 'M03':'decision-register',
 'M04':'evidence-index',
 'M05':'incidents-lessons',
 'M06':'session-summaries',
 'M07':'sleep-review-queue',
 'M08':'archive',
 'M09':'forget-log',
}
ALLOWED_TYPES={'instruction','task','decision','evidence','incident','session','note'}
ALLOWED_AUTHORITY={'owner','user','governor','agent','import'}
ALLOWED_EVENT_TYPES={'decision','verified_result','blocker','next_step','task_state','risk','lesson','context','observation'}
MAX_DIRECTIVES=50
SECRET_PATTERNS=[
 re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH |ED25519 )?PRIVATE KEY-----',re.I),
 re.compile(r'(?i)(?:api[_-]?key|access[_-]?token|secret[_-]?key|password)\s*[:=]\s*["\']?[A-Za-z0-9_\-]{14,}'),
 re.compile(r'\bgh[pousr]_[A-Za-z0-9]{25,}\b'),
]

def now():return dt.datetime.now(dt.timezone.utc).isoformat(timespec='seconds')
def digest(blob):return hashlib.sha256(blob.encode('utf-8') if isinstance(blob,str) else blob).hexdigest()
def norm(s):return ' '.join(s.strip().split())
def validate_text(s,label='内容'):
 if not isinstance(s,str) or not 3<=len(norm(s))<=4096: raise ValueError(f'{label} 长度必须在 3..4096 字符之间')
 if any(p.search(s) for p in SECRET_PATTERNS):raise ValueError(f'{label} 疑似包含私钥/口令/令牌；禁止记忆，请使用秘密管理器')
 return norm(s)
def bank_check(b):
 if b not in BANKS:raise ValueError(f'未知编号库 {b}; 可用: {", ".join(BANKS)}')
 return b

def location(root):
 root=Path(root).expanduser().resolve();root.mkdir(parents=True,exist_ok=True)
 # tools never follow arbitrary user-supplied relative output paths into hidden locations
 return root

class Store:
 def __init__(self,root):
  self.root=location(root);self.db=self.root/'MEMORY.sqlite3'
  self.conn=sqlite3.connect(self.db)
  self.conn.row_factory=sqlite3.Row
  self.conn.execute('PRAGMA foreign_keys=ON');self.conn.execute('PRAGMA busy_timeout=4000')
  self.conn.execute('PRAGMA secure_delete=ON')
  self.conn.execute('PRAGMA journal_mode=WAL')
  self.conn.executescript('''
CREATE TABLE IF NOT EXISTS records(
 id TEXT PRIMARY KEY, bank TEXT NOT NULL, kind TEXT NOT NULL, task_id TEXT NOT NULL DEFAULT '',
 content TEXT NOT NULL, content_hash TEXT NOT NULL, source_ref TEXT NOT NULL,
 authority TEXT NOT NULL, status TEXT NOT NULL, created_at TEXT NOT NULL,
 updated_at TEXT NOT NULL, supersedes TEXT NOT NULL DEFAULT '', confidence REAL NOT NULL DEFAULT 1,
 tags TEXT NOT NULL DEFAULT '[]');
CREATE INDEX IF NOT EXISTS idx_bank_status ON records(bank,status);
CREATE INDEX IF NOT EXISTS idx_task ON records(task_id);
CREATE INDEX IF NOT EXISTS idx_hash ON records(content_hash);
CREATE TABLE IF NOT EXISTS events(
 seq INTEGER PRIMARY KEY AUTOINCREMENT, at TEXT NOT NULL, action TEXT NOT NULL,
 record_id TEXT NOT NULL, detail TEXT NOT NULL, prev_hash TEXT NOT NULL, event_hash TEXT NOT NULL);
''')
 def close(self):self.conn.close()
 def _audit(self,action,record_id,detail):
  prev=self.conn.execute('SELECT event_hash FROM events ORDER BY seq DESC LIMIT 1').fetchone()
  prev=prev['event_hash'] if prev else '0'*64
  ts=now();detail=json.dumps(detail,ensure_ascii=False,sort_keys=True)
  h=digest('\n'.join([prev,ts,action,record_id,detail]))
  self.conn.execute('INSERT INTO events(at,action,record_id,detail,prev_hash,event_hash) VALUES (?,?,?,?,?,?)',(ts,action,record_id,detail,prev,h))
 def count_directives(self):
  return self.conn.execute("SELECT COUNT(*) n FROM records WHERE bank='M01' AND status='active'").fetchone()['n']
 def add(self,bank,kind,text,source,authority='user',task='',status='candidate',tags=None,confidence=1.0,supersedes=''):
  bank_check(bank);text=validate_text(text);source=validate_text(source,'来源')
  if kind not in ALLOWED_TYPES:raise ValueError('Unsupported memory type')
  if authority not in ALLOWED_AUTHORITY:raise ValueError('Unsupported authority')
  if not 0<=confidence<=1:raise ValueError('Confidence must be 0..1')
  if bank=='M01' and status=='active' and self.count_directives()>=MAX_DIRECTIVES:raise ValueError('50 条长期指令上限；先归档/合并旧条目')
  if bank=='M00' and status=='active':raise ValueError('M00 仅保存参考摘要；不得在此直接更改宪法/授予权限')
  if status not in {'candidate','active','archived'}:raise ValueError('Invalid status')
  ch=digest(text.casefold());dupe=self.conn.execute('SELECT id FROM records WHERE content_hash=? AND bank=? AND task_id=? AND status!=\'archived\' LIMIT 1',(ch,bank,task)).fetchone()
  if dupe:return {'id':dupe['id'],'result':'duplicate'}
  id='MEM-'+secrets.token_hex(8).upper();ts=now()
  with self.conn:
   self.conn.execute('INSERT INTO records VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)',(
    id,bank,kind,task,text,ch,source,authority,status,ts,ts,supersedes,confidence,json.dumps(tags or [],ensure_ascii=False)))
   self._audit('ADD',id,{'bank':bank,'kind':kind,'authority':authority,'source_sha256':digest(source),'status':status})
  return {'id':id,'result':'created','status':status,'bank':bank}
 def remember(self,text,source,task='',owner_confirmed=False):
  # User's explicit "remember" is a durable standing instruction; other drafts require review.
  return self.add('M01','instruction',text,source,'user' if owner_confirmed else 'agent',task,'active' if owner_confirmed else 'candidate')
 def approve(self,id,by='owner',target=None):
  if by not in {'owner','user','governor'}:raise ValueError('Only authorized reviewer can approve')
  item=self.conn.execute('SELECT * FROM records WHERE id=?',(id,)).fetchone()
  if not item:raise KeyError('Unknown memory ID')
  if item['status']!='candidate':raise ValueError('Only candidates can be approved')
  dest=bank_check(target or ('M06' if item['bank']=='M07' else item['bank']))
  if dest in {'M00','M07','M09'}:raise ValueError('Candidate cannot be promoted to special bank')
  if dest=='M01' and (by not in {'owner','user'} or item['kind']!='instruction' or item['authority']!='user'):raise ValueError('Only explicit user instructions can become long-term directives')
  if dest=='M01' and by not in {'owner','user'}:raise ValueError('Only owner/user can approve standing instructions')
  if dest=='M01' and self.count_directives()>=MAX_DIRECTIVES:raise ValueError('Long-term instruction limit reached')
  with self.conn:
   self.conn.execute('UPDATE records SET bank=?,status=?,updated_at=? WHERE id=?',(dest,'active',now(),id))
   self._audit('APPROVE',id,{'by':by,'bank':dest})
  return {'id':id,'status':'active','bank':dest}
 def reject(self,id,by='owner'):
  if by not in {'owner','user','governor'}:raise ValueError('Only authorized reviewer can reject')
  with self.conn:
   item=self.conn.execute('SELECT id FROM records WHERE id=? AND status=?',(id,'candidate')).fetchone()
   if not item:raise ValueError('Only existing candidates can be rejected')
   self.conn.execute('UPDATE records SET status=?,updated_at=? WHERE id=?',('archived',now(),id))
   self._audit('REJECT',id,{'by':by})
  return {'id':id,'status':'archived'}
 def forget(self,id,by='user'):
  if by not in {'user','owner'}:raise ValueError('Only user/owner can request forgetting')
  with self.conn:
   item=self.conn.execute('SELECT bank FROM records WHERE id=?',(id,)).fetchone()
   if not item:raise KeyError('Unknown memory ID')
   self.conn.execute('DELETE FROM records WHERE id=?',(id,))
   self._audit('FORGET',id,{'by':by,'from_bank':item['bank'],'content_not_retained':True})
  return {'id':id,'result':'purged_from_database','caveat':'Backups/exports/checkpoints require separate disposal; SQLite WAL may retain deleted bytes until checkpoint and VACUUM'}
 def clean_deleted(self):
  self.conn.execute('PRAGMA wal_checkpoint(TRUNCATE)');self.conn.execute('VACUUM')
 def query(self,q='',bank=None,status='active',task='',limit=30):
  where=['status=?'];args=[status]
  if bank:bank_check(bank);where.append('bank=?');args.append(bank)
  if task:where.append('task_id=?');args.append(task)
  if q:where.append('(content LIKE ? OR source_ref LIKE ? OR tags LIKE ?)');args += ['%'+q+'%']*3
  rows=self.conn.execute('SELECT * FROM records WHERE '+' AND '.join(where)+' ORDER BY updated_at DESC LIMIT ?',(*args,min(100,max(1,limit)))).fetchall()
  return [{k:r[k] for k in r.keys()} for r in rows]
 def sleep(self,source_file,save=True):
  # A "sleep" is a *review pass*, never hidden asynchronous model work.
  src=Path(source_file).expanduser().resolve()
  doc=json.loads(src.read_text(encoding='utf-8'))
  if not isinstance(doc,dict) or not isinstance(doc.get('sessions'),list):raise ValueError('Need {"sessions":[...]}')
  results=[]
  for sess in doc['sessions']:
   if not isinstance(sess,dict):raise ValueError('Invalid session')
   sid=validate_text(str(sess.get('session_id','')),'session_id')
   task=validate_text(str(sess.get('task_id','')),'task_id')
   events=sess.get('events',[])
   if not isinstance(events,list):raise ValueError('Events must be array')
   keep=[];seen=set()
   for e in events:
    if not isinstance(e,dict) or e.get('type') not in ALLOWED_EVENT_TYPES:continue
    if not e.get('evidence_ref'):continue
    fact=validate_text(str(e.get('text','')))
    ev=validate_text(str(e['evidence_ref']),'evidence')
    k=digest(e['type']+'\0'+fact.casefold())
    if k in seen:continue
    seen.add(k);keep.append((e['type'],fact,ev))
   if not keep:continue
   # A mechanical digest of sourced records, not a synthetic/hallucinated summary.
   chunks=[f'[{kind}] {txt} (证据: {ref})' for kind,txt,ref in keep]
   content=f'Task {task} / Session {sid} 摘要：\n'+'\n'.join(chunks)
   if len(content)>4096:
    content=content[:4000]+'\n[TRUNCATED: review source events before approval]'
   source=f'sleep-input:{src.name};session:{sid}'
   if save:r=self.add('M07','session',content,source,'import',task,'candidate',tags=['sleep',sid],confidence=0.8)
   else:r={'result':'dry-run','status':'candidate'}
   results.append({'session_id':sid,'task_id':task,'events_kept':len(keep),'candidate':r,'preview':content})
  return results
 def verify(self):
  prev='0'*64;issues=[]
  for ev in self.conn.execute('SELECT * FROM events ORDER BY seq'):
   h=digest('\n'.join([prev,ev['at'],ev['action'],ev['record_id'],ev['detail']]))
   if h!=ev['event_hash'] or prev!=ev['prev_hash']:issues.append('Audit chain mismatch at '+str(ev['seq']))
   prev=ev['event_hash']
  for r in self.conn.execute('SELECT id,content,content_hash FROM records'):
   if digest(r['content'].casefold())!=r['content_hash']:issues.append('Content digest mismatch '+r['id'])
  if self.count_directives()>MAX_DIRECTIVES:issues.append('Directive capacity exceeded')
  return {'ok':not issues,'errors':issues,'directives':self.count_directives(),'rows':self.conn.execute('SELECT COUNT(*) FROM records').fetchone()[0], 'audit_events':self.conn.execute('SELECT COUNT(*) FROM events').fetchone()[0], 'note':'Local audit is not tamper-proof against a writer controlling the entire DB'}
 def export(self,out,task=''):
  out=Path(out).expanduser().resolve()
  # Never export candidates as trusted long-term knowledge.
  wh="WHERE status='active'" + (" AND (task_id=? OR (bank='M01' AND task_id=''))" if task else "")
  rows=[dict(r) for r in self.conn.execute("SELECT * FROM records "+wh+" ORDER BY bank,updated_at DESC",(task,) if task else ())]
  if task:
   # Standing instructions are global, while task memory remains isolated.
   globals_=self.query(status='active',bank='M01',limit=100)
   rows=globals_+[r for r in rows if r['id'] not in {g['id'] for g in globals_}]
  lines=['# ZeoStudio 编号记忆库 · 审阅用摘要','',f'生成时间：{now()}','**本文件为摘要与索引，不是法源或权限凭证。**','']
  for bank in BANKS:
   selected=[r for r in rows if r['bank']==bank]
   if not selected:continue
   lines.append(f'## {bank} · {BANKS[bank]}')
   for r in selected:lines += [f"- **{r['id']}** [{r['kind']}] {r['content']}",f"  - 来源：{r['source_ref']} · 更新：{r['updated_at']} · Task：{r['task_id'] or '—'}"]
   lines.append('')
  out.parent.mkdir(parents=True,exist_ok=True);out.write_text('\n'.join(lines)+'\n',encoding='utf-8')
  return {'export':str(out),'items':sum(bool(r) for r in rows),'sha256':digest(out.read_bytes())}

def main(argv=None):
 ap=argparse.ArgumentParser(description='ZeoStudio numbered memory banks: explicit instructions + reviewed sleep summary')
 ap.add_argument('--workspace',default='.zeo_memory',help='Private workspace directory (never commit live memory with secrets)')
 sub=ap.add_subparsers(dest='command',required=True)
 for x in ['init','banks','verify','status']:sub.add_parser(x)
 p=sub.add_parser('remember');p.add_argument('--text',required=True);p.add_argument('--source',required=True);p.add_argument('--task',default='');p.add_argument('--confirmed',action='store_true',help='User expressly requested memory storage')
 p=sub.add_parser('add');p.add_argument('--bank',required=True);p.add_argument('--kind',required=True);p.add_argument('--text',required=True);p.add_argument('--source',required=True);p.add_argument('--task',default='');p.add_argument('--authority',default='agent')
 p=sub.add_parser('sleep');p.add_argument('--input',required=True);p.add_argument('--dry-run',action='store_true')
 for x in ['approve','reject','forget']:
  p=sub.add_parser(x);p.add_argument('id');p.add_argument('--by',default='owner');
  if x=='approve':p.add_argument('--bank',default=None)
 p=sub.add_parser('search');p.add_argument('--query',default='');p.add_argument('--bank');p.add_argument('--task',default='');p.add_argument('--status',default='active',choices=['active','candidate','archived']);p.add_argument('--limit',type=int,default=30)
 p=sub.add_parser('export');p.add_argument('--output',required=True);p.add_argument('--task',default='')
 a=ap.parse_args(argv)
 if a.command=='banks':result=BANKS
 else:
  s=Store(a.workspace)
  try:
   if a.command=='init':result={'workspace':str(s.root),'version':VERSION,'db':str(s.db),'banks':BANKS}
   elif a.command=='remember':result=s.remember(a.text,a.source,a.task,a.confirmed)
   elif a.command=='add':result=s.add(a.bank,a.kind,a.text,a.source,a.authority,a.task)
   elif a.command=='sleep':result=s.sleep(a.input,not a.dry_run)
   elif a.command=='approve':result=s.approve(a.id,a.by,a.bank)
   elif a.command=='reject':result=s.reject(a.id,a.by)
   elif a.command=='forget':result=s.forget(a.id,a.by);s.clean_deleted()
   elif a.command=='search':result=s.query(a.query,a.bank,a.status,a.task,a.limit)
   elif a.command=='export':result=s.export(a.output,a.task)
   elif a.command=='verify':result=s.verify()
   elif a.command=='status':result={'banks':BANKS,'active_by_bank':{b:s.conn.execute('SELECT COUNT(*) FROM records WHERE bank=? AND status=?',(b,'active')).fetchone()[0] for b in BANKS},'candidates':s.conn.execute("SELECT COUNT(*) FROM records WHERE status='candidate'").fetchone()[0]}
  finally:s.close()
 print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__=='__main__':
 try:main()
 except (ValueError,KeyError,sqlite3.DatabaseError,FileNotFoundError) as exc:
  print(json.dumps({'error':str(exc)},ensure_ascii=False),file=sys.stderr);sys.exit(2)
