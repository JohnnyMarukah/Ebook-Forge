#!/bin/bash

################################################################################
# 🛠️ EBOOK FORGE v0.3.1 - E-book to Audiobook Converter
# Description: Production-ready robust script with atomic cache, manifests,
#              native chapters, explicit ffmpeg formats, and empty-part filters.
################################################################################

# ==============================================================================
# 1. DEPENDENCY VERIFICATION
# Checks whether all required system commands and tools are available.
# If any dependency is missing, an error popup is shown via Zenity and the script exits.
# ==============================================================================
MISSING_DEPS=""

for cmd in zenity ebook-convert ebook-meta ffmpeg ffprobe python3 timeout; do
    if ! command -v "$cmd" &> /dev/null && [ ! -x ~/.local/bin/$cmd ]; then
        MISSING_DEPS="$MISSING_DEPS $cmd"
    fi
done

if ! command -v edge-tts &> /dev/null && [ ! -x ~/.local/bin/edge-tts ] && ! python3 -c "import edge_tts" 2>/dev/null; then
    MISSING_DEPS="$MISSING_DEPS edge-tts"
fi

if [ -n "$MISSING_DEPS" ]; then
    zenity --error --text="Missing required dependencies:$MISSING_DEPS\n\nPlease install them before running Ebook Forge." 2>/dev/null
    echo "Error: Missing dependencies:$MISSING_DEPS"
    exit 1
fi

if command -v edge-tts &> /dev/null; then
    EDGE_TTS_CMD="edge-tts"
elif [ -x ~/.local/bin/edge-tts ]; then
    EDGE_TTS_CMD="$HOME/.local/bin/edge-tts"
else
    EDGE_TTS_CMD="python3 -m edge_tts.cli"
fi


# ==============================================================================
# 2. INTERACTIVE CONFIGURATION
# Opens graphical dialog boxes (Zenity) allowing the user to select:
# - Book language (Polish or English)
# - TTS voice actor/neural profile
# - Output audio format (Opus or M4B)
# - Audio quality (bitrate)
# ==============================================================================
JEZYK=$(zenity --list --title="Ebook Forge - Language Selection" \
  --text="Select book language:" \
  --radiolist --column="Select" --column="Code" --column="Description" \
  TRUE "pl" "Polish (Polski)" \
  FALSE "en" "English" \
  --width=400 --height=220 2>/dev/null)

[ -z "$JEZYK" ] && exit 0

if [ "$JEZYK" = "pl" ]; then
    GLOS=$(zenity --list --title="Ebook Forge - Voice Selection (PL)" \
      --text="Select Polish TTS voice:" \
      --radiolist --column="Select" --column="Voice ID" --column="Description" \
      TRUE "pl-PL-MarekNeural" "Marek (Male, natural)" \
      FALSE "pl-PL-ZofiaNeural" "Zofia (Female, natural)" \
      --width=450 --height=220 2>/dev/null)
else
    GLOS=$(zenity --list --title="Ebook Forge - Voice Selection (EN)" \
      --text="Select English TTS voice:" \
      --radiolist --column="Select" --column="Voice ID" --column="Description" \
      TRUE "en-US-GuyNeural" "Guy (US - Male, natural)" \
      FALSE "en-US-AriaNeural" "Aria (US - Female, natural)" \
      FALSE "en-GB-RyanNeural" "Ryan (UK - Male, natural)" \
      FALSE "en-GB-SoniaNeural" "Sonia (UK - Female, natural)" \
      --width=500 --height=280 2>/dev/null)
fi

[ -z "$GLOS" ] && exit 0

FORMAT_WYJSCIOWY=$(zenity --list --title="Ebook Forge - Output Format" \
  --text="Select audiobook container format:" \
  --radiolist --column="Select" --column="Format" --column="Description" \
  FALSE "opus" "Opus (.opus) - Lightweight, great compression (PC/Linux)" \
  TRUE "m4b" "M4B (.m4b) - Audiobook with chapters & position memory (Mobile)" \
  --width=500 --height=230 2>/dev/null)

