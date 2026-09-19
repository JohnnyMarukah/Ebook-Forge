#!/bin/bash

################################################################################
# 🛠️ EBOOK FORGE v0.3 - E-book to Audiobook Converter
# Features: Dual Mode (Auto-GUI / Auto-CLI), Atomic Cache, Manifests,
#           Native Chapters, Explicit FFmpeg Formats, Multi-tier Cover Logic,
#           Strict Output Validation (FFmpeg & FFprobe) & Live Terminal Progress.
################################################################################

# ==============================================================================
# 1. ENVIRONMENT DETECTION & DEPENDENCY CHECK
# ==============================================================================
USE_GUI=false
if ([ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]) && command -v zenity &> /dev/null; then
    USE_GUI=true
fi

MISSING_DEPS=""
for cmd in ebook-convert ebook-meta ffmpeg ffprobe python3 timeout; do
    if ! command -v "$cmd" &> /dev/null && [ ! -x ~/.local/bin/$cmd ]; then
        MISSING_DEPS="$MISSING_DEPS $cmd"
    fi
done

if ! command -v edge-tts &> /dev/null && [ ! -x ~/.local/bin/edge-tts ] && ! python3 -c "import edge_tts" 2>/dev/null; then
    MISSING_DEPS="$MISSING_DEPS edge-tts"
fi

if [ -n "$MISSING_DEPS" ]; then
    if [ "$USE_GUI" = true ]; then
        zenity --error --text="Brakujące zależności:$MISSING_DEPS\n\nZainstaluj je przed uruchomieniem Ebook Forge." 2>/dev/null
    else
        echo -e "\033[0;31mBłąd: Brakujące zależności:$MISSING_DEPS\033[0m"
    fi
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
# 2. INTERACTIVE CONFIGURATION (GUI vs CLI Dual Mode)
# ==============================================================================
if [ "$USE_GUI" = true ]; then
    # --- GUI MODE (Zenity) ---
    JEZYK=$(zenity --list --title="Ebook Forge v0.3 - Język / Language" \
      --text="Wybierz język książki / Select book language:" \
      --radiolist --column="Wybierz" --column="Kod" --column="Opis" \
      TRUE "pl" "Język Polski" \
      FALSE "en" "English (Angielski)" \
      --width=400 --height=220 2>/dev/null)
    [ -z "$JEZYK" ] && exit 0

    if [ "$JEZYK" = "pl" ]; then
        GLOS=$(zenity --list --title="Ebook Forge - Wybór Lektora (PL)" \
          --text="Wybierz polski głos syntezatora:" \
          --radiolist --column="Wybierz" --column="ID Głosu" --column="Opis" \
          TRUE "pl-PL-MarekNeural" "Marek (Męski, naturalny)" \
          FALSE "pl-PL-ZofiaNeural" "Zofia (Żeński, naturalny)" \
          --width=450 --height=220 2>/dev/null)
    else
        GLOS=$(zenity --list --title="Ebook Forge - Voice Selection (EN)" \
          --text="Select English voice:" \
          --radiolist --column="Wybierz" --column="Voice ID" --column="Description" \
          TRUE "en-US-GuyNeural" "Guy (US - Male, natural)" \
          FALSE "en-US-AriaNeural" "Aria (US - Female, natural)" \
          FALSE "en-GB-RyanNeural" "Ryan (UK - Male, natural)" \
          FALSE "en-GB-SoniaNeural" "Sonia (UK - Female, natural)" \
          --width=500 --height=280 2>/dev/null)
    fi
    [ -z "$GLOS" ] && exit 0

    FORMAT_WYJSCIOWY=$(zenity --list --title="Ebook Forge - Format Wyjściowy" \
      --text="Wybierz format pliku audiobooka:" \
      --radiolist --column="Wybierz" --column="Format" --column="Opis" \
      FALSE "opus" "Opus (.opus) - Lekki, świetna kompresja (PC/Linux)" \
      TRUE "m4b" "M4B (.m4b) - Audiobook z rozdziałami i zapamiętywaniem pozycji (Telefon)" \
      --width=500 --height=230 2>/dev/null)
    [ -z "$FORMAT_WYJSCIOWY" ] && exit 0

    BITRATE=$(zenity --list --title="Ebook Forge - Jakość Dźwięku" \
      --text="Wybierz jakość (bitrate):" \
      --radiolist --column="Wybierz" --column="Bitrate" --column="Opis" \
      FALSE "16k" "Niska (najmniejszy plik, dobra do długich treści)" \
      TRUE "32k" "Standardowa (dobry balans rozmiar/jakość - zalecane)" \
      FALSE "64k" "Wysoka (najlepsza czystość głosu, największy plik)" \
      --width=450 --height=250 2>/dev/null)
    [ -z "$BITRATE" ] && exit 0

    KATALOG_WEJSCIOWY="$(zenity --file-selection --directory --title="Ebook Forge - Wybierz katalog z książkami" 2>/dev/null)"
    [ -z "$KATALOG_WEJSCIOWY" ] && exit 0

