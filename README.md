# 🛠️ Ebook Forge

[![Bash](https://img.shields.io/badge/Language-Bash-4EAA25.svg)](#)
[![Python](https://img.shields.io/badge/Language-Python-3776AB.svg)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

*(Scroll down for the English version)*

## 🇵🇱 O projekcie (Polski)
**Ebook Forge** to potężny, kuloodporny skrypt napisany w Bashu i Pythonie, służący do automatycznej konwersji e-booków i dokumentów na wysokiej jakości audiobooki w formatach .m4b (z obsługą rozdziałów) oraz .opus. Narzędzie wykorzystuje niesamowicie naturalne głosy z usługi Microsoft Edge TTS i jest zaprojektowane z myślą o maksymalnej niezawodności, odporności na błędy sieciowe oraz wygodzie użytkowania.

### ✨ Główne funkcje
* **Dwa tryby pracy (Auto GUI/CLI):** Skrypt automatycznie wykrywa środowisko. Uruchom go na desktopie, a zobaczysz eleganckie okienka (Zenity). Uruchom przez SSH lub w Termuxie, a przełączy się w czytelny interfejs terminalowy z paskiem postępu.
* **Format M4B z rozdziałami:** Generuje natywne pliki .m4b z pełną obsługą rozdziałów i zapamiętywaniem pozycji odsłuchu na smartfonach. Dostępny również ultra-lekki format .opus.
* **Atomowy Cache i Wznawianie (Checkpointing):** Jeśli stracisz połączenie z internetem w połowie grubej książki, skrypt przy kolejnym uruchomieniu wznowi pracę dokładnie w miejscu przerwania, nie tracąc wygenerowanych już danych.
* **Inteligentne okładki:** Automatycznie wyciąga okładki z metadanych e-booka (Calibre) lub używa lokalnych plików graficznych (cover.jpg, nazwa książki).
* **Kuloodporna walidacja:** Każda wygenerowana część jest sprawdzana. Finalny audiobook przechodzi rygorystyczne testy przez ffprobe (rozmiar, czas trwania, błędy kontenera).
* **Samoorganizacja:** Po udanej konwersji, gotowy audiobook trafia do folderu Audiobooks/, oryginał do Processed/, a szczegółowe logi do Logs/.
* **Obsługiwane formaty wejściowe:** EPUB, MOBI, PDF, TXT, FB2, DOCX, ODT, RTF.

### ⚙️ Wymagania
Przed uruchomieniem upewnij się, że masz zainstalowane w systemie:
* calibre (zawiera ebook-convert i ebook-meta)
* ffmpeg i ffprobe
* python3
* edge-tts (instalacja przez: pip install edge-tts)
* zenity (tylko jeśli chcesz używać trybu okienkowego GUI)

### 🚀 Użycie
1. Pobierz skrypt i nadaj mu prawa do wykonywania wpisując w terminalu: chmod +x ebook_forge.sh
2. Uruchom skrypt poleceniem: ./ebook_forge.sh
3. Postępuj zgodnie z instrukcjami na ekranie, aby wybrać język, głos, format oraz jakość (bitrate).

### 📬 Kontakt i zgłaszanie błędów
Znalazłeś błąd, coś nie działa w Twoim środowisku, a może masz pomysł na nową funkcję? 
Całą komunikację prowadzimy publicznie, aby inni użytkownicy również mogli na tym skorzystać. Otwórz nowe zgłoszenie w zakładce Issues w tym repozytorium na GitHubie (dzięki temu unikamy też botów spamowych).

### ☕ Wsparcie
Jeśli ten skrypt okazał się dla Ciebie przydatny, oszczędził Ci mnóstwo czasu lub po prostu umilił słuchanie ulubionych książek, będzie mi bardzo miło, jeśli postawisz mi wirtualną kawę! Dzięki temu mam motywację do dalszego rozwijania projektu.

<a href="https://buymeacoffee.com/johnny.marukah" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>

---
---

## 🇬🇧 About the project (English)
**Ebook Forge** is a powerful, bulletproof Bash/Python script for automatically converting e-books and documents into high-quality audiobooks in .m4b (with native chapters) and .opus formats. It uses highly natural voices from Microsoft Edge TTS and is designed for maximum reliability, network fault tolerance, and ease of use.

### ✨ Key Features
* **Dual Mode (Auto GUI/CLI):** The script detects your environment. Run it on a desktop for elegant GUI dialogs (Zenity), or run it via SSH/Terminal for a clean CLI interactive menu with a progress bar.
* **Native M4B Chapters:** Generates .m4b files with full chapter support and playback resume functionality for mobile apps. Ultra-efficient .opus format is also available.
* **Atomic Cache & Resume Support:** If your internet connection drops halfway through a 1000-page book, Ebook Forge will resume exactly where it left off on the next run, without losing already generated audio.
* **Smart Cover Extraction:** Automatically extracts cover art from e-book metadata (via Calibre) or falls back to local images (cover.jpg, book title).
* **Bulletproof Validation:** Every audio chunk is verified. The final audiobook undergoes strict testing via ffprobe (size, duration, container errors).
* **Auto-organization:** Successfully converted audiobooks are moved to Audiobooks/, original files to Processed/, and detailed logs to Logs/.
* **Supported Input Formats:** EPUB, MOBI, PDF, TXT, FB2, DOCX, ODT, RTF.

### ⚙️ Requirements
Make sure you have the following dependencies installed:
* calibre (provides ebook-convert and ebook-meta)
* ffmpeg & ffprobe
* python3
* edge-tts (install via: pip install edge-tts)
* zenity (only if you want to use the GUI mode)

### 🚀 Usage
1. Download the script and make it executable by running: chmod +x ebook_forge.sh
2. Run the script: ./ebook_forge.sh
3. Follow the on-screen instructions to select the language, voice, format, and bitrate.

### 📬 Contact & Bug Reports
Found a bug, something isn't working in your environment, or you have a feature request? 
To keep things organized and avoid spam bots, all communication is handled directly on GitHub. Please open a new issue in the Issues tab of this repository.

### ☕ Support
If you find this script useful, if it saved you hours of reading, or just made enjoying your favorite books easier, consider buying me a coffee! Your support keeps me motivated to improve this project.

<a href="https://buymeacoffee.com/johnny.marukah" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>
