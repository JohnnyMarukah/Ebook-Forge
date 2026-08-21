# 🛠️ Ebook Forge

> **Transform your digital library and documents into immersive audiobooks.**

**Ebook Forge** is an advanced, lightweight Linux tool designed to automatically convert e-books and text documents into high-quality, perfectly split audiobooks in **Opus** format. Built with stability and reliability in mind, it handles large files effortlessly, protects your SSD using RAM-based temporary storage, and includes built-in recovery mechanisms to survive network interruptions.

---

## ✨ Key Features

* **Wide Format Support:** Handles EPUB, MOBI, PDF, TXT, FB2, DOCX, ODT, and RTF (with full case-insensitive extension matching).
* **Smart Text Splitting:** Automatically splits books into 30 equal parts, completely eliminating the common issue of truncated or cut-off audiobook endings.
* **Network Resilience:** Features built-in automatic retries and delay intervals to gracefully handle DNS timeouts or unstable internet connections during speech synthesis.
* **RAM Optimization:** Utilizes `/dev/shm` (RAM memory) for temporary text and audio processing to speed up operations and save your SSD from unnecessary write cycles.
* **Clean Graphical Interface:** Powered by Zenity, offering folder selection dialogs, dynamic progress bars, and clean graceful exits.
* **Comprehensive Logging:** Generates a main session log (`konwersja.log`) as well as individual summary logs (`.log`) with conversion durations for every processed file.

---

## 📦 Dependencies

Before running Ebook Forge, ensure you have the following tools installed on your Linux system:

1. **Calibre** (`ebook-convert`): Used for extracting raw text from various e-book and document formats.
2. **FFmpeg**: Used for high-efficiency audio compression (`libopus`) and seamless file merging.
3. **Zenity**: Required for graphical dialogs and progress bars.
4. **Python 3**: Required for text parsing and volume-based splitting.
5. **edge-tts**: Python-based text-to-speech engine leveraging Microsoft Edge's neural voices.

### Installation on Ubuntu / Debian:
```bash
sudo apt update
sudo apt install calibre ffmpeg zenity python3 python3-pip
pip install edge-tts
