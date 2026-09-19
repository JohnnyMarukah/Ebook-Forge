# Changelog

## [0.3.0] - 2026-09-19

### 🇵🇱 Polski

#### ✨ Dodano
- **Dual Mode (Auto-GUI / Auto-CLI):** Skrypt automatycznie wykrywa środowisko graficzne i uruchamia interfejs Zenity lub przełącza się na interaktywne menu terminalowe.
- **Pasek postępu CLI:** Wprowadzono tekstowy pasek postępu aktualizowany w czasie rzeczywistym podczas pracy w terminalu.
- **Atomowy Cache:** System wznawiania pracy (checkpointing). Przerwanie skryptu nie niszczy wygenerowanych już plików audio.
- **Inteligentne okładki:** Wielopoziomowe wykrywanie okładek (metadane Calibre -> plik nazwy książki -> standardowy `cover.jpg`).
- **Natywne Rozdziały:** Generowanie plików `.m4b` z pełnymi metadanymi czasowymi rozdziałów na smartfony.

#### 🐛 Naprawiono
- **Błąd ekstrakcji Calibre:** Naprawiono błąd `ValueError` przez zamianę rozszerzenia tymczasowego `.tmp` na `extract.txt`.
- **Formatowanie FFmpeg:** Wprowadzono jawne flagi kontenera (`-f mp4` oraz `-f ogg`) dla stabilności muxowania.
- **Krytyczny błąd Edge-TTS:** Dodano filtr pomijający puste pliki tekstowe, co zapobiega przerywaniu konwersji.
- **Rygorystyczna walidacja:** Zabezpieczono proces weryfikacji wyjściowych plików audio przy użyciu narzędzia `ffprobe`.

---

### 🇬🇧 English

#### ✨ Added
- **Dual Mode (Auto-GUI / Auto-CLI):** The script automatically detects the graphical environment to run the Zenity GUI or switch to an interactive CLI menu.
- **CLI Progress Bar:** Added a real-time text-based progress bar during terminal execution.
- **Atomic Cache:** Resume checkpointing system. Interrupting the script does not destroy already generated audio files.
- **Smart Covers:** Multi-tier cover detection (Calibre metadata -> book name file -> standard `cover.jpg`).
- **Native Chapters:** Generation of `.m4b` files with full chapter time metadata for smartphones.

#### 🐛 Fixed
- **Calibre Extraction Bug:** Fixed `ValueError` by replacing the `.tmp` extension with `extract.txt`.
- **FFmpeg Formatting:** Introduced explicit container flags (`-f mp4` and `-f ogg`) for muxing stability.
- **Edge-TTS Critical Bug:** Added a filter to skip empty text files, preventing conversion failures.
- **Strict Validation:** Secured the verification process of output audio files using `ffprobe`.
