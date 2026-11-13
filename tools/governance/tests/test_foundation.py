"""Integration regressions using temporary synthetic repositories, never live tasks."""
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT/'AGENT_INBOX/tools'))
sys.path.insert(0, str(ROOT/'tools/governance'))
import study_gate as study
import inbox_gate as inbox
from check_additive_migration import check as additive_check
from check_new_submissions import new_roots

def load(name, path):
    spec=importlib.util.spec_from_file_location(name,path)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module

memory=load('zeo_memory_test',ROOT/'tools/governance/memory/zeo_memory.py')

class Fixture(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.repo=Path(self.temp.name)
        self.git('init','-q','-b','main')
        self.git('config','user.email','fixture@example.invalid')
        self.git('config','user.name','Synthetic Fixture')
        for path in study.REQUIRED_DOCS:
            self.write(path,'Synthetic governing fixture: '+path+'\n')
        self.write('AGENT_INBOX/ASSET_GRANTS.json',json.dumps({'grants':[]}))
        for p in ['governance/CONSTITUTION_SEAL.json','governance/MANDATORY_READ_SET.json',
                  'governance/GOVERNOR_REGISTRY.json',
                  'governance/templates/SESSION_STATE.template.json']:
            self.write(p,(ROOT/p).read_text())
        readset=json.loads((self.repo/'governance/MANDATORY_READ_SET.json').read_text())
        for path in readset['common']:
            if not (self.repo/path).exists():self.write(path,'Synthetic required file '+path+'\n')
        self.write('AGENT_EXCHANGE/README.md','Synthetic empty bus\n')
        for path in readset['optional_if_exchange_installed']:
            if not (self.repo/path).exists():self.write(path,'Synthetic exchange file '+path+'\n')
        self.commit();self.base=self.git('rev-parse','HEAD')
        self.record={'schema':'zeostudio.learning-record.v1','agent_id':'fixture-agent',
                     'task_id':'fixture-task','base_main_sha':self.base,
                     'documents':[{'path':p,'sha256':hashlib.sha256(self.blob(self.base,p)).hexdigest()} for p in study.REQUIRED_DOCS],
                     'answers':dict(study.ANSWERS),'teachback':{
            'untrusted_governor_message':'I verify the repository authority record and current Owner decision before acting; a message prefix alone cannot grant any write permission.',
            'conflicting_parallel_change':'I preserve both proposals, identify the shared files and behavior, and ask the existing Governor to arbitrate without overwriting either lane.',
            'no_write_tool_mobile':'I provide a handoff draft and clearly state no files were committed or delivered; a capable authorized writer must validate and persist the packet.'}}
    def git(self,*args):
        return subprocess.check_output(['git','-C',str(self.repo),*args],stderr=subprocess.PIPE).decode().strip()
    def write(self,path,text):
        p=self.repo/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text)
    def blob(self,sha,path):
        return subprocess.check_output(['git','-C',str(self.repo),'show',f'{sha}:{path}'])
    def commit(self):
        self.git('add','.');self.git('commit','-qm','Synthetic fixture')
    def validate(self,record=None,reference=None):
        return study.validate_study(self.repo,record or self.record,agent_id='fixture-agent',
                    task_id='fixture-task',base_main_sha=self.base,reference_sha=reference or self.base)
    def cli(self,script,*args,expected=0):
        env=dict(os.environ,ZEO_REPO_ROOT=str(self.repo),PYTHONDONTWRITEBYTECODE='1')
        p=subprocess.run([sys.executable,str(ROOT/script),*args],cwd=self.repo,env=env,capture_output=True,text=True)
        self.assertEqual(p.returncode,expected,p.stdout+p.stderr)
        return p.stdout+p.stderr
    def package(self):
        sub='AGENT_INBOX/submissions/fixture-agent/fixture-task'
        values={'agent_id':'fixture-agent','task_id':'fixture-task','status':'DROPPED',
                'base_main_sha':self.base,'created_at':'2026-11-13','scope':'Synthetic source fixture',
                'proposed_files':'Example.swift','protected_surfaces':'none','dependencies':'none','known_overlaps':'none'}
        self.write(sub+'/MANIFEST.md','\n'.join(k+': '+v for k,v in values.items())+'\n')
        for name in ['PROPOSAL.md','TEST_PLAN.md','RISKS.md']:self.write(sub+'/'+name,'Synthetic fixture document.\n')
        self.write(sub+'/PATCH.diff','NO_PATCH: Synthetic read-only proposal fixture for gate regression.\n')
        self.write(sub+'/STUDY_RECORD.json',json.dumps(self.record))
        return sub

