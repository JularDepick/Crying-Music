# Crying-Music Quick App

[简体中文](./README.md)
| [English]

# Architecture and Technology

| Item | Technology |
|:---:|:---:|
| Programming Language | C++17 |
| GUI | Qt 6 Quick / QML |
| Multimedia | Qt Multimedia(MediaPlayer / AudioOutput) |
| Build System | CMake |

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
├── LICENSE.Qt      # Full Qt license texts (GPLv3 and LGPLv3) and Qt copyright notice
├── LICENSE.FDL     # GNU Free Documentation License (Qt documentation is not distributed here)
├── resource.qrc    # Qt resource manifest
├── resource.rc     # Windows resource file
├── favicon.jpg     # Application icon
├── icon.ico        # Windows icon
├── reference.png   # UI reference image
├── assets/         # SVG icons
├── components/     # C++ helper components
├── qml/            # QML components and singletons
└── scripts/        # Helper scripts
```

# Version Number Index
- The complete list is maintained in [version.index.md](../../version.index.md)

# Open Source License and Third-Party Notices

This application uses Qt with dynamic linking, and Qt is licensed under the GNU LGPL version 3

| Item | Description |
|:---:|:---|
| Framework | Qt 6.11.1, distributed as shared libraries together with the application |
| Qt license | GNU LGPL version 3, the LGPL-licensed parts are used under LGPLv3 |
| Qt copyright | Copyright (C) The Qt Company Ltd. and contributors |
| License texts | See [LICENSE.Qt](./LICENSE.Qt) in this directory, which contains the full GNU GPLv3 and GNU LGPLv3 texts and the Qt copyright notice |
| Qt source code | https://download.qt.io/official_releases/qt/6.11/6.11.1/ , or request it from the project author if the link is unavailable |
| Replaceability | Qt is distributed as shared libraries, so users may replace the Qt libraries inside the application directory |
| Other third-party components | Licenses of components bundled with Qt (such as FFmpeg in the multimedia backend) are documented in the upstream Qt license and SBOM documents |
| Project license | AGPL-3.0, see LICENSE and COPYRIGHT in the repository root |
