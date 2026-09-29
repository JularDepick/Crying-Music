# 版本号索引

- 当前版本: `v0.1.0`
- 维护方式: 版本号更迭时按下表逐处替换; 行号会随文件改动漂移, 因此每行同时给出定位关键字

## 出现位置

| 文件 | 行号 | 定位关键字 | 出现形式 |
|:---:|:---:|:---|:---|
| `README.md` | 5 | `badge/Version-` | 版本徽章 |
| `README_en-US.md` | 5 | `badge/Version-` | 版本徽章 |
| `src/quick_app/CMakeLists.txt` | 5 | `project(CryingMusic VERSION` | 项目版本声明 |
| `src/quick_app/defines.hpp` | 1 | `#define VERSION` | 版本宏 |
| `src/quick_app/resource.rc` | 4, 5 | `FILEVERSION` / `PRODUCTVERSION` | 可执行文件版本, 四段十进制数 |
| `src/quick_app/resource.rc` | 18, 23 | `FileVersion` / `ProductVersion` | 可执行文件版本, 字符串 |
| `version.index.md` | 3 | `- 当前版本:` | 本索引自身的当前版本行 |

## 不参与同步的位置

- 绑定了具体历史版本的文档, 其文件名与内部记载都属于历史事实, 更迭版本号时不改动
- `src/quick_app/CMakeLists.txt` 中 QML 模块的 `VERSION 1.0` 是模块版本, 与项目版本号无关
- 源码与构建脚本中对 `VERSION` 宏与 `${PROJECT_VERSION}` 的引用不写死数字, 无需同步
- 未被 git 追踪的文档内若另有版本声明, 由该文档自身维护, 不并入本索引

> 版本号中 `x` 表示十进制数, 不限制位数, 无前导 0
