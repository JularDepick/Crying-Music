#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""songfile_taglib.py: 音频文件的封面, 歌词与元信息注入与剥离

引擎: TagLib, 经 pytaglib 绑定(pip install pytaglib), 与客户端读取标签走同一套实现.

用法:
    python scripts/songfile_taglib.py --mode merge --input temp/in --output temp/out
    python scripts/songfile_taglib.py --mode depart --input temp/in --output temp/out
    python scripts/songfile_taglib.py --mode merge --fsong mp3,flac --fcover jpg --flyrics lrc

模式:
    merge   把同名不同后缀的封面, 歌词与元信息注入音频文件, 产物写到输出目录
    depart  把音频里内嵌的封面与歌词剥离成同名不同后缀的文件, 音频本身清空标签

输入输出:
    --input 与 --output 不能是同一个目录; 任一缺省时用 .input/ 与 .output/
    输出目录不存在时自动创建, 同名产物直接覆盖

控制台只输出一个 JSON 体: status, message, warnings, list

限制:
    歌词只写普通歌词字段(USLT / LYRICS / (c)lyr 这类纯文本), 词级时间戳 SYLT 无法经这个绑定写入
    官方 pytaglib 轮子里的 TagLib 没有编入 ogg 支持, ogg 文件 TagLib 打不开;
    这时若 PATH 上有 ffmpeg 与 ffprobe, 自动改用 ffmpeg 兜底(ogg 不支持内嵌封面), 并记一条告警