[ -z "$FORMAT_WYJSCIOWY" ] && exit 0

BITRATE=$(zenity --list --title="Ebook Forge - Audio Quality" \
  --text="Select audio quality (bitrate):" \
  --radiolist --column="Select" --column="Bitrate" --column="Description" \
  FALSE "16k" "Low (smallest file size, good for long content)" \
  TRUE "32k" "Standard (good balance of size and quality - recommended)" \
  FALSE "64k" "High (best voice clarity, largest file size)" \
  --width=450 --height=250 2>/dev/null)

[ -z "$BITRATE" ] && exit 0


# ==============================================================================
# 3. WORKING DIRECTORY SELECTION
# Prompts the user to select the source directory containing e-books,
# changes working directory, and creates necessary subdirectories for outputs and logs.
# ==============================================================================
KATALOG_WEJSCIOWY="$(zenity --file-selection --directory --title="Ebook Forge - Select folder with documents/e-books" 2>/dev/null)"

[ -z "$KATALOG_WEJSCIOWY" ] && exit 0

cd "$KATALOG_WEJSCIOWY" || exit 1
mkdir -p "Audiobooks" "Processed" "Logs"


# ==============================================================================
# 4. LOGGING CONFIGURATION
# Sets up global logging variables, timestamped log files, and a logging function
# to track progress and errors during conversion sessions.
# ==============================================================================
SESSION_TIMESTAMP=$(date '+%Y-%m-%d_%H%M')
PLIK_LOGU_GLOWNY="Logs/${SESSION_TIMESTAMP}.log"
SESJA_START=$(date +%s)

