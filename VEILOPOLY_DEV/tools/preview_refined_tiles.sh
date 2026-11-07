#!/usr/bin/env bash
# Source-layer layout samples, NOT SpriteKit screenshots.
set -euo pipefail
dev_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
art="$dev_root/Veilopoly/Sources/VeilopolyUI/Resources"
out="${1:-$(mktemp -d /tmp/veilopoly-tiles.XXXXXX)}"
font=/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc
mkdir -p "$out"
for sample in jail electric street bottom; do
 width=354; height=216
 if [[ "$sample" == jail ]]; then height=354; fi
 if [[ "$sample" == bottom ]]; then width=234; height=354; fi
 magick "$art/astraTileFace.png" -resize "${width}x${height}!" "$out/$sample.png"
done
magick "$out/jail.png" \( "$art/astraTileJail.png" -resize 126x126 \) \
 -gravity center -geometry +0-39 -compose over -composite \
 -font "$font" -pointsize 27 -fill '#193a3b' -gravity center -annotate +0+72 '监狱 / 探访' "$out/jail.png"
magick "$out/electric.png" \( "$art/astraTileElectric.png" -resize 84x84 \) \
 -gravity center -geometry +0-33 -compose over -composite \
 -font "$font" -pointsize 27 -fill '#193a3b' -gravity center -annotate +0+36 '公共事业 12' \
 -pointsize 30 -annotate +0+78 '¥150' "$out/electric.png"
magick "$out/street.png" -fill '#eb619e' -draw 'rectangle 318,18 342,198' "$out/street.png"
for x in -66 -21 21 66; do
 printf -v placement '%+d-42' "$x"
 magick "$out/street.png" \( "$art/astraHouseGreen.png" -resize 42x42 \) \
  -gravity center -geometry "$placement" -compose over -composite "$out/street.png"
done
magick "$out/street.png" -font "$font" -pointsize 30 -fill '#193a3b' \
 -gravity center -annotate +0+24 '圣查尔斯广场' -annotate +0+78 '¥140' "$out/street.png"
magick "$out/bottom.png" -fill '#7dc7ed' -draw 'rectangle 18,12 216,36' \
 -font "$font" -pointsize 30 -fill '#193a3b' -gravity center \
 -annotate +0+24 $'康涅狄格\n大道' -annotate +0+147 '¥120' "$out/bottom.png"
magick montage -background '#123936' -fill '#e3e7e3' -font "$font" -pointsize 16 \
 -label '监狱：独立立体图标' "$out/jail.png" \
 -label '公共事业：文字正向' "$out/electric.png" \
 -label '地产：建筑单排，不挤名字' "$out/street.png" \
 -label '底边：长地名两行' "$out/bottom.png" \
 -tile 2x2 -geometry 354x354+22+24 "$out/refined-tiles.png"
magick "$out/refined-tiles.png" -gravity south -background '#101923' -splice 0x44 \
 -font "$font" -pointsize 16 -fill '#dde3e7' -annotate +0+13 '局部素材与布局合成示例 · 非 iOS 运行截图 · 建筑为演示状态' "$out/refined-tiles.png"
printf 'Tile layout samples: %s\n' "$out"