"""

import json
import os
import shutil
import subprocess
import sys

# ===== 配置区: 后缀清单, 扫描与输出都按清单顺序优先取靠前的 =====
# 音频后缀: 与客户端支持的容器一致
AUDIO_SUFFIXES = ["mp3", "m4a", "wav", "flac", "ogg"]
# 封面后缀
COVER_SUFFIXES = ["jpg", "jpeg", "png", "webp", "bmp"]
# 歌词后缀
LYRICS_SUFFIXES = ["lrc", "elrc", "txt"]
# 元信息后缀: 同名 JSON 里的 title / artist / album 会被写进音频
META_SUFFIXES = ["json"]
# 缺省目录
DEFAULT_INPUT_DIR = ".input"
DEFAULT_OUTPUT_DIR = ".output"
# 封面 MIME 到输出后缀: 剥离时按图片真实类型落盘
MIME_EXT = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp",
            "image/bmp": "bmp", "image/gif": "gif"}
# 元信息键: 大小写不敏感
META_KEYS = ("title", "artist", "album")
# ffmpeg 兜底用的可执行文件: 可用环境变量覆盖
FFMPEG = os.environ.get("SONGFILE_FFMPEG", "ffmpeg")
FFPROBE = os.environ.get("SONGFILE_FFPROBE", "ffprobe")
# 兜底时能内嵌封面的容器: ogg 与 wav 的封装不接受图片流
FFMPEG_COVER_OK = ("mp3", "flac", "m4a", "mp4", "aac")
# 图片编码名到输出后缀
CODEC_EXT = {"mjpeg": "jpg", "png": "png", "bmp": "bmp", "webp": "webp", "gif": "gif"}
# ===== 配置区结束 =====


def emit(status, message, warnings=None, items=None, code=0):
    """输出唯一一个 JSON 体并退出"""
    payload = {"status": status,
               "message": message,
               "warnings": list(warnings or []),
               "list": list(items or [])}
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    sys.exit(code)


def clean_path(text):
    """去掉用户带进来的引号与首尾空白"""
    value = str(text).strip()
    while len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        value = value[1:-1].strip()
    return value


def split_suffixes(values, fallback):
    """把 --fsong 这类参数展开成后缀清单: 支持逗号分隔与多次传入, 未给出时用缺省清单"""
    if not values:
        return list(fallback)
    out = []
    for one in values:
        for part in str(one).replace(";", ",").split(","):
            suffix = part.strip().lstrip(".").lower()
            if suffix and suffix not in out:
                out.append(suffix)
    return out or list(fallback)


def parse_args(argv):
    """解析命令行: 只认下面这些开关, 值可以带引号"""
    options = {"mode": "", "input": "", "output": "", "fsong": [], "fcover": [], "flyrics": []}
    index = 0
    while index < len(argv):
        token = argv[index]
        if token not in ("--mode", "--input", "--output", "--fsong", "--fcover", "--flyrics"):
            emit("error", "未知参数: %s" % token, code=1)
        if index + 1 >= len(argv):
            emit("error", "参数 %s 缺少取值" % token, code=1)
        value = clean_path(argv[index + 1])
        if token == "--mode":
            options["mode"] = value.lower()
        elif token == "--input":
            options["input"] = value
        elif token == "--output":
            options["output"] = value
        elif token == "--fsong":
            options["fsong"].append(value)
        elif token == "--fcover":
            options["fcover"].append(value)
        else:
            options["flyrics"].append(value)
        index += 2
    return options


def suffix_of(name):
    """文件后缀, 小写且不带点"""
    return os.path.splitext(name)[1].lstrip(".").lower()


def stem_of(name):
    """文件主名, 不含后缀"""
    return os.path.splitext(name)[0]


def list_dir(path):
    """列出目录下的常规文件, 只扫第一层"""
    try:
        return sorted(one for one in os.listdir(path)
                      if os.path.isfile(os.path.join(path, one)))
    except OSError:
        return []


def pick_sidecar(stem, suffixes, existing, warnings):
    """按后缀清单顺序找同名旁挂文件: 命中第一个就返回, 其余同类的记一条告警"""
    hits = [one for one in existing
            if stem_of(one) == stem and suffix_of(one) in suffixes]
    if not hits:
        return ""
    hits.sort(key=lambda one: suffixes.index(suffix_of(one)))
    if len(hits) > 1:
        warnings.append("同名旁挂文件不止一个, 取 %s, 忽略 %s" %
                        (hits[0], ", ".join(hits[1:])))
    return hits[0]


def sniff_mime(data, suffix):
    """按文件头判断图片类型, 认不出时退回后缀"""
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    if data[:2] == b"\xff\xd8":
        return "image/jpeg"
    if data[:6] in (b"GIF87a", b"GIF89a"):
        return "image/gif"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    if data[:2] == b"BM":
        return "image/bmp"
    return {"png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "gif": "image/gif",
            "webp": "image/webp", "bmp": "image/bmp"}.get(suffix, "image/jpeg")


def read_text(path, warnings):
    """按 UTF-8 读文本, 失败时退到 GBK 并记告警"""
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return handle.read()
    except UnicodeDecodeError:
        warnings.append("%s 不是 UTF-8, 按 GBK 读取" % os.path.basename(path))
        with open(path, "r", encoding="gbk", errors="replace") as handle:
            return handle.read()


def read_meta(path, warnings):
    """读同名 JSON 元信息: 只取 title / artist / album, 键名大小写不敏感"""
    text = read_text(path, warnings)
    try:
        raw = json.loads(text)
    except ValueError as error:
        warnings.append("%s 不是合法 JSON, 已跳过: %s" % (os.path.basename(path), error))
        return {}
    if not isinstance(raw, dict):
        warnings.append("%s 不是对象, 已跳过" % os.path.basename(path))
        return {}
    out = {}
    for key, value in raw.items():
        name = str(key).strip().lower()
        if name in META_KEYS:
            text_value = str(value).strip()
            if text_value:
                out[name] = text_value
    return out


def open_taglib():
    """惰性导入 pytaglib: 缺依赖时给出可读的提示"""
    try:
        import taglib
    except ImportError:
        emit("error", "缺少依赖 pytaglib, 先执行 pip install pytaglib", code=1)
    return taglib


def merge_one(taglib, input_dir, output_dir, name, cover, lyrics, fields, warnings):
    """注入: 复制音频到输出目录, 再把封面, 歌词与元信息写进这份产物"""
    src = os.path.join(input_dir, name)
    dst = os.path.join(output_dir, name)
    shutil.copyfile(src, dst)
    stem = stem_of(name)
    applied = []
    handle = taglib.File(dst)
    try:
        if fields:
            for key, value in fields.items():
                handle.tags[key.upper()] = [value]
            applied.append("元信息")
        if not (handle.tags.get("TITLE") or [""])[0]:
            handle.tags["TITLE"] = [stem]
            applied.append("曲名(取文件名)")
        if cover:
            with open(os.path.join(input_dir, cover), "rb") as image:
                data = image.read()
            handle.pictures = [taglib.Picture(data=data,
                                              mime_type=sniff_mime(data, suffix_of(cover)))]
            applied.append("封面")
        if lyrics:
            handle.tags["LYRICS"] = [read_text(os.path.join(input_dir, lyrics), warnings)]
            applied.append("歌词")
        handle.save()
    finally:
        handle.close()
    if not applied:
        warnings.append("%s 没有可注入的封面, 歌词或元信息" % name)
    return [dst], ("已注入: %s" % ", ".join(applied)) if applied else "只复制了音频"


def depart_one(taglib, input_dir, output_dir, name, cover_suffixes, lyrics_suffixes, warnings):
    """剥离: 音频清空标签后落到输出目录, 封面与歌词各存成同名不同后缀的文件"""
    src = os.path.join(input_dir, name)
    dst = os.path.join(output_dir, name)
    stem = stem_of(name)
    outputs = [dst]
    handle = taglib.File(src)
    try:
        pictures = list(handle.pictures)
        tags = dict(handle.tags)
    finally:
        handle.close()
    shutil.copyfile(src, dst)
    clean = taglib.File(dst)
    try:
        clean.tags.clear()
        clean.pictures = []
        clean.save()
    finally:
        clean.close()
    notes = []
    if pictures:
        mime = str(getattr(pictures[0], "mime_type", "") or "")
        if not mime:
            mime = sniff_mime(pictures[0].data, "")
        ext = MIME_EXT.get(mime, "")
        if ext and ext in cover_suffixes:
            cover_path = os.path.join(output_dir, stem + "." + ext)
            with open(cover_path, "wb") as image:
                image.write(pictures[0].data)
            outputs.append(cover_path)
            notes.append("封面")
        else:
            warnings.append("%s 的内嵌封面类型 %s 不在本次封面后缀清单内, 未落盘" %
                            (name, mime or "未知"))
    text = (tags.get("LYRICS") or [""])[0]
    if text.strip():
        ext = lyrics_suffixes[0]
        if "<" in text and "elrc" in lyrics_suffixes:
            ext = "elrc"
        lyrics_path = os.path.join(output_dir, stem + "." + ext)
        with open(lyrics_path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text if text.endswith("\n") else text + "\n")
        outputs.append(lyrics_path)
        notes.append("歌词")
    if not notes:
        warnings.append("%s 没有内嵌封面或歌词, 只落了干净音频" % name)
    return outputs, ("已剥离: %s" % ", ".join(notes)) if notes else "只落了干净音频"


def have_ffmpeg():
    """兜底引擎是否可用"""
    return bool(shutil.which(FFMPEG)) and bool(shutil.which(FFPROBE))


def run_ffmpeg(args):
    """跑一次 ffmpeg, 失败时抛出带 stderr 尾部的异常"""
    result = subprocess.run([FFMPEG, "-y", "-loglevel", "error"] + args,
                            capture_output=True, text=True, errors="replace")
    if result.returncode != 0:
        raise RuntimeError("ffmpeg 失败: %s" % (result.stderr or "").strip()[:200])
    return result


def ffprobe_info(path):
    """读一遍容器信息: 标签与流"""
    result = subprocess.run([FFPROBE, "-v", "quiet", "-print_format", "json",
                             "-show_format", "-show_streams", path],
                            capture_output=True, text=True, errors="replace")
    if result.returncode != 0:
        raise RuntimeError("ffprobe 失败: %s" % (result.stderr or "").strip()[:200])
    return json.loads(result.stdout or "{}")


def tags_lower(tags):
    """把容器里的标签键统一成小写, 方便按名字取值"""
    return {str(key).lower(): str(value) for key, value in (tags or {}).items()}


def merge_one_ffmpeg(input_dir, output_dir, name, cover, lyrics, fields, warnings):
    """ffmpeg 兜底注入: 音频流原样复制, 元信息与歌词写成容器自己的字段"""
    src = os.path.join(input_dir, name)
    dst = os.path.join(output_dir, name)
    ext = suffix_of(name)
    embed = bool(cover) and ext in FFMPEG_COVER_OK
    if cover and not embed:
        warnings.append("%s 的容器 %s 不支持内嵌封面, 封面未写入" % (name, ext))
    args = ["-i", src]
    if embed:
        args += ["-i", os.path.join(input_dir, cover), "-map", "0:a", "-map", "1:v",
                 "-c:v", "copy", "-disposition:v", "attached_pic"]
    else:
        args += ["-map", "0:a"]
    args += ["-c:a", "copy"]
    applied = []
    for key, value in fields.items():
        args += ["-metadata", "%s=%s" % (key, value)]
    if fields:
        applied.append("元信息")
    if lyrics:
        args += ["-metadata", "lyrics=" + read_text(os.path.join(input_dir, lyrics), warnings)]
        applied.append("歌词")
    args += [dst]
    run_ffmpeg(args)
    if embed:
        applied.append("封面")
    if not applied:
        warnings.append("%s 没有可注入的封面, 歌词或元信息" % name)
    return [dst], ("已注入(ffmpeg 兜底): %s" % ", ".join(applied)) if applied else "只复制了音频"


def depart_one_ffmpeg(input_dir, output_dir, name, cover_suffixes, lyrics_suffixes, warnings):
    """ffmpeg 兜底剥离: 音频流复制并清空标签, 封面与歌词另存同名文件"""
    src = os.path.join(input_dir, name)
    dst = os.path.join(output_dir, name)
    stem = stem_of(name)
    info = ffprobe_info(src)
    tags = tags_lower(info.get("format", {}).get("tags"))
    text = ""
    for key in ("lyrics", "unsyncedlyrics", "lyrics-eng", "lyrics-zh"):
        if tags.get(key, "").strip():
            text = tags[key]
            break
    outputs = [dst]
    run_ffmpeg(["-i", src, "-map", "0:a", "-c", "copy", "-map_metadata", "-1", dst])
    notes = []
    videos = [one for one in info.get("streams", []) if one.get("codec_type") == "video"]
    if videos:
        codec = str(videos[0].get("codec_name", "")).lower()
        ext = CODEC_EXT.get(codec, "")
        if ext and ext in cover_suffixes:
            cover_path = os.path.join(output_dir, stem + "." + ext)
            run_ffmpeg(["-i", src, "-map", "0:v:0", "-c", "copy", cover_path])
            outputs.append(cover_path)
            notes.append("封面")
        else:
            warnings.append("%s 的内嵌封面编码 %s 不在本次封面后缀清单内, 未落盘" %
                            (name, codec or "未知"))
    if text.strip():
        ext = lyrics_suffixes[0]
        if "<" in text and "elrc" in lyrics_suffixes:
            ext = "elrc"
        lyrics_path = os.path.join(output_dir, stem + "." + ext)
        with open(lyrics_path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text if text.endswith("\n") else text + "\n")
        outputs.append(lyrics_path)
        notes.append("歌词")
    if not notes:
        warnings.append("%s 没有内嵌封面或歌词, 只落了干净音频" % name)
    return outputs, ("已剥离(ffmpeg 兜底): %s" % ", ".join(notes)) if notes else "只落了干净音频"


def run_one(mode, taglib, input_dir, output_dir, name, cover_suffixes, lyrics_suffixes,
            existing, warnings):
    """先走 TagLib, 打不开时按需退到 ffmpeg"""
    stem = stem_of(name)
    cover = pick_sidecar(stem, cover_suffixes, existing, warnings) if mode == "merge" else ""
    lyrics = pick_sidecar(stem, lyrics_suffixes, existing, warnings) if mode == "merge" else ""
    meta = pick_sidecar(stem, META_SUFFIXES, existing, warnings) if mode == "merge" else ""
    fields = read_meta(os.path.join(input_dir, meta), warnings) if meta else {}
    try:
        if mode == "merge":
            return merge_one(taglib, input_dir, output_dir, name, cover, lyrics, fields, warnings)
        return depart_one(taglib, input_dir, output_dir, name, cover_suffixes,
                          lyrics_suffixes, warnings)
    except Exception as error:
        if not have_ffmpeg():
            raise
        warnings.append("%s 用 TagLib 处理失败, 改用 ffmpeg 兜底: %s" % (name, error))
        if mode == "merge":
            return merge_one_ffmpeg(input_dir, output_dir, name, cover, lyrics, fields, warnings)
        return depart_one_ffmpeg(input_dir, output_dir, name, cover_suffixes,
                                 lyrics_suffixes, warnings)


def main(argv):
    if len(argv) == 0:
        emit("error", "无参数拒绝执行: 至少给出 --mode merge 或 --mode depart", code=1)
    options = parse_args(argv)
    if options["mode"] not in ("merge", "depart"):
        emit("error", "--mode 只能是 merge 或 depart", code=1)
    input_dir = options["input"] or DEFAULT_INPUT_DIR
    output_dir = options["output"] or DEFAULT_OUTPUT_DIR
    input_dir = os.path.abspath(input_dir)
    output_dir = os.path.abspath(output_dir)
    if os.path.normcase(input_dir) == os.path.normcase(output_dir):
        emit("error", "输入目录与输出目录不能相同: %s" % input_dir, code=1)
    if not os.path.isdir(input_dir):
        emit("error", "输入目录不存在: %s" % input_dir, code=1)
    os.makedirs(output_dir, exist_ok=True)
    taglib = open_taglib()
    audio_suffixes = split_suffixes(options["fsong"], AUDIO_SUFFIXES)
    cover_suffixes = split_suffixes(options["fcover"], COVER_SUFFIXES)
    lyrics_suffixes = split_suffixes(options["flyrics"], LYRICS_SUFFIXES)
    existing = list_dir(input_dir)
    targets = [one for one in existing if suffix_of(one) in audio_suffixes]
    warnings = []
    items = []
    if not targets:
        warnings.append("输入目录里没有匹配的音频文件: %s" % ", ".join(audio_suffixes))
    for name in targets:
        try:
            outputs, note = run_one(options["mode"], taglib, input_dir, output_dir, name,
                                    cover_suffixes, lyrics_suffixes, existing, warnings)
            items.append({"input": os.path.join(input_dir, name),
                          "outputs": outputs, "ok": True, "message": note})
        except Exception as error:
            items.append({"input": os.path.join(input_dir, name),
                          "outputs": [], "ok": False,
                          "message": "%s: %s" % (type(error).__name__, error)})
    failed = [one for one in items if not one["ok"]]
    status = "ok" if not failed else ("partial" if items else "error")
    message = "%s 模式处理 %d 个音频, 成功 %d, 失败 %d" % (
        options["mode"], len(items), len(items) - len(failed), len(failed))
    emit(status, message, warnings, items, code=0 if status == "ok" else 2)


if __name__ == "__main__":
    main(sys.argv[1:])
