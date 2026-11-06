from pathlib import Path
import json, hashlib, subprocess, zipfile, html, shutil, math
from concurrent.futures import ThreadPoolExecutor
from PIL import Image

ROOT=Path(__file__).resolve().parent.parent if Path(__file__).parent.name=='sources' else Path('/workspace/outputs/Veilopoly_Astra_ART_B01_v1')
ROOT.mkdir(parents=True,exist_ok=True)
NAVY='#0B1420'; PANEL='#152533'; GOLD='#D4B77C'; TEAL='#84B8BD'; INK='#EAF0F2'; MUTED='#A6B8C4'; RED='#E79B98'
PAPER='#F1EDDD'; PRINT='#314C57'; FAINT='#B7BEAF'
PROPERTY_COLORS={'umber':'#8A5D48','sky':'#69A7BE','orchid':'#AD729C','amber':'#D99A4E','coral':'#C96865','ochre':'#B5A64B','jade':'#5E9C81','cobalt':'#537EB3'}
records=[]; layouts={}; jobs=[]
DEFS='''<defs>
<linearGradient id="metal" x2="0.8" y2="1"><stop stop-color="#293E4D"/><stop offset=".48" stop-color="#162735"/><stop offset="1" stop-color="#101D29"/></linearGradient>
<linearGradient id="gold" x2=".3" y2="1"><stop stop-color="#E1CCA0"/><stop offset=".5" stop-color="#C9AC74"/><stop offset="1" stop-color="#AD8955"/></linearGradient>
<linearGradient id="glass" x2="1" y2="1"><stop stop-color="#A6CDDA" stop-opacity=".18"/><stop offset=".6" stop-color="#345361" stop-opacity=".12"/><stop offset="1" stop-color="#92B6BD" stop-opacity=".06"/></linearGradient>
<radialGradient id="ambient"><stop stop-color="#233B48"/><stop offset="1" stop-color="#0B1420"/></radialGradient>
<pattern id="grain" width="4" height="4" patternUnits="userSpaceOnUse"><path d="M0 .5H4" stroke="#CBDFE4" stroke-opacity=".025"/></pattern>
<linearGradient id="paper" x2=".4" y2="1"><stop stop-color="#F7F3E5"/><stop offset="1" stop-color="#E7E6D3"/></linearGradient>
<pattern id="paperfiber" width="12" height="12" patternUnits="userSpaceOnUse"><path d="M1 2h3m3 5h4M2 11h2" stroke="#5B796C" stroke-width=".35" opacity=".1"/></pattern>
</defs>'''
def rect(x,y,w,h,fill,rx=0,stroke='none',sw=1,extra=''):
 return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" {extra}/>'
def line(x,y,x2,y2,color=TEAL,opacity=1):
 return f'<path d="M{x} {y}H{x2}" stroke="{color}" opacity="{opacity}"/>' if y==y2 else f'<path d="M{x} {y}L{x2} {y2}" stroke="{color}" opacity="{opacity}"/>'
def text(x,y,s,size=14,color=INK,weight=400,anchor='start',spacing=0):
 return f'<text x="{x}" y="{y}" fill="{color}" font-family="Noto Sans CJK SC, sans-serif" font-size="{size}" font-weight="{weight}" text-anchor="{anchor}" letter-spacing="{spacing}">{html.escape(s)}</text>'
def group(x,y,body,scale=1): return f'<g transform="translate({x} {y}) scale({scale})">{body}</g>'
def svg(w,h,body): return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{DEFS}{body}</svg>'
def surface(w,h,accent=GOLD):
 return rect(.5,.5,w-1,h-1,'url(#metal)',16,'#405564')+rect(1,1,w-2,h-2,'url(#grain)',16)+rect(5,5,w-10,h-10,'none',12,'#90AEB8',.5, 'opacity=".16"')+line(23,1,w-23,1,'#A4BEC6',.7)+line(24,h-1,68,h-1,accent,.85)
