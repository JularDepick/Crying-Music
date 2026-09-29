<div align="center">

# Crying-Music

[![Version](https://img.shields.io/badge/Version-v0.1.0-red)](./COMMERCIAL.md)
[![Copyright](https://img.shields.io/badge/Copyright-JularDepick-0066AA)](./COPYRIGHT)
[![License](https://img.shields.io/badge/License-AGPL--3.0-orange)](./LICENSE)

[简体中文]
| [English](./README_en-US.md)

</div>

---

一个参考了主流音乐播放器的实现。


## 架构和技术

### Quick App
| 事项 | 技术 |
|:---:|:---:|
| 编程语言 | C++17 |
| 图形化 | Qt 6 Quick / QML |
| 多媒体 | Qt Multimedia |
| 构建系统 | CMake |


## 目录结构
```
Crying-Music/
├── src/                    # 源码目录
│   └── quick_app/          # Quick App(内部结构见 src/quick_app/README.md)
├── docs/                   # 开发参考文档
├── .gitignore              # Git 忽略配置
├── README.md               # 项目说明文档
├── README_en-US.md         # 英文说明文档
├── LICENSE                 # 许可证
└── COPYRIGHT               # 版权信息
```


## 源码目录索引
- [Quick App](./src/quick_app/README.md)


## 版权信息

Copyright &copy; 2026 JularDepick

详见 [COPYRIGHT](./COPYRIGHT) 。


## 许可证

本仓库采用 [AGPL-3.0 许可证](./LICENSE) 。

各子模块的第三方组件声明与相关义务见对应子模块的 README(如 [Quick App](./src/quick_app/README.md))