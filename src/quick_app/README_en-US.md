# Crying-Music Quick App

[简体中文](./README.md)
| [English]

# Features

- Music library: add files by hand or scan a local folder, probe metadata (title, artist, duration, cover), list them in the local and download pages
- Playback: play/pause, previous/next, seek and volume, play modes, playlist, restore the last position and volume on start
- Liked and recent: per song like flag and recent playback list, saved with the storage directory
- Online library: meta and manifest hosted on the online-data branch of this repository, recommendation grid on the home page, streaming playback and download, covers and lyrics cached, silent asset backfill for downloaded songs
- Search: top bar keyword search, exact and fuzzy recall plus unified ranking on the C++ side
- Lyrics page: full screen overlay, line highlight, per word progress for enhanced lyrics, four context menu items (font size, color, display position, offset), streaming lyrics shown while downloading
- Desktop floating lyrics: a separate floating window, its dragged position and colors are saved, toggled from the player bar, the lyrics page and the system tray
- System tray: menu with now playing, play/pause, previous, next, play order, like, desktop lyrics, show or hide the window and quit
- Settings: four categories (playback and download, lyrics and cache, key bindings, about and license), online play strategy, two download naming templates (title-artist, artist-title), download folder, cover cache lifetime and immediate cleanup, audio cache limit and immediate cleanup, lyrics enhancement switch, rebindable shortcuts for six playback actions
- Themes: six preset color schemes (four light and two dark), the choice is saved as a UI preference
- User: email code login without registration, login kept on disk for 7 days, QQ mailboxes get a cached QQ avatar, listening time is converted to a user level and reported periodically, playback is unaffected when signed out
- Shortcuts: Space for play/pause, Ctrl+Space to stop, Ctrl+Alt+, and Ctrl+Alt+. for previous and next, Ctrl+Up and Ctrl+Down for volume
- Playlist panel: one instance on the main window and one on the lyrics page, shared playlist, independent switches

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
├── CMakeLists.txt         # CMake build configuration
├── defines.hpp            # Global macros
├── main.cpp               # Entry point
├── Main.qml               # Main QML UI
├── DesignTask.md          # Design tasks
├── README.md              # Chinese documentation
├── README_en-US.md        # English documentation
├── LICENSE                # Full project license (same as the file in the repository root)
├── COPYRIGHT              # Copyright information (same as the file in the repository root)
├── LICENSE.Qt             # Full Qt license texts (GPLv3 and LGPLv3) and Qt copyright notice
├── LICENSE.FDL            # GNU Free Documentation License (Qt documentation is not distributed here)
├── LICENSE.FFmpeg         # Full LGPL-2.1 license text of the FFmpeg backend
├── THIRD-PARTY-NOTICES.md # Third party notices (Chinese only): Qt and the components bundled with it, plus FFmpeg
├── resource.qrc           # Qt resource manifest (license texts embedded under the licenses/ alias)
├── resource.rc            # Windows resource file
├── favicon.jpg            # Application icon
├── icon.ico               # Windows icon
├── reference.png          # UI reference image
├── .qtcreator/            # Qt Creator project user files (CMakeLists.txt.user, tracked by git)
├── assets/                # SVG icons (grouped by UI area under assets/iconfont)
├── components/            # C++ helper components
├── qml/                   # QML components and singletons
└── scripts/               # Helper scripts
```

# Version Index
- Every location is listed in [version.index.md](../../version.index.md) (Chinese only)

# Licensing and Third Party Notices

This program uses Qt through dynamic linking, Qt is licensed under GNU LGPL version 3

| Item | Description |
|:---:|:---:|
| Framework | Qt 6.11.1, distributed as dynamic libraries with the program |
| Qt license | GNU LGPL version 3, this program uses the LGPL licensed parts under LGPLv3 |
| Qt copyright | Copyright (C) The Qt Company Ltd. and contributors |
| License text | See [LICENSE.Qt](./LICENSE.Qt) in this directory, it contains the full GNU GPLv3 and GNU LGPLv3 texts and the Qt copyright notice |
| Qt source code | https://download.qt.io/official_releases/qt/6.11/6.11.1/ , ask the project author if the link is unavailable |
| Modify and relink | Qt ships as separate dynamic libraries, so anyone may replace the Qt libraries in the program directory, relink with a modified build and run this program; the program does not link Qt statically and does not prevent such a replacement |
| Project license | GNU AGPL version 3, full text in [LICENSE](./LICENSE) , copyright in [COPYRIGHT](./COPYRIGHT) , corresponding source at https://github.com/JularDepick/Crying-Music , that source is the Corresponding Source under section 6 of AGPL-3.0 and can be used to rebuild and relink this program |
| Replaceability | Qt is distributed as dynamic libraries, users may replace the Qt libraries in the application directory |
| Other third party components | See [THIRD-PARTY-NOTICES.md](./THIRD-PARTY-NOTICES.md) in this directory (Chinese only) for Qt and the components bundled with it (such as zlib, libpng, FreeType, HarfBuzz, PCRE2) and for the FFmpeg multimedia backend; the full LGPL-2.1 text of FFmpeg is in [LICENSE.FFmpeg](./LICENSE.FFmpeg), both files are shipped with the release package |