else
    # --- CLI MODE (Terminal Interactive) ---
    clear
    echo -e "\033[1;36m====================================================\033[0m"
    echo -e "\033[1;36m          🛠️  EBOOK FORGE v0.3 (TRYB CLI)           \033[0m"
    echo -e "\033[1;36m====================================================\033[0m\n"

    echo "1) Wybór języka / Select language:"
    echo "   [1] Polski (pl)"
    echo "   [2] English (en)"
    read -p "   Wybór [1-2, domyślnie 1]: " J_CHOICE
    [ "$J_CHOICE" = "2" ] && JEZYK="en" || JEZYK="pl"

    echo -e "\n2) Wybór lektora / Select voice:"
    if [ "$JEZYK" = "pl" ]; then
        echo "   [1] Marek (Męski, naturalny)"
        echo "   [2] Zofia (Żeński, naturalny)"
        read -p "   Wybór [1-2, domyślnie 1]: " V_CHOICE
        [ "$V_CHOICE" = "2" ] && GLOS="pl-PL-ZofiaNeural" || GLOS="pl-PL-MarekNeural"
    else
        echo "   [1] Guy (US - Male)"
        echo "   [2] Aria (US - Female)"
        echo "   [3] Ryan (UK - Male)"
        echo "   [4] Sonia (UK - Female)"
        read -p "   Wybór [1-4, domyślnie 1]: " V_CHOICE
        case $V_CHOICE in
            2) GLOS="en-US-AriaNeural" ;;
            3) GLOS="en-GB-RyanNeural" ;;
            4) GLOS="en-GB-SoniaNeural" ;;
            *) GLOS="en-US-GuyNeural" ;;
        esac
    fi

    echo -e "\n3) Format wyjściowy / Output format:"
    echo "   [1] M4B (.m4b) - Z rozdziałami i pozycją (Telefon)"
    echo "   [2] Opus (.opus) - Lekki, wysoka kompresja (PC/Linux)"
    read -p "   Wybór [1-2, domyślnie 1]: " F_CHOICE
    [ "$F_CHOICE" = "2" ] && FORMAT_WYJSCIOWY="opus" || FORMAT_WYJSCIOWY="m4b"

    echo -e "\n4) Jakość dźwięku / Bitrate:"
    echo "   [1] 16k - Niska (najmniejszy plik)"
    echo "   [2] 32k - Standardowa (zalecana)"
    echo "   [3] 64k - Wysoka (najczystszy głos)"
    read -p "   Wybór [1-3, domyślnie 2]: " B_CHOICE
    case $B_CHOICE in
        1) BITRATE="16k" ;;
        3) BITRATE="64k" ;;
        *) BITRATE="32k" ;;
    esac

    echo -e "\n5) Podaj ścieżkę do katalogu z e-bookami [Enter = obecny katalog]:"
    read -p "   Ścieżka: " KATALOG_WEJSCIOWY
    KATALOG_WEJSCIOWY=${KATALOG_WEJSCIOWY:-"."}
