from pathlib import Path
from PIL import Image
import hashlib,json,zipfile,xml.etree.ElementTree as ET

root=Path(__file__).resolve().parent.parent
manifest=json.loads((root/'ASSET_MANIFEST.json').read_text())
mapping=json.loads((root/'SPRITE_MAP.json').read_text())
checks=[]
assets=manifest['assets']
asset_count=len(assets)
layout_count=len(mapping['layouts'])
assert len({a['alias'] for a in assets})==len(assets)
mem=0
for a in assets:
 p=root/a['path']; im=Image.open(p)
 assert list(im.size)==a['pixel_dimensions'],p
 assert 'A' in im.getbands(),p
 assert hashlib.sha256(p.read_bytes()).hexdigest()==a['sha256'],p
 assert hashlib.sha256((root/a['source']).read_bytes()).hexdigest()==a['source_sha256'],a['source']
 tree=ET.parse(root/a['source']); assert tree.getroot().get('viewBox')
 assert not tree.findall('.//{http://www.w3.org/2000/svg}text'),p
 ins=a['cap_insets_pt']
 if ins: assert ins[0]+ins[2]<a['logical_size_pt'][1] and ins[1]+ins[3]<a['logical_size_pt'][0],p
 for slot in a['text_slots']:
  x,y,w,h=slot['rect']; assert x>=0 and y>=0 and x+w<=a['logical_size_pt'][0] and y+h<=a['logical_size_pt'][1],(a['alias'],slot)
 for box in a.get('hit_targets_local_pt',{}).values():
  x,y,w,h=box;assert w>=44 and h>=44 and x+w<=a['logical_size_pt'][0] and y+h<=a['logical_size_pt'][1]
 mem+=im.width*im.height*4
for name,l in mapping['layouts'].items():
 W,H=l['canvas_pt'];assert W>H
 bx,by,bw,bh=l['board_viewport'];px,py,pw,ph=l['right_panel']
 assert bx+bw<px and px+pw<=W and py+ph<=H
 for x,y,w,h in l['capsule_targets']:assert w>=44 and h>=44 and x+w<=W and y+h<=H
 assert l['fixed_footer'][3]>=44
 hx,hy,hw,hh=l['hud'];assert hy+hh<=H-l['safe_area_reference'][2]
 x,y,w,h=l['hero_rect'];cx,cy,cw,ch=l['scroll_clip'];assert x>=cx and y>=cy and x+w<=cx+cw and y+h<=cy+ch
 for x,y,w,h in l.get('bid_controls',{}).values():assert w>=44 and h>=44
 phase=name.split('_')[0].lower();device='ipad' if H>500 else 'iphone'
 img=Image.open(root/f'previews/{device}-landscape/{phase}-{W}x{H}.png');assert img.size==(W*2,H*2)
