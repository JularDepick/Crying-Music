<div align="center">

# Crying-Music

[![Version](https://img.shields.io/badge/Version-v0.1.0-red)](./COMMERCIAL.md)
[![Copyright](https://img.shields.io/badge/Copyright-JularDepick-0066AA)](./COPYRIGHT)
[![License](https://img.shields.io/badge/License-AGPL--3.0-orange)](./LICENSE)

[简体中文](./README.md)
| [English]

</div>

---

A desktop music player built as an implementation of mainstream players, with the whole UI drawn by Qt Quick / QML


## Features

- Music library: add files by hand or scan a local folder, read title, artist, duration and cover, then list them
- Playback: play/pause, previous/next, seek, volume, play modes, queue and resume from the last position
- Online library: recommendation grid on the home page, streaming playback and download, covers and lyrics cached on disk, played tracks cached whole for reuse when downloading
- Search: top bar keyword search with exact and fuzzy matching, results can be played directly
- Lyrics page: full screen lyrics, line highlight, per word progress for enhanced lyrics, adjustable font size and offset
- Settings and themes: online play strategy, download naming and folder, cover and audio cache limits and cleanup, lyrics enhancement switch, six preset color schemes (four light and two dark)


## Architecture and Technology

### Quick App
| Item | Technology |
|:---:|:---:|
| Programming Language | C++17 |
| GUI | Qt 6 Quick / QML |
| Multimedia | Qt Multimedia |
| Network | Qt Network |
| Build System | CMake |


## Directory Structure
```
Crying-Music/
├── .github/workflows/      # GitHub Actions workflows (static site deployment, Quick App release)
├── src/                    # Source directory
│   └── quick_app/          # Quick App (see src/quick_app/README.md)
├── docs/                   # Documentation
├── .gitignore              # Git ignore configuration
├── README.md               # Project documentation (Chinese)
├── README_en-US.md         # Project documentation (English)
├── version.index.md        # Version index
├── COMMERCIAL.md           # Commercial licensing contact
├── LICENSE                 # License file
└── COPYRIGHT               # Copyright information
```


## Source Directory Index
- [Quick App](./src/quick_app/README.md)


## Copyright

Copyright &copy; 2026 JularDepick

See [COPYRIGHT](./COPYRIGHT) for details.


## License

This repository is licensed under the [AGPL-3.0 License](./LICENSE)

Third party statements of each submodule live in that submodule's README (for example [Quick App](./src/quick_app/README.md))