ICONS={
'purchase':'M7 13l9-7 9 7v14H7z M12 27v-9h8v9 M4 14l12-10 12 10',
'auction':'M8 7l5-5 11 11-5 5z M13 14L4 23 M3 27h18 M5 24h14v3',
'trade':'M4 10h23l-5-5 M27 10l-5 5 M28 22H5l5-5 M5 22l5 5',
'bank':'M3 10l13-7 13 7z M4 28h24 M6 24h20 M8 13v8 M16 13v8 M24 13v8',
'settlement':'M10 4h12v9a6 6 0 0 1-12 0z M10 7H5v5a6 6 0 0 0 6 6 M22 7h5v5a6 6 0 0 1-6 6 M16 19v7 M10 28h12',
'wallet':'M5 8h20v18H5z M5 8l16-4v4 M20 14h8v7h-8z M24 17v1',
'location':'M16 29S6 18 6 12a10 10 0 0 1 20 0c0 6-10 17-10 17z M16 9a3 3 0 1 0 0 6a3 3 0 1 0 0-6',
'lock':'M9 14v-5a7 7 0 0 1 14 0v5 M6 14h20v15H6z M16 20v4',
'bankrupt':'M5 5h22v22H5z M8 9l5 5 5-3 6 11 M18 22h6v-6',
'turn':'M8 8a11 11 0 1 1-3 12 M8 3v6H2 M14 11l7 5-7 5z',
'period':'M5 6h22v23H5z M10 3v6 M22 3v6 M5 12h22 M10 18h3 M19 18h3 M10 23h3',
'check':'M5 16l7 7L27 8',
'error':'M16 3L30 28H2z M16 11v8 M16 23v1',
'pending':'M16 3a13 13 0 1 1-13 13 M16 7v10l6 3',
'plus':'M16 6v20 M6 16h20',
'minus':'M6 16h20',
'close':'M7 7l18 18 M25 7L7 25',
'chevron':'M12 7l9 9-9 9',
'deposit':'M4 23h24v6H4z M16 2v17 M10 13l6 6 6-6',
'loan':'M5 7h22v19H5z M5 13h22 M10 20h5 M23 17v6 M20 20h6',
'investment':'M4 27h24 M8 23v-7 M16 23V9 M24 23V3',
'shield':'M16 3l11 5v9c0 6-11 12-11 12S5 23 5 17V8z M11 15l4 4 7-8',
'card':'M7 4h18v25H7z M11 9h10 M11 23h10 M16 12l4 4-4 4-4-4z',
'sound':'M4 12h6l8-7v22l-8-7H4z M23 10q8 6 0 12',
'info':'M16 2a14 14 0 1 0 0 28a14 14 0 1 0 0-28 M16 14v10 M16 8v1',
'mortgage':'M5 13l11-9 11 9 M8 12v15h16V12 M12 20h8',
'star':'M16 3l4 9 10 1-8 7 2 10-8-5-8 5 2-10-8-7 10-1z',
'player':'M16 4a5 5 0 1 0 0 10a5 5 0 1 0 0-10 M5 29v-5a11 11 0 0 1 22 0v5',
}
def icon(name,color=GOLD): return f'<path d="{ICONS[name]}" fill="none" stroke="{color}" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round"/>'
def rosette(cx,cy,r,color=PRINT,opacity=.24):
 # Original guilloche-style line geometry, not a copied banknote or currency seal.
 b=''
 for offset in [0,.65,1.3]:
  points=[]
  for i in range(481):
   t=i*math.tau/480; rr=r*(.89+.075*math.cos(18*t+offset))
   points.append(f'{cx+rr*math.cos(t):.2f},{cy+rr*math.sin(t):.2f}')
  b+=f'<polyline points="{" ".join(points)}" fill="none" stroke="{color}" stroke-width=".45" opacity="{opacity}"/>'
 for rr in [.65,.71,1]: b+=f'<circle cx="{cx}" cy="{cy}" r="{r*rr}" fill="none" stroke="{color}" stroke-width=".65" opacity="{opacity}"/>'
 return b
def paper(w,h,c=PRINT,band=0):
 b=rect(.5,.5,w-1,h-1,'url(#paper)',8,c,.8)+rect(1,1,w-2,h-2,'url(#paperfiber)',8)
 b+=rect(7,7,w-14,h-14,'none',4,c,.6)+rect(10,10,w-20,h-20,'none',2,c,.35)
 if band: b+=rect(11,11,w-22,band,c,2)
 for x,y,sx,sy in [(14,14,1,1),(w-14,14,-1,1),(14,h-14,1,-1),(w-14,h-14,-1,-1)]:
  b+=f'<path d="M{x} {y+10*sy}V{y}h{10*sx}" fill="none" stroke="{c}" stroke-width="1"/>'
 return b
def voucher(w=320,h=144,c=PROPERTY_COLORS['cobalt']):
 b=paper(w,h,c)+rosette(h*.47,h/2,h*.36,c,.5)
 b+=group(h*.47-16,h/2-16,icon('bank',c))
 # Hatching stays to the margins so program-rendered values remain readable.
 for y in range(23,int(h)-18,5):
  b+=line(w-48,y,w-16,y,c,.15)
 rule_top=17 if h<100 else 29; rule_bottom=h-16 if h<100 else h-29
 b+=line(h*.9,rule_top,w-60,rule_top,c,.4)+line(h*.9,rule_bottom,w-60,rule_bottom,c,.4)
 return b
def deed(w=288,h=360,c=PROPERTY_COLORS['jade']):
 b=paper(w,h,c,14)+rosette(w/2,83,43,c,.16)+group(w/2-22,61,icon('purchase',c),44/32)
 b+=line(24,130,w-24,130,c,.5)
 for y in range(193,int(h)-30,38): b+=line(24,y,w-24,y,c,.18)
 return b
def ticket(w=320,h=160):
 b=paper(w,h,PRINT)+rosette(48,h/2,34,PRINT,.3)+group(32,h/2-16,icon('auction',PRINT))
 b+=f'<path d="M91 12V{h-12}" stroke="{PRINT}" opacity=".35" stroke-dasharray="2 4"/>'+line(108,42,w-22,42,PRINT,.3)+line(108,h-42,w-22,h-42,PRINT,.3)
 return b
