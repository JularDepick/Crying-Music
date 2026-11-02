pragma Singleton
import QtQuick

import AppHelper 1.0

import "./"

Item {
    id: serverRoot;
    /* 远程数据分布:
        * 元信息(meta.json)在仓库的 online-data 分支, 它的候选地址写在下面的 meta_file_url, 是在线曲库的唯一入口
        * 歌曲清单, 音频本体, 封面, 歌词与增强歌词都由元信息声明: 若干个备用数据根, 以及各类资源在数据根下的目录与扩展名
     * 资源获取流程:
        * 依次尝试多个备用地址 oss.meta_file_url[i] ,拿到即止
        * 元信息就绪后立即按它声明的目录结构与扩展名解析进 oss.audio_*_base_url 与 oss.audio_*_ext:
          * audio_base_url[i] 依次加 audio.manifest_file, audio.file_folder, audio.cover_folder,
            audio.lyrics_lrc_folder 与 audio.lyrics_elrc_folder, 得到各类资源的候选前缀
          * 扩展名分别取 audio.file_ext, audio.cover_ext, audio.lyrics_lrc_ext 与 audio.lyrics_elrc_ext
        * 清单只给不带扩展名的主文件名, 播放地址, 封面名与歌词名都由它加各自的扩展名拼出
        * 将获取到的 JSON 内容分别覆盖存进同结构的 oss.meta 与 oss.manifest
        * 元信息和清单文件体积小、更新频繁, 直接用 XMLHttpRequest 即时拉取; 封面与歌词由 C++ 侧下载到本地缓存后复用
    */
    property var oss:
    ({
        /* 元信息的候选地址: 在线曲库的唯一入口, 只能在这里硬编码 */
        "meta_file_url": [
            "https://raw.githubusercontent.com/JularDepick/Crying-Music/online-data/oss/meta.json",
            "https://JularDepick.github.io/Crying-Music/oss/meta.json",
            "https://cdn.jsdelivr.net/gh/JularDepick/Crying-Music@online-data/oss/meta.json"
        ],
        /* 获取到的元信息原文与清单原文 */
        "meta": ({}),
        "manifest": [],
        /* 以下各项由元信息解析而来: *_base_url 为数据根加目录拼好的候选前缀, *_ext 为该类文件的扩展名;
         * 元信息未就绪时全部为空 */
        "audio_manifest_base_url": [],
        "audio_file_base_url": [],
        "audio_file_ext": "",
        "audio_cover_base_url": [],
        "audio_cover_ext": "",
        "audio_lyrics_lrc_base_url": [],
        "audio_lyrics_lrc_ext": "",
        "audio_lyrics_elrc_base_url": [],
        "audio_lyrics_elrc_ext": ""
    });
    /* 清单加载状态: 0 未加载, 1 加载中, 2 已就绪, 3 加载失败 */
    property int loadState: 0;
    /* 最近一次失败的原因, 供界面提示使用 */
    property string loadError: "";
    /* 已播放在线歌曲的时长与大小: 键为播放地址, 值形如 {duration:秒, size:字节};
     * 只作为元数据就绪前的临时显示数据, 随在线缓存一起落盘 */
    property var playedMeta: ({});
    /* 正在探测字节数的在线歌曲与探测失败的歌曲: 每首歌只探测一次 */
    property var _sizeProbing: ({});
    property var _sizeMiss: ({});
    /* 封面缓存: 封面文件名 -> 带版本串的本地缓存地址, 整体替换以便界面绑定能收到通知 */
    property var coverCache: ({})
    /* 封面缓存索引: 封面文件名 -> {path:本地路径, at:缓存时刻毫秒, ttl:该条目自己的生命周期毫秒};
     * 生命周期在写入时定下, 之后在设置页改档位不影响已经缓存的封面 */
    property var coverIndex: ({})
    /* 歌词缓存: 歌词文件名 -> 本地缓存路径, 整体替换以便界面绑定能收到通知;
     * 歌词是纯文本且体积很小, 不做生命周期, 落盘后长期复用 */
    property var lyricsCache: ({})
    /* 歌词偏移索引: 键为歌词缓存文件名, 值形如 {offsetMs: 毫秒}; 正值表示歌词提前显示 */
    property var lyricsIndex: ({})
    /* 拉取失败的歌词: 本进程内不再重试 */
    property var lyricsMiss: ({})
    /* 正在拉取的歌词: 同一份歌词同一时刻只保留一组对冲请求 */
    property var _lyricsPending: ({})
    /* 歌词流式来源: 键为歌词名, 值为首个开始返回数据的源; 同一份歌词的其余源的部分文本丢弃 */
    property var _lyricsOwners: ({})
    /* 歌词的部分文本: 只用于边下边显, 完整内容仍以歌词缓存文件为准 */
    signal lyricsPartial(string lyricsName, string text);
    /* 后台补全队列与是否正在补全 */
    property var _coverQueue: []
    property bool _coverFilling: false
    /* 索引是否需要写盘 */
    property bool _coverIndexDirty: false;
    /* 拉取失败的封面, 不再重试 */
    property var coverMiss: ({});
    /* 正在拉取的封面: 同一个封面同一时刻只保留一组对冲请求 */
    property var _coverPending: ({});
    /* 对冲拉取的并发上限: A 管元信息, 清单与歌词, B 管封面补全, 两套计数互不挤占 */
    property int fetchLimitA: 8;
    property int fetchLimitB: 8;
    /* 在途请求表: 每项是一次"某个资源的某个候选源"的请求 */
    property var _netReqs: []
    /* 因并发上限而排队的分组 */
    property var _netQueue: []
    /* 尝试键 -> 尝试对象, 供 C++ 的下载回调找回自己的请求 */
    property var _netByKey: ({})
    /* 是否有一次拉取在途: 并发保护, 静默刷新与普通拉取互斥 */
    property bool _fetching: false;
    /* 对外的拉取在途状态: 界面据此禁用刷新入口, 避免点出并行的拉取 */
    readonly property bool fetching: _fetching;
    /* 本次拉取是否静默: 静默刷新只更新数据与缓存, 不改界面可见的加载状态 */
    property bool _silent: false;
    /* 曲库数据发生变化(拉取成功或后台刷新成功), 供界面按需重建 */
    signal manifestUpdated();
    /* 封面缓存被清空: 界面据此重建一次, 让可见的封面按需重新缓存 */
    signal coverCacheCleared();
    /* 歌词缓存就绪: 界面据此重新读一次该歌词文本 */
    signal lyricsUpdated(string lyricsName);
    /* 是否处于失败后的自动重试中 */
    property bool _retryOn: false;
    /* 当前的重试间隔: 每失败一次加一个步长, 到上限封顶, 成功后复位 */
    property int _retryGapMs: Define.onlineRetryBaseMs;
    /* 本次运行的元信息是否来自本地缓存: 该模式下失败不切换界面状态, 改为后台轮询 */
    property bool _metaFromCache: false;
    /* 缓存模式下的后台轮询开关: meta 源已全部失败, 轮询只更新缓存文件, 不打断本次运行 */
    property bool _metaPollOn: false;
    /* 缓存指向的对象存储是否已确认不可用(404): 置位后立即重取元信息, 拿到即启用 */
    property bool _ossDead: false;
    /* 是否已升级为立即重取: 升级期间的失败按退避节拍继续重试 */
    property bool _escalateOn: false;
    /* 元信息声明的数据根基址, 用于识别 404 是否来自元信息指向的数据根 */
    property var _ossRoots: [];
    /* 数据根健康表: 键为元信息声明的数据根基址, 值为 true 表示本次运行内已判死;
     * 在线音频的播放或下载在这个根上失败时置位, 之后取用地址跳过它
     */
    property var _rootDown: ({})
    /* 已实证可用的主机来源(小写) -> true: 元信息, 清单, 封面与歌词的任一次成功都算一次实证,
     * 在线音频优先取用这些来源的数据根, 避免把不可达的数据根排在前面
     */
    property var _liveOrigins: ({})
    /* 失败后的重试节拍: 首次按退避下限等待, 每次重试先把间隔拉长一个步长, 到上限封顶;
     * 拉取成功即停表并复位
     */
    Timer {
        id: retryTimer;
        interval: serverRoot._retryGapMs;
        repeat: true;
        running: serverRoot._retryOn;
        onTriggered: {
            serverRoot._retryTick();
        }
    }
    /* 资产补全的节拍: 队列非空时每 5 秒检查一次 */
    Timer {
        id: assetTimer;
        interval: 5000;
        repeat: true;
        running: serverRoot._assetItems.length>0;
        onTriggered: {
            serverRoot._assetTick();
        }
    }
    /* 缓存模式下的元信息轮询: 按节拍持续取最新元信息, 成功也只写缓存文件 */
    Timer {
        id: metaPollTimer;
        interval: Define.onlineMetaPollMs;
        repeat: true;
        running: serverRoot._metaPollOn;
        onTriggered: {
            serverRoot._metaPollTick();
        }
    }
    /* 封面缓存索引写盘: 连续拉取时合并成一次写入 */
    Timer {
        id: coverIndexTimer;
        interval: 2000;
        repeat: false;
        running: serverRoot._coverIndexDirty;
        onTriggered: {
            serverRoot.saveCoverIndex();
        }
    }
    /* 对冲拉取的心跳: 有在途或排队请求时按 50ms 检查对冲与硬超时, 并给排队的分组补位 */
    Timer {
        id: netTimer;
        interval: 50;
        repeat: true;
        running: (serverRoot._netReqs.length>0 || serverRoot._netQueue.length>0);
        onTriggered: {
            serverRoot._netTick();
        }
    }
    /* 小文件下载回调: 封面走 C++, 歌词走 QML 自己的 XHR, 因此这里只处理封面的尝试 */
    Connections {
        target: AppNetHelper;
        function onCachedFileReady(attemptKey,localPath) {
            var req=serverRoot._netByKey[attemptKey];
            if(req===undefined || req===null || req.closed===true) {
                return;
            }
            if(req.group.validate && req.group.validate(localPath)===false) {
                serverRoot._netLose(req,"缓存路径无效");
                return;
            }
            serverRoot._netWin(req,localPath);
        }
        function onSizeReady(taskKey,bytes) {
            delete serverRoot._sizeProbing[taskKey];
            serverRoot.rememberSize(taskKey,bytes);
        }
        function onSizeFailed(taskKey,reason) {
            delete serverRoot._sizeProbing[taskKey];
            serverRoot._sizeMiss[taskKey]=true;
            Assist.dwarn("在线","音频大小探测失败: ",taskKey,", 原因 ",reason);
        }
        function onCachedFileFailed(attemptKey,reason) {
            var req=serverRoot._netByKey[attemptKey];
            if(req===undefined || req===null || req.closed===true) {
                return;
            }
            serverRoot._netLose(req,reason);
        }
        /* 4xx 或 5xx 状态: 404 交给元信息侧判断缓存里的元信息是否已过时 */
        function onHttpError(url,status) {
            if(status===404) {
                serverRoot._noteOssStatus(url);
            }
        }
    }
    /* 数据根基址归一: 元信息的 audio_base_url 给出多个备用数据根, 允许是数组或单个字符串;
     * 去空白, 补齐末尾分隔符并去重; 元信息不合格时返回空数组 */
    function _metaRoots(meta) {
        var res=[];
        if(meta===null || meta===undefined || typeof meta!=="object") {
            return res;
        }
        var raw=meta.audio_base_url;
        var list=(Array.isArray(raw)? raw:(typeof raw==="string"? [raw]:[]));
        for(var i=0;i<list.length;i++) {
            var b=(typeof list[i]==="string"? String(list[i]).trim():"");
            if(b==="") {
                continue;
            }
            if(b.charAt(b.length-1)!=="/") {
                b=b+"/";
            }
            if(res.indexOf(b)<0) {
                res.push(b);
            }
        }
        return res;
    }
    /* 目录字段归一: 去掉前导分隔符并补齐末尾分隔符; 空值返回空字符串 */
    function _folderOf(value) {
        var s=(typeof value==="string"? String(value).trim():"");
        while(s.charAt(0)==="/") {
            s=s.substring(1);
        }
        return (s===""? "":(s.charAt(s.length-1)==="/"? s:s+"/"));
    }
    /* 扩展名字段归一: 补齐前导点号; 空值返回空字符串 */
    function _extOf(value) {
        var s=(typeof value==="string"? String(value).trim():"");
        return (s===""? "":(s.charAt(0)==="."? s:"."+s));
    }
    /* 按元信息声明的目录结构与扩展名构造各类资源的候选前缀: 数据根与目录拼成前缀,
     * 同一数据根下清单, 音频, 封面, 普通歌词与增强歌词各一条前缀 */
    function _parseOss(meta) {
        var spec=({"audio_manifest_base_url":[],
                   "audio_file_base_url":[],
                   "audio_file_ext":"",
                   "audio_cover_base_url":[],
                   "audio_cover_ext":"",
                   "audio_lyrics_lrc_base_url":[],
                   "audio_lyrics_lrc_ext":"",
                   "audio_lyrics_elrc_base_url":[],
                   "audio_lyrics_elrc_ext":""});
        if(meta===null || meta===undefined || typeof meta!=="object") {
            return spec;
        }
        var a=(meta.audio!==null && meta.audio!==undefined && typeof meta.audio==="object"
               ? meta.audio:({}));
        var manifestFile=(typeof a["manifest_file"]==="string"? String(a["manifest_file"]).trim():"");
        var fileDir=_folderOf(a["file_folder"]);
        var coverDir=_folderOf(a["cover_folder"]);
        var lrcDir=_folderOf(a["lyrics_lrc_folder"]);
        var elrcDir=_folderOf(a["lyrics_elrc_folder"]);
        var roots=_metaRoots(meta);
        for(var i=0;i<roots.length;i++) {
            var root=roots[i];
            if(manifestFile!=="") {
                spec.audio_manifest_base_url.push(root+manifestFile);
            }
            if(fileDir!=="") {
                spec.audio_file_base_url.push(root+fileDir);
            }
            if(coverDir!=="") {
                spec.audio_cover_base_url.push(root+coverDir);
            }
            if(lrcDir!=="") {
                spec.audio_lyrics_lrc_base_url.push(root+lrcDir);
            }
            if(elrcDir!=="") {
                spec.audio_lyrics_elrc_base_url.push(root+elrcDir);
            }
        }
        spec.audio_file_ext=_extOf(a["file_ext"]);
        spec.audio_cover_ext=_extOf(a["cover_ext"]);
        spec.audio_lyrics_lrc_ext=_extOf(a["lyrics_lrc_ext"]);
        spec.audio_lyrics_elrc_ext=_extOf(a["lyrics_elrc_ext"]);
        return spec;
    }
    /* 元信息是否可用: 至少有一个数据根, 且能拼出清单与音频的前缀 */
    function _metaValid(meta) {
        var spec=_parseOss(meta);
        return (spec.audio_manifest_base_url.length>0 && spec.audio_file_base_url.length>0);
    }
    /* 按候选前缀拼出地址: 文件名按 URL 规则编码, 以兼容中文与日文文件名 */
    function _urlsOf(bases,name) {
        var res=[];
        if(Array.isArray(bases)!==true || typeof name!=="string" || name==="") {
            return res;
        }
        var enc=encodeURIComponent(name);
        for(var i=0;i<bases.length;i++) {
            var base=String(bases[i]);
            if(base!=="") {
                res.push(base+enc);
            }
        }
        return res;
    }
    /* 在线标识的规范地址: 取第一个候选数据根拼出, 它就是存储里的在线标识,
     * 收藏, 最近播放, 播放队列与下载记录都以它为键, 因此本函数不随数据根健康度变化
     */
    function audioUrlOf(onlineId) {
        var list=_urlsOf(oss.audio_file_base_url,onlineId);
        return (list.length>0? list[0]:"");
    }
    /* 在线音频的全部候选地址: 每个数据根一条, 顺序即元信息声明的顺序 */
    function audioUrlCandidates(onlineId) {
        return _urlsOf(oss.audio_file_base_url,onlineId);
    }
    /* 地址所属的数据根: 取与地址前缀匹配的数据根基址, 不属于任何数据根时返回空字符串 */
    function _rootOf(url) {
        var u=String(url);
        for(var i=0;i<_ossRoots.length;i++) {
            var root=String(_ossRoots[i]);
            if(root!=="" && u.indexOf(root)===0) {
                return root;
            }
        }
        return "";
    }
    /* 地址的主机来源(小写): 用来判断这台主机本次运行内是否已经实证可用 */
    function _originOf(url) {
        var u=String(url);
        var i=u.indexOf("://");
        if(i<0) {
            return "";
        }
        var j=u.indexOf("/",i+3);
        return (j<0? u:u.substring(0,j)).toLowerCase();
    }
    /* 记一次实证: 某次拉取成功即说明这台主机本次运行内可用 */
    function noteOriginLive(url) {
        var o=_originOf(url);
        if(o==="") {
            return false;
        }
        _liveOrigins[o]=true;
        return true;
    }
    /* 在线音频的实际取用地址: 跳过本次运行内已判死的数据根, 优先取已实证可用的主机;
     * 候选全部判死时退回 fallback(缺省取第一个候选), 保持判死之前的行为;
     * 它只决定实际请求哪个地址, 不改变在线标识本身
     */
    function mediaUrlOf(onlineId,fallback) {
        var list=audioUrlCandidates(onlineId);
        var fb=(typeof fallback==="string"? fallback:"");
        if(list.length<=0) {
            return fb;
        }
        var first="";
        for(var i=0;i<list.length;i++) {
            var u=list[i];
            if(_rootDown[_rootOf(u)]===true) {
                continue;
            }
            if(_liveOrigins[_originOf(u)]===true) {
                return u;
            }
            if(first==="") {
                first=u;
            }
        }
        if(first!=="") {
            return first;
        }
        return (fb!==""? fb:list[0]);
    }
    /* 换根重试用到的下一个地址: 跳过当前地址与已判死的数据根, 没有可换的返回空字符串 */
    function mediaUrlAfter(onlineId,currentUrl) {
        var list=audioUrlCandidates(onlineId);
        var cur=String(currentUrl);
        for(var i=0;i<list.length;i++) {
            var u=list[i];
            if(u===cur || _rootDown[_rootOf(u)]===true) {
                continue;
            }
            return u;
        }
        return "";
    }
    /* 把某个数据根判死: 在线音频在它上面播放或下载失败时调用, 只认元信息声明的数据根;
     * 判死只作用于本次运行, 下次启动重新从元信息的声明顺序开始
     */
    function markMediaDead(url) {
        var root=_rootOf(url);
        if(root==="") {
            return false;
        }
        if(_rootDown[root]===true) {
            return false;
        }
        _rootDown[root]=true;
        Assist.dwarn("在线","数据根本次运行内判为不可用: ",root);
        return true;
    }
    /* 是否为在线键: 在线歌曲在存储里的标识就是它的播放地址 */
    function isOnlineKey(key) {
        return (typeof key==="string" && (key.indexOf("http://")===0 || key.indexOf("https://")===0));
    }
    /* 清单行数组: 未就绪时为空数组 */
    function manifestRows() {
        return (Array.isArray(oss.manifest)? oss.manifest: []);
    }
    /* 歌手数组拼成一行文本: 多歌手用斜杠分隔 */
    function singersText(singers) {
        if(Array.isArray(singers)===false) {
            return "未知歌手";
        }
        var res=[];
        for(var i=0;i<singers.length;i++) {
            var s=String(singers[i]);
            if(s!=="") {
                res.push(s);
            }
        }
        return (res.length>0? res.join("/"):"未知歌手");
    }
    /* 清单行的主文件名: 清单只给不带扩展名的主文件名, 各类资源都用它加各自的扩展名 */
    function rowFileName(row) {
        if(row===null || row===undefined || typeof row!=="object" || typeof row["fn"]!=="string") {
            return "";
        }
        return String(row["fn"]);
    }
    /* 在线标识: 主文件名加音频扩展名, 等于线上文件名, 因此下载记录与已播放缓存都不受清单结构变化影响 */
    function onlineIdOfRow(row) {
        var fn=rowFileName(row);
        return (fn===""? "":fn+String(oss.audio_file_ext));
    }
    /* 封面名: 主文件名加封面扩展名 */
    function coverNameOfRow(row) {
        var fn=rowFileName(row);
        return (fn===""? "":fn+String(oss.audio_cover_ext));
    }
    /* 歌词名: 主文件名加普通歌词扩展名; 增强歌词只在缺普通歌词时兜底, 缓存仍按这个名字落盘 */
    function lyricsNameOfRow(row) {
        var fn=rowFileName(row);
        return (fn===""? "":fn+String(oss.audio_lyrics_lrc_ext));
    }
    /* 由清单行构造条目: 在线标识取主文件名加音频扩展名, 播放地址取第一个数据根拼出;
     * 时长优先取清单声明的秒数, 清单没有该字段时退回已播放缓存 */
    function onlineEntryOfRow(row) {
        var id=onlineIdOfRow(row);
        if(id==="") {
            return null;
        }
        var url=audioUrlOf(id);
        if(url==="") {
            return null;
        }
        var pm=playedMetaOf(url);
        var dur=(typeof row["dur"]==="number" && row["dur"]>0
                 ? Math.floor(row["dur"]):(pm===null? 0:pm["duration"]));
        var sn=(typeof row["sn"]==="string" && row["sn"]!==""? row["sn"]:rowFileName(row));
        /* 封面与歌词由列表委托在行可见时按需请求, 避免一次性发起上百个请求 */
        return ({
            "songname": sn,
            "singer": singersText(row["sgr"]),
            "absfpath": url,
            "absipath": "",
            "size": (pm===null? 0:pm["size"]),
            "duration": dur,
            "source": "online",
            "online": true,
            "onlineId": id,
            "cover": coverNameOfRow(row),
            "lyrics": lyricsNameOfRow(row),
            "liked": GlobalFileStorage.isLiked(url),
            "checked": false
        });
    }
    /* 由在线键反查条目: 清单未就绪或查不到时退回用地址末段当曲名 */
    function onlineEntryOfKey(key) {
        if(isOnlineKey(key)===false) {
            return null;
        }
        var rows=manifestRows();
        for(var i=0;i<rows.length;i++) {
            if(audioUrlOf(onlineIdOfRow(rows[i]))===key) {
                return onlineEntryOfRow(rows[i]);
            }
        }
        var name=key;
        var cut=name.lastIndexOf("/");
        if(cut>=0) {
            name=name.substring(cut+1);
        }
        try {
            name=decodeURIComponent(name);
        } catch(e) {
            name=key;
        }
        var dot=name.lastIndexOf(".");
        if(dot>0) {
            name=name.substring(0,dot);
        }
        var pm2=playedMetaOf(key);
        return ({
            "songname": name,
            "singer": "未知歌手",
            "absfpath": key,
            "absipath": "",
            "size": (pm2===null? 0:pm2["size"]),
            "duration": (pm2===null? 0:pm2["duration"]),
            "source": "online",
            "online": true,
            "onlineId": "",
            "cover": "",
            "lyrics": "",
            "liked": GlobalFileStorage.isLiked(key),
            "checked": false
        });
    }
    /* 按在线标识反查条目: 下载记录里存的是在线标识(主文件名加音频扩展名), 不是播放地址 */
    function onlineEntryOfId(onlineId) {
        if(typeof onlineId!=="string" || onlineId==="") {
            return null;
        }
        var rows=manifestRows();
        for(var i=0;i<rows.length;i++) {
            if(onlineIdOfRow(rows[i])===onlineId) {
                return onlineEntryOfRow(rows[i]);
            }
        }
        return null;
    }
    /* 拉取失败后的一次性放弃: 每个资源记为 {tries:失败次数, at:最近一次失败时刻};
     * 失败次数用尽后本次运行不再重试, 未用尽时冷却一段时间再放行, 以便瞬时故障自愈
     */
    readonly property int missMaxTries: 3
    readonly property int missCooldownMs: 60000
    /* 某个资源当前是否仍处于放弃状态 */
    function _missActive(map,name) {
        var one=map[name];
        if(one===undefined || one===null) {
            return false;
        }
        var tries=(typeof one==="object" && typeof one["tries"]==="number"? one["tries"]:1);
        if(tries>=missMaxTries) {
            return true;
        }
        var at=(typeof one==="object" && typeof one["at"]==="number"? one["at"]:0);
        return ((Date.now()-at)<missCooldownMs);
    }
    /* 记一次失败: 失败次数累加并刷新时刻 */
    function _noteMiss(map,name) {
        var one=map[name];
        var tries=(one!==undefined && one!==null && typeof one==="object"
                    && typeof one["tries"]==="number"? one["tries"]+1:1);
        map[name]=({"tries":tries,"at":Date.now()});
        return tries;
    }
    /* 封面缓存路径: 未缓存时为空字符串 */
    function coverPathOf(coverName) {
        if(typeof coverName!=="string" || coverName==="") {
            return "";
        }
        var p=coverCache[coverName];
        return (typeof p==="string"? p:"");
    }
    /* 封面的候选地址: 由元信息给出的封面前缀依次拼出 */
    function coverUrlCandidates(coverName) {
        return _urlsOf(oss.audio_cover_base_url,coverName);
    }
    /* 请求一个封面的本地缓存: 已缓存或已失败时直接返回, 每个封面只发起一组对冲请求 */
    function requestCover(coverName) {
        if(typeof coverName!=="string" || coverName==="") {
            return false;
        }
        if(coverPathOf(coverName)!=="") {
            return true;
        }
        if(_missActive(coverMiss,coverName)===true || _coverPending[coverName]===true) {
            return false;
        }
        return _coverRequest(coverName,false);
    }
    /* 发起一组封面拉取: 同一封面同一时刻只允许一组; force 为真时忽略已存在的缓存文件 */
    function _coverRequest(name,force) {
        if(typeof name!=="string" || name==="") {
            return false;
        }
        if(_coverPending[name]===true) {
            return false;
        }
        var urls=coverUrlCandidates(name);
        if(GlobalFileStorage.coverCacheDir()==="" || urls.length<=0) {
            return false;
        }
        _coverPending[name]=true;
        return _netStart("cover",name,urls,
                         {"force":(force===true),
                          "validate":function(localPath) { return (typeof localPath==="string" && localPath!==""); },
                          "ok":function(localPath) { serverRoot._coverDone(name,localPath); },
                          "fail":function(reason) { serverRoot._coverFailed(name,reason); }});
    }
    /* 封面拿到: 记进缓存与索引, 并推进补全队列 */
    function _coverDone(name,localPath) {
        delete _coverPending[name];
        delete coverMiss[name];
        var at=Date.now();
        var c=({});
        for(var k in coverCache) {
            c[k]=coverCache[k];
        }
        c[name]=String(localPath)+"?t="+String(at);
        coverCache=c;
        var idx=({});
        for(var k2 in coverIndex) {
            idx[k2]=coverIndex[k2];
        }
        idx[name]=({"path":String(localPath),"at":at,"ttl":coverTtlMs()});
        coverIndex=idx;
        _coverIndexDirty=true;
        Assist.dlog("在线","封面已缓存: ",name);
        _pumpCoverQueue();
    }
    /* 封面全部候选源都失败: 本进程内不再重试 */
    function _coverFailed(name,reason) {
        delete _coverPending[name];
        _noteMiss(coverMiss,name);
        Assist.derror("在线","封面拉取失败: ",name,", 原因 ",reason);
        _pumpCoverQueue();
    }
    /* 歌词缓存路径: 未缓存时为空字符串, 值是可直接读盘的文件地址 */
    function lyricsPathOf(lyricsName) {
        if(typeof lyricsName!=="string" || lyricsName==="") {
            return "";
        }
        var p=lyricsCache[lyricsName];
        return (typeof p==="string"? p:"");
    }
    /* 按歌词增强开关取这一档实际使用的歌词名: 关闭时用普通歌词(lrc), 开启时用增强歌词(elrc);
     * 入参是清单给出的普通歌词名, 出参是这一档要缓存与显示的文件名 */
    function lyricsVariantName(lyricsName) {
        var name=String(lyricsName===undefined || lyricsName===null? "":lyricsName);
        if(name==="") {
            return "";
        }
        var lrcExt=String(oss.audio_lyrics_lrc_ext);
        var elrcExt=String(oss.audio_lyrics_elrc_ext);
        var main=name;
        /* 入参可能已经是某一档的歌词名: 两档的扩展名都剥掉, 保证本函数可以重复调用 */
        if(lrcExt!=="" && main.length>lrcExt.length
           && main.substring(main.length-lrcExt.length)===lrcExt) {
            main=main.substring(0,main.length-lrcExt.length);
        }
        if(elrcExt!=="" && main.length>elrcExt.length
           && main.substring(main.length-elrcExt.length)===elrcExt) {
            main=main.substring(0,main.length-elrcExt.length);
        }
        if(GlobalFileStorage.lyricsEnhanced()!==true || elrcExt==="") {
            return main+lrcExt;
        }
        return main+elrcExt;
    }
    /* 歌词的候选地址: 增强开启时先按数据根试增强歌词, 再退回普通歌词(仍可显示, 只是没有逐字进度);
     * 增强关闭时只试普通歌词; 无论实际取到哪一种, 缓存一律按这一档的歌词名落盘 */
    function lyricsUrlCandidates(lyricsName) {
        var res=[];
        var name=String(lyricsName===undefined || lyricsName===null? "":lyricsName);
        if(name==="") {
            return res;
        }
        var lrcExt=String(oss.audio_lyrics_lrc_ext);
        var elrcExt=String(oss.audio_lyrics_elrc_ext);
        var main=name;
        if(lrcExt!=="" && main.length>lrcExt.length
           && main.substring(main.length-lrcExt.length)===lrcExt) {
            main=main.substring(0,main.length-lrcExt.length);
        }
        if(elrcExt!=="" && main.length>elrcExt.length
           && main.substring(main.length-elrcExt.length)===elrcExt) {
            main=main.substring(0,main.length-elrcExt.length);
        }
        if(elrcExt!=="") {
            var enh=_urlsOf(oss.audio_lyrics_elrc_base_url,main+elrcExt);
            for(var i=0;i<enh.length;i++) {
                res.push(enh[i]);
            }
        }
        if(lrcExt!=="") {
            var lrc=_urlsOf(oss.audio_lyrics_lrc_base_url,main+lrcExt);
            for(var j=0;j<lrc.length;j++) {
                res.push(lrc[j]);
            }
        }
        return res;
    }
    /* 请求一份歌词: 已缓存或已失败时直接返回; 歌词按当前播放项单条拉取, 不做后台补全 */
    function requestLyrics(lyricsName) {
        var name=lyricsVariantName(lyricsName);
        if(name==="") {
            return false;
        }
        if(lyricsPathOf(name)!=="") {
            return true;
        }
        if(_missActive(lyricsMiss,name)===true || _lyricsPending[name]===true) {
            return false;
        }
        var urls=lyricsUrlCandidates(name);
        if(GlobalFileStorage.lyricsCacheDir()==="" || urls.length<=0) {
            return false;
        }
        _lyricsPending[name]=true;
        var started=_netStart("lyrics",name,urls,
                              {"validate":function(text) { return (typeof text==="string" && text!==""); },
                               "ok":function(text) { serverRoot._lyricsDone(name,text); },
                               "fail":function(reason) { serverRoot._lyricsFailed(name,reason); }});
        if(started!==true) {
            delete _lyricsPending[name];
        }
        return started;
    }
    /* 歌词拿到: 写盘并记进内存索引 */
    function _lyricsDone(lyricsName,text) {
        var dir=GlobalFileStorage.lyricsCacheDir();
        var path=dir+"/"+lyricsName;
        var ok=(dir!=="" && AppFileHelper.writeFile(path,text,"UTF-8")===true);
        delete _lyricsPending[lyricsName];
        delete _lyricsOwners[lyricsName];
        if(ok!==true) {
            _noteMiss(lyricsMiss,lyricsName);
            Assist.dwarn("在线","歌词写入失败: ",lyricsName);
            return false;
        }
        delete lyricsMiss[lyricsName];
        var m=({});
        for(var k in lyricsCache) {
            m[k]=lyricsCache[k];
        }
        m[lyricsName]=path;
        lyricsCache=m;
        Assist.dlog("在线","歌词已缓存: ",lyricsName);
        lyricsUpdated(lyricsName);
        return true;
    }
    /* 歌词全部候选源都失败: 本进程内不再重试 */
    function _lyricsFailed(lyricsName,reason) {
        delete _lyricsPending[lyricsName];
        delete _lyricsOwners[lyricsName];
        _noteMiss(lyricsMiss,lyricsName);
        Assist.derror("在线","歌词拉取失败: ",lyricsName,", 原因 ",reason);
    }
    /* 歌词缓存概况: 已缓存份数与清单条目数, 供设置页显示 */
    function lyricsCacheStats() {
        return ({"cached":Object.keys(lyricsCache).length,
                 "total":manifestRows().length});
    }
    /* 读盘: 歌词缓存目录里已有的歌词直接接管, 以文件名为键, 无需重新下载 */
    function loadLyricsCache() {
        var dir=GlobalFileStorage.lyricsCacheDir();
        if(dir==="") {
            return false;
        }
        var files=AppFileHelper.listFiles(dir);
        var m=({});
        for(var i=0;i<files.length;i++) {
            var url=String(files[i]);
            var cut=url.lastIndexOf("/");
            if(cut<0) {
                continue;
            }
            var name=url.substring(cut+1);
            try {
                name=decodeURIComponent(name);
            } catch(e) {
                ;
            }
            /* 索引文件不是歌词, 不参与接管 */
            if(name===GlobalFileStorage.lyricsCacheIndexFileName) {
                continue;
            }
            m[name]=url;
        }
        lyricsCache=m;
        Assist.dlog("在线","恢复歌词缓存: ",Object.keys(m).length," 份");
        return true;
    }
    /* 歌词缓存索引的落盘路径: 缓存目录未确定时为空字符串 */
    function lyricsIndexPath() {
        var dir=GlobalFileStorage.lyricsCacheDir();
        if(dir==="") {
            return "";
        }
        return dir+"/"+GlobalFileStorage.lyricsCacheIndexFileName;
    }
    /* 读盘歌词偏移索引: 缺失或解析失败时按全部零偏移处理 */
    function loadLyricsIndex() {
        var path=lyricsIndexPath();
        var m=({});
        if(path!=="") {
            var txt=AppFileHelper.readFile(path,"UTF-8");
            if(txt!=="") {
                try {
                    var obj=JSON.parse(txt);
                    if(obj!==null && typeof obj==="object") {
                        for(var k in obj) {
                            var one=obj[k];
                            var ms=(one!==null && one!==undefined && typeof one==="object"
                                    && typeof one["offsetMs"]==="number"? Math.round(one["offsetMs"]):0);
                            m[k]=({"offsetMs":ms});
                        }
                    }
                } catch(e) {
                    Assist.dwarn("在线","歌词偏移索引解析失败, 按零偏移处理: ",e);
                }
            }
        }
        lyricsIndex=m;
        Assist.dlog("在线","恢复歌词偏移索引: ",Object.keys(m).length," 项");
        return true;
    }
    /* 写盘歌词偏移索引 */
    function saveLyricsIndex() {
        var path=lyricsIndexPath();
        if(path==="") {
            return false;
        }
        return AppFileHelper.writeFile(path,JSON.stringify(lyricsIndex),"UTF-8");
    }
    /* 某份歌词的偏移量(毫秒): 无记录时为零 */
    function lyricsOffsetMs(lyricsName) {
        var name=String(lyricsName===undefined || lyricsName===null? "":lyricsName);
        var one=lyricsIndex[name];
        if(one===null || one===undefined || typeof one["offsetMs"]!=="number") {
            return 0;
        }
        return Math.round(one["offsetMs"]);
    }
    /* 写入某份歌词的偏移量: 绝对值限制在设计常量给出的上限内, 零偏移不保留记录 */
    function setLyricsOffsetMs(lyricsName,ms) {
        var name=String(lyricsName===undefined || lyricsName===null? "":lyricsName);
        if(name==="") {
            return false;
        }
        var v=Math.round(Number(ms));
        if(isNaN(v)===true) {
            return false;
        }
        var lim=Define.lyricsOffsetMaxMs;
        v=(v>lim? lim:(v<-lim? -lim:v));
        var m=({});
        for(var k in lyricsIndex) {
            m[k]=lyricsIndex[k];
        }
        if(v===0) {
            delete m[name];
        } else {
            m[name]=({"offsetMs":v});
        }
        lyricsIndex=m;
        var ok=saveLyricsIndex();
        Assist.dlog("在线","写入歌词偏移: ",name,", ",v," 毫秒, 落盘 ",ok);
        return ok;
    }
    /* 立即清空歌词缓存: 删除缓存目录里的文件并清空内存索引与偏移索引 */
    function clearLyricsCache() {
        var dir=GlobalFileStorage.lyricsCacheDir();
        if(dir==="") {
            Assist.dwarn("在线","清理歌词缓存失败: 缓存目录未确定");
            return false;
        }
        if(AppFileHelper.removeDir(dir,true)!==true) {
            Assist.dwarn("在线","清理歌词缓存失败: 缓存目录删除失败");
            return false;
        }
        AppFileHelper.makeDir(dir,true);
        _lyricsAbortAll();
        lyricsCache=({});
        lyricsMiss=({});
        _lyricsPending=({});
        _lyricsOwners=({});
        lyricsIndex=({});
        Assist.dlog("在线","歌词缓存与偏移索引已清空");
        return true;
    }
    /* 当前封面缓存生命周期(毫秒) */
    function coverTtlMs() {
        return GlobalFileStorage.coverCacheTtlDays()*86400000;
    }
    /* 封面缓存索引的落盘路径: 缓存目录未确定时为空字符串 */
    function coverIndexPath() {
        var dir=GlobalFileStorage.coverCacheDir();
        if(dir==="") {
            return "";
        }
        return dir+"/"+GlobalFileStorage.coverCacheIndexFileName;
    }
    /* 读封面缓存索引: 缺失或损坏时按空索引处理 */
    function loadCoverIndex() {
        coverIndex=({});
        var path=coverIndexPath();
        if(path==="") {
            return false;
        }
        var txt=AppFileHelper.readFile(path,"UTF-8");
        if(txt==="") {
            return false;
        }
        var obj=null;
        try {
            obj=JSON.parse(txt);
        } catch(e) {
            Assist.dwarn("在线","封面缓存索引解析失败: ",e);
            return false;
        }
        if(obj===null || typeof obj!=="object") {
            return false;
        }
        var m=({});
        for(var k in obj) {
            var one=obj[k];
            if(one===null || typeof one!=="object" || typeof one.path!=="string") {
                continue;
            }
            m[k]=({"path":one.path,
                   "at":(typeof one.at==="number"? one.at:Date.now()),
                   "ttl":(typeof one.ttl==="number" && one.ttl>0? one.ttl:coverTtlMs())});
        }
        coverIndex=m;
        Assist.dlog("在线","已恢复封面缓存索引: 共 ",Object.keys(m).length," 条");
        return true;
    }
    /* 写封面缓存索引 */
    function saveCoverIndex() {
        _coverIndexDirty=false;
        var path=coverIndexPath();
        if(path==="") {
            return false;
        }
        return (AppFileHelper.writeFile(path,JSON.stringify(coverIndex),"UTF-8")===true);
    }
    /* 某个封面是否已过期: 没有索引条目时按未过期处理, 由启动流程补登记 */
    function coverExpired(name) {
        var e=coverIndex[name];
        if(e===undefined) {
            return false;
        }
        return (Date.now()>=(Number(e["at"])+Number(e["ttl"])));
    }
    /* 启动时接管本地封面: 索引里文件仍在的条目立刻可用, 随后静默补全未缓存或已过期的封面 */
    function bootstrapCoverCache() {
        var dir=GlobalFileStorage.coverCacheDir();
        if(dir==="") {
            Assist.dwarn("在线","封面缓存不可用: 缓存目录未确定");
            return false;
        }
        loadCoverIndex();
        var c=({});
        var idx=({});
        var hit=0;
        for(var k in coverIndex) {
            var e=coverIndex[k];
            var path=String(e["path"]);
            if(AppFileHelper.existsFile(path)!==true) {
                continue;
            }
            idx[k]=e;
            c[k]=path+"?t="+String(e["at"]);
            hit=hit+1;
        }
        coverIndex=idx;
        coverCache=c;
        _coverIndexDirty=true;
        Assist.dlog("在线","封面缓存就绪: 复用 ",hit," 个本地封面");
        startCoverFill();
        return true;
    }
    /* 静默全量补全封面: 只排队未缓存或已过期的条目, 并发上限取设计常量 */
    function startCoverFill() {
        if(_coverFilling===true) {
            return false;
        }
        var rows=manifestRows();
        var l=rows.length;
        if(l<=0) {
            return false;
        }
        var queued=0;
        for(var i=0;i<l;i++) {
            var name=coverNameOfRow(rows[i]);
            if(name==="") {
                continue;
            }
            var cached=(coverPathOf(name)!=="");
            if(cached===true && coverExpired(name)!==true) {
                continue;
            }
            if(_missActive(coverMiss,name)===true || _coverPending[name]===true
               || _coverQueue.indexOf(name)>=0) {
                continue;
            }
            _coverQueue.push(name);
            queued=queued+1;
        }
        if(queued<=0) {
            return false;
        }
        _coverFilling=true;
        Assist.dlog("在线","封面补全开始: 待拉取 ",queued," 个, 清单共 ",l," 首");
        _pumpCoverQueue();
        return true;
    }
    /* 按并发上限推进补全队列 */
    function _pumpCoverQueue() {
        while(_netLiveOf("B")<fetchLimitB && _coverQueue.length>0) {
            var name=_coverQueue.shift();
            if(_missActive(coverMiss,name)===true || _coverPending[name]===true) {
                continue;
            }
            /* 已有缓存的是过期刷新, 必须忽略缓存文件重新下载 */
            var force=(coverPathOf(name)!=="");
            _coverRequest(name,force);
        }
        if(_coverQueue.length<=0 && _netQueuedCovers()<=0 && _netLiveOf("B")<=0 && _coverFilling===true) {
            _coverFilling=false;
            saveCoverIndex();
            Assist.dlog("在线","封面补全结束");
        }
    }
    /* 排队等在途额度里的封面组数 */
    function _netQueuedCovers() {
        var n=0;
        for(var i=0;i<_netQueue.length;i++) {
            if(_netQueue[i].kind==="cover" && _netQueue[i].done!==true) {
                n=n+1;
            }
        }
        return n;
    }
    /* 封面缓存概况: 已缓存个数与清单条目数, 供设置页显示 */
    function coverCacheStats() {
        return ({"cached":Object.keys(coverCache).length,
                 "total":manifestRows().length});
    }
    /* 立即清空封面缓存: 删除缓存目录里的文件并清空内存与索引 */
    function clearCoverCache() {
        var dir=GlobalFileStorage.coverCacheDir();
        if(dir==="") {
            Assist.dwarn("在线","清理封面缓存失败: 缓存目录未确定");
            return false;
        }
        if(AppFileHelper.removeDir(dir,true)!==true) {
            Assist.dwarn("在线","清理封面缓存失败: 缓存目录删除失败");
            return false;
        }
        AppFileHelper.makeDir(dir,true);
        _coverAbortAll();
        AppNetHelper.clearCachedFileWon();
        coverCache=({});
        coverIndex=({});
        coverMiss=({});
        _coverPending=({});
        _coverQueue=[];
        _coverFilling=false;
        saveCoverIndex();
        Assist.dlog("在线","封面缓存已清空");
        coverCacheCleared();
        return true;
    }
    /* ===== 已下载曲目的资产补全: 封面与歌词缺失时按退避节拍静默重试 ===== */
    /* 待补全队列: 每项形如
     * {kind:"cover"|"lyrics", owner:在线标识, name, tries, nextAt, deadline, deadlineCap, inflight} */
    property var _assetItems: []
    /* 每项最多尝试的次数 */
    readonly property int assetMaxTries: 3
    /* 失败后的退避节拍: 30 秒, 2 分钟, 10 分钟 */
    readonly property var assetBackoffMs: [30000,120000,600000]
    /* 一次尝试的等待窗口: 请求仍在途(含排队等并发额度)时只延长等待, 不算一次失败;
     * 从发起起超过三倍窗口仍未结算才判失败
     */
    readonly property int assetWaitMs: 60000
    /* 资产的实际文件名: 歌词按当前增强档取变体名, 封面就是封面名;
     * 补全队列里存的是这一档的实际名字, 与缓存落盘名一致
     */
    function assetNameOf(kind,name) {
        var n=String(name===undefined || name===null? "":name);
        return (kind==="lyrics"? lyricsVariantName(n):n);
    }
    /* 某类资产是否已经就绪 */
    function assetReadyOf(kind,name) {
        if(typeof name!=="string" || name==="") {
            return true;
        }
        return (kind==="cover"? (coverPathOf(name)!==""):(lyricsPathOf(name)!==""));
    }
    /* 某类资产的这次请求是否仍然在途: 在途包括已发起与排队等并发额度两种 */
    function _assetLiveOf(kind,name) {
        return (kind==="cover"? (_coverPending[name]===true):(_lyricsPending[name]===true));
    }
    /* 把一个资产排进补全队列: 已就绪, 已在队列或名字为空时忽略;
     * 同一首的同类资产以在线标识为键去重, 名字以清单为准, 非在途时就地更新
     */
    function enqueueAsset(kind,name,owner) {
        var real=assetNameOf(kind,name);
        if(typeof real!=="string" || real==="") {
            return false;
        }
        if(assetReadyOf(kind,real)===true) {
            return false;
        }
        var key=(typeof owner==="string"? owner:"");
        for(var i=0;i<_assetItems.length;i++) {
            var one=_assetItems[i];
            if(one["kind"]!==kind || one["owner"]!==key) {
                continue;
            }
            if(one["name"]!==real && one["inflight"]!==true) {
                one["name"]=real;
                one["nextAt"]=Date.now();
            }
            return false;
        }
        var v=_assetItems.slice();
        v.push({"kind":kind,"owner":key,"name":real,"tries":0,"nextAt":Date.now(),
                "deadline":0,"deadlineCap":0,"inflight":false});
        _assetItems=v;
        return true;
    }
    /* 扫描下载记录: 缺封面或歌词的排进补全队列; 封面名与歌词名优先按在线标识查清单, 查不到才用记录里存的名字 */
    function ensureDownloadedAssets() {
        var list=GlobalFileStorage.downloads;
        var queued=0;
        var n=(list===undefined || list===null? 0:list.length);
        for(var i=0;i<n;i++) {
            var one=list[i];
            var cover=(one["cover"]===undefined? "":String(one["cover"]));
            var lyrics=(one["lyrics"]===undefined? "":String(one["lyrics"]));
            /* 封面名与歌词名以当前清单为准: 记录里的名字可能来自旧结构, 清单查不到该条时才沿用记录值 */
            var id=(typeof one["onlineId"]==="string"? one["onlineId"]:"");
            var ent=onlineEntryOfId(id);
            if(ent!==null) {
                if(String(ent["cover"])!=="") {
                    cover=String(ent["cover"]);
                }
                if(String(ent["lyrics"])!=="") {
                    lyrics=String(ent["lyrics"]);
                }
            }
            if(enqueueAsset("cover",cover,id)===true) {
                queued=queued+1;
            }
            if(enqueueAsset("lyrics",lyrics,id)===true) {
                queued=queued+1;
            }
        }
        if(queued>0) {
            Assist.dlog("下载","已下载曲目的资产待补全: ",queued," 项");
        }
        return queued;
    }
    /* 节拍: 在途项到期结算, 非在途项到期发起一次尝试 */
    function _assetTick() {
        var now=Date.now();
        var items=_assetItems.slice();
        for(var i=0;i<items.length;i++) {
            var one=items[i];
            if(_assetItems.indexOf(one)<0) {
                continue;
            }
            if(one["inflight"]===true) {
                /* 请求仍在途时只延长等待窗口: 排队等并发额度不算失败;
                 * 超过总上限仍未结算才判一次失败
                 */
                if(_assetLiveOf(one["kind"],one["name"])===true && now<one["deadlineCap"]) {
                    one["deadline"]=now+assetWaitMs;
                    continue;
                }
                one["inflight"]=false;
                if(assetReadyOf(one["kind"],one["name"])===true) {
                    _assetRemove(one);
                    continue;
                }
                one["tries"]=one["tries"]+1;
                if(one["tries"]>=assetMaxTries) {
                    Assist.dwarn("下载","资产补全放弃: ",one["kind"]," ",one["name"]);
                    _assetRemove(one);
                } else {
                    one["nextAt"]=now+assetBackoffMs[Math.min(one["tries"]-1,assetBackoffMs.length-1)];
                    Assist.dwarn("下载","资产补全失败, 稍后重试: ",one["kind"]," ",one["name"]);
                }
                continue;
            }
            if(now<one["nextAt"]) {
                continue;
            }
            /* 增强档可能在运行中被切换: 每次尝试前按当前档位重新归一歌词名 */
            one["name"]=assetNameOf(one["kind"],one["name"]);
            one["inflight"]=true;
            one["deadline"]=now+assetWaitMs;
            one["deadlineCap"]=now+assetWaitMs*3;
            _assetStart(one["kind"],one["name"]);
        }
        return true;
    }
    function _assetRemove(one) {
        var v=[];
        for(var i=0;i<_assetItems.length;i++) {
            if(_assetItems[i]!==one) {
                v.push(_assetItems[i]);
            }
        }
        _assetItems=v;
    }
    /* 发起一次资产补全: 先清掉一次性放弃标记, 再走既有请求入口 */
    function _assetStart(kind,name) {
        if(kind==="cover") {
            delete coverMiss[name];
            return requestCover(name);
        }
        delete lyricsMiss[name];
        return requestLyrics(name);
    }
    /* 启动引导: 先读磁盘缓存让曲库立即可用; 有缓存时再后台静默刷新, 失败不影响界面;
     * 没有缓存时按普通流程拉取, 界面照常显示加载态 */
    function bootstrap() {
        loadPlayedMeta();
        var had=loadCache();
        bootstrapCoverCache();
        loadLyricsCache();
        loadLyricsIndex();
        ensureDownloadedAssets();
        if(had===true) {
            refreshSilently();
        } else {
            ensureLoaded();
        }
        return had;
    }
    /* 从缓存文件恢复元信息与清单: 两者都有效时直接进入就绪态 */
    function loadCache() {
        var dir=GlobalFileStorage.onlineCacheDir();
        if(dir==="") {
            return false;
        }
        var metaTxt=AppFileHelper.readFile(dir+"/"+GlobalFileStorage.onlineMetaFileName,"UTF-8");
        var manTxt=AppFileHelper.readFile(dir+"/"+GlobalFileStorage.onlineManifestFileName,"UTF-8");
        if(metaTxt==="" || manTxt==="") {
            Assist.dlog("在线","没有可用的缓存, 等待在线拉取");
            return false;
        }
        var meta=null;
        var man=null;
        try {
            meta=JSON.parse(metaTxt);
            man=JSON.parse(manTxt);
        } catch(e) {
            Assist.dwarn("在线","缓存解析失败: ",e);
            return false;
        }
        if(_metaValid(meta)!==true) {
            Assist.dwarn("在线","缓存里的元信息结构不正确");
            return false;
        }
        if(Array.isArray(man)===false) {
            Assist.dwarn("在线","缓存里的清单结构不正确");
            return false;
        }
        _setData(meta,man);
        loadState=2;
        loadError="";
        /* 进入缓存模式: 本次运行的元信息来自本地缓存, 后续失败只做后台轮询 */
        _metaFromCache=true;
        _metaPollOn=false;
        _ossDead=false;
        _escalateOn=false;
        Assist.dlog("在线","已从缓存恢复在线曲库: 共 ",man.length," 首");
        return true;
    }
    /* 把当前元信息与清单写回缓存: 存储目录未确定或写入失败时返回 false */
    function saveCache() {
        var dir=GlobalFileStorage.onlineCacheDir();
        if(dir==="") {
            return false;
        }
        var okMeta=AppFileHelper.writeFile(dir+"/"+GlobalFileStorage.onlineMetaFileName,
                                           JSON.stringify(oss.meta),"UTF-8");
        var okMan=AppFileHelper.writeFile(dir+"/"+GlobalFileStorage.onlineManifestFileName,
                                          JSON.stringify(oss.manifest),"UTF-8");
        if(okMeta===true && okMan===true) {
            Assist.dlog("在线","在线曲库缓存已更新");
            return true;
        }
        Assist.dwarn("在线","在线曲库缓存写入失败");
        return false;
    }
    /* 用一份新的元信息与清单替换当前数据: 元信息原文存进 oss.meta,
     * 目录结构与扩展名解析进 oss.audio_* 各项, 其它模块只读 oss 上拼好的前缀 */
    function _setData(meta,manifest) {
        var spec=_parseOss(meta);
        serverRoot.oss=({"meta_file_url":serverRoot.oss.meta_file_url,
                         "meta":meta,
                         "manifest":(Array.isArray(manifest)? manifest:[]),
                         "audio_manifest_base_url":spec.audio_manifest_base_url,
                         "audio_file_base_url":spec.audio_file_base_url,
                         "audio_file_ext":spec.audio_file_ext,
                         "audio_cover_base_url":spec.audio_cover_base_url,
                         "audio_cover_ext":spec.audio_cover_ext,
                         "audio_lyrics_lrc_base_url":spec.audio_lyrics_lrc_base_url,
                         "audio_lyrics_lrc_ext":spec.audio_lyrics_lrc_ext,
                         "audio_lyrics_elrc_base_url":spec.audio_lyrics_elrc_base_url,
                         "audio_lyrics_elrc_ext":spec.audio_lyrics_elrc_ext});
        /* 记下数据根: 缓存模式下据此识别对象存储的 404 */
        serverRoot._ossRoots=_metaRoots(meta);
        Assist.dlog("在线","元信息已解析: 数据根 ",serverRoot._ossRoots.length," 个, 清单前缀 ",
                    (spec.audio_manifest_base_url.length>0? spec.audio_manifest_base_url[0]:"(缺)"),
                    ", 扩展名 ",spec.audio_file_ext," ",spec.audio_cover_ext," ",
                    spec.audio_lyrics_lrc_ext," ",spec.audio_lyrics_elrc_ext);
    }
    /* 取一首在线歌曲的已播放缓存: 没有记录时返回 null */
    function playedMetaOf(key) {
        var one=playedMeta[key];
        return (one===undefined? null:one);
    }
    /* 记一次在线歌曲的时长: 只接受正数秒, 值没变时不写盘 */
    function rememberDuration(key,seconds) {
        var sec=Math.floor(Number(seconds));
        if(isOnlineKey(key)===false || !(sec>0)) {
            return false;
        }
        return _mergePlayedMeta(key,{"duration":sec});
    }
    /* 记一次在线歌曲的字节数: 只接受正数字节, 值没变时不写盘 */
    function rememberSize(key,bytes) {
        var n=Math.floor(Number(bytes));
        if(isOnlineKey(key)===false || !(n>0)) {
            return false;
        }
        return _mergePlayedMeta(key,{"size":n});
    }
    /* 合并一条已播放元数据: 时长与大小各自独立保留, 整体替换对象以便界面绑定收到通知 */
    function _mergePlayedMeta(key,patch) {
        var old=playedMetaOf(key);
        var next=({"duration":(old===null? 0:old["duration"]),
                   "size": (old===null? 0:old["size"])});
        for(var k in patch) {
            next[k]=patch[k];
        }
        if(old!==null && old["duration"]===next["duration"] && old["size"]===next["size"]) {
            return false;
        }
        var m=({});
        for(var key2 in playedMeta) {
            m[key2]=playedMeta[key2];
        }
        m[key]=next;
        playedMeta=m;
        savePlayedMeta();
        Assist.dlog("在线","已播放在线歌曲: ",key,", 时长 ",next["duration"]," 秒, 大小 ",next["size"]," 字节");
        return true;
    }
    /* 读盘: 在线缓存目录下的已播放元数据, 文件缺失或损坏时保持空表 */
    function loadPlayedMeta() {
        var dir=GlobalFileStorage.onlineCacheDir();
        if(dir==="") {
            return false;
        }
        var txt=AppFileHelper.readFile(dir+"/"+GlobalFileStorage.onlinePlayedMetaFileName,"UTF-8");
        if(txt==="") {
            return false;
        }
        var obj=null;
        try {
            obj=JSON.parse(txt);
        } catch(e) {
            Assist.dwarn("在线","已播放元数据缓存解析失败: ",e);
            return false;
        }
        if(obj===null || typeof obj!=="object") {
            return false;
        }
        var m=({});
        for(var k in obj) {
            var one=obj[k];
            if(one===null || typeof one!=="object") {
                continue;
            }
            m[k]=({"duration":(typeof one.duration==="number"? one.duration:0),
                   "size": (typeof one.size==="number"? one.size:0)});
        }
        playedMeta=m;
        Assist.dlog("在线","已恢复播放过的在线歌曲元数据: 共 ",Object.keys(m).length," 首");
        return true;
    }
    /* 写盘: 存储目录未确定或写入失败时返回 false */
    function savePlayedMeta() {
        var dir=GlobalFileStorage.onlineCacheDir();
        if(dir==="") {
            return false;
        }
        return (AppFileHelper.writeFile(dir+"/"+GlobalFileStorage.onlinePlayedMetaFileName,
                                        JSON.stringify(playedMeta),"UTF-8")===true);
    }
    /* 请求在线歌曲的字节数: key 是在线标识(记录用的键), url 是实际取用的地址, 缺省与 key 相同;
     * 已有值或已探测失败时直接返回, 每首歌只探测一次
     */
    function ensureSize(key,url) {
        if(isOnlineKey(key)===false) {
            return false;
        }
        var pm=playedMetaOf(key);
        if(pm!==null && pm["size"]>0) {
            return true;
        }
        if(_sizeMiss[key]===true || _sizeProbing[key]===true) {
            return false;
        }
        var target=(typeof url==="string" && isOnlineKey(url)===true? url:key);
        _sizeProbing[key]=true;
        AppNetHelper.probeAudioSize(target,key);
        return true;
    }
    /* 拉取在线曲库: 元信息就绪后再拉清单, 两者都成功才算就绪 */
    function ensureLoaded() {
        if(_fetching===true || loadState===1 || loadState===2) {
            return false;
        }
        _retryReset();
        _silent=false;
        loadState=1;
        loadError="";
        return _startFetch();
    }
    /* 后台静默刷新: 不改界面的加载状态, 失败时保留现有数据与缓存 */
    function refreshSilently() {
        if(_fetching===true) {
            return false;
        }
        _silent=true;
        return _startFetch();
    }
    /* 手动刷新: 按静默刷新处理, 有数据时不动加载状态, 失败也不做视觉反馈 */
    function refreshNow() {
        _retryReset();
        return refreshSilently();
    }
    /* 重试节拍: 后台静默重拉, 成功即停表并覆写缓存; 每次触发先把下一次的等待拉长一个步长 */
    function _retryTick() {
        if(_fetching===true) {
            return false;
        }
        _retryAdvance();
        Assist.dlog("在线","后台重试拉取在线曲库, 下一次间隔 ",Math.round(_retryGapMs/1000)," 秒");
        _silent=true;
        return _startFetch();
    }
    /* 重试退避: 每失败一次把间隔加一个步长, 到上限即封顶 */
    function _retryAdvance() {
        var next=_retryGapMs+Define.onlineRetryStepMs;
        _retryGapMs=(next>Define.onlineRetryMaxMs? Define.onlineRetryMaxMs:next);
        return _retryGapMs;
    }
    /* 重试退避复位: 拉取成功与用户手动触发时回到下限 */
    function _retryReset() {
        _retryGapMs=Define.onlineRetryBaseMs;
        return _retryGapMs;
    }
    /* 缓存模式下的后台轮询节拍: 对象存储已失效时改为立即重取并启用 */
    function _metaPollTick() {
        if(_fetching===true || _metaPollInFlight()===true || _escalateOn===true) {
            return false;
        }
        if(_ossDead===true) {
            return _escalateMeta();
        }
        return _pollMetaToCache();
    }
    /* 拉一次元信息并只更新缓存文件: 成功也不替换本次运行已生效的元信息与清单 */
    function _pollMetaToCache() {
        var started=_netStart("meta","metaPoll",oss.meta_file_url,
                              {"validate":function(data) { return serverRoot._metaValid(data); },
                               "ok":function(data) { serverRoot._metaPollDone(data); },
                               "fail":function(reason) { serverRoot._metaPollFail(reason); }});
        return started;
    }
    /* 后台轮询是否有在途请求: 直接看请求表, 被其它拉取中止时不会留下永远置位的标志 */
    function _metaPollInFlight() {
        for(var i=0;i<_netReqs.length;i++) {
            var one=_netReqs[i];
            if(one.closed===true) {
                continue;
            }
            if(one.group!==undefined && one.group!==null && one.group.key==="metaPoll") {
                return true;
            }
        }
        return false;
    }
    /* 轮询成功: 只写缓存; 若此时已确认对象存储失效, 则立即启用这份新元信息 */
    function _metaPollDone(data) {
        var dir=GlobalFileStorage.onlineCacheDir();
        var ok=false;
        if(dir!=="") {
            ok=AppFileHelper.writeFile(dir+"/"+GlobalFileStorage.onlineMetaFileName,
                                       JSON.stringify(data),"UTF-8");
        }
        if(_ossDead===true) {
            Assist.dlog("在线","轮询到最新元信息, 且缓存指向的对象存储已失效: 立即启用, 缓存写入 ",
                        (ok===true? "成功":"失败"));
            _escalateOn=true;
            _ossDead=false;
            /* 升级期间的失败只记日志: 界面已经有可用的曲库, 不切到失败态 */
            _silent=true;
            _setData(data,oss.manifest);
            _metaFromCache=false;
            _loadManifest();
            return true;
        }
        Assist.dlog("在线","轮询到最新元信息: 只更新缓存(",(ok===true? "成功":"失败"),
                    "), 本次运行继续使用已生效的元信息");
        return ok;
    }
    /* 轮询失败: 继续等下一个节拍, 缓存里的元信息照常使用 */
    function _metaPollFail(reason) {
        Assist.dwarn("在线","后台轮询元信息失败, 继续使用缓存: ",reason);
        return false;
    }
    /* 立即重取元信息并立即启用: 缓存指向的对象存储已不可用时使用 */
    function _escalateMeta() {
        if(_fetching===true || _metaPollInFlight()===true) {
            return false;
        }
        Assist.dwarn("在线","缓存的元信息指向的对象存储不可用, 立即重取最新元信息并启用");
        _escalateOn=true;
        _ossDead=false;
        _silent=true;
        return _startFetch();
    }
    /* 记一次 404: 只认缓存模式下来自元信息声明的数据根的地址 */
    function _noteOssStatus(url) {
        if(_metaFromCache!==true || _ossDead===true || _escalateOn===true) {
            return false;
        }
        var u=String(url);
        var fromRoot=false;
        for(var i=0;i<_ossRoots.length;i++) {
            var root=String(_ossRoots[i]);
            if(root!=="" && u.indexOf(root)===0) {
                fromRoot=true;
                break;
            }
        }
        if(fromRoot!==true) {
            return false;
        }
        _ossDead=true;
        Assist.dwarn("在线","数据根返回 404, 缓存里的元信息已过时: ",u);
        return _escalateMeta();
    }
    /* 发起一次拉取: 从元信息开始, 拿到后继续拉清单 */
    function _startFetch() {
        _fetching=true;
        Assist.dlog("在线","开始拉取在线曲库: 元信息与清单",(_silent? "(后台静默)":""));
        _netStart("meta","meta",oss.meta_file_url,
                  {"validate":function(data) { return serverRoot._metaValid(data); },
                   "ok":function(data) {
                       Assist.dlog("在线","元信息就绪: 数据根 ",serverRoot._metaRoots(data).join(" "));
                       serverRoot._setData(data,serverRoot.oss.manifest);
                       /* 元信息已在本次运行生效, 退出缓存模式 */
                       serverRoot._metaFromCache=false;
                       serverRoot._loadManifest();
                   },
                   "fail":function(reason) {
                       serverRoot._fail(reason);
                   }});
        return true;
    }
    /* 拉取清单 */
    function _loadManifest() {
        _netStart("manifest","manifest",oss.audio_manifest_base_url,
                  {"validate":function(data) { return Array.isArray(data); },
                   "ok":function(data) {
                       serverRoot._setData(serverRoot.oss.meta,data);
                       serverRoot._finishOk();
                   },
                   "fail":function(reason) {
                       serverRoot._fail(reason);
                   }});
    }
    /* 拉取成功: 覆写缓存, 进入就绪态并通知界面 */
    function _finishOk() {
        _fetching=false;
        _retryOn=false;
        _retryReset();
        /* 元信息与清单都已由在线数据生效: 退出缓存模式与轮询/升级状态 */
        _metaFromCache=false;
        _metaPollOn=false;
        _ossDead=false;
        _escalateOn=false;
        saveCache();
        loadState=2;
        loadError="";
        Assist.dlog("在线","清单就绪: 共 ",manifestRows().length," 首");
        serverRoot.manifestUpdated();
        serverRoot.startCoverFill();
        /* 清单就绪后可以把下载记录里的歌词名补齐, 再扫一次资产 */
        ensureDownloadedAssets();
        _silent=false;
    }
    /* 加载失败: 有缓存可用时不进入失败态, 改为后台轮询元信息;
     * 已升级为立即重取时按退避节拍继续重试; 没有缓存可用时才进入失败态 */
    function _fail(reason) {
        _netAbortFetch();
        _fetching=false;
        if(_metaFromCache===true) {
            _silent=false;
            if(_escalateOn===true) {
                _retryOn=true;
                Assist.dwarn("在线","立即重取元信息失败, 继续按退避节拍重试: ",reason);
                return;
            }
            _metaPollOn=true;
            _retryOn=false;
            Assist.dwarn("在线","在线元信息不可用, 继续使用缓存并后台轮询最新元信息: ",reason);
            return;
        }
        _retryOn=true;
        if(_silent===true) {
            _silent=false;
            Assist.dwarn("在线","后台刷新失败, 继续使用缓存: ",reason);
            return;
        }
        loadState=3;
        loadError=reason;
        Assist.derror("在线","在线曲库加载失败: ",reason);
    }
    /* ===== 对冲拉取: 同一组候选源并行发起, 拿到即止 ===== */
    /* 起一组拉取: kind 决定传输方式与对冲时延, key 标识资源, urls 为候选地址;
     * opts 给出 validate(校验单个源的数据, 返回 false 算该源失败), ok 与 fail(整组结果),
     * 以及 force(只对封面有效: 过期刷新时忽略已存在的缓存文件) */
    function _netStart(kind,key,urls,opts) {
        var list=[];
        if(Array.isArray(urls)) {
            for(var i=0;i<urls.length;i++) {
                var one=String(urls[i]);
                if(one!=="") {
                    list.push(one);
                }
            }
        }
        var group=({"kind":kind, "key":String(key), "urls":list, "next":0, "live":0,
                    "done":false, "hedgeMs":_netHedgeMs(kind),
                    "validate":(opts? opts["validate"]:null),
                    "ok":(opts? opts["ok"]:null),
                    "fail":(opts? opts["fail"]:null),
                    "force":(opts? opts["force"]===true:false)});
        if(list.length<=0) {
            group.done=true;
            if(group.fail) {
                group.fail("没有可用的候选地址");
            }
            return false;
        }
        _netLaunch(group);
        return true;
    }
    /* 每类资源的对冲等待时长 */
    function _netHedgeMs(kind) {
        if(kind==="meta") {
            return Define.onlineMetaHedgeMs;
        }
        if(kind==="manifest") {
            return Define.onlineManifestHedgeMs;
        }
        if(kind==="lyrics") {
            return Define.onlineLyricsHedgeMs;
        }
        return Define.onlineCoverHedgeMs;
    }
    /* 并发分组: 封面算 B 组, 元信息, 清单与歌词算 A 组 */
    function _netClassOf(kind) {
        return (kind==="cover"? "B":"A");
    }
    /* 该组类别允许的在途请求数 */
    function _netCapOf(kind) {
        return (kind==="cover"? fetchLimitB:fetchLimitA);
    }
    /* 某组类别的在途请求数 */
    function _netLiveOf(cls) {
        var n=0;
        for(var i=0;i<_netReqs.length;i++) {
            if(_netReqs[i].closed!==true && _netReqs[i].cls===cls) {
                n=n+1;
            }
        }
        return n;
    }
    /* 拉起该组的下一个候选: 并发已满时排队, 候选全部拉起过时只做收尾判定 */
    function _netLaunch(group) {
        if(group.done===true) {
            return false;
        }
        if(group.next>=group.urls.length) {
            _netPrune(group);
            return false;
        }
        if(_netLiveOf(_netClassOf(group.kind))>=_netCapOf(group.kind)) {
            if(_netQueue.indexOf(group)<0) {
                _netQueue.push(group);
            }
            return false;
        }
        var url=group.urls[group.next];
        var index=group.next;
        group.next=group.next+1;
        return _netFire(group,url,index);
    }
    /* 发起一次尝试 */
    function _netFire(group,url,index) {
        var req=({"group":group, "cls":_netClassOf(group.kind), "url":url, "index":index,
                  "startAt":Date.now(), "hedged":false, "closed":false, "xhr":null,
                  "attemptKey":"", "token":0});
        group.live=group.live+1;
        _netReqs=_netReqs.concat([req]);
        if(group.kind==="cover") {
            /* 封面走 C++ 下载: 尝试键带序号以免并行尝试被去重, 落盘名仍用云端原始文件名 */
            req.attemptKey=group.key+"#"+String(index);
            _netByKey[req.attemptKey]=req;
            Assist.dlog("在线","请求封面: ",url);
            AppNetHelper.fetchCachedFile(url,req.attemptKey,GlobalFileStorage.coverCacheDir(),
                                         group.force===true,group.key);
            return true;
        }
        var xhr=null;
        try {
            xhr=new XMLHttpRequest();
        } catch(e) {
            Assist.derror("在线","请求对象不可用: ",e);
            _netLose(req,"请求对象不可用");
            return false;
        }
        req.xhr=xhr;
        req.token=Date.now()+Math.random();
        var token=req.token;
        xhr.onreadystatechange=function() {
            if(req.closed===true || group.done===true || req.token!==token) {
                return;
            }
            /* 歌词支持边下边显: 首个开始返回数据的源独占流式来源, 它的部分文本随到随发 */
            if(xhr.readyState===XMLHttpRequest.LOADING) {
                if(group.kind==="lyrics") {
                    if(serverRoot._lyricsOwners[group.key]===undefined) {
                        serverRoot._lyricsOwners[group.key]=req.url;
                        Assist.dlog("在线","歌词流式来源: ",req.url);
                    }
                    if(serverRoot._lyricsOwners[group.key]===req.url && xhr.responseText!=="") {
                        serverRoot.lyricsPartial(group.key,xhr.responseText);
                    }
                }
                return;
            }
            if(xhr.readyState!==XMLHttpRequest.DONE) {
                return;
            }
            serverRoot._netSettle(req,xhr);
        };
        Assist.dlog("在线","请求: ",url);
        try {
            xhr.open("GET",url);
            xhr.send();
        } catch(e2) {
            Assist.dwarn("在线","请求发起失败: ",url,", ",e2);
            _netLose(req,"请求发起失败");
            return false;
        }
        return true;
    }
    /* XHR 到齐: 取数据交给该组的校验与胜出判定 */
    function _netSettle(req,xhr) {
        var group=req.group;
        if(xhr.status<200 || xhr.status>=300 || xhr.responseText==="") {
            Assist.dwarn("在线","地址不可用: ",req.url,", 状态 ",xhr.status);
            if(xhr.status===404) {
                /* 404 可能意味着缓存里的元信息指向的对象存储已过时, 交给元信息侧判断 */
                serverRoot._noteOssStatus(req.url);
            }
            _netLose(req,"地址不可用");
            return false;
        }
        var payload=xhr.responseText;
        if(group.kind!=="lyrics") {
            try {
                payload=JSON.parse(xhr.responseText);
            } catch(e) {
                Assist.dwarn("在线","内容解析失败: ",req.url,", ",e);
                _netLose(req,"内容解析失败");
                return false;
            }
        }
        if(group.validate && group.validate(payload)===false) {
            Assist.dwarn("在线","内容结构不符: ",req.url);
            _netLose(req,"内容结构不符");
            return false;
        }
        return _netWin(req,payload);
    }
    /* 一次尝试失败: 关闭它并立即拉起该组的下一个候选 */
    function _netLose(req,reason) {
        var group=req.group;
        if(group===undefined || group===null || group.done===true || req.closed===true) {
            return false;
        }
        req.closed=true;
        _netDrop(req);
        group.live=Math.max(0,group.live-1);
        Assist.dwarn("在线","候选源失败: ",req.url,", 原因 ",reason);
        _netLaunch(group);
        _netPrune(group);
        _netDrain();
        return true;
    }
    /* 某次尝试成功: 关闭同组其余在途请求, 只通知一次 */
    function _netWin(req,payload) {
        var group=req.group;
        if(group.done===true) {
            return false;
        }
        serverRoot.noteOriginLive(req.url);
        group.done=true;
        req.closed=true;
        _netDrop(req);
        group.live=Math.max(0,group.live-1);
        var rest=_netReqs.slice();
        for(var i=0;i<rest.length;i++) {
            var one=rest[i];
            if(one.group!==group || one.closed===true) {
                continue;
            }
            one.closed=true;
            _netAbort(one);
            _netDrop(one);
            group.live=Math.max(0,group.live-1);
        }
        _netDrain();
        if(group.ok) {
            group.ok(payload);
        }
        return true;
    }
    /* 收尾判定: 候选全部拉起过且没有在途请求时判整组失败 */
    function _netPrune(group) {
        if(group.done===true) {
            return false;
        }
        if(group.next<group.urls.length || group.live>0) {
            return false;
        }
        group.done=true;
        _netDrain();
        if(group.fail) {
            group.fail("候选地址全部不可用");
        }
        return true;
    }
    /* 中止一次尝试的传输层请求 */
    function _netAbort(req) {
        var x=req.xhr;
        req.xhr=null;
        if(x!==null && x!==undefined) {
            try {
                x.abort();
            } catch(e) {
                ;
            }
        }
        if(req.attemptKey!=="") {
            AppNetHelper.cancelCachedFile(req.attemptKey);
        }
    }
    /* 把一次尝试从在途表里摘掉 */
    function _netDrop(req) {
        if(req.attemptKey!=="") {
            delete _netByKey[req.attemptKey];
        }
        var rest=[];
        for(var i=0;i<_netReqs.length;i++) {
            if(_netReqs[i]!==req) {
                rest.push(_netReqs[i]);
            }
        }
        _netReqs=rest;
    }
    /* 心跳: 检查对冲与硬超时, 再给排队的分组补位 */
    function _netTick() {
        var now=Date.now();
        var list=_netReqs.slice();
        for(var i=0;i<list.length;i++) {
            var req=list[i];
            if(req.closed===true || req.group.done===true) {
                continue;
            }
            var elapsed=now-req.startAt;
            if(elapsed>=Define.onlineSourceTimeoutMs) {
                Assist.dwarn("在线","候选源超时: ",req.url);
                _netLose(req,"超时");
                continue;
            }
            if(req.hedged===false && elapsed>=req.group.hedgeMs) {
                req.hedged=true;
                _netLaunch(req.group);
            }
        }
        _netDrain();
    }
    /* 补位: 并发有空时按排队顺序拉起分组 */
    function _netDrain() {
        if(_netQueue.length<=0) {
            return false;
        }
        var queue=_netQueue;
        _netQueue=[];
        for(var i=0;i<queue.length;i++) {
            var g=queue[i];
            if(g.done===true) {
                continue;
            }
            if(_netLiveOf(_netClassOf(g.kind))<_netCapOf(g.kind)) {
                _netLaunch(g);
            } else {
                _netQueue.push(g);
            }
        }
        return true;
    }
    /* 放弃本轮的元信息与清单请求: 封面与歌词的在途请求不受影响 */
    function _netAbortFetch() {
        var list=_netReqs.slice();
        for(var i=0;i<list.length;i++) {
            var req=list[i];
            if(req.group.kind!=="meta" && req.group.kind!=="manifest") {
                continue;
            }
            req.closed=true;
            req.group.done=true;
            _netAbort(req);
            _netDrop(req);
        }
        var queue=[];
        for(var j=0;j<_netQueue.length;j++) {
            var g=_netQueue[j];
            if(g.kind==="meta" || g.kind==="manifest") {
                g.done=true;
                continue;
            }
            queue.push(g);
        }
        _netQueue=queue;
        return true;
    }
    /* 中止全部封面组: 清理封面缓存时调用 */
    function _coverAbortAll() {
        var list=_netReqs.slice();
        for(var i=0;i<list.length;i++) {
            var req=list[i];
            if(req.group.kind!=="cover") {
                continue;
            }
            req.closed=true;
            req.group.done=true;
            _netAbort(req);
            _netDrop(req);
        }
        var queue=[];
        for(var j=0;j<_netQueue.length;j++) {
            if(_netQueue[j].kind!=="cover") {
                queue.push(_netQueue[j]);
            } else {
                _netQueue[j].done=true;
            }
        }
        _netQueue=queue;
        return true;
    }
    /* 中止全部歌词组: 清理歌词缓存时调用 */
    function _lyricsAbortAll() {
        var list=_netReqs.slice();
        for(var i=0;i<list.length;i++) {
            var req=list[i];
            if(req.group.kind!=="lyrics") {
                continue;
            }
            req.closed=true;
            req.group.done=true;
            _netAbort(req);
            _netDrop(req);
        }
        var queue=[];
        for(var j=0;j<_netQueue.length;j++) {
            if(_netQueue[j].kind!=="lyrics") {
                queue.push(_netQueue[j]);
            } else {
                _netQueue[j].done=true;
            }
        }
        _netQueue=queue;
        return true;
    }
}
