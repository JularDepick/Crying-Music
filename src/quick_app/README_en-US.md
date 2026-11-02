# Crying-Music Quick App

[简体中文](./README.md)
| [English]

# Features

- Music library: add files by hand or scan a local folder, probe metadata (title, artist, duration, cover), list them in the local and download pages
- Playback: play/pause, previous/next, seek and volume, play modes, queue, restore the last position and volume on start
- Liked and recent: per song like flag and recent playback list, saved with the storage directory
- Online library: meta and manifest hosted on the online-data branch of this repository, recommendation grid on the home page, streaming playback and download, covers and lyrics cached, silent asset backfill for downloaded songs
- Search: top bar keyword search, exact and fuzzy recall plus unified ranking on the C++ side
- Lyrics page: full screen overlay, line highlight, per word progress for enhanced lyrics, font size and offset from the context menu, streaming lyrics shown while downloading
- Settings: tabs by category, online play strategy, three download naming templates, download folder, cover cache lifetime and immediate cleanup, lyrics enhancement switch
- Themes: four preset color schemes, the choice is saved as a UI preference
- Play list panel: one instance on the main window and one on the lyrics page, shared queue, independent switches

# Architecture and Technology

| Item | Technology |
|:---:|:---:|
| Programming Language | C++17 |
| GUI | Qt 6 Quick / QML (QtQuick.Controls.Basic) |
| Multimedia | Qt Multimedia (MediaPlayer / AudioOutput) |
| Network | Qt Network (QNetworkAccessManager) |
| Build System | CMake |
| Toolchain | MinGW 64-bit |

# Directory Structure

```
quick_app/
├── CMakeLists.txt  # CMake build configuration
├── defines.hpp     # Global macros
├── main.cpp        # Entry point
├── Main.qml        # Main QML UI
├── DesignTask.md   # Design tasks
├── README.md       # Chinese documentation
├── README_en-US.md # English documentation
├── LICENSE         # Full project license (same as the file in the repository root)
├── COPYRIGHT       # Copyright information (same as the file in the repository root)
├── LICENSE.Qt      # Full Qt license texts (GPLv3 and LGPLv3) and Qt copyright notice
├── LICENSE.FDL     # GNU Free Documentation License (Qt documentation is not distributed here)
├── resource.qrc    # Qt resource manifest (license texts embedded under the licenses/ alias)
├── resource.rc     # Windows resource file
├── favicon.jpg     # Application icon
├── icon.ico        # Windows icon
├── reference.png   # UI reference image
├── assets/         # SVG icons (grouped by UI area under assets/iconfont)
├── components/     # C++ helper components
├── qml/            # QML components and singletons
└── scripts/        # Helper scripts
```

# Version Index
- Every location is listed in [version.index.md](../../version.index.md)

# Licensing and Third Party Notices

This program uses Qt through dynamic linking, Qt is licensed under GNU LGPL version 3

| Item | Description |
|:---:|:---|
| Framework | Qt 6.11.1, distributed as dynamic libraries with the program |
| Qt license | GNU LGPL version 3, this program uses the LGPL licensed parts under LGPLv3 |
| Qt copyright | Copyright (C) The Qt Company Ltd. and contributors |
| License text | See [LICENSE.Qt](./LICENSE.Qt) in this directory, it contains the full GNU GPLv3 and GNU LGPLv3 texts and the Qt copyright notice |
| Qt source code | https://download.qt.io/official_releases/qt/6.11/6.11.1/ , ask the project author if the link is unavailable |
| Replaceability | Qt is distributed as dynamic libraries, users may replace the Qt libraries in the application directory |
| Other third party components | Licenses of components shipped with Qt (for example the FFmpeg multimedia backend) are covered by the upstream Qt license and SBOM documents |
| Project license | AGPL-3.0, see LICENSE and COPYRIGHT in the repository root |
