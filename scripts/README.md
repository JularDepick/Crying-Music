# 辅助脚本

工作目录下的通用辅助脚本, 与 `src/quick_app/scripts/` 下的构建打包脚本分开存放: 这里放面向开发与测试的工具, 那里放随客户端构建产物走的脚本。

```
scripts/
├── README.md           # 本文件
└── songfile_taglib.py  # 音频文件的封面, 歌词与元信息注入与剥离
```

## songfile_taglib.py

把音频文件里内嵌的封面, 歌词与元信息剥离成同名不同后缀的旁挂文件, 或者反过来把旁挂文件注入音频文件。标签引擎是 TagLib, 经 `pytaglib` 绑定调用, 与客户端读取标签走同一套实现。

### 环境

| 依赖 | 说明 |
|:---:|:---|
| Python 3 | 脚本本身只用标准库 |
| pytaglib | 标签引擎, 执行 `pip install pytaglib` 安装; 官方轮子自带的 TagLib 没有编入 ogg 支持 |
| ffmpeg 与 ffprobe | 可选, 只在 TagLib 打不开某个文件时作为兜底; 需要在 PATH 上, 或用环境变量 `SONGFILE_FFMPEG` `SONGFILE_FFPROBE` 指定 |

### 用法

```
python scripts/songfile_taglib.py --mode merge  --input <输入目录> --output <输出目录>
python scripts/songfile_taglib.py --mode depart --input <输入目录> --output <输出目录>
python scripts/songfile_taglib.py --mode merge  --fsong mp3,flac --fcover jpg --flyrics lrc
```

| 参数 | 说明 |
|:---:|:---|
| `--mode` | 必填, `merge` 为合并(注入), `depart` 为拆分(剥离) |
| `--input` | 输入目录, 缺省为 `.input/`, 必须已存在 |
| `--output` | 输出目录, 缺省为 `.output/`, 不存在时自动创建 |
| `--fsong` | 本次只处理这些音频后缀, 逗号分隔或重复传入 |
| `--fcover` | 本次只使用这些封面后缀 |
| `--flyrics` | 本次只使用这些歌词后缀 |

约定:

- 不带任何参数直接拒绝执行, 输出 `status: error` 的 JSON 并退出码 1
- 输入目录与输出目录不能相同, 归一成绝对路径后比较
- 路径可以带引号, 含空格与非 ASCII 字符的目录已实测
- 只扫描输入目录的第一层, 不进子目录
- 输出目录里的同名产物一律覆盖

### 合并模式

1. 扫描输入目录里后缀命中清单的音频文件
2. 按后缀清单顺序找同名旁挂文件: 封面, 歌词, 元信息(同名 `.json` 里的 `title` `artist` `album`)
3. 把音频复制到输出目录, 再在这份产物上覆盖写入: 元信息字段, 封面(替换原有图片), 歌词(替换原有歌词)
4. 音频本身没有曲名时用文件名兜底

### 拆分模式

1. 扫描输入目录里后缀命中清单的音频文件
2. 音频复制到输出目录并清空全部标签与封面, 得到干净音频
3. 内嵌封面按图片真实类型落成同名 `.jpg` `.png` 等文件; 内嵌歌词落成同名歌词文件, 文本里带词级标记时优先 `.elrc`

### 输出

控制台只输出一个 JSON 体, 便于上层脚本直接解析:

```json
{
  "status": "ok",
  "message": "merge 模式处理 2 个音频, 成功 2, 失败 0",
  "warnings": [],
  "list": [
    {
      "input": "…\\in\\song.mp3",
      "outputs": ["…\\out\\song.mp3"],
      "ok": true,
      "message": "已注入: 元信息, 封面, 歌词"
    }
  ]
}
```

| 字段 | 说明 |
|:---:|:---|
| `status` | `ok` 全部成功, `partial` 有文件失败, `error` 整体无法执行 |
| `message` | 一句话汇总 |
| `warnings` | 告警清单, 例如旁挂文件重复, 封面类型不在清单内, 退回兜底引擎 |
| `list` | 每个输入文件的产物路径, 成功与否与说明 |

退出码: `ok` 为 0, `partial` 为 2, `error` 为 1。

### 配置区

脚本顶部的配置区集中了后缀清单与缺省目录, 扫描与输出都按清单顺序优先取靠前的:

| 常量 | 缺省值 | 用途 |
|:---:|:---|:---|
| `AUDIO_SUFFIXES` | mp3, m4a, wav, flac, ogg | 音频后缀, 与客户端支持的容器一致 |
| `COVER_SUFFIXES` | jpg, jpeg, png, webp, bmp | 封面后缀 |
| `LYRICS_SUFFIXES` | lrc, elrc, txt | 歌词后缀 |
| `META_SUFFIXES` | json | 元信息后缀 |
| `DEFAULT_INPUT_DIR` | .input | 缺省输入目录 |
| `DEFAULT_OUTPUT_DIR` | .output | 缺省输出目录 |

### 限制与已知取舍

- 歌词只写纯文本字段(`USLT` / `LYRICS` / `©lyr` 这类), 词级时间戳 `SYLT` 经这个绑定写不进去, 合并产物只有行级歌词
- 官方 pytaglib 轮子自带的 TagLib 没有编入 ogg 支持, ogg 文件常常打不开; 这时若 PATH 上有 ffmpeg 与 ffprobe 会自动兜底, 并记一条告警
- 兜底引擎下 ogg 与 wav 的封装不接受图片流, 封面写不进去, 只写元信息与歌词
- 拆分时只取第一张内嵌封面; 封面与歌词的输出后缀由真实类型决定, 不在 `--fcover` `--flyrics` 清单内时跳过并告警
- 合并与拆分都不改音频流本身, 只重写容器里的标签数据