def offer(w=288,h=188):
 b=paper(w,h,PRINT)+rect(11,11,w/2-14,7,PROPERTY_COLORS['jade'],1)+rect(w/2+3,11,w/2-14,7,PROPERTY_COLORS['cobalt'],1)
 b+=line(w/2,30,w/2,h-24,PRINT,.2)
 for xx in [w*.25,w*.75]: b+=group(xx-14,48,icon('card',PRINT),28/32)+line(xx-w*.16,117,xx+w*.16,117,PRINT,.2)
 b+=f'<circle cx="{w/2}" cy="{h/2}" r="19" fill="{PAPER}" stroke="{FAINT}"/>'+group(w/2-12,h/2-12,icon('trade',PRINT),24/32)
 return b
def certificate(w=320,h=280):
 b=paper(w,h,'#927545')+rosette(w/2,54,34,'#927545',.45)+group(w/2-16,38,icon('settlement','#927545'))
 b+=line(28,130,w-28,130,'#927545',.45)+line(40,h-37,w-40,h-37,'#927545',.35)
 for side in [-1,1]:
  for i in range(5):
   xx=w/2+side*(43+i*2); yy=53+i*8
   b+=f'<ellipse cx="{xx}" cy="{yy}" rx="3" ry="6" fill="#927545" opacity=".45" transform="rotate({side*(28+i*10)} {xx} {yy})"/>'
 return b
def button(w=240,h=48,tone='primary',state='normal'):
 fill='url(#gold)' if tone=='primary' else 'url(#glass)'; stroke='#D8C08D' if tone=='primary' else '#557080'
 if state=='pressed': fill='#9D7D4B' if tone=='primary' else '#344D5C'
 if state=='disabled': fill='#23303A'; stroke='#455460'
 b=rect(.5,.5,w-1,h-1,fill,10,stroke)+line(12,2,w-12,2,'#F2E5C9',.25)
 if state=='loading': b+=group(14,(h-22)/2,icon('pending',NAVY if tone=='primary' else INK),22/32)
 if state=='disabled': b+=group(14,(h-20)/2,icon('lock',MUTED),20/32)
 return b
def export(alias,path,w,h,body,kind='component',state='normal',insets=None,density=2,slots=None):
 p=ROOT/(path+'.svg'); p.parent.mkdir(parents=True,exist_ok=True); p.write_text(svg(w,h,body))
 png=ROOT/(path+'.png'); jobs.append((p,png,w*density,h*density))
 records.append(dict(alias=alias,path=str(png.relative_to(ROOT)),source=str(p.relative_to(ROOT)),logical_size_pt=[w,h],pixel_dimensions=[w*density,h*density],density=density,kind=kind,state=state,anchor_top_left=[0,0],spritekit_anchor=[0,1],alpha=True,transparent_region='Outside silhouette; see alpha_bounds_px after render',resize_mode='nine_slice' if insets else 'aspect_fit',cap_insets_pt=insets,cap_insets_px=[i*density for i in insets] if insets else None,dynamic_text_baked=False,text_slots=slots or [],K1_delta='NEW',target_scene=['BUY','AUCTION','TRADE','BANK','SETTLEMENT'],original_asset_url=None,source_license='Original commissioned vector artwork; Owner may use, modify and distribute; no third-party artwork',provenance='sources/build_assets.py — original procedural SVG geometry'))

for name in ICONS: export('astra.icon.'+name,'ui/icons/'+name,32,32,icon(name),'icon',density=3)
for tone in ['primary','secondary']:
 for state in ['normal','pressed','disabled','loading']:
  export(f'astra.button.{tone}.{state}',f'ui/components/button-{tone}-{state}',240,48,button(tone=tone,state=state),state=state,insets=[12,42,12,12],slots=[dict(key='label',rect=[44,8,180,32],font_pt=14)])
for typ,color in [('action',GOLD),('glass',TEAL),('light','#8A703F')]:
 b=surface(320,320,color) if typ!='light' else rect(.5,.5,319,319,'#E4E9E7',16,'#A9BABE')+line(20,2,300,2,'#FFFFFF',.8)
 export('astra.panel.'+typ,'ui/panels/'+typ,320,320,b,'panel',insets=[24,24,24,24])
export('astra.panel.inset','ui/panels/inset',240,72,rect(.5,.5,239,71,'#0D1B27',10,'#344A59')+line(14,1,226,1,'#78929C',.15),'panel',insets=[12,12,12,12])
export('astra.texture.brushed','ui/panels/brushed-metal',64,64,rect(0,0,64,64,PANEL)+rect(0,0,64,64,'url(#grain)'),'texture',density=2)
export('astra.modal.scrim','ui/panels/modal-scrim',32,32,rect(0,0,32,32,'#030911',extra='fill-opacity=".76"'),'scrim',insets=[0,0,0,0],density=1)
for state,c in [('normal','#405564'),('current',GOLD),('jailed',TEAL),('bankrupt',RED)]:
 b=surface(180,68,c)+rect(10,13,34,34,'#1C3344',9,c)
 b+=group(17,20,icon({'normal':'player','current':'turn','jailed':'lock','bankrupt':'bankrupt'}[state],c),20/32)
 if state=='current': b+=rect(55,1,100,2,GOLD,1)
 export('astra.hud.player.'+state,'ui/components/player-'+state,180,68,b,state=state,insets=[16,52,16,16],slots=[dict(key='name',rect=[54,8,116,20],font_pt=12),dict(key='cash',rect=[54,28,116,24],font_pt=18),dict(key='position_status',rect=[54,50,116,16],font_pt=11)])
