#!/usr/bin/env bash
# Diagnostic source-layer composition, NOT a SpriteKit/device screenshot.
set -euo pipefail
dev_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
resources="$dev_root/Veilopoly/Sources/VeilopolyUI/Resources"
tile_map="$dev_root/INCOMING_ASSETS/KIMI_K2_BOARD_20261107/KIMI_K2_TILE_MAP_40.json"
preview_dir="${1:-$(mktemp -d /tmp/veilopoly-center-preview.XXXXXX)}"
mkdir -p "$preview_dir"
for theme in Dark Light; do
 preview="$preview_dir/center-city-$theme.png"
 magick "$resources/kimiK2BoardTable$theme.png" -resize 1024x940! \
  \( "$resources/kimiK2BoardEdge$theme.png" -resize 1024x940! \) -compose over -composite \
  \( "$resources/kimiK2BoardBase$theme.png" -resize 1024x940! \) -composite \
  \( "$resources/kimiK2BoardFrame$theme.png" -resize 1024x940! \) -composite \
  \( "$resources/astraCenterCity.png" -resize 448x448! \) -gravity center -composite "$preview"
 while IFS=$'\t' read -r crop_x crop_y crop_w crop_h display_w display_h angle offset_x offset_y; do
  magick "$resources/kimiK2Tiles$theme.png" -crop "${crop_w}x${crop_h}+${crop_x}+${crop_y}" \
   +repage -resize "${display_w}x${display_h}!" -background none -rotate "$angle" "$preview_dir/tile.png"
  printf -v placement '%+d%+d' "$offset_x" "$offset_y"
  magick "$preview" "$preview_dir/tile.png" -gravity center -geometry "$placement" \
   -compose over -composite "$preview"
 done < <(jq -r '.tiles[] | [.frame_px_top_origin[], .display_pt[], (-.rotation_deg),
            ((.center_design_pt[0] - 512) | round), ((470 - .center_design_pt[1]) | round)] | @tsv' "$tile_map")
done
printf 'Source-layer diagnostic previews: %s\n' "$preview_dir"
