pragma Singleton
import QtQuick

import AppHelper 1.0

import "./"

Item {
    id: serverRoot;
    /* OSS信息获取流程:
     * 依次尝试在多个备用地址 oss.meta_file_url[i] 和 oss.manifest_file_url[i] ,拿到即止
     * 将获取到的JSON文件内容分别覆盖存进同结构的JSON对象 oss.meta 和 oss.manifest
     * 清单与元信息体积小, 直接用 XMLHttpRequest 拉取; 图标由 C++ 侧下载到本地缓存后复用
     */
    property var oss:
    ({
        "meta_file_url": [
            "https://raw.githubusercontent.com/JularDepick/Crying-Music/main/oss/meta.json",
            "https://JularDepick.github.io/Crying-Music/oss/meta.json"
        ],
        "manifest_file_url": [
            "https://raw.githubusercontent.com/JularDepick/Crying-Music/main/audio/manifest.json",
            "https://JularDepick.github.io/Crying-Music/audio/manifest.json"
        ],
        "meta": ({ "audio_obj_base_url":"<被覆盖为获取到的audio_obj_base_url>" }),
        "manifest": ([{ "filename":"完整文件名称","icon":"图标文件名称","songname":"歌曲名称","singers":["歌手1"] }]),
        "icon_file_base_url": [
            "https://raw.githubusercontent.com/JularDepick/Crying-Music/main/audio/icon/",
            "https://JularDepick.github.io/Crying-Music/audio/icon/"
        ]
    });
    /* 清单加载状态: 0 未加载, 1 加载中, 2 已就绪, 3 加载失败 */
    property int loadState: 0;
    /* 最近一次失败的原因, 供界面提示使用 */
    property string loadError: "";
    /* 图标缓存: 图标文件名 -> 本地缓存路径(标准化); 整体替换以便界面绑定能收到通知 */
    property var iconCache: ({});
    /* 拉取失败的图标, 不再重试 */
    property var iconMiss: ({});
    /* 单次请求的候选地址与回调, 地址轮换只在这个状态机里进行 */
    property var _reqUrls: [];
    property int _reqIndex: 0;
    property var _reqOk: null;
    property var _reqFail: null;
    property var _xhr: null;
    property int _reqToken: 0;
    /* 正在拉取的图标与已试过的候选下标 */
    property var _iconPending: ({});
    property var _iconTries: ({});
    /* 是否有一次拉取在途: 并发保护, 静默刷新与普通拉取互斥 */
    property bool _fetching: false;
    /* 本次拉取是否静默: 静默刷新只更新数据与缓存, 不改界面可见的加载状态 */
    property bool _silent: false;
    /* 曲库数据发生变化(拉取成功或后台刷新成功), 供界面按需重建 */
    signal manifestUpdated();
    /* 是否处于失败后的自动重试中 */
    property bool _retryOn: false;
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
    /* 单个候选地址的请求超时: 超时即换下一个备用地址 */
    Timer {
        id: reqTimer;
        interval: Define.onlineRequestTimeoutMs;
        onTriggered: {
            serverRoot._onTimeout();
        }
    }
    /* 图标请求结果: 成功写进缓存, 失败换下一个候选地址 */
    Connections {
        target: AppNetHelper;
        function onIconReady(cacheKey,localPath) {
            var c=({});
            for(var k in serverRoot.iconCache) {
                c[k]=serverRoot.iconCache[k];
            }
            c[cacheKey]=localPath;
            serverRoot.iconCache=c;
            delete serverRoot._iconPending[cacheKey];
            Assist.dlog("在线","图标已缓存: ",cacheKey);
        }
        function onIconFailed(cacheKey,reason) {
            var urls=serverRoot.iconUrlCandidates(cacheKey);
            var n=(serverRoot._iconTries[cacheKey]===undefined? 0:serverRoot._iconTries[cacheKey])+1;
            serverRoot._iconTries[cacheKey]=n;
            Assist.dwarn("在线","图标地址不可用: ",cacheKey,", 原因 ",reason);
            var dir=GlobalFileStorage.iconCacheDir();
            if(n<urls.length && dir!=="") {
                AppNetHelper.fetchIcon(urls[n],cacheKey,dir);
                return;
            }
            serverRoot.iconMiss[cacheKey]=true;
            delete serverRoot._iconPending[cacheKey];
            Assist.derror("在线","图标拉取失败: ",cacheKey);
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
        var icon=(typeof row.icon==="string"? row.icon:"");
        /* 图标由列表委托在行可见时按需请求, 避免一次性发起上百个请求 */
        return ({
            "songname": (typeof row.songname==="string" && row.songname!==""? row.songname:row.filename),
            "singer": singersText(row.singers),
            "absfpath": url,
            "absipath": "",
            "size": 0,
            "duration": 0,
            "source": "online",
            "online": true,
            "onlineId": row.filename,
            "icon": icon,
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
        return ({
            "songname": name,
            "singer": "未知歌手",
            "absfpath": key,
            "absipath": "",
            "size": 0,
            "duration": 0,
            "source": "online",
            "online": true,
            "onlineId": "",
            "icon": "",
            "liked": GlobalFileStorage.isLiked(key),
            "checked": false
        });
    }
    /* 图标缓存路径: 未缓存时为空字符串 */
    function iconPathOf(iconName) {
        if(typeof iconName!=="string" || iconName==="") {
            return "";
        }
        var p=iconCache[iconName];
        return (typeof p==="string"? p:"");
    }
    /* 图标的候选地址: 由备用基址依次拼出 */
    function iconUrlCandidates(iconName) {
        var res=[];
        var bases=oss.icon_file_base_url;
        if(Array.isArray(bases)===false || typeof iconName!=="string" || iconName==="") {
            return res;
        }
        var enc=encodeURIComponent(iconName);
        for(var i=0;i<bases.length;i++) {
            res.push(String(bases[i])+enc);
        }
        return res;
    }
    /* 请求一个图标的本地缓存: 已缓存或已失败时直接返回, 每个图标只发起一次 */
    function requestIcon(iconName) {
        if(typeof iconName!=="string" || iconName==="") {
            return false;
        }
        if(iconPathOf(iconName)!=="") {
            return true;
        }
        if(iconMiss[iconName]===true || _iconPending[iconName]===true) {
            return false;
        }
        var dir=GlobalFileStorage.iconCacheDir();
        var urls=iconUrlCandidates(iconName);
        if(dir==="" || urls.length<=0) {
            return false;
        }
        _iconPending[iconName]=true;
        _iconTries[iconName]=0;
        AppNetHelper.fetchIcon(urls[0],iconName,dir);
        return true;
    }
    /* 启动引导: 先读磁盘缓存让曲库立即可用; 有缓存时再后台静默刷新, 失败不影响界面;
     * 没有缓存时按普通流程拉取, 界面照常显示加载态 */
    function bootstrap() {
        var had=loadCache();
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
    /* 用一份新的元信息与清单替换当前数据, 三组候选地址保持不变 */
    function _setData(meta,manifest) {
        serverRoot.oss=({"meta_file_url":serverRoot.oss.meta_file_url,
                         "manifest_file_url":serverRoot.oss.manifest_file_url,
                         "icon_file_base_url":serverRoot.oss.icon_file_base_url,
                         "meta":meta,
                         "manifest":manifest});
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
    /* 发起一次拉取: 从元信息开始, 拿到后继续拉清单 */
    function _startFetch() {
        _fetching=true;
        Assist.dlog("在线","开始拉取在线曲库: 元信息与清单",(_silent? "(后台静默)":""));
        _getJson(oss.meta_file_url,function(data) {
            if(data===null || typeof data!=="object" || typeof data.audio_obj_base_url!=="string"
               || data.audio_obj_base_url==="") {
                serverRoot._fail("元信息结构不正确");
                return;
            }
            Assist.dlog("在线","元信息就绪: 对象存储基址 ",data.audio_obj_base_url);
            serverRoot._setData(data,serverRoot.oss.manifest);
            serverRoot._loadManifest();
        },function(reason) {
            serverRoot._fail(reason);
        });
        return true;
    }
    /* 拉取清单 */
    function _loadManifest() {
        _getJson(oss.manifest_file_url,function(data) {
            if(Array.isArray(data)===false) {
                serverRoot._fail("清单结构不正确");
                return;
            }
            serverRoot._setData(serverRoot.oss.meta,data);
            serverRoot._finishOk();
        },function(reason) {
            serverRoot._fail(reason);
        });
    }
    /* 拉取成功: 覆写缓存, 进入就绪态并通知界面 */
    function _finishOk() {
        _fetching=false;
        _retryOn=false;
        saveCache();
        loadState=2;
        loadError="";
        Assist.dlog("在线","清单就绪: 共 ",manifestRows().length," 首");
        serverRoot.manifestUpdated();
        _silent=false;
    }
    /* 加载失败: 静默刷新只记日志并继续用缓存, 其余情况进入失败态 */
    function _fail(reason) {
        _fetching=false;
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
    /* 依次尝试候选地址取一份 JSON: 拿到即止, 全部失败时回调失败原因 */
    function _getJson(urls,ok,fail) {
        _reqUrls=(Array.isArray(urls)? urls.slice():[]);
        _reqOk=ok;
        _reqFail=fail;
        _reqIndex=0;
        _tryNextUrl();
    }
    /* 尝试下一个候选地址 */
    function _tryNextUrl() {
        if(_reqIndex>=_reqUrls.length) {
            var f=_reqFail;
            _resetRequest();
            if(f) {
                f("候选地址全部不可用");
            }
            return;
        }
        var url=_reqUrls[_reqIndex];
        _reqIndex=_reqIndex+1;
        _reqToken=_reqToken+1;
        var token=_reqToken;
        var xhr=null;
        try {
            xhr=new XMLHttpRequest();
        } catch(e) {
            Assist.derror("在线","请求对象不可用: ",e);
            _tryNextUrl();
            return;
        }
        _xhr=xhr;
        xhr.onreadystatechange=function() {
            if(xhr.readyState!==XMLHttpRequest.DONE) {
                return;
            }
            if(serverRoot._reqToken!==token) {
                return;
            }
            reqTimer.stop();
            if(xhr.status>=200 && xhr.status<300 && xhr.responseText!=="") {
                var data=null;
                try {
                    data=JSON.parse(xhr.responseText);
                } catch(e2) {
                    Assist.dwarn("在线","内容解析失败: ",url,", ",e2);
                }
                if(data!==null) {
                    var ok=serverRoot._reqOk;
                    serverRoot._resetRequest();
                    if(ok) {
                        ok(data);
                    }
                    return;
                }
            } else {
                Assist.dwarn("在线","地址不可用: ",url,", 状态 ",xhr.status);
            }
            serverRoot._tryNextUrl();
        };
        Assist.dlog("在线","请求: ",url);
        reqTimer.restart();
        try {
            xhr.open("GET",url);
            xhr.send();
        } catch(e3) {
            reqTimer.stop();
            Assist.dwarn("在线","请求发起失败: ",url,", ",e3);
            _xhr=null;
            _tryNextUrl();
        }
    }
    /* 请求超时: 作废本次请求并换下一个地址 */
    function _onTimeout() {
        Assist.dwarn("在线","请求超时, 换下一个备用地址");
        _reqToken=_reqToken+1;
        var x=_xhr;
        _xhr=null;
        if(x!==null) {
            try {
                x.abort();
            } catch(e) {
            }
        }
        _tryNextUrl();
    }
    /* 复位请求状态 */
    function _resetRequest() {
        reqTimer.stop();
        _xhr=null;
        _reqUrls=[];
        _reqOk=null;
        _reqFail=null;
        _reqIndex=0;
    }
}
