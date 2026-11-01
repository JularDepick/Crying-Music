pragma Singleton
import QtQuick

import AppHelper 1.0

import "./"

Item {
    id: serverRoot;
    /* 远程数据分布:
        * OSS元数据、歌曲清单、封面图片、歌词文件在仓库的 online-data 分支
        * OSS侧也有歌曲清单、封面图片、歌词文件的备份,用于兜底
     * 资源获取流程:
        * 依次尝试多个备用地址 oss.meta_file_url[i] 与 oss.manifest_file_url[i], 拿到即止
        * OSS元信息就绪后立即把OSS派生的地址追加为兜底备用源:
          * 基址去掉末尾的 file/ 即数据根, 该根下取 manifest.json, cover/ 与 lyrics/
        * 将获取到的 JSON 内容分别覆盖存进同结构的 oss.meta 与 oss.manifest
        * 清单与元信息体积小, 直接用 XMLHttpRequest 拉取; 封面与歌词由 C++ 侧下载到本地缓存后复用
    */
    property var oss:
    ({
        "meta_file_url": [
            "https://raw.githubusercontent.com/JularDepick/Crying-Music/online-data/oss/meta.json",
            "https://JularDepick.github.io/Crying-Music/oss/meta.json"
        ],
        "manifest_file_url": [
            "https://raw.githubusercontent.com/JularDepick/Crying-Music/online-data/audio/manifest.json",
            "https://JularDepick.github.io/Crying-Music/audio/manifest.json"
        ],
        "meta": ({ "audio_obj_base_url":"<被覆盖为获取到的audio_obj_base_url>" }),
        "manifest": ([{ "filename":"完整文件名称","cover":"封面文件名称","lyrics":"歌词文件名称","songname":"歌曲名称","singers":["歌手1"] }]),
        "cover_file_base_url": [
            "https://raw.githubusercontent.com/JularDepick/Crying-Music/online-data/audio/cover/",
            "https://JularDepick.github.io/Crying-Music/audio/cover/"
        ],
        "lyrics_file_base_url": [
            "https://raw.githubusercontent.com/JularDepick/Crying-Music/online-data/audio/lyrics/",
            "https://JularDepick.github.io/Crying-Music/audio/lyrics/"
        ]
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
    /* 拉取失败的歌词: 本进程内不再重试 */
    property var lyricsMiss: ({})
    /* 正在拉取的歌词: 同一份歌词同一时刻只保留一组对冲请求 */
    property var _lyricsPending: ({})
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
    /* 本次运行的元信息是否来自本地缓存: 该模式下失败不切换界面状态, 改为后台轮询 */
    property bool _metaFromCache: false;
    /* 缓存模式下的后台轮询开关: meta 源已全部失败, 轮询只更新缓存文件, 不打断本次运行 */
    property bool _metaPollOn: false;
    /* 缓存指向的对象存储是否已确认不可用(404): 置位后立即重取元信息, 拿到即启用 */
    property bool _ossDead: false;
    /* 是否已升级为立即重取: 升级期间的失败按固定节拍继续重试 */
    property bool _escalateOn: false;
    /* 元信息派生出的对象存储数据根, 用于识别 404 是否来自该对象存储 */
    property string _ossDataRoot: "";
    /* 失败后的重试节拍: 每分钟一次, 直到拉取成功; 成功即停表 */
    Timer {
        id: retryTimer;
        interval: 60000;
        repeat: true;
        running: serverRoot._retryOn;
        onTriggered: {
            serverRoot._retryTick();
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
    /* 对象存储基址: 元信息未就绪时为空字符串 */
    function audioBaseUrl() {
        var m=oss.meta;
        if(m===undefined || m===null || typeof m.audio_obj_base_url!=="string") {
            return "";
        }
        return m.audio_obj_base_url;
    }
    /* 在线标识转播放地址: 文件名按 URL 规则编码, 以兼容中文与日文文件名 */
    function audioUrlOf(onlineId) {
        if(typeof onlineId!=="string" || onlineId==="") {
            return "";
        }
        var base=audioBaseUrl();
        if(base==="") {
            return "";
        }
        return base+encodeURIComponent(onlineId);
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
    /* 由清单行构造条目: 在线标识取 filename, 播放地址取对象存储基址拼出 */
    function onlineEntryOfRow(row) {
        if(row===undefined || row===null || typeof row.filename!=="string") {
            return null;
        }
        var url=audioUrlOf(row.filename);
        if(url==="") {
            return null;
        }
        var cover=(typeof row.cover==="string"? row.cover:"");
        var lyrics=(typeof row.lyrics==="string"? row.lyrics:"");
        /* 播放过的歌曲带上缓存的时长与大小: 元数据就绪前先按这两个值显示 */
        var pm=playedMetaOf(url);
        /* 封面由列表委托在行可见时按需请求, 避免一次性发起上百个请求 */
        return ({
            "songname": (typeof row.songname==="string" && row.songname!==""? row.songname:row.filename),
            "singer": singersText(row.singers),
            "absfpath": url,
            "absipath": "",
            "size": (pm===null? 0:pm["size"]),
            "duration": (pm===null? 0:pm["duration"]),
            "source": "online",
            "online": true,
            "onlineId": row.filename,
            "cover": cover,
            "lyrics": lyrics,
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
            if(audioUrlOf(rows[i]["filename"])===key) {
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
    /* 封面缓存路径: 未缓存时为空字符串 */
    function coverPathOf(coverName) {
        if(typeof coverName!=="string" || coverName==="") {
            return "";
        }
        var p=coverCache[coverName];
        return (typeof p==="string"? p:"");
    }
    /* 封面的候选地址: 由备用基址依次拼出 */
    function coverUrlCandidates(coverName) {
        var res=[];
        var bases=oss.cover_file_base_url;
        if(Array.isArray(bases)===false || typeof coverName!=="string" || coverName==="") {
            return res;
        }
        var enc=encodeURIComponent(coverName);
        for(var i=0;i<bases.length;i++) {
            res.push(String(bases[i])+enc);
        }
        return res;
    }
    /* 请求一个封面的本地缓存: 已缓存或已失败时直接返回, 每个封面只发起一组对冲请求 */
    function requestCover(coverName) {
        if(typeof coverName!=="string" || coverName==="") {
            return false;
        }
        if(coverPathOf(coverName)!=="") {
            return true;
        }
        if(coverMiss[coverName]===true || _coverPending[coverName]===true) {
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
        coverMiss[name]=true;
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
    /* 歌词的候选地址: 由备用基址依次拼出, 空基址跳过 */
    function lyricsUrlCandidates(lyricsName) {
        var res=[];
        var bases=oss.lyrics_file_base_url;
        if(Array.isArray(bases)===false || typeof lyricsName!=="string" || lyricsName==="") {
            return res;
        }
        var enc=encodeURIComponent(lyricsName);
        for(var i=0;i<bases.length;i++) {
            var base=String(bases[i]);
            if(base!=="") {
                res.push(base+enc);
            }
        }
        return res;
    }
    /* 请求一份歌词: 已缓存或已失败时直接返回; 歌词按当前播放项单条拉取, 不做后台补全 */
    function requestLyrics(lyricsName) {
        if(typeof lyricsName!=="string" || lyricsName==="") {
            return false;
        }
        if(lyricsPathOf(lyricsName)!=="") {
            return true;
        }
        if(lyricsMiss[lyricsName]===true || _lyricsPending[lyricsName]===true) {
            return false;
        }
        var urls=lyricsUrlCandidates(lyricsName);
        if(GlobalFileStorage.lyricsCacheDir()==="" || urls.length<=0) {
            return false;
        }
        _lyricsPending[lyricsName]=true;
        var started=_netStart("lyrics",lyricsName,urls,
                              {"validate":function(text) { return (typeof text==="string" && text!==""); },
                               "ok":function(text) { serverRoot._lyricsDone(lyricsName,text); },
                               "fail":function(reason) { serverRoot._lyricsFailed(lyricsName,reason); }});
        if(started!==true) {
            delete _lyricsPending[lyricsName];
        }
        return started;
    }
    /* 歌词拿到: 写盘并记进内存索引 */
    function _lyricsDone(lyricsName,text) {
        var dir=GlobalFileStorage.lyricsCacheDir();
        var path=dir+"/"+lyricsName;
        var ok=(dir!=="" && AppFileHelper.writeFile(path,text,"UTF-8")===true);
        delete _lyricsPending[lyricsName];
        if(ok!==true) {
            lyricsMiss[lyricsName]=true;
            Assist.dwarn("在线","歌词写入失败: ",lyricsName);
            return false;
        }
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
        lyricsMiss[lyricsName]=true;
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
            m[name]=url;
        }
        lyricsCache=m;
        Assist.dlog("在线","恢复歌词缓存: ",Object.keys(m).length," 份");
        return true;
    }
    /* 立即清空歌词缓存: 删除缓存目录里的文件并清空内存索引 */
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
        Assist.dlog("在线","歌词缓存已清空");
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
            var name=(typeof rows[i]["cover"]==="string"? rows[i]["cover"]:"");
            if(name==="") {
                continue;
            }
            var cached=(coverPathOf(name)!=="");
            if(cached===true && coverExpired(name)!==true) {
                continue;
            }
            if(coverMiss[name]===true || _coverPending[name]===true || _coverQueue.indexOf(name)>=0) {
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
            if(coverMiss[name]===true || _coverPending[name]===true) {
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
    /* 启动引导: 先读磁盘缓存让曲库立即可用; 有缓存时再后台静默刷新, 失败不影响界面;
     * 没有缓存时按普通流程拉取, 界面照常显示加载态 */
    function bootstrap() {
        loadPlayedMeta();
        var had=loadCache();
        bootstrapCoverCache();
        loadLyricsCache();
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
        if(meta===null || typeof meta!=="object" || typeof meta.audio_obj_base_url!=="string"
           || meta.audio_obj_base_url==="") {
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
    /* 用一份新的元信息与清单替换当前数据: 各组候选地址保持不变,
     * 元信息就绪后再把对象存储派生的地址追加为兜底备用源 */
    function _setData(meta,manifest) {
        var next=({"meta_file_url":serverRoot.oss.meta_file_url,
                   "manifest_file_url":serverRoot.oss.manifest_file_url,
                   "cover_file_base_url":serverRoot.oss.cover_file_base_url,
                   "lyrics_file_base_url":serverRoot.oss.lyrics_file_base_url,
                   "meta":meta,
                   "manifest":manifest});
        serverRoot.oss=_withDerivedSources(next);
    }
    /* 追加对象存储派生的兜底备用源: 基址末尾的 file/ 去掉即数据根,
     * 清单, 封面与歌词分别取该根下的 manifest.json, cover/ 与 lyrics/;
     * 元信息缺失或基址为空时原样返回 */
    function _withDerivedSources(spec) {
        var base="";
        if(spec.meta!==undefined && spec.meta!==null && typeof spec.meta.audio_obj_base_url==="string") {
            base=spec.meta.audio_obj_base_url;
        }
        if(base==="") {
            return spec;
        }
        var root=base;
        if(root.charAt(root.length-1)!=="/") {
            root=root+"/";
        }
        if(root.length>=5 && root.substring(root.length-5)==="file/") {
            root=root.substring(0,root.length-5);
        }
        spec.manifest_file_url=_appendUniqueUrl(spec.manifest_file_url,root+"manifest.json");
        spec.cover_file_base_url=_appendUniqueUrl(spec.cover_file_base_url,root+"cover/");
        spec.lyrics_file_base_url=_appendUniqueUrl(spec.lyrics_file_base_url,root+"lyrics/");
        /* 记下数据根: 缓存模式下据此识别对象存储的 404 */
        serverRoot._ossDataRoot=root;
        Assist.dlog("在线","追加对象存储兜底源: ",root);
        return spec;
    }
    /* 候选地址去重追加: 空地址不入列, 已存在的地址不重复追加 */
    function _appendUniqueUrl(list,url) {
        var res=(Array.isArray(list)? list.slice():[]);
        if(typeof url!=="string" || url==="") {
            return res;
        }
        if(res.indexOf(url)>=0) {
            return res;
        }
        res.push(url);
        return res;
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
    /* 请求在线歌曲的字节数: 已有值或已探测失败时直接返回, 每首歌只探测一次 */
    function ensureSize(key) {
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
        _sizeProbing[key]=true;
        AppNetHelper.probeAudioSize(key,key);
        return true;
    }
    /* 拉取在线曲库: 元信息就绪后再拉清单, 两者都成功才算就绪 */
    function ensureLoaded() {
        if(_fetching===true || loadState===1 || loadState===2) {
            return false;
        }
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
        return refreshSilently();
    }
    /* 重试节拍: 后台静默重拉, 成功即停表并覆写缓存 */
    function _retryTick() {
        if(_fetching===true) {
            return false;
        }
        Assist.dlog("在线","后台重试拉取在线曲库");
        _silent=true;
        return _startFetch();
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
                              {"validate":function(data) { return (data!==null && typeof data==="object"
                                                                  && typeof data.audio_obj_base_url==="string"
                                                                  && data.audio_obj_base_url!==""); },
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
    /* 记一次 404: 只认缓存模式下来自当前对象存储数据根的地址 */
    function _noteOssStatus(url) {
        if(_metaFromCache!==true || _ossDead===true || _escalateOn===true) {
            return false;
        }
        var u=String(url);
        if(_ossDataRoot==="" || u.indexOf(_ossDataRoot)!==0) {
            return false;
        }
        _ossDead=true;
        Assist.dwarn("在线","对象存储返回 404, 缓存里的元信息已过时: ",u);
        return _escalateMeta();
    }
    /* 发起一次拉取: 从元信息开始, 拿到后继续拉清单 */
    function _startFetch() {
        _fetching=true;
        Assist.dlog("在线","开始拉取在线曲库: 元信息与清单",(_silent? "(后台静默)":""));
        _netStart("meta","meta",oss.meta_file_url,
                  {"validate":function(data) { return (data!==null && typeof data==="object"
                                                      && typeof data.audio_obj_base_url==="string"
                                                      && data.audio_obj_base_url!==""); },
                   "ok":function(data) {
                       Assist.dlog("在线","元信息就绪: 对象存储基址 ",data.audio_obj_base_url);
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
        _netStart("manifest","manifest",oss.manifest_file_url,
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
        _silent=false;
    }
    /* 加载失败: 有缓存可用时不进入失败态, 改为后台轮询元信息;
     * 已升级为立即重取时按固定节拍继续重试; 没有缓存可用时才进入失败态 */
    function _fail(reason) {
        _netAbortFetch();
        _fetching=false;
        if(_metaFromCache===true) {
            _silent=false;
            if(_escalateOn===true) {
                _retryOn=true;
                Assist.dwarn("在线","立即重取元信息失败, 继续按节拍重试: ",reason);
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
            if(xhr.readyState!==XMLHttpRequest.DONE) {
                return;
            }
            if(req.closed===true || group.done===true || req.token!==token) {
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
