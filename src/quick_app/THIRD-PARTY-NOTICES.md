# Crying-Music Quick App 第三方组件声明

本文件列出发布包内随包分发的第三方组件及其许可归属, 只做事实性说明, 不转载任何许可全文;
随包附有全文的只有 Qt 与 FFmpeg 两项, 分别见 LICENSE.Qt 与 LICENSE.FFmpeg, 其余组件的全文按本文件给出的地址向上游获取

## Qt

| 事项 | 说明 |
|:---:|:---:|
| 组件 | Qt 6.11.1 |
| 分发形式 | 动态库, 随发布包分发(Qt6Core.dll, Qt6Quick.dll, Qt6Multimedia.dll 等) |
| 许可 | GNU LGPL version 3, 本程序按 LGPLv3 使用其 LGPL 授权部分 |
| 版权 | Copyright (C) The Qt Company Ltd. and contributors |
| 许可全文 | 见发布包内 LICENSE.Qt |
| 源码获取 | 见发布包内 README.md 的 Qt 源码获取条目 |
| 可替换性 | Qt 以动态库形式分发, 用户可自行替换应用目录下的 Qt 动态库 |

## Qt 内置第三方组件

Qt 官方二进制包在编译时把下列组件静态链接进 Qt 动态库, 它们随 Qt 动态库一同分发,
不是发布包里单独的 DLL; 各组件均为宽松许可, 与 Qt 的 LGPLv3 兼容, 因此可以静态链接,
用户仍可整体替换 Qt 动态库, 见上一节的可替换性条目与 README.md 的修改与重新链接条目

| 组件 | Qt 6.11.1 内的版本 | 许可类型 | 官方源码获取 |
|:---:|:---:|:---:|:---:|
| zlib | 1.3.2 | Zlib License | https://github.com/madler/zlib |
| libpng | 1.6.58 | Libpng License 与 PNG Reference Library version 2 | https://github.com/pnggroup/libpng |
| FreeType | 2.14.3 | FreeType Project License 或 GNU GPL version 2 | https://gitlab.freedesktop.org/freetype/freetype |
| HarfBuzz | 14.5.0 | MIT License | https://github.com/harfbuzz/harfbuzz |
| PCRE2 | 10.48 | BSD 3-Clause 与 PCRE2 binary-like Packages Exception | https://github.com/PCRE2Project/pcre2 |

以上版本号取自 Qt 官方文档的第三方组件清单 https://doc.qt.io/qt-6/licenses-used-in-qt.html ,
该页同时给出每个组件在 Qt 文档中的许可全文页面(如 qtcore-attribution-zlib.html, qtgui-attribution-libpng.html),
这些全文不随本发布包分发, 需要时按上述地址获取

## FFmpeg 多媒体后端

| 事项 | 说明 |
|:---:|:---:|
| 组件 | Qt 6.11.1 官方二进制包随附的 FFmpeg 多媒体后端, FFmpeg 9.0.1 |
| 后端插件 | multimedia/ffmpegmediaplugin.dll |
| FFmpeg 库文件 | avcodec-61.dll, avformat-61.dll, avutil-59.dll, swresample-5.dll, swscale-8.dll |
| 版权归属 | FFmpeg 项目及其贡献者 |
| 许可说明 | 本程序分发的这一份按 GNU LGPL version 2.1 或更高版本授权, 未启用 GPL 专属组件; FFmpeg 上游默认按 GNU LGPL version 2.1 或更高版本授权, 启用 GPL 专属组件时整体按 GNU GPL version 2 或更高版本授权, 官方说明见 https://ffmpeg.org/legal.html |
| 许可全文 | 见发布包内 LICENSE.FFmpeg, 即 GNU LGPL version 2.1 全文 |
| 源码获取 | FFmpeg 官方源码发布见 https://ffmpeg.org/download.html , 本程序所用的版本与构建配置见 Qt 官方文档的第三方组件清单 https://doc.qt.io/qt-6/licenses-used-in-qt.html , 需要对应源码时也可向项目作者索取 |

## TagLib 音频标签库

| 事项 | 说明 |
|:---:|:---:|
| 组件 | TagLib 2.3.2 |
| 用途 | 读取本地音频(mp3, m4a, wav, flac, ogg)的标签, 内嵌封面与内嵌歌词 |
| 分发形式 | 静态链接进 CryingMusic.exe, 发布包里没有单独的 DLL; 源码目录内随附一份预构建产物, 即静态库与公开头文件(`src/quick_app/external/taglib/`), 便于他人从源码构建 |
| 许可 | GNU LGPL version 2.1 与 Mozilla Public License version 1.1 双许可; 本程序按 MPL-1.1 使用未修改的上游源码 |
| 版权 | Copyright (C) TagLib 项目及其贡献者, 主要作者 Scott Wheeler 等, 完整名单见上游仓库的 AUTHORS |
| 上游依赖 | https://github.com/taglib/taglib 与 https://taglib.org/ , 本程序未修改其源码 |
| 许可全文 | 随包分发的 `LICENSE.TagLib-LGPL` 与 `LICENSE.TagLib-MPL`, 即上游 COPYING.LGPL 与 COPYING.MPL 原文; 源码目录内见 `src/quick_app/external/taglib/` 下的同名文件 |
| 补充 | 若后续改为动态库分发, 需要把 tag.dll 一并放进发布包并更新本节; 随源码携带的那份是 MinGW 64 位构建的静态库, 只用于构建期链接, 不进发布包 |

## 随包分发的说明与许可文件

| 文件 | 说明 |
|:---:|:---:|
| LICENSE | 本项目 AGPL-3.0 许可全文 |
| COPYRIGHT | 本项目版权信息 |
| LICENSE.Qt | Qt 的 GNU GPLv3 与 GNU LGPLv3 全文以及 Qt 版权声明 |
| LICENSE.FDL | GNU 文档许可, 本项目不分发 Qt 文档 |
| LICENSE.FFmpeg | FFmpeg 后端的 GNU LGPL version 2.1 全文 |
| LICENSE.TagLib-LGPL | TagLib 的 GNU LGPL version 2.1 全文 |
| LICENSE.TagLib-MPL | TagLib 的 Mozilla Public License version 1.1 全文 |
| README.md | 本程序的中文说明文档 |
| README_en-US.md | 本程序的英文说明文档 |
| THIRD-PARTY-NOTICES.md | 本文件 |
