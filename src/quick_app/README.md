# Crying-Music Quick App

# 架构和技术

| 事项 | 技术 |
|:---:|:---:|
| 编程语言 | C++17 |
| 图形化 | Qt 6 Quick / QML |
| 多媒体 | Qt Multimedia(MediaPlayer / AudioOutput) |
| 构建系统 | CMake |

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
├── LICENSE.Qt      # Qt 许可全文(GPLv3 与 LGPLv3)与 Qt 版权声明
├── LICENSE.FDL     # GNU 文档许可(本项目不分发 Qt 文档)
├── licenses/       # 随存储目录补全的许可文本四件套(COPYRIGHT/LICENSE/LICENSE.FDL/LICENSE.Qt)
├── resource.qrc    # qrc 资源清单
├── resource.rc     # Windows 资源文件
├── favicon.jpg     # 应用图标
├── icon.ico        # Windows 图标
├── reference.png   # 界面参考图
├── assets/         # SVG 图标
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
