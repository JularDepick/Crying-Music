# Crying-Music Quick App

[简体中文]
| [English](./README_en-US.md)

# 功能特性

- 音乐库: 手动添加或扫描本地文件夹, 元数据探测(歌名, 歌手, 时长, 封面), 本地与下载页列表
- 播放: 播放暂停, 上下曲, 进度拖动与音量, 播放顺序切换, 播放队列, 断点与音量落盘恢复
- 喜欢与最近: 单曲喜欢标记与最近播放列表, 随存储目录落盘
- 在线曲库: 元信息与清单由仓库的 online-data 分支托管, 首页推荐封面网格, 流式播放与下载, 封面与歌词缓存, 已下载曲目的资产静默补全
- 搜索: 顶栏关键字搜索, C++ 侧精确与模糊两路召回与统一排序
- 歌词页: 全屏覆盖层, 逐行高亮, 增强歌词的逐字进度, 右键调节字号与偏移, 在线歌词边下边显
- 设置: 按分类 tab 分页, 在线播放策略, 下载命名三档, 下载目录, 封面缓存生命周期与立即清理, 歌词增强开关
- 主题: 四套预设配色, 选择落盘为界面偏好
- 播放列表面板: 主界面与歌词页各一份实例, 队列共享, 开关互不干扰

# 架构和技术

| 事项 | 技术 |
|:---:|:---:|
| 编程语言 | C++17 |
| 图形化 | Qt 6 Quick / QML(QtQuick.Controls.Basic) |
| 多媒体 | Qt Multimedia(MediaPlayer / AudioOutput) |
| 网络 | Qt Network(QNetworkAccessManager) |
| 构建系统 | CMake |
| 工具链 | MinGW 64-bit |

# 目录结构

```
quick_app/
├── CMakeLists.txt  # CMake 构建配置
├── defines.hpp     # 宏定义
├── main.cpp        # 程序入口
├── Main.qml        # QML 主界面
├── DesignTask.md   # 设计任务
├── README.md       # 中文说明
├── README_en-US.md # 英文说明
├── LICENSE         # 项目许可全文(与仓库根目录同名文件一致)
├── COPYRIGHT       # 版权信息(与仓库根目录同名文件一致)
├── LICENSE.Qt      # Qt 许可全文(GPLv3 与 LGPLv3)与 Qt 版权声明
├── LICENSE.FDL     # GNU 文档许可(本项目不分发 Qt 文档)
├── resource.qrc    # qrc 资源清单(许可文本以 licenses/ 为别名嵌入)
├── resource.rc     # Windows 资源文件
├── favicon.jpg     # 应用图标
├── icon.ico        # Windows 图标
├── reference.png   # 界面参考图
├── assets/         # SVG 图标(assets/iconfont 下按界面分区)
├── components/     # C++ 辅助组件
├── qml/            # QML 组件与单例
└── scripts/        # 辅助脚本
```

# 版本号索引
- 全量出现位置见 [version.index.md](../../version.index.md)

# 开源许可与第三方声明

本程序以动态链接方式使用 Qt, Qt 按 GNU LGPL version 3 授权

| 事项 | 说明 |
|:---:|:---|
| 使用的框架 | Qt 6.11.1, 以动态库形式随程序分发 |
| Qt 许可 | GNU LGPL version 3, 本程序按 LGPLv3 使用其 LGPL 授权部分 |
| Qt 版权 | Copyright (C) The Qt Company Ltd. and contributors |
| 许可全文 | 见本目录 [LICENSE.Qt](./LICENSE.Qt), 内含 GNU GPLv3 与 GNU LGPLv3 全文以及 Qt 版权声明 |
| Qt 源码获取 | https://download.qt.io/official_releases/qt/6.11/6.11.1/ , 该链接不可用时向项目作者索取 |
| 可替换性 | Qt 以动态库形式随程序分发, 用户可自行替换应用目录下的 Qt 动态库 |
| 其它第三方组件 | Qt 随附的第三方组件(如多媒体后端的 FFmpeg)许可见上游 Qt 的许可与 SBOM 文档 |
| 本项目许可 | AGPL-3.0, 见仓库根目录 LICENSE 与 COPYRIGHT |
