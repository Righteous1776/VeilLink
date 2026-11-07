#!/usr/bin/env bash
set -euo pipefail
dev_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="$dev_root/INCOMING_ASSETS/ASTRA_TILE_ART_R1"
resources="$dev_root/Veilopoly/Sources/VeilopolyUI/Resources"
read -r width height < <(magick identify -format '%w %h\n' "$source_dir/icons.source.png")
aliases=(Go Jail Park GoToJail Rail Electric Water Chest Chance Tax)
for i in "${!aliases[@]}"; do
 x=$(( (i % 5) * width / 5 )); right=$(( (i % 5 + 1) * width / 5 ))
 y=$(( (i / 5) * height / 2 )); bottom=$(( (i / 5 + 1) * height / 2 ))
 magick "$source_dir/icons.source.png" -crop "$((right-x))x$((bottom-y))+$x+$y" \
  +repage -trim +repage -resize 112x112 -gravity center -background none -extent 128x128 \
  -strip "PNG32:$resources/astraTile${aliases[$i]}.png"
done
magick "$source_dir/face.source.png" -crop 840x1300+90+120 +repage -resize 256x384! \
 -strip "PNG32:$resources/astraTileFace.png"