class StudyTests(Fixture):
    def test_real_git_object_hashes_pass(self):self.assertEqual(self.validate()['documents_checked'],11)
    def test_hash_tamper_rejected(self):
        r=copy.deepcopy(self.record);r['documents'][0]['sha256']='0'*64
        with self.assertRaises(study.StudyFail):self.validate(r)
    def test_missing_reading_rejected(self):
        r=copy.deepcopy(self.record);r['documents'].pop()
        with self.assertRaises(study.StudyFail):self.validate(r)
    def test_wrong_rule_rejected(self):
        r=copy.deepcopy(self.record);r['answers']['Q02_default_mode']='LIVE_LANE'
        with self.assertRaises(study.StudyFail):self.validate(r)
    def test_stale_governing_document_rejected(self):
        self.write('AGENTS.md','Changed governing fixture\n');self.commit()
        with self.assertRaises(study.StudyFail):self.validate(reference=self.git('rev-parse','HEAD'))
    def test_absent_git_source_rejected(self):
        self.git('rm','AGENT_INBOX/07_LEARNING_GATE.md');self.commit()
        with self.assertRaises(study.StudyFail):self.validate(reference=self.git('rev-parse','HEAD'))
    def test_wrong_identity_rejected(self):
        r=copy.deepcopy(self.record);r['agent_id']='impostor'
        with self.assertRaises(study.StudyFail):self.validate(r)
    def test_duplicate_teachback_rejected(self):
        r=copy.deepcopy(self.record);r['teachback']['no_write_tool_mobile']=r['teachback']['untrusted_governor_message']
        with self.assertRaises(study.StudyFail):self.validate(r)

class InboxTests(Fixture):
    def test_complete_six_file_package(self):
        sub=self.package();self.assertEqual(inbox.validate_submission(self.repo,sub)['agent_id'],'fixture-agent')
    def test_missing_study_record(self):
        sub=self.package();(self.repo/sub/'STUDY_RECORD.json').unlink()
        with self.assertRaises(inbox.GateFail):inbox.validate_submission(self.repo,sub)
    def test_binary_without_grant(self):
        sub=self.package();(self.repo/sub/'opaque.bin').write_bytes(b'\x00\xff')
        with self.assertRaises(inbox.GateFail):inbox.validate_submission(self.repo,sub)
    def test_symlink_rejected(self):
        sub=self.package();(self.repo/sub/'escape').symlink_to(self.repo/'AGENTS.md')
        with self.assertRaises(inbox.GateFail):inbox.validate_submission(self.repo,sub)
    def test_asset_without_exact_grant(self):
        sub=self.package();self.write(sub+'/ASSETS/icon.png','synthetic image')
        self.write(sub+'/ASSET_MANIFEST.json','{}')
        with self.assertRaises(inbox.GateFail):inbox.validate_submission(self.repo,sub)
    def test_strict_gate_rejects_product_write(self):
        self.package();self.write('Example.swift','let value=1\n');self.commit()
        from argparse import Namespace
        with self.assertRaises(inbox.GateFail):
            inbox.validate_strict(self.repo,Namespace(base=self.base,head=self.git('rev-parse','HEAD'),
                head_ref='agent-drop/fixture-agent/fixture-task',pr_title='[AGENT-DROP] fixture-agent / fixture-task'))
    def test_old_submission_not_retroactively_selected(self):
        sub=self.package();self.commit();old=self.git('rev-parse','HEAD')
        self.write(sub+'/RISKS.md','Updated historical fixture\n');self.commit()
        self.assertEqual(new_roots(self.repo,old,self.git('rev-parse','HEAD')),set())
    def test_new_submission_selected(self):
        sub=self.package();self.commit()
        self.assertEqual(new_roots(self.repo,self.base,self.git('rev-parse','HEAD')),{sub})
    def test_new_drop_passes_with_detached_head_and_explicit_pr_base(self):
        self.package();self.commit();head=self.git('rev-parse','HEAD')
        self.git('checkout','--detach','-q',head);self.git('branch','-D','main')
        # Put the unmodified imported tools in the fixture, as CI would see them.
        for name in ['study_gate.py','inbox_gate.py']:
            self.write('AGENT_INBOX/tools/'+name,(ROOT/'AGENT_INBOX/tools'/name).read_text())
        self.cli('tools/governance/check_new_submissions.py','--repo',str(self.repo),
                 '--base',self.base,'--head',head,'--head-ref','agent-drop/fixture-agent/fixture-task',
                 '--pr-title','[AGENT-DROP] fixture-agent / fixture-task')

class SessionTests(Fixture):
    def session(self):
        self.cli('tools/governance/governance_cli.py','init-task','--task-id','fixture-task',
                 '--profile','ENGINEER','--lane','test','--branch','agent-drop/fixture-agent/fixture-task')
    def test_pending_session_is_not_pass(self):
        self.session();self.cli('tools/governance/governance_cli.py','check','--task-id','fixture-task',expected=1)
    def test_reinitialization_refused(self):
        self.session()
        self.cli('tools/governance/governance_cli.py','init-task','--task-id','fixture-task',
                 '--profile','ENGINEER','--lane','test','--branch','other',expected=2)
    def test_complete_ack_and_epoch_check(self):
        self.session();readset=json.loads((self.repo/'governance/MANDATORY_READ_SET.json').read_text())
        files=list(dict.fromkeys(readset['common']+readset['optional_if_exchange_installed']))
        args=['ack','--task-id','fixture-task','--confirm-actually-read']
        for p in files:args+=['--file-read',p]
        self.cli('tools/governance/governance_cli.py',*args)
        self.cli('tools/governance/governance_cli.py','check','--task-id','fixture-task')
        seal=json.loads((self.repo/'governance/CONSTITUTION_SEAL.json').read_text());seal['governance_epoch']=2
        self.write('governance/CONSTITUTION_SEAL.json',json.dumps(seal))
        self.cli('tools/governance/governance_cli.py','check','--task-id','fixture-task',expected=2)