for state,c,ic in [('positive',TEAL,'plus'),('negative',RED,'minus'),('confirmed',TEAL,'check'),('error',RED,'error'),('loading',GOLD,'pending'),('empty',MUTED,'info')]:
 b=rect(.5,.5,239,47,'#172A37',10,c)+group(14,12,icon(ic,c),24/32)
 export('astra.feedback.'+state,'ui/components/feedback-'+state,240,48,b,state=state,insets=[12,44,12,12],slots=[dict(key='message_or_delta',rect=[48,8,180,32],font_pt=14)])
export('astra.card.face','ui/panels/card-face',280,360,surface(280,360)+rect(12,12,256,336,'none',10,'#76674D',.7)+group(120,24,icon('card'),1.25)+line(26,83,254,83,GOLD,.3),'panel',insets=[88,26,26,26],slots=[dict(key='card_title',rect=[24,96,232,32],font_pt=20),dict(key='card_body',rect=[24,144,232,150],font_pt=16)])
export('astra.hud.period','ui/components/period',180,40,rect(.5,.5,179,39,'#152935',20,'#44606D')+group(12,9,icon('period',TEAL),22/32),insets=[18,42,18,18],slots=[dict(key='period_status',rect=[42,6,124,28],font_pt=12)])
export('astra.hud.capsule.sample','ui/components/capsule-sample',93,44,rect(.5,.5,92,43,'#EDF0EB',22,'#B8C5C8')+line(46.5,10,46.5,34,'#9FAFB4',.6)+''.join(f'<circle cx="{x}" cy="22" r="2" fill="#15212C"/>' for x in [17,23,29])+'<circle cx="70" cy="22" r="10" fill="none" stroke="#15212C" stroke-width="2"/><circle cx="70" cy="22" r="4" fill="#15212C"/>','reference_only')

PHASES={'BUY':('地产购入','purchase','取得下一块资产'), 'AUCTION':('公开拍卖','auction','每一次出价，都要有分寸'), 'TRADE':('玩家交易','trade','公平交换，重新定义版图'), 'BANK':('银行与金融','bank','仅限不可兑换的游戏积分'), 'SETTLEMENT':('本局结算','settlement','每一步选择，都留下回响')}
def emblem(name,w=288):
 c={'BUY':PROPERTY_COLORS['jade'],'AUCTION':'#966C46','TRADE':PRINT,'BANK':PROPERTY_COLORS['cobalt'],'SETTLEMENT':'#927545'}[name]
 b=paper(w,84,c)+rosette(42,42,29,c,.38)+group(28,28,icon(PHASES[name][1],c),28/32)+line(82,24,w-22,24,c,.3)+line(82,60,w-22,60,c,.3)
 return b
for phase in PHASES:
 export('astra.phase.'+phase.lower()+'.ornament','ui/components/'+phase.lower()+'-ornament',288,84,emblem(phase),'ornament',slots=[dict(key='property_or_context_title',rect=[84,29,184,26],font_pt=16)])

for name,c in PROPERTY_COLORS.items():
 export('astra.deed.'+name,'ui/tabletop/deed-'+name,288,360,deed(c=c),'card',slots=[dict(key='property_name',rect=[24,137,240,38],font_pt=20),dict(key='price_rent_owner',rect=[24,179,240,136],font_pt=14)])
for name in ['cobalt','jade','coral','amber']:
 export('astra.voucher.'+name,'ui/tabletop/voucher-'+name,320,144,voucher(c=PROPERTY_COLORS[name]),'card',slots=[dict(key='currency_context',rect=[132,34,126,20],font_pt=12),dict(key='amount',rect=[132,58,126,32],font_pt=24),dict(key='status',rect=[132,94,126,18],font_pt=11)])
export('astra.auction.ticket','ui/tabletop/auction-ticket',320,160,ticket(),'card',slots=[dict(key='property_name',rect=[108,49,188,26],font_pt=16),dict(key='current_bid',rect=[108,80,188,32],font_pt=24)])
export('astra.trade.offer','ui/tabletop/trade-offer',288,188,offer(),'card',slots=[dict(key='offered_assets',rect=[20,82,102,30],font_pt=14),dict(key='requested_assets',rect=[166,82,102,30],font_pt=14),dict(key='offered_cash',rect=[20,128,102,32],font_pt=18),dict(key='requested_cash',rect=[166,128,102,32],font_pt=18)])
export('astra.settlement.certificate','ui/tabletop/settlement-certificate',320,280,certificate(),'card',slots=[dict(key='winner',rect=[28,96,264,28],font_pt=20),dict(key='net_worth',rect=[28,149,264,40],font_pt=28),dict(key='summary',rect=[28,200,264,36],font_pt=13)])
export('astra.texture.paper','ui/tabletop/paper-fiber',64,64,rect(0,0,64,64,'url(#paper)')+rect(0,0,64,64,'url(#paperfiber)'),'texture')

