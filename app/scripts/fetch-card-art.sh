#!/usr/bin/env bash
# Downloads the 78 public-domain Rider–Waite–Smith card scans from Wikimedia
# Commons into the app's asset catalog (as card-<id> imagesets), plus the
# Playfair Display / Nunito fonts, so Arcana is fully offline & App-Store-ready.
#
# Without running this the app still works: card art streams from Wikimedia at
# runtime (cached), with a procedural cosmic card face as the offline fallback.
#
# Usage:  ./scripts/fetch-card-art.sh
set -euo pipefail

cd "$(dirname "$0")/.."
ASSETS="Arcana/Resources/Assets.xcassets"
FONTS_DIR="Arcana/Resources/Fonts"
BASE="https://commons.wikimedia.org/wiki/Special:FilePath"

add_card() { # id  wikimedia-file
  local id="$1" file="$2"
  local dir="$ASSETS/card-$id.imageset"
  mkdir -p "$dir"
  if [ ! -s "$dir/card.jpg" ]; then
    echo "fetching $id ($file)"
    curl -fsSL "$BASE/$file" -o "$dir/card.jpg"
  fi
  cat > "$dir/Contents.json" <<EOF
{
  "images" : [
    { "filename" : "card.jpg", "idiom" : "universal", "scale" : "1x" },
    { "idiom" : "universal", "scale" : "2x" },
    { "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF
}

# --- Major arcana -----------------------------------------------------------
majors=(
  "RWS_Tarot_00_Fool.jpg" "RWS_Tarot_01_Magician.jpg" "RWS_Tarot_02_High_Priestess.jpg"
  "RWS_Tarot_03_Empress.jpg" "RWS_Tarot_04_Emperor.jpg" "RWS_Tarot_05_Hierophant.jpg"
  "RWS_Tarot_06_Lovers.jpg" "RWS_Tarot_07_Chariot.jpg" "RWS_Tarot_08_Strength.jpg"
  "RWS_Tarot_09_Hermit.jpg" "RWS_Tarot_10_Wheel_of_Fortune.jpg" "RWS_Tarot_11_Justice.jpg"
  "RWS_Tarot_12_Hanged_Man.jpg" "RWS_Tarot_13_Death.jpg" "RWS_Tarot_14_Temperance.jpg"
  "RWS_Tarot_15_Devil.jpg" "RWS_Tarot_16_Tower.jpg" "RWS_Tarot_17_Star.jpg"
  "RWS_Tarot_18_Moon.jpg" "RWS_Tarot_19_Sun.jpg" "RWS_Tarot_20_Judgement.jpg"
  "RWS_Tarot_21_World.jpg"
)
for i in "${!majors[@]}"; do
  add_card "major-$i" "${majors[$i]}"
done

# --- Minor arcana ------------------------------------------------------------
declare -A prefixes=( [wands]="Wands" [cups]="Cups" [swords]="Swords" [pentacles]="Pents" )
for suit in wands cups swords pentacles; do
  for n in $(seq 1 14); do
    add_card "$suit-$n" "$(printf '%s%02d.jpg' "${prefixes[$suit]}" "$n")"
  done
done

# --- Fonts (SIL OFL) ---------------------------------------------------------
mkdir -p "$FONTS_DIR"
gf="https://raw.githubusercontent.com/google/fonts/main/ofl"
declare -A fonts=(
  ["PlayfairDisplay-Regular.ttf"]="$gf/playfairdisplay/PlayfairDisplay%5Bwght%5D.ttf"
  ["Nunito-Regular.ttf"]="$gf/nunito/Nunito%5Bwght%5D.ttf"
)
for name in "${!fonts[@]}"; do
  if [ ! -s "$FONTS_DIR/$name" ]; then
    echo "fetching font $name"
    curl -fsSL "${fonts[$name]}" -o "$FONTS_DIR/$name" || echo "  (skipped — fetch static weights manually from fonts.google.com)"
  fi
done

echo
echo "Done. Re-run 'xcodegen generate' then rebuild — the app now uses bundled art."
echo "Note: variable-font files cover one family each; for exact Medium/SemiBold/Bold"
echo "weights download the static TTFs from fonts.google.com and drop them in $FONTS_DIR."
