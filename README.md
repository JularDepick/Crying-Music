<div align="center">

# Crying-Music

[![Version](https://img.shields.io/badge/Version-v0.1.0-red)](./COMMERCIAL.md)
[![Copyright](https://img.shields.io/badge/Copyright-JularDepick-0066AA)](./COPYRIGHT)
[![License](https://img.shields.io/badge/License-AGPL--3.0-orange)](./LICENSE)

[简体中文]
| [English](./README_en-US.md)

</div>

---

一个参考主流音乐播放器实现的桌面音乐播放器, 界面由 Qt Quick / QML 绘制


## 功能特性

- 音乐库: 手动添加或扫描本地文件夹, 读取歌名, 歌手, 时长与封面, 按列表展示
- 播放: 播放暂停, 上下曲, 进度拖动, 音量调节, 播放顺序切换, 播放队列与断点续播
- 在线曲库: 首页推荐以封面网格展示, 支持流式播放与下载, 封面与歌词落在本地缓存
- 搜索: 顶栏关键字搜索, 精确与模糊两路匹配, 结果页可直接播放
- 歌词页: 全屏歌词, 逐行高亮, 增强歌词的逐字进度, 字号与偏移可调
- 设置与主题: 在线播放策略, 下载命名与目录, 缓存生命周期, 歌词增强开关, 四套预设配色


## 架构和技术

### Quick App
| 事项 | 技术 |
|:---:|:---:|
| 编程语言 | C++17 |
| 图形化 | Qt 6 Quick / QML |
| 多媒体 | Qt Multimedia |
| 网络 | Qt Network |
| 构建系统 | CMake |


## 目录结构
```
Crying-Music/
├── .github/workflows/      # GitHub Actions 工作流(静态站点部署, Quick App 发布)
├── src/                    # 源码目录
│   └── quick_app/          # Quick App(内部结构见 src/quick_app/README.md)
├── docs/                   # 开发参考文档
├── .gitignore              # Git 忽略配置
├── README.md               # 项目说明文档
├── README_en-US.md         # 英文说明文档
├── version.index.md        # 版本号索引
├── COMMERCIAL.md           # 商业授权联系方式
├── LICENSE                 # 许可证
└── COPYRIGHT               # 版权信息
```


## 源码目录索引
- [Quick App](./src/quick_app/README.md)


## 版权信息

Copyright &copy; 2026 JularDepick

详见 [COPYRIGHT](./COPYRIGHT)


## 许可证

本仓库采用 [AGPL-3.0 许可证](./LICENSE)

各子模块的第三方组件声明与相关义务见对应子模块的 README(如 [Quick App](./src/quick_app/README.md))
