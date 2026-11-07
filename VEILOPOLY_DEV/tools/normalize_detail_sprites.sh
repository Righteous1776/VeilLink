#!/usr/bin/env bash
# Mechanical extraction/size normalization only; artwork is image-tool generated.
set -euo pipefail
dev_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sheet="$dev_root/INCOMING_ASSETS/ASTRA_DETAIL_SPRITES_R1/details.source.png"
resources="$dev_root/Veilopoly/Sources/VeilopolyUI/Resources"
aliases=(astraTokenPawnBlue astraTokenCarRed astraTokenShipGreen astraTokenPlaneGold astraHouseGreen astraHotelRed)
for index in "${!aliases[@]}"; do
 x=$(( (index % 3) * 512 ))
 y=$(( (index / 3) * 512 ))
 magick "$sheet" -crop "512x512+$x+$y" +repage -trim +repage \
  -resize 112x112 -gravity center -background none -extent 128x128 -strip \
  "PNG32:$resources/${aliases[$index]}.png"
done
