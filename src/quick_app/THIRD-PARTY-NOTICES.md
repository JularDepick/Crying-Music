# Crying-Music Quick App 第三方组件声明

本文件列出发布包内随包分发的第三方组件及其许可归属, 只做事实性说明, 不转载任何许可全文

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

## FFmpeg 多媒体后端

| 事项 | 说明 |
|:---:|:---:|
| 组件 | Qt 6.11.1 官方二进制包随附的 FFmpeg 多媒体后端 |
| 后端插件 | multimedia/ffmpegmediaplugin.dll |
| FFmpeg 库文件 | avcodec-61.dll, avformat-61.dll, avutil-59.dll, swresample-5.dll, swscale-8.dll |
| 版权归属 | FFmpeg 项目及其贡献者 |
| 许可说明 | FFmpeg 上游默认按 GNU LGPL version 2.1 或更高版本授权, 启用 GPL 专属组件时整体按 GNU GPL version 2 或更高版本授权, 官方说明见 https://ffmpeg.org/legal.html |
| 源码获取 | FFmpeg 官方源码发布见 https://ffmpeg.org/download.html , Qt 官方二进制包内 FFmpeg 的版本与构建配置见 Qt 官方对应版本的第三方许可与 SBOM 文档 |
| 许可全文 | 全文以上游发布为准, 本文件不转载 |

## 随包分发的说明与许可文件

| 文件 | 说明 |
|:---:|:---:|
| LICENSE | 本项目 AGPL-3.0 许可全文 |
| COPYRIGHT | 本项目版权信息 |
| LICENSE.Qt | Qt 的 GNU GPLv3 与 GNU LGPLv3 全文以及 Qt 版权声明 |
| LICENSE.FDL | GNU 文档许可, 本项目不分发 Qt 文档 |
| README.md | 本程序的说明文档 |