def compact(phase):
 w=256;h=174
 if phase=='BUY':
  c=PROPERTY_COLORS['jade']; b=paper(w,h,c,10)+rosette(39,49,26,c,.32)+group(26,36,icon('purchase',c),26/32)
  for yy in [77,108,133,158]: b+=line(18,yy,238,yy,c,.22)
 elif phase=='AUCTION':
  b=paper(w,h,PRINT)+rosette(32,36,20,PRINT,.3)+group(20,24,icon('auction',PRINT),24/32)+line(58,55,236,55,PRINT,.25)
  b+=rect(62,118,132,44,'#FCFAF0',6,PRINT,.8)
  for xx,name in [(12,'minus'),(200,'plus')]: b+=rect(xx,118,44,44,'#DCE1D1',6,PRINT,.5)+group(xx+12,130,icon(name,PRINT),20/32)
 elif phase=='TRADE': b=offer(w,h)
 elif phase=='BANK':
  b=voucher(w,86,PROPERTY_COLORS['cobalt'])
  for xx,name in [(0,'deposit'),(134,'loan')]: b+=rect(xx,98,122,76,'#11222F',8,'#405968')+group(xx+12,110,icon(name,TEAL),20/32)
 else:
  b=paper(w,h,'#927545')+rosette(128,38,27,'#927545',.45)+group(115,25,icon('settlement','#927545'),26/32)
  b+=line(24,87,232,87,'#927545',.35)+line(24,139,232,139,'#927545',.3)
 return b

HERO_SLOTS={
 'BUY':[('property_name',[76,44,160,24]),('price',[142,82,94,24]),('cash_after',[142,108,94,24]),('rent',[142,134,94,24])],
 'AUCTION':[('property_name',[60,22,176,28]),('highest_bid',[146,62,90,24]),('leading_player',[146,87,90,24]),('bid_input',[72,124,112,32])],
 'TRADE':[('my_assets',[20,83,84,28]),('their_assets',[152,83,84,28]),('my_cash',[20,126,84,32]),('their_cash',[152,126,84,32])],
 'BANK':[('wallet',[88,34,116,28]),('deposit',[12,142,98,26]),('loan',[146,142,98,26])],
 'SETTLEMENT':[('winner',[24,64,208,22]),('net_worth',[24,109,208,29]),('property_count',[144,144,88,24])]
}
for phase in PHASES:
 export('astra.hero.'+phase.lower(),'ui/tabletop/hero-'+phase.lower(),256,174,compact(phase),'card',slots=[dict(key=key,rect=box,font_pt=16) for key,box in HERO_SLOTS[phase]])
 if phase=='AUCTION': records[-1]['hit_targets_local_pt']={'decrease_bid':[12,118,44,44],'bid_input':[62,118,132,44],'increase_bid':[200,118,44,44]}

def hero_preview(phase):
 b=compact(phase)
 def t(x,y,s,size=12,c=PRINT,anchor='start'): return text(x,y,s,size,c,500,anchor)
 if phase=='BUY':
  b+=t(76,41,'产权凭证',10)+t(76,61,'—',18)
  for yy,label in [(101,'购入价格'),(126,'购买后余额'),(151,'基础租金')]: b+=t(18,yy,label)+t(236,yy,'—',16,anchor='end')
 elif phase=='AUCTION':
  b+=t(60,36,'竞价标的 · —',13)+t(18,80,'当前最高出价')+t(236,80,'—',18,anchor='end')+t(18,105,'领先玩家')+t(236,105,'—',14,anchor='end')+t(128,146,'—',22,anchor='middle')
 elif phase=='TRADE':
  for xx,label in [(64,'我方提供'),(192,'对方提供')]: b+=t(xx,36,label,12,anchor='middle')+t(xx,104,'地产 · —',12,anchor='middle')+t(xx,147,'积分 · —',14,anchor='middle')
 elif phase=='BANK':
  b+=t(88,30,'可用游戏积分',10)+t(88,58,'—',22)
  for xx,label in [(0,'活期存款'),(134,'未偿贷款')]: b+=t(xx+42,125,label,11,INK)+t(xx+12,161,'—',20,INK)
 else:
  b+=t(128,81,'获胜玩家 · —',13,anchor='middle')+t(128,106,'净资产',11,anchor='middle')+t(128,132,'—',24,anchor='middle')+t(24,161,'地产总数')+t(232,161,'—',16,anchor='end')
 return b

def viewport(x,y,w,h):
 # Layout-only scene locator. No tile artwork, model, or Kimi asset replacement.
 b=rect(x,y,w,h,'#0D1C27',16,'#2E4757')
 side=min(w-40,h-30); bx=x+(w-side)/2; by=y+(h-side)/2
 b+=rect(bx,by,side,side,'none',5,'#35515F',.8)+rect(bx+side*.12,by+side*.12,side*.76,side*.76,'none',3,'#2A424F',.7)
 for t in range(1,10):
  d=side*t/10
  b+=line(bx+d,by,bx+d,by+side*.12,'#2A424F',.7)+line(bx+d,by+side*.88,bx+d,by+side,'#2A424F',.7)
  b+=line(bx,by+d,bx+side*.12,by+d,'#2A424F',.7)+line(bx+side*.88,by+d,bx+side,by+d,'#2A424F',.7)
 b+=text(x+w/2,y+h/2-6,'VEILOPOLY',22,'#597582',500,'middle',4)+text(x+w/2,y+h/2+20,'KIMI · 完整棋盘接入区域',11,'#67828F',400,'middle')
 return b