checks=[f'{asset_count} unique asset aliases: PASS',f'{asset_count} SVGs have viewBox and no baked text: PASS',f'{asset_count} PNGs have alpha and declared dimensions: PASS','PNG and source SVG SHA256 matches: PASS','nine-slice borders and text-slot bounds valid: PASS',f'{layout_count} landscape previews match @2x target canvas: PASS',f'{layout_count} layouts: board/panel non-overlap, HUD safe bounds and hero clip containment PASS','capsule targets, auction overlays and action footer >=44pt in layout data: PASS']
(root/'VALIDATION.md').write_text('# B01 v1.1 export verification\n\nCommand: `python sources/package_and_verify.py` → generated files and layout metadata checked → PASS\n\n'+'\n'.join('- '+x for x in checks)+f'\n\nAll {asset_count} PNGs loaded uncompressed together: {mem/1048576:.2f} MiB RGBA (excludes previews and Kimi scene). This is a size estimate, NOT GPU profiling. Production should load only the needed state skins.\n\nPENDING / NOT RUN: Apple app rendering, GPU profiling, physical-device safe areas and hit testing, real keyboard and Dynamic Type behavior. This package has not been integrated into the game or accepted by Owner.\n')
cards=''
for phase in ['buy','auction','trade','bank','settlement']:
 cards+=f'<article><h2>{phase.upper()}</h2><img data-phase="{phase}" src="previews/iphone-landscape/{phase}-844x390.png" alt="{phase}横屏布局"><p><a data-source="{phase}" href="previews/iphone-landscape/{phase}-844x390.svg">可编辑整屏 SVG</a> · <a href="sources/screens/{phase}-panel-editable.svg">展开操作栏 SVG</a></p></article>'
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Veilopoly · Astra B01</title><style>body{margin:0;background:#0b1420;color:#eaf0f2;font:15px system-ui;padding:30px}main{max-width:1400px;margin:auto}h1{color:#d4b77c;letter-spacing:2px}h2{font-size:15px;letter-spacing:3px}p{color:#a6b8c4;line-height:1.7}img{width:100%;height:auto;border:1px solid #344b58;border-radius:12px}article{margin-top:32px}a{color:#d4b77c}select{padding:12px;color:#eaf0f2;background:#203442;border-radius:8px}header{position:sticky;top:0;background:#0b1420ed;padding:10px 0;z-index:2}</style><main><header><h1>VEILOPOLY / ASTRA B01</h1><select id="size" aria-label="选择画布"><option value="844x390">iPhone · 844×390pt</option><option value="852x393">iPhone · 852×393pt</option><option value="1180x820">iPad · 1180×820pt</option></select></header><p>左侧为 Kimi 场景定位线框；运行资产无动态文字。整屏预览不用于游戏贴图。<br><a href="MANIFEST.md">交付清单</a> · <a href="ASSET_MANIFEST.json">资源别名与规格</a> · <a href="SPRITE_MAP.json">布局与锚点</a> · <a href="sources/INTEGRATION.md">接入说明</a></p>'''+cards+'''<article><h2>COMPONENT LIBRARY</h2><img src="previews/component-library.png" alt="组件状态库"></article></main><script>document.getElementById('size').onchange=e=>{const size=e.target.value,dir=size==='1180x820'?'ipad-landscape':'iphone-landscape';document.querySelectorAll('[data-phase]').forEach(i=>i.src=`previews/${dir}/${i.dataset.phase}-${size}.png`);document.querySelectorAll('[data-source]').forEach(i=>i.href=`previews/${dir}/${i.dataset.source}-${size}.svg`);};</script></html>'''
page=page.replace('<article><h2>COMPONENT LIBRARY</h2>','<article><h2>REFERENCE REVISION / v1.1</h2><img src="previews/reference-review.png" alt="票券与地产证组件"><p><a href="previews/reference-review.svg">可编辑组件总览 SVG</a></p></article><article><h2>COMPONENT LIBRARY</h2>')
(root/'index.html').write_text(page)
index=[]
for p in sorted(root.rglob('*')):
 if not p.is_file() or p.name in ['FILE_INDEX.json','SHA256SUMS.txt']:continue
 assert p.suffix in ['.svg','.png','.md','.json','.txt','.html','.py'],p
 item=dict(path=str(p.relative_to(root)),bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest())
 if p.suffix=='.png':item['pixel_dimensions']=list(Image.open(p).size)
 index.append(item)
(root/'FILE_INDEX.json').write_text(json.dumps(dict(note='Index excludes itself and SHA256SUMS to avoid self-reference; all other files included.',files=index),ensure_ascii=False,indent=2)+'\n')
entries=index+[dict(path='FILE_INDEX.json',sha256=hashlib.sha256((root/'FILE_INDEX.json').read_bytes()).hexdigest())]
(root/'SHA256SUMS.txt').write_text(''.join(f"{e['sha256']}  {e['path']}\n" for e in entries))
out=root.parent/(root.name+'.zip')
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for p in sorted(root.rglob('*')):
  if p.is_file():z.write(p,str(Path(root.name)/p.relative_to(root)))
with zipfile.ZipFile(out) as z:assert z.testzip() is None
digest=hashlib.sha256(out.read_bytes()).hexdigest()
out.with_suffix('.zip.sha256').write_text(digest+'  '+out.name+'\n')
print('\n'.join(checks));print(f'ZIP {out}\nFILES {len(index)+2}\nBYTES {out.stat().st_size}\nSHA256 {digest}')
