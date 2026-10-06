# 🛠️ Ebook Forge

**Ebook Forge** is a robust, production-ready Bash script designed to automatically convert your e-books and documents into high-quality audiobooks (supporting **M4B** with native chapters and cover art, or lightweight **Opus** files) using Calibre, FFmpeg, and Edge-TTS.

---

## Features

* **Smart Text Splitting**: Intelligently breaks large texts into manageable parts while maintaining paragraph integrity.
* **Atomic Caching**: Preserves progress and caches generated parts, allowing seamless resume capabilities if interrupted.
* **Multiple Output Formats**: 
  * `M4B`: Includes embedded chapter metadata and cover art (ideal for mobile devices).
  * `Opus`: Lightweight and compressed (great for PC/Linux storage).
* **Automated Validation**: Integrates `ffprobe` checks to ensure media integrity before writing final files.
* **Rich Notifications**: Modular integration options to notify you upon completion (Home Assistant webhook, email, etc.).

---

## Prerequisites

Ensure the following tools are installed on your system:
* `bash`
* `ffmpeg` & `ffprobe`
* `calibre` (`ebook-convert`, `ebook-meta`)
* `python3` & `edge-tts`
* `zenity` (for graphical dialogs)

---

## Usage

1. Clone or download the repository.
2. Make the script executable:
   chmod +x ebook_forge.sh
3. Run the script and select your target directory containing e-books:
   ./ebook_forge.sh

---

## Legal Disclaimer

### Third-Party Services (`edge-tts`)
This script utilizes `edge-tts` to interact with Microsoft online text-to-speech services via unofficial endpoints. 
* **No Affiliation:** Ebook Forge is an independent, open-source tool and is **not** affiliated with, endorsed, or sponsored by Microsoft Corporation.
* **API Changes:** Microsoft may modify or block access to these endpoints at any time. The author takes no responsibility for service disruptions.
* **Terms of Service:** Users are solely responsible for ensuring their usage complies with local laws, copyright regulations, and applicable terms of service.

### Intended Use
This tool is designed strictly for personal, educational, and offline use (converting lawfully acquired e-books for personal convenience). The author does not condone copyright infringement.

### Limitation of Liability
The software is provided "as is", without warranty of any kind. The author shall not be held liable for any claims or damages arising from the use of this software.

---

## License
Distributed under the MIT License. See `LICENSE` for more information.