def screen(phase,W,H):
 tablet=H>500; safe=24 if tablet else 44; top=12 if tablet else 6
 right=400 if tablet else 288; rx=W-safe-right; lx=safe; boardw=rx-lx-16
 header=56; footer=88 if tablet else 84; vy=top+header; vh=H-vy-footer-12
 b=rect(0,0,W,H,'url(#ambient)')+rect(0,0,W,H,'url(#grain)')
 b+=text(lx,top+22,'VEILOPOLY',18,GOLD,600,spacing=3)+text(lx,top+41,'THE STRATEGY OF OWNERSHIP',8,MUTED,spacing=2)
 b+=text(rx,top+23,phase,14,GOLD,600,spacing=2)+text(rx,top+42,'策略桌游 / '+PHASES[phase][0],11,MUTED)
 b+=group(W-safe-93,top,rect(.5,.5,92,43,'#EDF0EB',22)+line(46.5,10,46.5,34,'#9FAFB4',.6)+''.join(f'<circle cx="{a}" cy="22" r="2" fill="#15212C"/>' for a in [17,23,29])+'<circle cx="70" cy="22" r="10" fill="none" stroke="#15212C" stroke-width="2"/><circle cx="70" cy="22" r="4" fill="#15212C"/>')
 b+=viewport(lx,vy,boardw,vh)
 # Four compact data-driven HUD positions, visually distinct states.
 gap=6; hw=(boardw-3*gap)/4; hy=H-footer
 for i,(c,ic,st) in enumerate([(GOLD,'turn','当前回合'),(TEAL,'location','位置 —'),(MUTED,'lock','监狱'),(RED,'bankrupt','已破产')]):
  xx=lx+i*(hw+gap); b+=rect(xx,hy,hw,62,'#142734',10,c,.7)+group(xx+9,hy+8,icon(ic,c),16/32)+text(xx+30,hy+21,'玩家 —',11,INK)+text(xx+9,hy+41,'—',18,c,500)+text(xx+9,hy+55,st,10,MUTED)
 b+=group(rx,vy,surface(right,H-vy-22))
 y=vy+24
 b+=text(rx+18,y,PHASES[phase][0],22,INK,500)+text(rx+18,y+19,PHASES[phase][2],10,MUTED)
 ey=y+32; bodytop=ey; actionY=H-22-16-44
 # Runtime content is scrollable only within right-panel body; footer remains fixed.
 rows={'BUY':[('地产分组','—'),('当前持有人','—'),('购买后状态','待确认')], 'AUCTION':[('竞价状态','等待出价'),('可用积分','—'),('最低加价','—')], 'TRADE':[('交易对象','—'),('确认状态','等待确认'),('待交换地产','—')], 'BANK':[('贷款 / 到期周期','— / —'),('抵押地产','—'),('金融规则','待批准')], 'SETTLEMENT':[('排名 / 玩家','— / —'),('现金','—'),('已完成回合','—')]}[phase]
 clip=f'clip-{phase}-{W}'; b+=f'<defs><clipPath id="{clip}">{rect(rx+16,bodytop-4,right-32,max(0,actionY-bodytop-12),'white')}</clipPath></defs><g clip-path="url(#{clip})">'
 scale=(right-32)/256
 b+=group(rx+16,ey,hero_preview(phase),scale)
 slots=[dict(key=key,rect=[rx+16+box[0]*scale,ey+box[1]*scale,box[2]*scale,box[3]*scale],binding=key,value='runtime') for key,box in HERO_SLOTS[phase]]
 if tablet:
  yy=ey+174*scale+32
  for i,(label,value) in enumerate(rows):
   ry=yy+i*36; b+=text(rx+18,ry,label,13,MUTED)+text(rx+right-18,ry,value,15,INK,500,'end')+line(rx+18,ry+12,rx+right-18,ry+12,'#3D5461',.5)
  yy+=128
  if phase=='BANK':
   b+=text(rx+18,yy,'模拟投资 · 规则待确认',12,GOLD)
   for i,label in enumerate(['托管产品','创投产品','股票产品']):
    b+=rect(rx+18,yy+16+i*48,right-36,44,'#11222F',8,'#344B58')+group(rx+30,yy+26+i*48,icon('lock',MUTED),20/32)+text(rx+62,yy+44+i*48,label+' · 未开放',13,MUTED)
  elif phase=='SETTLEMENT':
   b+=text(rx+18,yy,'资产明细',14,GOLD)
   for i in range(3): b+=line(rx+18,yy+22+i*48,rx+right-18,yy+22+i*48,'#35505E',.5)+text(rx+18,yy+47+i*48,'玩家 —',13,MUTED)+text(rx+right-20,yy+47+i*48,'—',16,INK,500,'end')
  else:
   b+=rect(rx+18,yy,right-36,108,'url(#glass)',10,'#3D5664')+group(rx+32,yy+18,icon('shield',TEAL),24/32)+text(rx+70,yy+36,'核对并确认',14,INK)+text(rx+32,yy+68,'数值由当前游戏状态提供',12,MUTED)+text(rx+32,yy+90,'右侧独立滚动 · 棋盘固定',11,MUTED)
 b+='</g>'
 labels={'BUY':('送入拍卖','购买地产'),'AUCTION':('退出竞价','确认出价'),'TRADE':('取消','确认交易'),'BANK':('查看明细','规则待定'),'SETTLEMENT':('查看回顾','返回大厅')}[phase]
 bw=(right-44)/2
 for i,label in enumerate(labels):
  xx=rx+16+i*(bw+12); state='disabled' if phase=='BANK' and i==1 else 'normal'; tone='secondary' if i==0 else 'primary'
  b+=group(xx,actionY,button(bw,44,tone,state))+text(xx+bw/2+(8 if state=='disabled' else 0),actionY+28,label,13,(MUTED if state=='disabled' else NAVY if i==1 else INK),500,'middle')
 b+=rect(W/2-55,H-9,110,3,'#ADBCC4',2,extra='opacity=".35"')
 layouts[f'{phase}_{W}x{H}']=dict(canvas_pt=[W,H],safe_area_reference=[top,safe,22,safe],board_viewport=[lx,vy,boardw,vh],right_panel=[rx,vy,right,H-vy-22],scroll_clip=[rx+16,bodytop-4,right-32,max(0,actionY-bodytop-12)],fixed_footer=[rx+16,actionY,right-32,44],capsule=[W-safe-93,top,93,44],capsule_targets=[[W-safe-93,top,46,44],[W-safe-46,top,46,44]],hud=[lx,hy,boardw,62],text_slots=slots,board_is_layout_placeholder=True)
 layouts[f'{phase}_{W}x{H}']['hero_asset']='astra.hero.'+phase.lower()
 layouts[f'{phase}_{W}x{H}']['hero_rect']=[rx+16,ey,256*scale,174*scale]
 if phase=='AUCTION': layouts[f'{phase}_{W}x{H}']['bid_controls']={key:[rx+16+box[0]*scale,ey+box[1]*scale,box[2]*scale,box[3]*scale] for key,box in {'decrease_bid':[12,118,44,44],'bid_input':[62,118,132,44],'increase_bid':[200,118,44,44]}.items()}
 return b