fi


# ==============================================================================
# 3. DIRECTORY PREPARATION & LOGGING
# ==============================================================================
cd "$KATALOG_WEJSCIOWY" || exit 1
mkdir -p "Audiobooks" "Processed" "Logs"

SESSION_TIMESTAMP=$(date '+%Y-%m-%d_%H%M')
PLIK_LOGU_GLOWNY="Logs/${SESSION_TIMESTAMP}.log"
SESJA_START=$(date +%s)

log_msg() {
  local MSG="$1"
  local INDYWIDUALNY_LOG="$2"
  
  if [ "$USE_GUI" = false ]; then
    echo -e "\033[0;32m$(date '+%H:%M:%S')\033[0m - $MSG"
  else
    echo "# $MSG"
  fi
  
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $MSG" >> "$PLIK_LOGU_GLOWNY"
  if [ -n "$INDYWIDUALNY_LOG" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $MSG" >> "$INDYWIDUALNY_LOG"
  fi
}

echo "================================================================================" > "$PLIK_LOGU_GLOWNY"
echo "Ebook Forge v0.3 - Session started | Voice: $GLOS | Format: .$FORMAT_WYJSCIOWY | Bitrate: $BITRATE | $(date)" >> "$PLIK_LOGU_GLOWNY"
echo "================================================================================" >> "$PLIK_LOGU_GLOWNY"

LICZBA_CZESCI=30


# ==============================================================================
# 4. SOURCE FILE SEARCH
# ==============================================================================
shopt -s nullglob
PLIKI=(
  *.epub *.EPUB *.mobi *.MOBI *.pdf *.PDF 
  *.txt *.TXT *.fb2 *.FB2 *.docx *.DOCX *.odt *.ODT *.rtf *.RTF
)
shopt -u nullglob

LACZNIE=${#PLIKI[@]}

if [ "$LACZNIE" -eq 0 ]; then
    if [ "$USE_GUI" = true ]; then
        zenity --error --text="Nie znaleziono obsługiwanych plików e-booków w wybranym folderze!" 2>/dev/null
    else
        echo -e "\n\033[0;31mBłąd: Nie znaleziono obsługiwanych plików e-booków w folderze!\033[0m"
    fi
    exit 0
fi


# ==============================================================================
# 5. MAIN PROCESSING LOOP & PROGRESS BAR
# ==============================================================================
STATE_DIR=$(mktemp -d -p /dev/shm ebook_forge_state_XXXXXX)
echo 0 > "$STATE_DIR/sukcesy"
echo 0 > "$STATE_DIR/pominiete"
echo 0 > "$STATE_DIR/bledy"

# Funkcja rysująca pasek postępu w terminalu CLI
draw_cli_progress() {
    local pct=$1
    local width=30
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local bar_f=$(printf "%${filled}s" | tr ' ' '=')
    local bar_e=$(printf "%${empty}s" | tr ' ' '-')
    printf "\r\033[1;33mProgress: [%s>%s] %3d%%\033[0m" "$bar_f" "$bar_e" "$pct"
}

run_processing() {
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
    
    [ "$USE_GUI" = true ] && echo "$BAZA_PROCENT" || draw_cli_progress "$BAZA_PROCENT"

    if [ -f "Audiobooks/${NAZWA_BAZOWA}.${FORMAT_WYJSCIOWY}" ]; then
      log_msg "[$AKTUALNY/$LACZNIE] POMINIĘTO: Audiobooks/${NAZWA_BAZOWA}.${FORMAT_WYJSCIOWY} już istnieje." "$PLIK_LOGU_KSIAZKI"
      POMINIETE=$((POMINIETE + 1))
      echo "$POMINIETE" > "$STATE_DIR/pominiete"
      continue
    fi

    CACHE_DIR=".cache_${NAZWA_BAZOWA}"
    mkdir -p "$CACHE_DIR"
    MANIFEST_FILE="${CACHE_DIR}/manifest.json"
    TXT_FILE="${CACHE_DIR}/book.txt"

    # Manifest Cache Check
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
        log_msg "[$AKTUALNY/$LACZNIE] Niezgodność konfiguracji cache dla $NAZWA_BAZOWA. Niszczenie starego cache..." "$PLIK_LOGU_KSIAZKI"
        rm -rf "$CACHE_DIR"
        mkdir -p "$CACHE_DIR"
      fi
    fi

    python3 -c '
import json, sys
data = {
    "source": sys.argv[1],
    "voice": sys.argv[2],
    "language": sys.argv[3],
    "format": sys.argv[4],
    "bitrate": sys.argv[5],
    "parts": int(sys.argv[6]),
    "version": "0.3"
}
with open(sys.argv[7], "w", encoding="utf-8") as f:
    json.dump(data, f, indent=4)
' "$PLIK" "$GLOS" "$JEZYK" "$FORMAT_WYJSCIOWY" "$BITRATE" "$LICZBA_CZESCI" "$MANIFEST_FILE"
    
    # KROK 1: Ekstrakcja tekstu
    if [ ! -s "$TXT_FILE" ]; then
      TEMP_TXT="${CACHE_DIR}/extract.txt"
      rm -f "$TEMP_TXT"
      
      if [ "$ROZSZERZENIE" = "txt" ] || [ "$ROZSZERZENIE" = "TXT" ]; then
        cp "$PLIK" "$TEMP_TXT"
      else
        log_msg "\n[$AKTUALNY/$LACZNIE] $NAZWA_BAZOWA | Krok 1: Ekstrakcja tekstu przez Calibre..." "$PLIK_LOGU_KSIAZKI"
        timeout 600 ebook-convert "$PLIK" "$TEMP_TXT" >> "$PLIK_LOGU_GLOWNY" 2>> "$PLIK_LOGU_KSIAZKI"
      fi
      
      if [ -s "$TEMP_TXT" ]; then
        mv "$TEMP_TXT" "$TXT_FILE"
      fi
    fi

    if [ ! -s "$TXT_FILE" ]; then
      log_msg "[$AKTUALNY/$LACZNIE] BŁĄD: Nie udało się pozyskać tekstu z $PLIK." "$PLIK_LOGU_KSIAZKI"
      BLEDY=$((BLEDY + 1))
      echo "$BLEDY" > "$STATE_DIR/bledy"
      continue
    fi

    # KROK 2: Podział tekstu
    log_msg "[$AKTUALNY/$LACZNIE] $NAZWA_BAZOWA | Krok 2: Podział na $LICZBA_CZESCI części..." "$PLIK_LOGU_KSIAZKI"
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

    # KROK 3: Synteza mowy Edge-TTS
    for CZESC_TXT in "${CZESCI[@]}"; do
      NR_CZESCI=$((NR_CZESCI + 1))
      BAZA_NAZWA="${CZESC_TXT%.txt}"
      
      AKTUALNY_PROCENT=$(( BAZA_PROCENT + (NR_CZESCI * SKOK_NA_PLIK / SUMA_CZESCI) ))
      [ "$USE_GUI" = true ] && echo "$AKTUALNY_PROCENT" || draw_cli_progress "$AKTUALNY_PROCENT"

      if [ "$FORMAT_WYJSCIOWY" = "m4b" ] && [ -s "${BAZA_NAZWA}.m4a" ]; then
        printf "file '%s'\n" "$(basename "${BAZA_NAZWA}.m4a")" >> "$LISTA_SCALANIA"
        continue
      elif [ "$FORMAT_WYJSCIOWY" = "opus" ] && [ -s "${BAZA_NAZWA}.opus" ]; then
        printf "file '%s'\n" "$(basename "${BAZA_NAZWA}.opus")" >> "$LISTA_SCALANIA"
        continue
      fi

      if [ ! -s "$CZESC_TXT" ] || ! grep -q '[[:graph:]]' "$CZESC_TXT"; then
        log_msg "[$AKTUALNY/$LACZNIE] $NAZWA_BAZOWA | Część $NR_CZESCI: Pusty tekst, pomijanie." "$PLIK_LOGU_KSIAZKI"
        continue
      fi
      
      log_msg "\n[$AKTUALNY/$LACZNIE] $NAZWA_BAZOWA | Krok 3: Synteza mowy (część $NR_CZESCI z $SUMA_CZESCI)..." "$PLIK_LOGU_KSIAZKI"
      
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
        log_msg "[$AKTUALNY/$LACZNIE] BŁĄD KRYTYCZNY: Nie udało się pobrać części $NR_CZESCI." "$PLIK_LOGU_KSIAZKI"
        BladKsiazki=1
        break
      fi

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

    # KROK 4: Scalanie, okładki, walidacja
    if [ $BladKsiazki -eq 0 ]; then
      log_msg "\n[$AKTUALNY/$LACZNIE] $NAZWA_BAZOWA | Krok 4: Scalanie z rozdziałami i okładką..." "$PLIK_LOGU_KSIAZKI"
      
      OKLADKA=""
      if [ "$ROZSZERZENIE" != "txt" ]; then
        ebook-meta "$PLIK" --get-cover="${CACHE_DIR}/embedded_cover.jpg" &>/dev/null
        if [ -s "${CACHE_DIR}/embedded_cover.jpg" ]; then
          OKLADKA="${CACHE_DIR}/embedded_cover.jpg"
        fi
      fi
      if [ -z "$OKLADKA" ]; then
        for img in "${NAZWA_BAZOWA}.jpg" "${NAZWA_BAZOWA}.jpeg" "${NAZWA_BAZOWA}.png"; do
          if [ -f "$img" ]; then OKLADKA="$img"; break; fi
        done
      fi
      if [ -z "$OKLADKA" ]; then
        for img in cover.jpg cover.jpeg cover.png COVER.JPG COVER.PNG; do
          if [ -f "$img" ]; then OKLADKA="$img"; break; fi
        done
      fi

      FINAL_OUTPUT="Audiobooks/${NAZWA_BAZOWA}.${FORMAT_WYJSCIOWY}"
      TEMP_OUTPUT="${FINAL_OUTPUT}.tmp"

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

        if [ -n "$OKLADKA" ]; then
          ffmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i "$LISTA_SCALANIA" -i "$METADATA_FILE" -i "$OKLADKA" -map 0:a -map 2:v -map_metadata 1 -c:a copy -c:v mjpeg -metadata title="$NAZWA_BAZOWA" -metadata artist="Ebook Forge" -metadata album="$NAZWA_BAZOWA" -disposition:v:0 attached_pic "$TEMP_OUTPUT" >> "$PLIK_LOGU_GLOWNY" 2>> "$PLIK_LOGU_KSIAZKI"
        else
          ffmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i "$LISTA_SCALANIA" -i "$METADATA_FILE" -map 0:a -map_metadata 1 -c:a copy -metadata title="$NAZWA_BAZOWA" -metadata artist="Ebook Forge" -metadata album="$NAZWA_BAZOWA" "$TEMP_OUTPUT" >> "$PLIK_LOGU_GLOWNY" 2>> "$PLIK_LOGU_KSIAZKI"
        fi
      else
        if [ -n "$OKLADKA" ]; then
          ffmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i "$LISTA_SCALANIA" -i "$OKLADKA" -map 0:a -map 1:v -c:a copy -c:v mjpeg -metadata title="$NAZWA_BAZOWA" -metadata artist="Ebook Forge" -metadata album="$NAZWA_BAZOWA" -disposition:v:0 attached_pic "$TEMP_OUTPUT" >> "$PLIK_LOGU_GLOWNY" 2>> "$PLIK_LOGU_KSIAZKI"
        else
          ffmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i "$LISTA_SCALANIA" -c:a copy -metadata title="$NAZWA_BAZOWA" -metadata artist="Ebook Forge" -metadata album="$NAZWA_BAZOWA" "$TEMP_OUTPUT" >> "$PLIK_LOGU_GLOWNY" 2>> "$PLIK_LOGU_KSIAZKI"
        fi
      fi

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
        log_msg "SUKCES: Ukończono konwersję i walidację $NAZWA_BAZOWA" "$PLIK_LOGU_KSIAZKI"
      else
        log_msg "BŁĄD: Walidacja pliku wyjściowego nie powiodła się dla $NAZWA_BAZOWA." "$PLIK_LOGU_KSIAZKI"
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

  [ "$USE_GUI" = true ] && echo "100" || draw_cli_progress 100
}


# ==============================================================================
# 6. EXECUTION ENGINE (GUI Subshell vs Direct CLI)
# ==============================================================================
if [ "$USE_GUI" = true ]; then
    run_processing | zenity --progress \
      --title="Ebook Forge v0.3 - Konwersja w toku" \
      --text="Przetwarzanie e-booków..." \
      --percentage=0 \
      --width=500 \
      --auto-close \
      --auto-kill 2>/dev/null
    KOD_ZAKONCZENIA=$?
else
    echo -e "\n\033[1;32mRozpoczynam konwersję w trybie CLI...\033[0m\n"
    run_processing
    KOD_ZAKONCZENIA=0
    echo ""
fi


# ==============================================================================
# 7. SUMMARY & CLEANUP
# ==============================================================================
FINAL_SUKCESY=$(cat "$STATE_DIR/sukcesy" 2>/dev/null || echo 0)
FINAL_POMINIETE=$(cat "$STATE_DIR/pominiete" 2>/dev/null || echo 0)
FINAL_BLEDY=$(cat "$STATE_DIR/bledy" 2>/dev/null || echo 0)
rm -rf "$STATE_DIR"

SESJA_KONIEC=$(date +%s)
SESJA_CZAS=$((SESJA_KONIEC - SESJA_START))
S_MINUTY=$((SESJA_CZAS / 60))
S_SEKUNDY=$((SESJA_CZAS % 60))

if [ $KOD_ZAKONCZENIA -eq 0 ] || [ $KOD_ZAKONCZENIA -eq 5 ]; then
    if [ "$USE_GUI" = true ]; then
        zenity --info --title="Ebook Forge v0.3 - Zakończono" \
          --text="Sesja zakończona w czasie ${S_MINUTY}m ${S_SEKUNDY}s.\n\nSukcesy: $FINAL_SUKCESY\nPominięte: $FINAL_POMINIETE\nBłędy: $FINAL_BLEDY\n\nSprawdź foldery 'Audiobooks' oraz 'Logs'." 2>/dev/null
    else
        echo -e "\n\033[1;36m====================================================\033[0m"
        echo -e "\033[1;32m          ✅ PODSUMOWANIE SESJI EBOOK FORGE          \033[0m"
        echo -e "\033[1;36m====================================================\033[0m"
        echo " Czas trwania : ${S_MINUTY}m ${S_SEKUNDY}s"
        echo " Sukcesy      : $FINAL_SUKCESY"
        echo " Pominięte    : $FINAL_POMINIETE"
        echo " Błędy        : $FINAL_BLEDY"
        echo -e "\033[1;36m====================================================\033[0m\n"
    fi
else
    if [ "$USE_GUI" = true ]; then
        zenity --warning --title="Przerwano" \
          --text="Konwersja zatrzymana przez użytkownika. Cache zachowany do wznowienia." 2>/dev/null
    else
        echo -e "\n\033[0;31m[!] Konwersja została przerwana. Cache zachowany.\033[0m\n"
    fi
fi