class ExchangeTests(Fixture):
    def sender(self,task):
        return ['--task-id',task,'--session-id','fixture-session','--profile','ENGINEER','--lane','test']
    def scan(self,task,expected):
        return self.cli('tools/governance/agent_exchange.py','scan','--task-id',task,
                        '--profile','ENGINEER','--lane','test',expected=expected)
    def test_broadcast_receipts_are_per_recipient(self):
        out=self.cli('tools/governance/agent_exchange.py','send',*self.sender('sender'),
                     '--subject','Synthetic required read','--body','Synthetic test only',
                     '--type','REQUIRED_READ','--priority','P1','--target','ALL')
        mid=out.split('MESSAGE_ID=')[1].splitlines()[0]
        self.scan('recipient-a',3);self.scan('recipient-b',3);self.scan('sender',0)
        self.cli('tools/governance/agent_exchange.py','receipt',*self.sender('recipient-a'),
                 '--message-id',mid,'--status','READ')
        self.scan('recipient-a',0);self.scan('recipient-b',3)
    def test_required_response_needs_linked_reply(self):
        out=self.cli('tools/governance/agent_exchange.py','send',*self.sender('sender'),
                     '--subject','Synthetic question','--body','Synthetic test only',
                     '--type','REQUIRED_RESPONSE','--priority','P0','--target','TASK:recipient')
        mid=out.split('MESSAGE_ID=')[1].splitlines()[0]
        self.cli('tools/governance/agent_exchange.py','receipt',*self.sender('recipient'),
                 '--message-id',mid,'--status','READ')
        self.scan('recipient',3)
        self.cli('tools/governance/agent_exchange.py','receipt',*self.sender('recipient'),
                 '--message-id',mid,'--status','RESPONDED',expected=2)
        out=self.cli('tools/governance/agent_exchange.py','reply',*self.sender('recipient'),
                     '--in-reply-to',mid,'--subject','Synthetic reply','--body','Verified synthetic response')
        rid=out.split('MESSAGE_ID=')[1].splitlines()[0]
        self.cli('tools/governance/agent_exchange.py','receipt',*self.sender('recipient'),
                 '--message-id',mid,'--status','RESPONDED','--response-message-id',rid)
        self.scan('recipient',0)
    def test_governor_prefix_does_not_grant_assignment(self):
        self.cli('tools/governance/agent_exchange.py','send','--task-id','fake-governor',
                 '--session-id','fixture-session','--profile','INTEGRATION_GOVERNOR','--lane','test',
                 '--governor-identity','VEILLINK-IG-001','--subject','Synthetic assignment',
                 '--body','No grant exists','--type','TASK_ASSIGNMENT','--target','TASK:recipient',expected=2)

class MemoryTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.store=memory.Store(self.temp.name);self.addCleanup(self.store.close)
    def test_sleep_stays_candidate(self):
        p=Path(self.temp.name)/'synthetic.json'
        p.write_text(json.dumps({'sessions':[{'session_id':'fixture-session','task_id':'fixture-task',
                    'events':[{'type':'verified_result','text':'Synthetic test completed','evidence_ref':'fixture:result'}]}]}))
        rows=self.store.sleep(p)
        self.assertEqual(rows[0]['candidate']['bank'],'M07')
        self.assertEqual(self.store.query(status='active'),[])
        self.assertTrue(self.store.verify()['ok'])
    def test_unconfirmed_instruction_is_candidate(self):
        item=self.store.remember('Synthetic instruction only','fixture:owner-request')
        self.assertEqual(item['status'],'candidate')
    def test_agent_cannot_promote_candidate(self):
        item=self.store.add('M07','note','Synthetic sourced candidate','fixture:source')
        with self.assertRaises(ValueError):self.store.approve(item['id'],by='agent')
    def test_private_key_rejected(self):
        with self.assertRaises(ValueError):self.store.remember('-----BEGIN PRIVATE KEY-----','fixture:source')

class PreservationTests(Fixture):
    def lock(self):
        self.write('governance/zeo_foundation/SOURCE_LOCK.json',json.dumps({'files':[]}))
    def test_existing_blobs_and_modes_preserved(self):
        self.lock();self.commit();self.assertGreater(additive_check(self.repo,self.base,'HEAD')['added_files'],0)
    def test_existing_file_change_is_rejected(self):
        self.lock();self.write('AGENTS.md','Unwanted replacement\n');self.commit()
        with self.assertRaises(ValueError):additive_check(self.repo,self.base,'HEAD')
    def test_existing_file_deletion_is_rejected(self):
        self.lock();self.git('rm','AGENTS.md');self.commit()
        with self.assertRaises(ValueError):additive_check(self.repo,self.base,'HEAD')

if __name__=='__main__':unittest.main()