for W,H in [(844,390),(852,393),(1180,820)]:
 for phase in PHASES:
  path=f'previews/{"ipad-landscape" if H>500 else "iphone-landscape"}/{phase.lower()}-{W}x{H}'
  p=ROOT/(path+'.svg');p.parent.mkdir(parents=True,exist_ok=True);p.write_text(svg(W,H,screen(phase,W,H)));jobs.append((p,ROOT/(path+'.png'),W*2,H*2))

# Standalone expanded panel compositions: fully editable text layer, no baked dynamic data.
for phase in PHASES:
 b=surface(360,640)+text(24,40,phase,12,GOLD,600,spacing=3)+text(24,78,PHASES[phase][0],26)+group(24,100,hero_preview(phase),312/256)
 for i,label in enumerate({'BUY':['地产分组','当前持有人','持有状态','购买限制'], 'AUCTION':['可用积分','最低加价','竞价状态','竞价规则'], 'TRADE':['交易对象','我方确认','对方确认','交易状态'], 'BANK':['到期周期','抵押地产','应还总额','规则状态'], 'SETTLEMENT':['最终排名','可用积分','已完成回合','回顾']}[phase]):
  yy=346+i*48;b+=text(24,yy,label,13,MUTED)+text(330,yy,'—',20,INK,500,'end')+line(24,yy+16,336,yy+16,'#3B5260',.6)
 b+=group(24,560,button(312,48,'primary','disabled' if phase=='BANK' else 'normal'))+text(180,590,'规则待定' if phase=='BANK' else '确认',15,NAVY if phase!='BANK' else MUTED,500,'middle')
 p=ROOT/f'sources/screens/{phase.lower()}-panel-editable.svg';p.parent.mkdir(parents=True,exist_ok=True);p.write_text(svg(360,640,b))

# One review sheet uses live SVG vectors; it is a preview, never a game texture.
b=rect(0,0,1200,960,NAVY)+text(40,50,'VEILOPOLY / MATERIAL & CONTROL LIBRARY',22,GOLD,500,spacing=2)+text(40,78,'ASTRA B01  ·  Editable vectors / text-free runtime skins',14,MUTED)
for j,tone in enumerate(['primary','secondary']):
 for i,state in enumerate(['normal','pressed','disabled','loading']):
  xx=40+i*290;yy=120+j*110;b+=group(xx,yy,button(260,48,tone,state))+text(xx,yy+72,tone+' / '+state,12,MUTED)
for i,(state,c,ic) in enumerate([('normal',MUTED,'player'),('current',GOLD,'turn'),('jailed',TEAL,'lock'),('bankrupt',RED,'bankrupt')]):
 xx=40+i*290;b+=group(xx,360,surface(260,90,c))+group(xx+16,380,icon(ic,c))+text(xx+62,394,'玩家姓名',14,INK)+text(xx+62,424,'— / '+state,14,c)
