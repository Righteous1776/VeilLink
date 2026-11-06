"""Assemble an editable reference-review sheet from the delivered SVG components.

Run after build_assets.py. No source component is modified. Every embedded SVG
instance receives a private ID namespace to avoid gradient/pattern collisions.
"""
from pathlib import Path
import html
import re
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'previews'
NAVY = '#0B1420'
GOLD = '#D4B77C'
INK = '#EAF0F2'
MUTED = '#A6B8C4'
COUNTER = 0


def rect(x, y, w, h, fill, radius=0, stroke='none'):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{fill}" stroke="{stroke}"/>'


def label(x, y, content, size=14, color=MUTED, weight=400, spacing=0):
    return (f'<text x="{x}" y="{y}" font-family="Noto Sans CJK SC, sans-serif" '
            f'font-size="{size}" font-weight="{weight}" letter-spacing="{spacing}" '
            f'fill="{color}">{html.escape(content)}</text>')


def divider(y):
    return f'<path d="M48 {y}H1552" stroke="#344956" stroke-width="1"/>'


def asset(name, x, y, width):
    global COUNTER
    COUNTER += 1
    path = ROOT / 'ui/tabletop' / (name + '.svg')
    source = ET.parse(path).getroot()
    _, _, w, h = map(float, source.attrib['viewBox'].split())
    contents = ''.join(ET.tostring(child, encoding='unicode') for child in source)
    prefix = f'instance{COUNTER}_'
    ids = re.findall(r'\bid="([^"]+)"', contents)
    for old in sorted(set(ids), key=len, reverse=True):
        new = prefix + old
        contents = contents.replace(f'id="{old}"', f'id="{new}"')
        contents = contents.replace(f'url(#{old})', f'url(#{new})')
        contents = contents.replace(f'href="#{old}"', f'href="#{new}"')
    scale = width / w
    shadow = rect(x + 2, y + 6, width, h * scale, '#050D15', 8)
    return shadow + f'<g transform="translate({x} {y}) scale({scale})">{contents}</g>'


def main():
    b = rect(0, 0, 1600, 1130, NAVY)
    b += rect(0, 0, 1600, 8, GOLD)
    b += label(48, 65, 'VEILOPOLY', 32, GOLD, 600, 5)
    b += label(48, 101, 'ASTRA B01 / TABLETOP MATERIAL SYSTEM', 15, INK, 500, 2)
    b += label(1130, 63, 'REFERENCE REVISION  v1.1', 14, GOLD, 500, 1)
    b += label(1130, 92, 'Editable SVG · Transparent PNG', 14)
    b += divider(126)
    b += label(48, 158, '01  /  FIVE OPERATION SURFACES', 14, GOLD, 500, 1.5)
    phases = [('buy', '地产购买'), ('auction', '拍卖竞价'), ('trade', '玩家交易'),
              ('bank', '银行金融'), ('settlement', '游戏结算')]
    for i, (name, cn) in enumerate(phases):
        x = 48 + i * 304
        b += asset('hero-' + name, x, 180, 284)
        b += label(x, 397, name.upper() + ' / ' + cn, 14, INK, 500)
        b += label(x, 419, 'astra.hero.' + name, 12)
    b += divider(446)
    b += label(48, 478, '02  /  BLANK VALUE VOUCHERS', 14, GOLD, 500, 1.5)
    names = ['cobalt', 'jade', 'coral', 'amber']
    for i, name in enumerate(names):
        x = 48 + i * 384
        b += asset('voucher-' + name, x, 499, 352)
        b += label(x, 685, 'astra.voucher.' + name, 13, INK)
    b += divider(713)
    b += label(48, 745, '03  /  PROPERTY GROUP COLOURS', 14, GOLD, 500, 1.5)
    names = ['umber', 'sky', 'orchid', 'amber', 'coral', 'ochre', 'jade', 'cobalt']
    for i, name in enumerate(names):
        x = 48 + i * 192
        b += asset('deed-' + name, x, 766, 160)
        b += label(x, 993, name.upper(), 12, INK, 500, 1)
        b += label(x, 1014, 'astra.deed.' + name, 11)
    b += divider(1042)
    b += label(48, 1074, 'UI components / not Kimi scene assets', 14, INK, 500)
    b += label(48, 1100, '运行素材不含金额、玩家姓名或状态数字；文字与交互由程序绑定。', 13)
    b += label(1090, 1074, 'NAVY FRAME / IVORY PAPER', 13, GOLD, 500, 1)
    b += label(1090, 1100, 'Original linework · No copied logos or mascots', 12)
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="1130" '
           f'viewBox="0 0 1600 1130">{b}</svg>')
    OUT.mkdir(exist_ok=True)
    target = OUT / 'reference-review.svg'
    target.write_text(svg, encoding='utf-8')
    ET.parse(target)
    subprocess.run(['inkscape', str(target), '--export-type=png',
                    '--export-filename=' + str(OUT / 'reference-review.png'),
                    '--export-width=1600', '--export-height=1130'], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(f'Created {target} and reference-review.png (1600x1130)')


if __name__ == '__main__':
    main()