log_msg() {
  local MSG="$1"
  local INDYWIDUALNY_LOG="$2"
  echo "# $MSG"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $MSG" >> "$PLIK_LOGU_GLOWNY"
  if [ -n "$INDYWIDUALNY_LOG" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $MSG" >> "$INDYWIDUALNY_LOG"
  fi
}

echo "================================================================================" > "$PLIK_LOGU_GLOWNY"
echo "Ebook Forge v0.3.1 - Session started | Voice: $GLOS | Format: .$FORMAT_WYJSCIOWY | Bitrate: $BITRATE | $(date)" >> "$PLIK_LOGU_GLOWNY"
echo "================================================================================" >> "$PLIK_LOGU_GLOWNY"

LICZBA_CZESCI=30


# ==============================================================================
# 5. SOURCE FILE SEARCH
# Scans the working directory for supported e-book and document formats.
# Exits gracefully if no matching files are found.
# ==============================================================================
shopt -s nullglob
PLIKI=(
  *.epub *.EPUB *.mobi *.MOBI *.pdf *.PDF 
  *.txt *.TXT *.fb2 *.FB2 *.docx *.DOCX *.odt *.ODT *.rtf *.RTF
)
shopt -u nullglob

LACZNIE=${#PLIKI[@]}

if [ "$LACZNIE" -eq 0 ]; then
    zenity --error --text="No supported document or e-book files found in the selected folder!" 2>/dev/null
    exit 0
fi


# ==============================================================================
# 6. MAIN PROCESSING LOOP
# Iterates through each discovered e-book, checks for existing output or cache,
# extracts text, splits it into parts, handles speech synthesis, and merges chapters.
# ==============================================================================
STATE_DIR=$(mktemp -d -p /dev/shm ebook_forge_state_XXXXXX)
echo 0 > "$STATE_DIR/sukcesy"
echo 0 > "$STATE_DIR/pominiete"
echo 0 > "$STATE_DIR/bledy"

(
trap 'exit 130' INT TERM

AKTUALNY=0
SUKCESY=0
POMINIETE=0
BLEDY=0

for PLIK in "${PLIKI[@]}" ; do
  KSIAZKA_START=$(date +%s)
  AKTUALNY=$((AKTUALNY + 1))
  ROZSZERZENIE="${PLIK##*.}"
  NAZWA_BAZOWA=$(basename "$PLIK" ".$ROZSZERZENIE")
  
  PLIK_LOGU_KSIAZKI="Logs/${NAZWA_BAZOWA}.log"
  
  echo "================================================================================" > "$PLIK_LOGU_KSIAZKI"
  echo "Ebook Forge - Conversion log: $PLIK" >> "$PLIK_LOGU_KSIAZKI"
  echo "================================================================================" >> "$PLIK_LOGU_KSIAZKI"

  BAZA_PROCENT=$(( (AKTUALNY - 1) * 100 / LACZNIE ))
  SKOK_NA_PLIK=$(( 100 / LACZNIE ))
  
  echo "$BAZA_PROCENT"

  # Skip if the final audiobook already exists in the output directory
  if [ -f "Audiobooks/${NAZWA_BAZOWA}.${FORMAT_WYJSCIOWY}" ]; then
    log_msg "[$AKTUALNY/$LACZNIE] SKIPPED: File Audiobooks/${NAZWA_BAZOWA}.${FORMAT_WYJSCIOWY} already exists." "$PLIK_LOGU_KSIAZKI"
    POMINIETE=$((POMINIETE + 1))
    echo "$POMINIETE" > "$STATE_DIR/pominiete"
    continue
  fi

  CACHE_DIR=".cache_${NAZWA_BAZOWA}"
  mkdir -p "$CACHE_DIR"
  MANIFEST_FILE="${CACHE_DIR}/manifest.json"
  TXT_FILE="${CACHE_DIR}/book.txt"

  # Validate cache configuration integrity against current settings
  if [ -f "$MANIFEST_FILE" ]; then
    CURRENT_MANIFEST=$(python3 -c '
import json, sys
m = {"source": sys.argv[1], "voice": sys.argv[2], "format": sys.argv[3], "bitrate": sys.argv[4]}
print(json.dumps(m, sort_keys=True))
' "$PLIK" "$GLOS" "$FORMAT_WYJSCIOWY" "$BITRATE")
    
    CACHED_MANIFEST=$(python3 -c '
import json, sys
try:
    with open(sys.argv[1], "r") as f:
        data = json.load(f)
    m = {"source": data.get("source"), "voice": data.get("voice"), "format": data.get("format"), "bitrate": data.get("bitrate")}
    print(json.dumps(m, sort_keys=True))
except:
    print("")
' "$MANIFEST_FILE")

    if [ "$CURRENT_MANIFEST" != "$CACHED_MANIFEST" ]; then
      log_msg "[$AKTUALNY/$LACZNIE] Cache configuration mismatch for $NAZWA_BAZOWA. Rebuilding cache..." "$PLIK_LOGU_KSIAZKI"
      rm -rf "$CACHE_DIR"
      mkdir -p "$CACHE_DIR"
    fi
  fi

  # Create or update manifest file with session metadata
  python3 -c '
import json, sys
data = {
    "source": sys.argv[1],
    "voice": sys.argv[2],
    "language": sys.argv[3],
    "format": sys.argv[4],
    "bitrate": sys.argv[5],
    "parts": int(sys.argv[6]),
    "version": "0.3.1"
}
with open(sys.argv[7], "w", encoding="utf-8") as f:
    json.dump(data, f, indent=4)
' "$PLIK" "$GLOS" "$JEZYK" "$FORMAT_WYJSCIOWY" "$BITRATE" "$LICZBA_CZESCI" "$MANIFEST_FILE"
  
  # Step 1: Extract clean text from source e-book using Calibre ebook-convert
  if [ ! -s "$TXT_FILE" ]; then
    TEMP_TXT="${CACHE_DIR}/extract.txt"
    rm -f "$TEMP_TXT"
    
    if [ "$ROZSZERZENIE" = "txt" ] || [ "$ROZSZERZENIE" = "TXT" ]; then
      cp "$PLIK" "$TEMP_TXT"
    else
      log_msg "[$AKTUALNY/$LACZNIE] $NAZWA_BAZOWA | Step 1: Text extraction via Calibre..." "$PLIK_LOGU_KSIAZKI"
      timeout 600 ebook-convert "$PLIK" "$TEMP_TXT" >> "$PLIK_LOGU_GLOWNY" 2>> "$PLIK_LOGU_KSIAZKI"
    fi
    
    if [ -s "$TEMP_TXT" ]; then
      mv "$TEMP_TXT" "$TXT_FILE"
    fi
  fi

  if [ ! -s "$TXT_FILE" ]; then
    log_msg "[$AKTUALNY/$LACZNIE] ERROR: Failed to prepare text from $PLIK." "$PLIK_LOGU_KSIAZKI"
    BLEDY=$((BLEDY + 1))
    echo "$BLEDY" > "$STATE_DIR/bledy"
    continue
  fi

  # Step 2: Smart text splitting into defined number of manageable chunks
  log_msg "[$AKTUALNY/$LACZNIE] $NAZWA_BAZOWA | Step 2: Smart splitting into $LICZBA_CZESCI parts..." "$PLIK_LOGU_KSIAZKI"
  rm -f "$CACHE_DIR"/part_*.txt "$CACHE_DIR"/part_*.m4a "$CACHE_DIR"/part_*.opus

  python3 -c '
import sys, os, re
txt_path, tmp_dir, parts_count = sys.argv[1], sys.argv[2], int(sys.argv[3])
with open(txt_path, "r", encoding="utf-8", errors="ignore") as f:
    text = f.read()
paragraphs = text.split("\n\n")
clean_paragraphs = [re.sub(r"\s+", " ", p).strip() for p in paragraphs if re.sub(r"\s+", " ", p).strip()]
total_chars = sum(len(p) + 2 for p in clean_paragraphs)
chars_per_part = max(1, total_chars // parts_count)
current_part, current_text, current_chars = 1, "", 0
for p in clean_paragraphs:
    current_text += p + "\n\n"
    current_chars += len(p) + 2
    if current_chars >= chars_per_part and current_part < parts_count:
        with open(os.path.join(tmp_dir, f"part_{current_part-1:02d}.txt"), "w", encoding="utf-8") as out:
            out.write(current_text)
        current_text, current_chars, current_part = "", 0, current_part + 1
if current_text.strip():
    with open(os.path.join(tmp_dir, f"part_{current_part-1:02d}.txt"), "w", encoding="utf-8") as out:
        out.write(current_text)
' "$TXT_FILE" "$CACHE_DIR" "$LICZBA_CZESCI"

  CZESCI=( "${CACHE_DIR}/part_"*.txt )
  SUMA_CZESCI=${#CZESCI[@]}
  NR_CZESCI=0
  LISTA_SCALANIA="${CACHE_DIR}/lista.txt"
  > "$LISTA_SCALANIA"
  BladKsiazki=0

  # Loop through each text part for speech synthesis and encoding
  for CZESC_TXT in "${CZESCI[@]}"; do
    NR_CZESCI=$((NR_CZESCI + 1))
    BAZA_NAZWA="${CZESC_TXT%.txt}"
    
    AKTUALNY_PROCENT=$(( BAZA_PROCENT + (NR_CZESCI * SKOK_NA_PLIK / SUMA_CZESCI) ))
    echo "$AKTUALNY_PROCENT"

    if [ "$FORMAT_WYJSCIOWY" = "m4b" ] && [ -s "${BAZA_NAZWA}.m4a" ]; then
      printf "file '%s'\n" "$(basename "${BAZA_NAZWA}.m4a")" >> "$LISTA_SCALANIA"
      continue
    elif [ "$FORMAT_WYJSCIOWY" = "opus" ] && [ -s "${BAZA_NAZWA}.opus" ]; then
      printf "file '%s'\n" "$(basename "${BAZA_NAZWA}.opus")" >> "$LISTA_SCALANIA"
      continue
    fi

    # Skip empty text parts that contain no visible characters
    if [ ! -s "$CZESC_TXT" ] || ! grep -q '[[:graph:]]' "$CZESC_TXT"; then
      log_msg "[$AKTUALNY/$LACZNIE] $NAZWA_BAZOWA | Part $NR_CZESCI: Empty text part, skipping." "$PLIK_LOGU_KSIAZKI"
      continue
    fi
    
    # Step 3: Speech synthesis using Edge TTS with automatic retry logic
    log_msg "[$AKTUALNY/$LACZNIE] $NAZWA_BAZOWA | Step 3: Speech synthesis (part $NR_CZESCI of $SUMA_CZESCI)..." "$PLIK_LOGU_KSIAZKI"
    
    SUKCES_SYNTEZY=0
    TRYB_PROBA=0
    MAX_PROB=5

    while [ $TRYB_PROBA -lt $MAX_PROB ] && [ $SUKCES_SYNTEZY -eq 0 ]; do
      TRYB_PROBA=$((TRYB_PROBA + 1))
      rm -f "${BAZA_NAZWA}.mp3"

      $EDGE_TTS_CMD --voice "$GLOS" --file "$CZESC_TXT" --write-media "${BAZA_NAZWA}.mp3" >> "$PLIK_LOGU_GLOWNY" 2>> "$PLIK_LOGU_KSIAZKI"

      if [ -s "${BAZA_NAZWA}.mp3" ] && [ "$(stat -c%s "${BAZA_NAZWA}.mp3")" -gt 3072 ]; then
        SUKCES_SYNTEZY=1
      else
        sleep 10
      fi
    done

    if [ $SUKCES_SYNTEZY -eq 0 ]; then
      log_msg "[$AKTUALNY/$LACZNIE] CRITICAL ERROR: Failed part $NR_CZESCI." "$PLIK_LOGU_KSIAZKI"
      BladKsiazki=1
      break
    fi

    # Encode individual audio parts into container formats using explicit ffmpeg parameters
    if [ "$FORMAT_WYJSCIOWY" = "m4b" ]; then
      timeout 180 ffmpeg -hide_banner -loglevel error -y -i "${BAZA_NAZWA}.mp3" -c:a aac -b:a "$BITRATE" -f mp4 "${BAZA_NAZWA}.m4a.tmp" < /dev/null >> "$PLIK_LOGU_GLOWNY" 2>> "$PLIK_LOGU_KSIAZKI"
      if [ -s "${BAZA_NAZWA}.m4a.tmp" ]; then
        mv "${BAZA_NAZWA}.m4a.tmp" "${BAZA_NAZWA}.m4a"
        printf "file '%s'\n" "$(basename "${BAZA_NAZWA}.m4a")" >> "$LISTA_SCALANIA"
      else
        BladKsiazki=1; break
      fi
    else
      timeout 180 ffmpeg -hide_banner -loglevel error -y -i "${BAZA_NAZWA}.mp3" -c:a libopus -b:a "$BITRATE" -vbr on -f ogg "${BAZA_NAZWA}.opus.tmp" < /dev/null >> "$PLIK_LOGU_GLOWNY" 2>> "$PLIK_LOGU_KSIAZKI"
      if [ -s "${BAZA_NAZWA}.opus.tmp" ]; then
        mv "${BAZA_NAZWA}.opus.tmp" "${BAZA_NAZWA}.opus"
        printf "file '%s'\n" "$(basename "${BAZA_NAZWA}.opus")" >> "$LISTA_SCALANIA"
      else
        BladKsiazki=1; break
      fi
    fi
    sleep 2
  done

  if [ $BladKsiazki -eq 0 ]; then
    # Step 4: Locate cover art and merge audio parts with chapter metadata
    log_msg "[$AKTUALNY/$LACZNIE] $NAZWA_BAZOWA | Step 4: Merging with chapters and cover..." "$PLIK_LOGU_KSIAZKI"
    
    OKLADKA=""
    if [ "$ROZSZERZENIE" != "txt" ]; then
      ebook-meta "$PLIK" --get-cover="${CACHE_DIR}/embedded_cover.jpg" &>/dev/null
      if [ -s "${CACHE_DIR}/embedded_cover.jpg" ]; then
        OKLADKA="${CACHE_DIR}/embedded_cover.jpg"
      fi
    fi
    if [ -z "$OKLADKA" ]; then
      for img in "${NAZWA_BAZOWA}.jpg" "${NAZWA_BAZOWA}.jpeg" "${NAZWA_BAZOWA}.png"; do
        if [ -f "$img" ]; then
          OKLADKA="$img"
          break
        fi
      done
    fi
    if [ -z "$OKLADKA" ]; then
      for img in cover.jpg cover.jpeg cover.png COVER.JPG COVER.PNG; do
        if [ -f "$img" ]; then
          OKLADKA="$img"
          break
        fi
      done
    fi

    FINAL_OUTPUT="Audiobooks/${NAZWA_BAZOWA}.${FORMAT_WYJSCIOWY}"
    TEMP_OUTPUT="Audiobooks/${NAZWA_BAZOWA}.m4a.tmp"

    if [ "$FORMAT_WYJSCIOWY" = "m4b" ]; then
      METADATA_FILE="${CACHE_DIR}/metadata.txt"
      python3 -c '
import sys, subprocess, os
cache_dir, metadata_path = sys.argv[1], sys.argv[2]
parts = sorted([os.path.join(cache_dir, f) for f in os.listdir(cache_dir) if f.startswith("part_") and f.endswith(".m4a")])
with open(metadata_path, "w", encoding="utf-8") as meta:
    meta.write(";FFMETADATA1\n")
    current_time = 0
    for i, p in enumerate(parts):
        cmd = ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", p]
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try: duration = float(res.stdout.strip())
        except: duration = 0.0
        start_ms, end_ms = int(current_time * 1000), int((current_time + duration) * 1000)
        meta.write("[CHAPTER]\nTIMEBASE=1/1000\n" + f"START={start_ms}\n" + f"END={end_ms}\n" + f"title=Part {i+1:02d}\n")
        current_time += duration
' "$CACHE_DIR" "$METADATA_FILE"

      # Merge chapters, cover image, and metadata into final M4B file safely using a temporary file
      if [ -n "$OKLADKA" ]; then
        ffmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i "$LISTA_SCALANIA" -i "$METADATA_FILE" -i "$OKLADKA" -map 0:a -map 2:v -map_metadata 1 -c:a copy -c:v mjpeg -metadata title="$NAZWA_BAZOWA" -metadata artist="Ebook Forge" -metadata album="$NAZWA_BAZOWA" -disposition:v:0 attached_pic -f mp4 "$TEMP_OUTPUT" >> "$PLIK_LOGU_GLOWNY" 2>> "$PLIK_LOGU_KSIAZKI"
      else
        ffmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i "$LISTA_SCALANIA" -i "$METADATA_FILE" -map 0:a -map_metadata 1 -c:a copy -metadata title="$NAZWA_BAZOWA" -metadata artist="Ebook Forge" -metadata album="$NAZWA_BAZOWA" -f mp4 "$TEMP_OUTPUT" >> "$PLIK_LOGU_GLOWNY" 2>> "$PLIK_LOGU_KSIAZKI"
      fi
    else
      if [ -n "$OKLADKA" ]; then
        ffmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i "$LISTA_SCALANIA" -i "$OKLADKA" -map 0:a -map 1:v -c:a copy -c:v mjpeg -metadata title="$NAZWA_BAZOWA" -metadata artist="Ebook Forge" -metadata album="$NAZWA_BAZOWA" -disposition:v:0 attached_pic "$TEMP_OUTPUT" >> "$PLIK_LOGU_GLOWNY" 2>> "$PLIK_LOGU_KSIAZKI"
      else
        ffmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i "$LISTA_SCALANIA" -c:a copy -metadata title="$NAZWA_BAZOWA" -metadata artist="Ebook Forge" -metadata album="$NAZWA_BAZOWA" "$TEMP_OUTPUT" >> "$PLIK_LOGU_GLOWNY" 2>> "$PLIK_LOGU_KSIAZKI"
      fi
    fi

    # Validate output audio file integrity using ffprobe
    FFMPEG_EXIT=$?
    VALID_AUDIO=0
    if [ $FFMPEG_EXIT -eq 0 ] && [ -s "$TEMP_OUTPUT" ]; then
      DURATION_CHECK=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$TEMP_OUTPUT" 2>/dev/null)
      if [ -n "$DURATION_CHECK" ] && (( $(echo "$DURATION_CHECK > 0" | bc -l 2>/dev/null || echo 1) )); then
        VALID_AUDIO=1
      fi
    fi

    if [ $VALID_AUDIO -eq 1 ]; then
      mv "$TEMP_OUTPUT" "$FINAL_OUTPUT"
      SUKCESY=$((SUKCESY + 1))
      echo "$SUKCESY" > "$STATE_DIR/sukcesy"
      mv "$PLIK" "./Processed/"
      rm -rf "$CACHE_DIR"
      log_msg "SUCCESS: Completed conversion and validation of $NAZWA_BAZOWA" "$PLIK_LOGU_KSIAZKI"
    else
      log_msg "ERROR: Output validation failed for $NAZWA_BAZOWA. Keeping cache." "$PLIK_LOGU_KSIAZKI"
      rm -f "$TEMP_OUTPUT"
      BLEDY=$((BLEDY + 1))
      echo "$BLEDY" > "$STATE_DIR/bledy"
    fi
  else
    BLEDY=$((BLEDY + 1))
    echo "$BLEDY" > "$STATE_DIR/bledy"
  fi
  sleep 2
done

echo "100"
) | zenity --progress \
  --title="Ebook Forge v0.3.1 - Conversion in progress" \
  --text="Processing books..." \
  --percentage=0 \
  --width=500 \
  --auto-close \
  --auto-kill 2>/dev/null

KOD_ZAKONCZENIA=$?

FINAL_SUKCESY=$(cat "$STATE_DIR/sukcesy" 2>/dev/null || echo 0)
FINAL_POMINIETE=$(cat "$STATE_DIR/pominiete" 2>/dev/null || echo 0)
FINAL_BLEDY=$(cat "$STATE_DIR/bledy" 2>/dev/null || echo 0)
rm -rf "$STATE_DIR"

SESJA_KONIEC=$(date +%s)
SESJA_CZAS=$((SESJA_KONIEC - SESJA_START))
S_MINUTY=$((SESJA_CZAS / 60))
S_SEKUNDY=$((SESJA_CZAS % 60))

# ==============================================================================
# 7. COMPLETION SUMMARY
# Displays a final Zenity notification dialog summarizing session results and metrics.
# ==============================================================================
if [ $KOD_ZAKONCZENIA -eq 0 ] || [ $KOD_ZAKONCZENIA -eq 5 ]; then
    zenity --info --title="Ebook Forge - Finished" \
      --text="Session completed in ${S_MINUTY}m ${S_SEKUNDY}s.\n\nSuccessful: $FINAL_SUKCESY\nSkipped: $FINAL_POMINIETE\nErrors: $FINAL_BLEDY\n\nCheck 'Audiobooks' and 'Logs' folders." 2>/dev/null
else
    zenity --warning --title="Aborted" \
      --text="Conversion stopped by user. Temp cache preserved for resume." 2>/dev/null
fi
