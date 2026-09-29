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
├── README.md       # 本文件
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
- [CMakeLists.txt:5](CMakeLists.txt)
- [defines.hpp:1](defines.hpp)
