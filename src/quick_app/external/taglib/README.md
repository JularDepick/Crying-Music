# TagLib(预构建产物)

本目录是 TagLib 的安装前缀, 供 CMake 以 `find_package(TagLib CONFIG)` 的方式使用;
有了它, 从源码构建本项目只需要装 Qt, 不需要另外安装 TagLib.

## 上游依赖

| 事项 | 说明 |
|:---:|:---|
| 上游仓库 | https://github.com/taglib/taglib |
| 上游站点 | https://taglib.org/ |
| 版本 | 2.3.2 |
| 来源 | 按上游该版本的默认选项静态编译, 上游源码未做修改 |

## 许可与版权

| 事项 | 说明 |
|:---:|:---|
| 许可 | GNU Lesser General Public License version 2.1 与 Mozilla Public License version 1.1 双许可 |
| 本项目的选择 | 按 MPL-1.1 使用未修改的上游源码 |
| 版权 | Copyright (C) TagLib 项目及其贡献者, 主要作者 Scott Wheeler 等, 完整名单见上游仓库的 AUTHORS |
| LGPL 全文 | 同目录的 `COPYING.LGPL` |
| MPL 全文 | 同目录的 `COPYING.MPL` |

两份许可全文随源码与产物一起分发: 源码内就是本目录的这两个文件,
发布包内为 `LICENSE.TagLib-LGPL` 与 `LICENSE.TagLib-MPL`.

## 内容

| 路径 | 说明 |
|:---:|:---|
| `include/taglib/` | 公开头文件, 编译期需要 |
| `include/utf8cpp/` | TagLib 公开头文件依赖的 utf8cpp 头文件, 编译期需要 |
| `lib/libtag.a` | 预构建静态库, MinGW 64 位(x86_64) |
| `lib/cmake/taglib/` | 预构建的 CMake 包配置, 目标名 `TagLib::tag`, 会自动带出 `TAGLIB_STATIC` 与头文件目录 |
| `COPYING.LGPL` | GNU LGPL version 2.1 全文 |
| `COPYING.MPL` | Mozilla Public License version 1.1 全文 |

## 已知限制

- 静态库是 MinGW 64 位工具链(GCC)构建的, 只适用于 MinGW 套件;
  用 MSVC 构建时需要自行编译一份, 并用 `-DTAGLIB_ROOT=<安装前缀>` 指定, CMakeLists 会给出提示
- 静态链接需要 zlib, 由 MinGW 工具链自带(`x86_64-w64-mingw32/lib/libz.a`), CMakeLists 里直接链接 `z`
- 库是静态链接进 `CryingMusic.exe` 的, 发布包里没有单独的 TagLib 动态库

## 替换方式

- 用自行编译的 TagLib 覆盖本目录时, 保持同样的布局(`include/` 与 `lib/`)即可
- 也可以不覆盖, 构建时传 `-DTAGLIB_ROOT=<安装前缀>`