for i,name in enumerate(ICONS):
 xx=40+(i%10)*116; yy=500+(i//10)*92;b+=group(xx+24,yy,icon(name))+text(xx+40,yy+55,name,11,MUTED,anchor='middle')
b+=rect(40,818,540,98,'#E4E9E7',14,'#A6BAC0')+text(62,855,'局部浅色备用',20,NAVY)+text(62,885,'只用于信息卡 / 不替换棋盘主题',14,'#425967')+group(620,818,surface(540,98))+text(644,856,'DEEP NAVY / CHAMPAGNE / OXIDIZED TEAL',12,GOLD)+text(644,885,'9-slice · 透明外缘 · 程序化文本',15,MUTED)
p=ROOT/'previews/component-library.svg';p.write_text(svg(1200,960,b));jobs.append((p,ROOT/'previews/component-library.png',1800,1440))

for state,col in [('normal','#49616E'),('focused',GOLD),('error',RED),('disabled','#36434D')]:
 b=rect(.5,.5,239,47,'#0A1823',10,col,1.2)
 if state=='error': b+=group(208,12,icon('error',RED),24/32)
 if state=='disabled': b+=group(208,14,icon('lock',MUTED),20/32)
 export('astra.input.'+state,'ui/components/input-'+state,240,48,b,state=state,insets=[12,12,12,40],slots=[dict(key='editable_value',rect=[14,8,180,32],font_pt=16)])
for state,col,ic in [('owned',TEAL,'check'),('mortgaged',GOLD,'mortgage'),('draft',MUTED,'lock'),('winner',GOLD,'star')]:
 export('astra.badge.'+state,'ui/components/badge-'+state,144,32,rect(.5,.5,143,31,'#1A2C38',16,col,.7)+group(10,7,icon(ic,col),18/32),state=state,insets=[14,34,14,14],slots=[dict(key='status',rect=[34,4,98,24],font_pt=12)])
export('astra.bank.loanQuote','ui/panels/loan-quote',320,280,surface(320,280)+group(20,20,icon('loan',TEAL))+line(20,68,300,68,TEAL,.3),'panel',insets=[72,20,20,20],slots=[dict(key='loan_ordinal',rect=[64,20,236,32],font_pt=18),dict(key='draft_rules',rect=[20,76,280,28],font_pt=12),dict(key='collateral_duration_total_due',rect=[20,116,280,140],font_pt=14)])
export('astra.bank.product','ui/panels/finance-product',288,104,surface(288,104,TEAL)+group(18,20,icon('investment',TEAL))+group(250,18,icon('lock',MUTED),18/32),'panel',insets=[18,60,18,36],slots=[dict(key='product_name',rect=[60,16,180,28],font_pt=14),dict(key='period_and_pending',rect=[60,48,200,40],font_pt=12)])

print(f'Rendering {len(jobs)} SVGs',flush=True)
def render(job):
 src,dst,w,h=job
 subprocess.run(['inkscape',str(src),'--export-type=png','--export-filename='+str(dst),'--export-width='+str(int(w)),'--export-height='+str(int(h))],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 return dst
with ThreadPoolExecutor(max_workers=4) as pool:
 for i,dst in enumerate(pool.map(render,jobs)):
  if i%15==0: print(f'rendered {i+1}/{len(jobs)}',flush=True)
for rec in records:
 p=ROOT/rec['path'];im=Image.open(p).convert('RGBA');rec['alpha_bounds_px']=list(im.getchannel('A').getbbox() or (0,0,0,0));rec['bytes']=p.stat().st_size;rec['sha256']=hashlib.sha256(p.read_bytes()).hexdigest();rec['source_sha256']=hashlib.sha256((ROOT/rec['source']).read_bytes()).hexdigest()
def js(path,data):
 p=ROOT/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
js('ASSET_MANIFEST.json',dict(schema='veilopoly.astra.art.b01.v1',package_version='1.1',assets=records,NEW=len(records),UPDATED=[],delta_from_astra_v1=dict(added_aliases=21,updated_aliases=['astra.phase.'+x.lower()+'.ornament' for x in PHASES],updated_previews=15),UNCHANGED_K1=['all original board/token/dice/card-back/audio assets; not redistributed'],PENDING=['ChatGPT integration','Apple layout/hit testing','Kimi final scene composition','B02 animation atlases'],reference_branch='dev/veilopoly',reference_sha='3a0973bb1bdf839f019ccf46f6d62c7b45796058'))
js('SPRITE_MAP.json',dict(coordinate_system='top-left pt; SpriteKit convert Y and use anchor (0,1)',assets={r['alias']:dict(path=r['path'],size_pt=r['logical_size_pt'],density=r['density'],anchor=r['spritekit_anchor'],cap_insets_pt=r['cap_insets_pt'],states=r['state'],z_position=100 if 'modal' in r['alias'] else 20) for r in records},layouts=layouts))
js('sources/design-tokens.json',dict(colors=dict(background=NAVY,panel=PANEL,gold=GOLD,teal=TEAL,text=INK,muted=MUTED,error=RED,light='#E4E9E7',paper=PAPER,print_on_paper=PRINT,property_groups=PROPERTY_COLORS),radii=dict(panel=16,control=10,capsule=22,paper=8),typography=dict(font='System SF Pro + PingFang SC; preview uses Noto Sans CJK SC; fonts not redistributed',title=22,body=14,label=12,micro=11,amount=22,numeric_features='monospaced tabular'),spacing=[4,8,12,16,24,32],touch_min_pt=[44,44],runtime_texture_scale=[2,3]))
if Path(__file__).resolve() != (ROOT/'sources/build_assets.py').resolve(): shutil.copy2(__file__,ROOT/'sources/build_assets.py')
print(f'COMPLETE {len(records)} runtime/reference assets; 15 screen previews',flush=True)
