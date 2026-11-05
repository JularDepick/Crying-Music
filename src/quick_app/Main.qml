import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls.Basic
import QtQuick.Controls.impl
import QtMultimedia
import Qt.labs.platform

import AppHelper 1.0

import "qml/"

ApplicationWindow {
    id: window;
    width: 1050;
    height: 690;
    minimumWidth: 1050;
    minimumHeight: 690;
    color: Define.nocolor;
    visible: false;
    title: qsTr(Define.initTitle);
    flags: Qt.Window | Qt.FramelessWindowHint;
    /* 画中画窗口的开关状态: 由窗口持有, 顶栏与歌词页两处操控栏副本共用同一个值, 保持状态链可被各处引用;
     * 画中画窗口本身尚未实现, 当前只用于副本之间的状态同步 */
    property bool flowCardShowed: false;
    /* 由窗口操控栏自己按下的最小化: 置位后最小化保持到任务栏,
     * 未置位时的最小化由可见性钩子改判为收起到托盘 */
    property bool selfMinimized: false;
    /* 音频输出的音量百分比: 由播放栏的音量滑块实时驱动, 音频输出绑定它 */
    property real outputVolume: (GlobalFileStorage.playState.volume===undefined? 100:GlobalFileStorage.playState.volume);

    /* 内存枢纽: 只存内存的临时状态, 不落盘; 由主界面持有并注入给各页。
     * 声明在页面之前, 保证页面构建时它已存在 */
    QtObject {
        id: memStorage;
        /* 音频元数据缓存: 标准化路径 -> {duration:秒, title:曲名, artist:歌手} */
        property var metaCache: ({});
        /* 加载进度: 供各模块共用的加载反馈, 同一时刻只服务一个使用者 */
        property var loadingState:
        ({
            using: false,
            value: 0,
            finishedTip: "",
            usedByWho: ""
        });
        /* 写入音频元数据 */
        function setMeta(absfpath,meta) {
            metaCache[absfpath]=meta;
        }
        /* 读取音频元数据: 未探测返回 null */
        function metaOf(absfpath) {
            var m=metaCache[absfpath];
            return (m===undefined? null:m);
        }
        /* 判断路径是否已探测过元数据 */
        function hasMeta(absfpath) {
            return (metaCache[absfpath]!==undefined);
        }
        /* 开始加载: 已在加载中时不打断当前使用者, 返回是否成功占用 */
        function startLoading(finishedTip,usedByWho) {
            if(loadingState.using) {
                return false;
            }
            loadingState=({"using":true,"value":0,"finishedTip":finishedTip,"usedByWho":usedByWho});
            return true;
        }
        /* 更新加载进度: 只接受当前使用者的更新, 返回是否被采纳 */
        function updateLoading(value,usedByWho) {
            if(loadingState.using===false || loadingState.usedByWho!==usedByWho) {
                return false;
            }
            loadingState=({"using":true,
                           "value":value,
                           "finishedTip":loadingState.finishedTip,
                           "usedByWho":usedByWho});
            return true;
        }
        /* 结束加载: 传使用者标识时只有匹配才结束 */
        function stopLoading(usedByWho) {
            if(loadingState.using===false) {
                return false;
            }
            if(usedByWho!==undefined && usedByWho!==loadingState.usedByWho) {
                return false;
            }
            loadingState=({"using":false,"value":0,"finishedTip":"","usedByWho":""});
            return true;
        }
        /* 在线音乐下载队列: 只存内存, 下载完成后写入存储的下载记录;
         * 首页推荐与本地和下载页共用同一份队列, 因此由内存枢纽持有 */
        property var downloadTasks: ([]);
        /* 按在线标识取下载任务, 没有该项时返回 null */
        function downloadTaskOf(onlineId) {
            var l=downloadTasks.length;
            for(var i=0;i<l;i++) {
                if(downloadTasks[i]["onlineId"]===onlineId) {
                    return downloadTasks[i];
                }
            }
            return null;
        }
        /* 某个本地路径已被哪个在线标识占用, 未占用返回空字符串 */
        function downloadedOwnerOf(path) {
            var v=GlobalFileStorage.downloads;
            var l=v.length;
            for(var i=0;i<l;i++) {
                if(v[i]["absfpath"]===path) {
                    return v[i]["onlineId"];
                }
            }
            return "";
        }
        /* 下载目标路径: 按命名模板拼主文件名, 重名时追加序号;
         * 扩展名沿用在线文件的扩展名, 保证音频格式不变;
         * 只对新建文件生效, 换挡不给已经下载好的文件改名, 记录按在线标识取路径, 因此文件名格式
         * 不参与曲目映射, 链接, 分类与标记 */
        function downloadDstOf(one) {
            var dir=GlobalFileStorage.downloadsDir();
            if(dir==="") {
                return "";
            }
            var id=String(one["onlineId"]);
            var name=Assist.composeDownloadName(GlobalFileStorage.downloadNameTemplate(),
                                                one["songname"],one["singer"],id);
            var dot=name.lastIndexOf(".");
            var base=(dot>0? name.substring(0,dot):name);
            var ext=(dot>0? name.substring(dot):"");
            var p=dir+"/"+name;
            var n=1;
            while(AppFileHelper.existsFile(p)===true && memStorage.downloadedOwnerOf(p)!==id) {
                n=n+1;
                p=dir+"/"+base+" ("+n+")"+ext;
            }
            return p;
        }
        /* 开始下载: 只接受在线条目, 已下载或已在队列中时直接返回 false */
        function startDownload(one) {
            if(one===undefined || one===null || one["online"]!==true) {
                return false;
            }
            var id=one["onlineId"];
            if(id===undefined || id==="") {
                Assist.dwarn("下载","缺少在线标识, 无法下载");
                return false;
            }
            if(GlobalFileStorage.downloadedPathOf(id)!=="") {
                Assist.dlog("下载","已下载, 跳过: ",id);
                return false;
            }
            if(memStorage.downloadTaskOf(id)!==null) {
                return false;
            }
            var dst=memStorage.downloadDstOf(one);
            if(dst==="") {
                Assist.derror("下载","下载目录不可用, 无法下载");
                return false;
            }
            /* 音频缓存里已有整曲时直接复制过去, 不再从数据根重下一遍 */
            var cachedAudio=Server.audioCachePathOf(id);
            if(cachedAudio!=="") {
                if(AppFileHelper.copyFile(cachedAudio,dst)===true) {
                    Server.touchAudioCache(id);
                    Assist.dlog("下载","复用音频缓存: ",id," -> ",dst);
                    memStorage.finishDownloadTask({"onlineId":id,
                                                   "songname":one["songname"],
                                                   "singer":one["singer"],
                                                   "cover":(one["cover"]===undefined? "":one["cover"]),
                                                   "lyrics":(one["lyrics"]===undefined? "":one["lyrics"])},dst);
                    return true;
                }
                Assist.dwarn("下载","音频缓存复制失败, 改为重新下载: ",id);
            }
            /* 实际取用的地址按数据根健康度挑选: 在线标识不变, 只影响这次请求打到哪个根 */
            var url=Server.mediaUrlOf(id,"");
            if(url==="") {
                Assist.derror("下载","在线地址不可用, 无法下载");
                return false;
            }
            var task=({"onlineId":id,
                       "songname":one["songname"],
                       "singer":one["singer"],
                       "cover":(one["cover"]===undefined? "":one["cover"]),
                       "lyrics":(one["lyrics"]===undefined? "":one["lyrics"]),
                       "url":url,
                       "dst":dst,
                       "progress":0,
                       "received":0,
                       "total":-1});
            var v=downloadTasks.slice();
            v.push(task);
            downloadTasks=v;
            Assist.dlog("下载","开始下载: ",id," -> ",dst);
            AppNetHelper.downloadAudio(url,dst,id);
            /* 顺带把这首曲目的封面与歌词一并取回: 已缓存或已放弃的请求会直接返回 */
            Server.requestCover((one["cover"]===undefined? "":String(one["cover"])));
            Server.requestLyrics((one["lyrics"]===undefined? "":String(one["lyrics"])));
            return true;
        }
        /* 取消下载: 中止请求, 队列的清理由失败回调统一完成 */
        function cancelDownload(taskKey) {
            if(taskKey===undefined || taskKey==="") {
                return false;
            }
            Assist.dlog("下载","取消下载: ",taskKey);
            AppNetHelper.cancelDownload(taskKey);
            return true;
        }
        /* 从下载队列移除一个任务 */
        function removeDownloadTask(taskKey) {
            var v=[];
            var l=downloadTasks.length;
            for(var i=0;i<l;i++) {
                if(downloadTasks[i]["onlineId"]!==taskKey) {
                    v.push(downloadTasks[i]);
                }
            }
            downloadTasks=v;
        }
        /* 下载进度: 百分比变化时才整体替换队列, 避免逐块刷新界面 */
        function onDownloadProgress(taskKey,received,total) {
            var t=memStorage.downloadTaskOf(taskKey);
            if(t===null) {
                return;
            }
            var pct=(total>0? Math.floor(received*100/total):0);
            var changed=(t["progress"]!==pct);
            t["progress"]=pct;
            t["received"]=received;
            t["total"]=total;
            if(changed===true) {
                downloadTasks=downloadTasks.slice();
            }
        }
        /* 下载收尾: 写入下载记录, 体检资产并提示; 正常下载与复用音频缓存共用这一份 */
        function finishDownloadTask(t,localPath) {
            if(t===null || t===undefined) {
                return false;
            }
            GlobalFileStorage.addDownloaded({"onlineId":t["onlineId"],
                                             "absfpath":localPath,
                                             "songname":t["songname"],
                                             "singer":t["singer"],
                                             "cover":t["cover"],
                                             "lyrics":t["lyrics"],
                                             "coverPath":Server.coverPathOf(t["cover"]),
                                             "size":AppFileHelper.fileSize(localPath),
                                             "duration":0});
            /* 记录写好后立刻体检一次资产: 缺的进补全队列, 由补全节拍静默重试 */
            Server.ensureDownloadedAssets();
            Assist.dlog("下载","下载完成: ",t["onlineId"]);
            memStorage.showDownloadTip("已下载: "+t["songname"]);
            return true;
        }
        /* 下载完成: 取出任务并收尾 */
        function onDownloadFinished(taskKey,localPath) {
            var t=memStorage.downloadTaskOf(taskKey);
            memStorage.removeDownloadTask(taskKey);
            memStorage.finishDownloadTask(t,localPath);
        }
        /* 下载失败后换数据根重试: 判掉当前根并换到下一个候选, 进度与文件从头再来;
         * 没有可换的候选时返回 false, 由调用方收尾
         */
        function retryDownloadOnNextRoot(t) {
            if(t===null || t===undefined) {
                return false;
            }
            var from=String(t["url"]);
            Server.markMediaDead(from);
            var next=Server.mediaUrlAfter(t["onlineId"],from);
            if(next==="") {
                return false;
            }
            t["url"]=next;
            t["progress"]=0;
            t["received"]=0;
            t["total"]=-1;
            downloadTasks=downloadTasks.slice();
            Assist.dwarn("下载","换数据根重试下载: ",t["onlineId"]," -> ",next);
            AppNetHelper.downloadAudio(next,t["dst"],t["onlineId"]);
            return true;
        }
        /* 下载失败或取消: 失败先换数据根再试一次, 取消与候选用尽才移除任务并提示 */
        function onDownloadFailed(taskKey,reason) {
            var t=memStorage.downloadTaskOf(taskKey);
            if(t===null) {
                return;
            }
            if(reason==="已取消") {
                memStorage.removeDownloadTask(taskKey);
                Assist.dlog("下载","已取消: ",t["onlineId"]);
                return;
            }
            /* 本地写盘问题与数据根无关: 换根重试没有意义, 直接按失败收尾 */
            if(reason==="目标文件无法写入" || reason==="目标路径无效" || reason==="参数不完整") {
                memStorage.removeDownloadTask(taskKey);
                Assist.derror("下载","下载失败: ",t["songname"],", ",reason);
                memStorage.showDownloadTip("下载失败: "+t["songname"]);
                return;
            }
            if(memStorage.retryDownloadOnNextRoot(t)===true) {
                return;
            }
            memStorage.removeDownloadTask(taskKey);
            Assist.dwarn("下载","下载失败: ",t["songname"],", ",reason);
            memStorage.showDownloadTip("下载失败: "+t["songname"]);
        }
        /* 播放策略: 边播放边下载时, 把正在播放且尚未下载的在线曲目顺带入队;
         * 不下载策略与本地曲目都直接跳过 */
        function followPlayStrategy(one) {
            if(one===undefined || one===null || one["online"]!==true) {
                return false;
            }
            if(GlobalFileStorage.onlinePlayStrategy()!=="downloadwhileplaying") {
                return false;
            }
            return memStorage.startDownload(one);
        }
        /* 下载结果的浮窗提示: 复用底部加载进度条 */
        function showDownloadTip(text) {
            if(memStorage.startLoading(text,"download")===false) {
                return false;
            }
            memStorage.updateLoading(100,"download");
            return true;
        }
    }

    /* 播放器: 队列, 播放顺序与播放命令都由它持有, 播放栏与各页面只经注入引用它 */
    MediaPlayer {
        id: fakePlayer;
        source: "";
    }
    MediaPlayer {
        id: player;
        audioOutput: AudioOutput {
            id: audioOutputer;
            volume: window.outputVolume/100;
        }
        source: "";
        onErrorOccurred: (error, errorString)=>{
            Assist.derror("播放","音频播放错误:",error,errorString);
            /* 解码失败与数据根无关: 只有取不到数据才换根 */
            if(error===MediaPlayer.FormatError) {
                return;
            }
            if(followMediaRootFailover()===true) {
                return;
            }
        }
        onMediaStatusChanged: {
            if(mediaStatus===MediaPlayer.LoadedMedia && pendingRestore===true) {
                /* 断点恢复: 音频加载完成后回到上次的播放进度, 但不自动播放 */
                pendingRestore=false;
                position=(GlobalFileStorage.playState.playingPosition===undefined? 0:GlobalFileStorage.playState.playingPosition);
                Assist.dlog("播放","断点恢复: ",source," 进度 ",position);
            }
            /* 数据真的到位(加载完成或已缓冲)之后才写已播放元数据: 源刚设上、加载失败或解码失败都不写 */
            if(mediaStatus===MediaPlayer.LoadedMedia || mediaStatus===MediaPlayer.BufferedMedia) {
                cachePlayingMeta();
            }
            if(mediaStatus===MediaPlayer.EndOfMedia) {
                Assist.dlog("播放","播放结束: ",source);
                player.playNext(true);
            }
        }
        property var id2obj: new Map();
        property var songobjs: ([]);
        /* 播放目标: 在线条目已下载到本地时复用本地文件, 否则按数据根健康度取实际地址流式播放;
         * 在线标识仍然是条目自带的规范地址, 换根只影响本次请求打到哪个数据根
         */
        function playbackTarget(one) {
            if(one===undefined || one===null) {
                return "";
            }
            if(one["online"]===true) {
                var p=GlobalFileStorage.downloadedPathOf(one["onlineId"]);
                if(p!=="") {
                    return p;
                }
                /* 已缓存过整曲时直接播缓存文件, 不再走网络 */
                var c=Server.audioCachePathOf(one["onlineId"]);
                if(c!=="") {
                    Server.touchAudioCache(one["onlineId"]);
                    return c;
                }
                var u=Server.mediaUrlOf(one["onlineId"],"");
                /* 没缓存就边播边缓存: 缓存走后台, 播放仍按实际取用地址拉流 */
                Server.enqueueAudioCache(one["onlineId"],u);
                return u;
            }
            return (one["absfpath"]===undefined? "":one["absfpath"]);
        }
        /* 在线清单刷新后重新解析当前在线歌曲的取用地址: 只在未在播放且地址确实变了时改源,
         * 避免打断正在播放的音频 */
        function recheckOnlineSource() {
            if(Server.isOnlineKey(playingWhich)===false) {
                return false;
            }
            if(playbackState===MediaPlayer.PlayingState) {
                return false;
            }
            var one=playingEntry();
            if(one===null) {
                return false;
            }
            var t=playbackTarget(one);
            if(t==="" || t===String(source)) {
                return false;
            }
            Assist.dlog("播放","在线清单更新, 重新解析播放地址: ",playingWhich," -> ",t);
            source=t;
            return true;
        }
        /* 在线曲目的媒体地址失败时换数据根重试一次: 判掉当前根后取下一个候选,
         * 队列里的条目与在线标识都不动; 已下载回退到本地文件与本地曲目不换源
         */
        function followMediaRootFailover() {
            if(Server.isOnlineKey(playingWhich)===false) {
                return false;
            }
            var from=String(source);
            if(from.indexOf("http")!==0) {
                return false;
            }
            Server.markMediaDead(from);
            var next=Server.mediaUrlAfter(playingWhich,from);
            if(next==="") {
                Assist.derror("播放","在线地址已没有可换的数据根: ",playingWhich);
                return false;
            }
            var pos=Math.max(0,Math.floor(position));
            Assist.dwarn("播放","换数据根重试在线播放: ",from," -> ",next,", 进度 ",pos);
            if(pos>0) {
                /* 已经播过一段: 换根后按上次进度续播 */
                GlobalFileStorage.setPlayPosition(pos);
                pendingRestore=true;
            }
            source=next;
            player.play();
            return true;
        }
        /* 播放前置校验: 在线条目无法离线校验, 交给播放器在失败时报告 */
        function playbackOk(one) {
            if(one===undefined || one===null || one["absfpath"]===undefined || one["absfpath"]==="") {
                return false;
            }
            if(one["online"]===true) {
                return true;
            }
            return AppFileHelper.existsFile(one["absfpath"]);
        }
        /* 当前播放项在队列中的条目, 找不到时返回 null */
        function playingEntry() {
            var l=sortlist.length;
            for(var i=0;i<l;i++) {
                if(sortlist[i]["absfpath"]===playingWhich) {
                    return sortlist[i];
                }
            }
            return null;
        }
        /* 当前播放项的在线标识: 在线条目直接用条目字段, 早期记录里的标识没有前缀就补上;
         * 已下载到本地再播放时 playingWhich 是本地路径, 因此不能只认它 */
        function cacheKeyOfPlaying() {
            var one=playingEntry();
            if(one!==null && one["online"]===true) {
                var raw=(one["onlineId"]===undefined || one["onlineId"]===null? "":String(one["onlineId"]));
                if(raw!=="") {
                    var tag=String(Define.onlineKeyTag);
                    return (raw.indexOf(tag)===0? raw:tag+raw);
                }
            }
            return (Server.isOnlineKey(playingWhich)===true? playingWhich:"");
        }
        /* 当前播放项的数据真正取到之后写缓存: 播的是本地文件时直接取文件大小,
         * 流式播放到这时才发起远端字节数探测; 时长同样在这一步记下, 列表在元数据就绪前就能显示 */
        function cachePlayingMeta() {
            var key=cacheKeyOfPlaying();
            if(key==="") {
                return false;
            }
            var src=String(source);
            if(src.indexOf("http")!==0) {
                Server.rememberSizeFromFile(key,src);
            } else {
                Server.ensureSize(key,src);
            }
            Server.rememberDuration(key,Math.floor(duration/1000));
            return true;
        }
        /* 时长变化时补记一次: 只在数据已经到位时写, 不提前落盘 */
        function rememberOnlineDuration() {
            if(mediaStatus!==MediaPlayer.LoadedMedia && mediaStatus!==MediaPlayer.BufferedMedia
               && mediaStatus!==MediaPlayer.BufferingMedia) {
                return false;
            }
            var key=cacheKeyOfPlaying();
            if(key==="") {
                return false;
            }
            return Server.rememberDuration(key,Math.floor(duration/1000));
        }
        /* 播放状态: 本模块自己持有, 每次改动后同步到存储枢纽 */
        property string playingWhich: "";
        property int playingIndex: -1;
        property var sortlist: ([]);
        /* 播放顺序: 0 随机播放, 1 顺序播放, 2 单曲循环, 3 列表循环 */
        property int playMode: 1;
        /* 断点恢复中: 待音频加载完成后把播放进度恢复到上次的位置 */
        property bool pendingRestore: false;
        /* 播放栏显示的曲名与歌手: 由 syncPlayingInfo 从当前播放项刷新, 空字符串表示未在播放 */
        property string playingTitle: "";
        property string playingSinger: "";
        /*[
            {songname:"心做し 心理作用", singer:"双笙-陈元汐", absfpath:"file:///C:\\Users\\liwenfang\\GitHub\\JularDepick\\Crying-Music\\src\\quick_app\\心做し_心理作用_双笙_陈元汐_.mp3"}
        ];*/
        function jump2play(which) {
            if(playbackOk(which)===false) {
                Assist.derror("播放","跳转错误: ",which);
                return false;
            }
            sortlist=insertAfterPlaying(which);
            playingWhich=which.absfpath;
            syncPlayingIndex();
            syncPlayState();
            /* 换歌即把播放进度归零, 避免断点恢复落到上一首的位置 */
            GlobalFileStorage.setPlayPosition(0);
            source=playbackTarget(which);
            GlobalFileStorage.addRecent(playingWhich);
            player.play();
            /* 播放策略: 边播放边下载时顺带把该曲加入下载队列 */
            memStorage.followPlayStrategy(which);
            Assist.dlog("播放","跳转成功: ",which);
            return true;
        }
        function insertNext(which) {
            if(which===undefined || which.absfpath===undefined) {
                Assist.derror("播放","插入错误: ",which);
                return false;
            }
            sortlist=insertAfterPlaying(which);
            syncPlayingIndex();
            syncPlayState();
            Assist.dlog("播放","插入下一首: ",which);
            return true;
        }
        /* 去重后插到当前播放项之后, 当前无播放项时追加到末尾 */
        function insertAfterPlaying(which) {
            var asl=[];
            var l=sortlist.length;
            for(var i=0;i<l;i++) {
                if(sortlist[i].absfpath!==which.absfpath) {
                    asl.push(sortlist[i]);
                }
            }
            var res=[];
            var n=asl.length;
            var done=false;
            for(var j=0;j<n;j++) {
                res.push(asl[j]);
                if(done===false && asl[j].absfpath===playingWhich) {
                    res.push(which);
                    done=true;
                }
            }
            if(done===false) {
                res.push(which);
            }
            return res;
        }
        /* 以整份列表构造播放队列并开始播放 */
        function playAll(list,which) {
            if(list===undefined || list.length<=0) {
                Assist.derror("播放","播放失败: 列表为空");
                return false;
            }
            var one=(which===undefined? list[0]:which);
            if(playbackOk(one)===false) {
                Assist.derror("播放","播放错误: ",one);
                return false;
            }
            sortlist=list.slice();
            if(playMode===0) {
                /* 随机播放: 换列表时同样先打乱 */
                sortlist=shuffleList(sortlist);
            }
            playingWhich=one.absfpath;
            syncPlayingIndex();
            syncPlayState();
            /* 换歌即把播放进度归零, 避免断点恢复落到上一首的位置 */
            GlobalFileStorage.setPlayPosition(0);
            source=playbackTarget(one);
            GlobalFileStorage.addRecent(playingWhich);
            player.play();
            memStorage.followPlayStrategy(one);
            Assist.dlog("播放","播放列表: ",sortlist.length);
            return true;
        }
        /* 直接切到队列中的某一项播放, 不改动队列顺序 */
        function playItem(which) {
            if(playbackOk(which)===false) {
                Assist.derror("播放","跳转错误: ",which);
                return false;
            }
            playingWhich=which.absfpath;
            syncPlayingIndex();
            syncPlayState();
            /* 换歌即把播放进度归零, 避免断点恢复落到上一首的位置 */
            GlobalFileStorage.setPlayPosition(0);
            source=playbackTarget(which);
            GlobalFileStorage.addRecent(playingWhich);
            player.play();
            memStorage.followPlayStrategy(which);
            return true;
        }
        /* 播放队列中指定下标的项 */
        function playIndex(idx) {
            var l=sortlist.length;
            if(idx<0 || idx>=l) {
                return false;
            }
            playingIndex=idx;
            playingWhich=sortlist[idx].absfpath;
            syncPlayState();
            /* 换歌即把播放进度归零, 避免断点恢复落到上一首的位置 */
            GlobalFileStorage.setPlayPosition(0);
            source=playbackTarget(sortlist[idx]);
            GlobalFileStorage.addRecent(playingWhich);
            player.play();
            memStorage.followPlayStrategy(sortlist[idx]);
            return true;
        }
        /* 下一曲: auto 为 true 表示播放结束后的自动切换 */
        function playNext(auto) {
            var l=sortlist.length;
            if(l<=0) {
                return false;
            }
            if(auto===true && playMode===2) {
                /* 单曲循环: 重播当前项 */
                position=0;
                play();
                return true;
            }
            var next=playingIndex+1;
            if(next<l) {
                return playIndex(next);
            }
            if(playMode===1) {
                /* 顺序播放: 自动切换时停止 */
                if(auto===true) {
                    stop();
                    Assist.dlog("播放","顺序播放结束");
                }
                return false;
            }
            if(playMode===0) {
                /* 随机播放: 重新打乱后从头播放 */
                sortlist=shuffleList(sortlist);
            }
            return playIndex(0);
        }
        /* 上一曲 */
        function playPrev() {
            var l=sortlist.length;
            if(l<=0) {
                return false;
            }
            var prev=playingIndex-1;
            if(prev<0) {
                if(playMode===1) {
                    return false;
                }
                prev=l-1;
            }
            return playIndex(prev);
        }
        /* 切换播放顺序: 切到随机时立即打乱当前队列 */
        function setPlayMode(mode) {
            Assist.dlog("播放","切换播放顺序: ",mode);
            playMode=mode;
            if(mode===0) {
                sortlist=shuffleList(sortlist);
                syncPlayingIndex();
            }
            syncPlayState();
            Assist.dlog("播放","播放顺序: ",mode);
        }
        /* 打乱列表顺序 */
        function shuffleList(v) {
            var res=v.slice();
            for(var i=res.length-1;i>0;i--) {
                var j=Math.floor(Math.random()*(i+1));
                var tmp=res[i];
                res[i]=res[j];
                res[j]=tmp;
            }
            return res;
        }
        /* 当前播放项在队列中的下标, 未找到返回 -1 */
        function indexOfPlaying() {
            var l=sortlist.length;
            for(var i=0;i<l;i++) {
                if(sortlist[i].absfpath===playingWhich) {
                    return i;
                }
            }
            return -1;
        }
        /* 同步当前播放项下标 */
        function syncPlayingIndex() {
            playingIndex=indexOfPlaying();
            return playingIndex;
        }
        /* 从播放队列中移除单项 */
        function removeItem(which) {
            Assist.dlog("队列","从队列移除: ",which.absfpath);
            var asl=[];
            var l=sortlist.length;
            for(var i=0;i<l;i++) {
                if(sortlist[i].absfpath!==which.absfpath) {
                    asl.push(sortlist[i]);
                }
            }
            sortlist=asl;
            syncPlayingIndex();
            syncPlayState();
        }
        /* 清空播放队列, 保留当前正在播放的项 */
        function clearList() {
            Assist.dlog("队列","清空队列: 清空 ",sortlist.length," 项, 保留当前播放项");
            var keep=[];
            var l=sortlist.length;
            for(var i=0;i<l;i++) {
                if(sortlist[i].absfpath===playingWhich) {
                    keep.push(sortlist[i]);
                }
            }
            sortlist=keep;
            syncPlayingIndex();
            syncPlayState();
        }
        /* 把本模块的播放状态推到枢纽, 供其它模块读取 */
        function syncPlayState() {
            GlobalFileStorage.setPlayState(sortlist,playingWhich,playingIndex,playMode);
            syncPlayingInfo();
        }
        /* 刷新播放栏显示的曲名与歌手: 取当前播放项, 找不到时清空 */
        function syncPlayingInfo() {
            var idx=indexOfPlaying();
            if(idx<0) {
                playingTitle="";
                playingSinger="";
                return false;
            }
            var one=sortlist[idx];
            playingTitle=(one["songname"]===undefined? "":one["songname"]);
            playingSinger=(one["singer"]===undefined? "":one["singer"]);
            return true;
        }
        /* 把播放进度推到枢纽: 落盘与断点恢复都从枢纽取 */
        function syncPlayPosition(ms) {
            GlobalFileStorage.setPlayPosition(ms);
        }
        /* 断点恢复: 校验队列与当前播放项后加载音频, 不自动播放;
         * 在线条目只要地址仍在就恢复, 真正的可用性交给播放器报错 */
        function restoreFromState() {
            var st=GlobalFileStorage.playState;
            sortlist=st.sortlist;
            playingWhich=st.playingWhich;
            playingIndex=st.playingIndex;
            playMode=st.playMode;
            var one=playingEntry();
            var usable=false;
            if(playingWhich!=="") {
                if(one!==null) {
                    usable=playbackOk(one);
                } else {
                    usable=AppFileHelper.existsFile(playingWhich);
                }
            }
            if(usable===false) {
                /* 上次的音频已不存在: 清掉当前播放项, 队列保留 */
                Assist.dwarn("播放","断点恢复失败: 上次的音频不可用, 已清掉当前播放项, 队列保留");
                playingWhich="";
                playingIndex=-1;
                syncPlayState();
                return false;
            }
            Assist.dlog("播放","断点恢复: 队列 ",sortlist.length," 项, 当前 ",playingWhich);
            pendingRestore=true;
            syncPlayingInfo();
            source=(one!==null? playbackTarget(one):playingWhich);
            return true;
        }
        /* 在线清单就绪后校正队列里的在线条目: 曲名与歌手一律以清单为准,
         * 因此清单就绪前按地址末段显示的临时名称会被改回清单值;
         * 下载到本地再播的条目 absfpath 是本地路径, 按条目的在线标识查,
         * 同时补齐清单与已播放缓存里的大小与时长, 列表与面板据此显示 */
        function refreshOnlineTitles() {
            var l=sortlist.length;
            var res=sortlist.slice();
            var changed=false;
            for(var i=0;i<l;i++) {
                var one=res[i];
                if(one===undefined || one===null || one["online"]!==true) {
                    continue;
                }
                var e=(Server.isOnlineKey(one["absfpath"])===true
                       ? Server.onlineEntryOfKey(one["absfpath"])
                       : Server.onlineEntryOfId(one["onlineId"]));
                if(e===null) {
                    continue;
                }
                if(one["songname"]!==e["songname"] || one["singer"]!==e["singer"]) {
                    one["songname"]=e["songname"];
                    one["singer"]=e["singer"];
                    changed=true;
                }
                if(e["cover"]!=="" && one["cover"]!==e["cover"]) {
                    one["cover"]=e["cover"];
                    changed=true;
                }
                if(!(one["duration"]>0) && e["duration"]>0) {
                    one["duration"]=e["duration"];
                    changed=true;
                }
                if(!(one["size"]>0) && e["size"]>0) {
                    one["size"]=e["size"];
                    changed=true;
                }
            }
            if(changed===true) {
                sortlist=res;
                /* 推回枢纽让面板与落盘拿到校正后的条目 */
                syncPlayState();
                Assist.dlog("在线","按清单校正队列里的在线条目");
            }
            return changed;
        }
        /* 从枢纽取回播放状态: 值不同才覆盖, 避免与推送动作形成回环 */
        function updateFromPlayState() {
            var st=GlobalFileStorage.playState;
            if(st.sortlist!==sortlist) {
                sortlist=st.sortlist;
            }
            if(st.playingWhich!==playingWhich) {
                playingWhich=st.playingWhich;
            }
            if(st.playingIndex!==playingIndex) {
                playingIndex=st.playingIndex;
            }
            if(st.playMode!==playMode) {
                playMode=st.playMode;
            }
            syncPlayingInfo();
        }
    }

    /* 系统托盘 */
    SystemTrayIcon {
        id: stIcon;
        visible: true;
        icon.source: "qrc:/favicon.jpg";
        tooltip: "泣水音乐";
        menu: Menu {
            id: stMenu;
            MenuItem {
               text: "退出";
               onTriggered: Qt.exit(0);
           }
           MenuSeparator {}
       }
        /* 左键单击切换收起与展开: 收起是隐藏到托盘, 展开时恢复上次的显示状态 */
        onActivated: (reason)=> {
            if(reason===SystemTrayIcon.Trigger || reason===SystemTrayIcon.DoubleClick
               || reason===SystemTrayIcon.MiddleClick) {
                window.toggleShown();
            }
        }
    }
    /* 收起与展开的唯一开关: 托盘图标与任务栏按钮都走这一条路径 */
    function toggleShown() {
        /* 展开前先清掉自己的最小化标记, 避免上一次标记残留影响下一次判断 */
        selfMinimized=false;
        if(window.visible===true && window.visibility!==Window.Minimized) {
            window.hide();
            return;
        }
        if(window.visibility===Window.Maximized) {
            window.showMaximized();
        } else if(window.visibility===Window.Minimized) {
            window.showNormal();
        } else {
            window.show();
        }
        window.raise();
        window.requestActivate();
    }
    /* 任务栏按钮在窗口已展开时按下会先最小化: 借这一步把窗口收起到托盘,
     * 使任务栏按钮与托盘图标都成为收起与展开的开关;
     * 操控栏自己按下的最小化会先把 selfMinimized 置位, 那种情况保持最小化到任务栏 */
    onVisibilityChanged: (visibility)=> {
        if(visibility===Window.Minimized) {
            if(selfMinimized===true) {
                selfMinimized=false;
            } else {
                Qt.callLater(function() { window.hide(); });
            }
        }
    }
    onClosing: (close)=> {
        if (stIcon.visible) {
            close.accepted=false;
            window.hide();
        }
    }

    /* 窗口边框拖拽 */
    MouseArea {
        anchors {left:parent.left; right:parent.right; top: parent.top;}
        height: Define.edgeMouseAreaD;
        cursorShape: Qt.SizeVerCursor;
        onPressed: window.startSystemResize(Qt.TopEdge);
    }
    MouseArea {
        anchors {left:parent.left; right:parent.right; bottom:parent.bottom;}
        height: Define.edgeMouseAreaD;
        cursorShape: Qt.SizeVerCursor;
        onPressed: window.startSystemResize(Qt.BottomEdge);
    }
    MouseArea {
        anchors {left:parent.left; top:parent.top; bottom:parent.bottom;}
        width: Define.edgeMouseAreaD;
        cursorShape: Qt.SizeHorCursor;
        onPressed: window.startSystemResize(Qt.LeftEdge);
    }
    MouseArea {
        anchors {right:parent.right; top:parent.top; bottom:parent.bottom;}
        width: Define.edgeMouseAreaD;
        cursorShape: Qt.SizeHorCursor;
        onPressed: window.startSystemResize(Qt.RightEdge);
    }
    MouseArea {
        anchors {left:parent.left; top:parent.top;}
        width: Define.cornerMouseAreaD;
        height: Define.cornerMouseAreaD;
        cursorShape: Qt.SizeFDiagCursor;
        onPressed: window.startSystemResize(Qt.LeftEdge | Qt.TopEdge);
    }
    MouseArea {
        anchors {right:parent.right; top:parent.top;}
        width: Define.cornerMouseAreaD;
        height: Define.cornerMouseAreaD;
        cursorShape: Qt.SizeBDiagCursor;
        onPressed: window.startSystemResize(Qt.RightEdge | Qt.TopEdge);
    }
    MouseArea {
        anchors {left:parent.left; bottom:parent.bottom;}
        width: Define.cornerMouseAreaD;
        height: Define.cornerMouseAreaD;
        cursorShape: Qt.SizeBDiagCursor;
        onPressed: window.startSystemResize(Qt.LeftEdge | Qt.BottomEdge);
    }
    MouseArea {
        anchors {right:parent.right; bottom:parent.bottom;}
        width: Define.cornerMouseAreaD;
        height: Define.cornerMouseAreaD;
        cursorShape: Qt.SizeFDiagCursor;
        onPressed: window.startSystemResize(Qt.RightEdge | Qt.BottomEdge);
    }

    /* 主页面容器 */
    Rectangle {
        id: canvas;
        anchors.fill: parent;
        topLeftRadius: Define.windowRadius;
        topRightRadius: Define.windowRadius;
        bottomLeftRadius: Define.windowRadius;
        bottomRightRadius: Define.windowRadius;
        border.width: 0.5;
        border.color: Define.windowBorderColor;
        color: Define.canvasColor;
        /* 拖动窗口 */
        MouseArea {
            id: canvasDrag;
            anchors.fill: parent;
            anchors.margins: Define.edgeMouseAreaD;
            acceptedButtons: Qt.LeftButton;
            onPressed: (mouse)=> {
                var mx=mouse.x;
                var my=mouse.y;
                var d=Define.windowPadding-Define.edgeMouseAreaD;
                if(mx<d || my<d || mx>(leftSidebar.width+mainArea.width+d) || my>(leftSidebar.height+d)) {
                    window.startSystemMove();
                }
            }
        }
        Rectangle {
            id: leftSidebar;
            anchors {left:parent.left; top:parent.top; bottom:parent.bottom;}
            anchors.leftMargin: Define.windowPadding;
            anchors.topMargin: Define.windowPadding;
            anchors.bottomMargin: Define.windowPadding;
            topLeftRadius: Define.mainAreaRaduis;
            topRightRadius: Define.mainAreaRaduis;
            bottomLeftRadius: Define.mainAreaRaduis;
            bottomRightRadius: Define.mainAreaRaduis;
            clip: true;
            property int bigWidth: 220;
            property int smallWidth: 75;
            /* 展开状态取自存储单例的界面状态, 改动只经存储接口写回, 因此重启后保持上次的状态 */
            property bool spreaded: GlobalFileStorage.uiState.leftSidebarSpreaded;
            width: (spreaded? bigWidth: smallWidth);
            color: Define.leftSidebarColor;
            function spread(b=true) {
                if(b===spreaded) {
                    return;
                }
                Assist.dlog("界面","左侧栏展开状态: ",b);
                GlobalFileStorage.setLeftSidebarSpreaded(b);
            }
            /* 左侧栏的右边框拖拽 */
            MouseArea {
                anchors {right:parent.right; top:parent.top; bottom:parent.bottom;}
                width: 5;
                cursorShape: Qt.SizeHorCursor;
                property int dragStartX: 0;
                property int dragEndX: 0;
                onPressed: (mouse)=> {
                    dragStartX=mouse.x;
                }
                onPositionChanged: (mouse)=> {
                    dragEndX=mouse.x;
                }
                onReleased: {
                    if(dragEndX<dragStartX && parent.spreaded) {
                        parent.spread(false);
                    } else if(dragEndX>dragStartX && !parent.spreaded) {
                        parent.spread(true);
                    }
                }
            }
            property var svg2obj: ({
                "profile" : mainArea_ProfilePage,
                "home" : mainArea_HomePage,
                "likedlist" : mainArea_LikedPage,
                "recentlist" : mainArea_RecentPage,
                "locallist" : mainArea_LocalPage,
                "settings" : mainArea_SettingsPage,
                "theme" : mainArea_ThemePage
            });
            Rectangle {
                id: leftSidebarHeader;
                anchors {left:parent.left; right:parent.right; top:parent.top;}
                height: 65;
                topLeftRadius: Define.mainAreaRaduis;
                topRightRadius: Define.mainAreaRaduis;
                bottomLeftRadius: Define.mainAreaRaduis;
                bottomRightRadius: Define.mainAreaRaduis;
                color: Define.leftSidebarHeaderColor;
                Row {
                    anchors {top:parent.top; bottom:parent.bottom;}
                    x: (leftSidebar.spreaded? Define.windowPadding*2:(leftSidebarHeader.width-width)/2);
                    topPadding: 10;
                    spacing: 10;
                    CustomButtonA {
                        height: 50;
                        width: height;
                        transEnabled: false;
                        onClicked: {
                            mainArea.jump2(leftSidebar.svg2obj["profile"]);
                        }
                        background: Image {
                            anchors.fill: parent;
                            id: userAvatar;
                            /* 登录后显示缓存的 QQ 头像小图, 未登录或不是纯数字 QQ 邮箱时用应用图标 */
                            source: (Account.avatarSource(Define.avatarSpecSmall)===""
                                     ? "qrc:/favicon.jpg":Account.avatarSource(Define.avatarSpecSmall));
                            fillMode: Image.PreserveAspectCrop;
                            layer.enabled: true;
                            layer.effect: MultiEffect {
                                maskEnabled: true;
                                maskSource: userAvatarMasker;
                            }
                            Item {
                                id: userAvatarMasker;
                                anchors.fill: parent;
                                visible: false;
                                layer.enabled: true;
                                Rectangle {
                                    anchors.fill: parent;
                                    radius: height/2;
                                    border.color: Define.subGrey;
                                    border.width: 0.5;
                                }
                            }
                        }
                    }
                    Column {
                        anchors {top:parent.top; bottom:parent.bottom;}
                        anchors.topMargin: 15;
                        spacing: 5;
                        visible: leftSidebar.spreaded;
                        Row {
                            spacing: 4;
                            Text {
                                color: Define.textColor;
                                id: userName;
                                /* 登录后直接显示邮箱地址, 未登录显示未登录; 过长时右侧省略 */
                                text: (Account.loggedIn===true? Account.email:"未登录");
                                font.pixelSize: 13;
                                width: 130;
                                elide: Text.ElideRight;
                            }
                        }
                        Row {
                            CustomButtonA {
                                id: userVIP;
                                icon.source: "qrc:/assets/iconfont/vip/vip10.svg";
                                icon.color: Define.vipRed;
                                transEnabled: false;
                                hoverHandlerEnabled: false;
                            }
                        }
                    }
                }
            }
            Rectangle {
                id: leftSidebarBody;
                anchors {top:leftSidebarHeader.bottom; bottom:leftSidebarFoot.top; left:parent.left; right:parent.right;}
                color: Define.canvasColor;
                property var svg2obj: parent.svg2obj;
                Column {
                    anchors.fill: parent;
                    anchors.topMargin: 10;
                    anchors.rightMargin: Define.windowPadding;
                    spacing: 1;
                    Repeater {
                        model: ListModel {
                            ListElement {svgname:"home"; title:"首页推荐"}
                            ListElement {svgname:"likedlist"; title:"我的喜欢"}
                            ListElement {svgname:"recentlist"; title:"最近播放"}
                            ListElement {svgname:"locallist"; title:"本地和下载"}
                        }
                        delegate: CustomButtonA {
                            height: 50;
                            x: (leftSidebar.spreaded? Define.windowRadius:(parent.width-width)/2);
                            width: (leftSidebar.spreaded? (parent.width-Define.windowRadius*2):height);
                            property var obj2: leftSidebar.svg2obj[svgname];
                            transEnabled: false;
                            background: Rectangle {
                                anchors.fill: parent;
                                color: (obj3.visible? (Define.choseDarkColor):(hovered? Define.hoverDarkColor:Define.canvasColor));
                                radius: 10;
                                property var obj3: parent.obj2;
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter;
                                    x: (leftSidebar.spreaded? Define.windowRadius*2:(parent.width-width)/2);
                                    spacing: 8;
                                    property var obj4: parent.obj3;
                                    ColorImage  {
                                        anchors.verticalCenter: parent.verticalCenter;
                                        width: 25;
                                        height: 25;
                                        source: `qrc:/assets/iconfont/leftsidebar/${svgname}`+(parent.obj4.visible? "_ed":"")+".svg";
                                        color: Define.btnIconColor;
                                    }
                                    Text {
                                        color: Define.textColor;
                                        anchors.verticalCenter: parent.verticalCenter;
                                        text: title;
                                        font.pixelSize: 14;
                                        visible: leftSidebar.spreaded;
                                    }
                                }
                            }
                            onClicked: {
                                mainArea.jump2(obj2);
                            }
                        }
                    }
                }
            }
            Rectangle {
                id: leftSidebarFoot;
                anchors {bottom:parent.bottom; left:parent.left;}
                anchors.bottomMargin: Define.windowPadding;
                width: (parent.width-Define.windowPadding);
                height: 25;
                color: Define.canvasColor;
                Row {
                    anchors.verticalCenter: parent.verticalCenter;
                    anchors.leftMargin: Define.windowPadding;
                    x: (leftSidebar.spreaded? (Define.windowPadding*2):(parent.width-width)/2);
                    spacing: 20;
                    CustomButtonA {
                        icon.source: `qrc:/assets/iconfont/leftsidebar/spread${leftSidebar.spreaded? "ed":""}.svg`;
                        onClicked: {
                            leftSidebar.spread(!leftSidebar.spreaded);
                        }
                    }
                    CustomButtonA {
                        icon.source: "qrc:/assets/iconfont/leftsidebar/settings.svg";
                        visible: leftSidebar.spreaded;
                        onClicked: {
                            mainArea.jump2(leftSidebar.svg2obj["settings"]);
                        }
                    }
                    CustomButtonA {
                        icon.source: "qrc:/assets/iconfont/leftsidebar/theme.svg";
                        visible: leftSidebar.spreaded;
                        onClicked: {
                            mainArea.jump2(leftSidebar.svg2obj["theme"]);
                        }
                    }
                }
            }
        }
        Rectangle {
            id: topNavBar;
            anchors {left:leftSidebar.right;right:parent.right; top:parent.top;}
            anchors.topMargin: Define.windowPadding;
            anchors.rightMargin: Define.windowPadding;
            height: 65;
            topLeftRadius: Define.mainAreaRaduis;
            topRightRadius: Define.mainAreaRaduis;
            bottomLeftRadius: Define.mainAreaRaduis;
            bottomRightRadius: Define.mainAreaRaduis;
            color: Define.topNavBarColor;
            /* 拖动窗口 */
            MouseArea {
                id: topNavBarDrag;
                anchors.fill: parent;
                acceptedButtons: Qt.LeftButton;
                property bool isDragging: false;
                onPressed: {
                    isDragging=false;
                }
                onPositionChanged: {
                    if (pressed && (!isDragging)) {
                        isDragging=true;
                        window.startSystemMove();
                    }
                }
                onDoubleClicked: {
                    if (!isDragging) {
                        if (window.visibility !== Window.Maximized) {
                            window.showMaximized();
                        } else {
                            window.showNormal();
                        }
                    }
                }
            }
            property int rowsTopMargin: 10;
            property int rowsHeight: 30;
            Row {
                id: hisButtons;
                anchors {top:parent.top; left:parent.left;}
                anchors.topMargin: parent.rowsTopMargin;
                leftPadding: 30;
                height: parent.rowsHeight;
                spacing: Define.btnSpacing;
                TopNavBarButton {
                    id: backwardBtn;
                    icon.source: "qrc:/assets/iconfont/topnavbar/backward.svg";
                    icon.color: (mainArea.uhis.length<=0? Define.forbdDarkColor:(hovered&&hoverColorEnabled? Define.btnHoverColor:Define.btnIconColor));
                    transEnabled: mainArea.uhis.length>0;
                    hoverHandlerEnabled: transEnabled;
                    onClicked: {
                        mainArea.undo();
                    }
                }
                TopNavBarButton {
                    id: forwardBtn;
                    icon.source: "qrc:/assets/iconfont/topnavbar/forward.svg";
                    icon.color: (mainArea.rhis.length<=0? Define.forbdDarkColor:(hovered&&hoverColorEnabled? Define.btnHoverColor:Define.btnIconColor));
                    transEnabled: mainArea.rhis.length>0;
                    hoverHandlerEnabled: transEnabled;
                    onClicked: {
                        mainArea.redo();
                    }
                }
                TopNavBarButton {
                    id: refreshBtn;
                    icon.source: "qrc:/assets/iconfont/topnavbar/refresh.svg";
                    onClicked: {
                        mainArea.refresh();
                    }
                }
            }
            Row {
                id: searchArea;
                anchors {top: parent.top; left:hisButtons.right;}
                anchors.topMargin: parent.rowsTopMargin;
                anchors.verticalCenter: parent.verticalCenter;
                leftPadding: 30;
                height: parent.rowsHeight;
                TextField {
                    id: searchInput;
                    width: 200;
                    height: 30;
                    background: Rectangle {
                        color: Define.forbdDarkColor;
                        topLeftRadius: 8;
                        bottomLeftRadius: 8;
                        anchors.fill: parent;
                    }
                    placeholderText: "搜索音乐";
                    /* 回车即搜索当前页面的列表 */
                    onAccepted: {
                        window.doSearch();
                    }
                }
                TopNavBarButton {
                    id: searchBtn;
                    icon.source: "qrc:/assets/iconfont/topnavbar/search.svg";
                    anchors.verticalCenter: searchInput.verticalCenter;
                    transEnabled: false;
                    onClicked: {
                        window.doSearch();
                    }
                    background: Rectangle {
                        color: Define.forbdDarkColor;
                        width: 25;
                        height: 30;
                        topRightRadius: 8;
                        bottomRightRadius: 8;
                        anchors.verticalCenter: parent.verticalCenter;
                    }
                }
            }
            /* 右上角窗口操控栏: 与歌词页共用同一份实现, 两处副本操控同一个窗口 */
            WindowControlBar {
                id: sysButtons;
                theWindow: window;
                anchors {top:parent.top; right:parent.right;}
                anchors.topMargin: parent.rowsTopMargin;
            }
        }
        Rectangle {
            id: mainArea;
            anchors {left:leftSidebar.right; right:parent.right; top:topNavBar.bottom; bottom:playerBar.top;}
            anchors.rightMargin: Define.windowPadding;
            anchors.bottomMargin: Define.windowPadding;
            bottomLeftRadius: Define.mainAreaRaduis;
            bottomRightRadius: Define.mainAreaRaduis;
            color: Define.mainAreaColor;
            clip: true;
            property var uhis: [];
            property var rhis: [];
            property var curr: mainArea_HomePage;
            /* 按当前页反查路由键: 路由表由左侧栏持有, 这里只做反查, 用于把导航位置落盘 */
            function routeKeyOf(which) {
                var t=leftSidebar.svg2obj;
                for(var k in t) {
                    if(t[k]===which) {
                        return k;
                    }
                }
                return "";
            }
            function _show(which) {
                if(curr===which) {
                    return;
                }
                Assist.dlog("界面","换页: ",routeKeyOf(which));
                curr.visible=false;
                curr=which;
                curr.visible=true;
                /* 每次真正换页都把当前页写进界面状态, 供下次启动停在同一页;
                 * 搜索结果页没有路由键, 不进界面状态, 重启后回到发起搜索前的页面 */
                var key=routeKeyOf(which);
                if(key!=="") {
                    GlobalFileStorage.setMainAreaPage(key);
                }
            }
            /* 按存储里的界面状态恢复上次停留的页面: 只换页, 不进历史栈;
             * 启动时不恢复到设置页, 统一回到首页并把存储同步为首页, 避免下次启动又停在设置页 */
            function applyStoredPage() {
                var obj=leftSidebar.svg2obj[GlobalFileStorage.uiState.mainAreaPage];
                if(obj===undefined || obj===null) {
                    Assist.dwarn("界面","恢复页面失败: 存储里的页面键无效: ",GlobalFileStorage.uiState.mainAreaPage);
                    return false;
                }
                if(obj===mainArea_SettingsPage) {
                    Assist.dlog("界面","启动时的页面为设置页, 改为停留首页");
                    GlobalFileStorage.setMainAreaPage("home");
                    obj=mainArea_HomePage;
                }
                _show(obj);
                return true;
            }
            function undo() {
                if(uhis.length<=0) {
                    return;
                }
                Assist.dlog("界面","后退");
                var utop=uhis[uhis.length-1];
                var uarr=uhis.slice();
                uarr.pop();
                uhis=uarr;
                var rarr=rhis.slice();
                rarr.push(curr);
                rhis=rarr;
                _show(utop);
            }
            function redo() {
                if(rhis.length<=0) {
                    return;
                }
                Assist.dlog("界面","前进");
                var rtop=rhis[rhis.length-1];
                var rarr=rhis.slice();
                rarr.pop();
                rhis=rarr;
                var uarr=uhis.slice();
                uarr.push(curr);
                uhis=uarr;
                _show(rtop);
            }
            function jump2(which) {
                if(curr===which) {
                    return;
                }
                Assist.dlog("界面","页面跳转: ",routeKeyOf(which));
                var uarr=uhis.slice();
                uarr.push(curr);
                uhis=uarr;
                rhis=[];
                _show(which);
            }
            function refresh() {
                if(curr!==undefined && curr.refresh) {
                    curr.refresh();
                }
            }
            MainAreaProfilePage {
                id: mainArea_ProfilePage;
                anchors.fill: parent;
            }
            MainAreaHomePage {
                id: mainArea_HomePage;
                thePlayer: player;
                theMemStorage: memStorage;
                anchors.fill: parent;
                visible: true;
            }
            MainAreaLikedPage {
                id: mainArea_LikedPage;
                thePlayer: player;
                theMemStorage: memStorage;
                anchors.fill: parent;
            }
            MainAreaRecentPage {
                id: mainArea_RecentPage;
                thePlayer: player;
                theMemStorage: memStorage;
                anchors.fill: parent;
            }
            MainAreaLocalPage {
                id: mainArea_LocalPage;
                thePlayer: player;
                theProber: fakePlayer;
                theMemStorage: memStorage;
                anchors.fill: parent;
            }
            MainAreaSettingsPage {
                id: mainArea_SettingsPage;
                anchors.fill: parent;
            }
            MainAreaThemePage {
                id: mainArea_ThemePage;
                anchors.fill: parent;
            }
            MainAreaResultPage {
                id: mainArea_ResultPage;
                thePlayer: player;
                theMemStorage: memStorage;
                anchors.fill: parent;
            }
        }
        /* 播放栏 */
        /* 播放栏: 与歌词页共用同一份实现, 卡片式与透明式由 cardStyle 区分 */
        PlayerBar {
            id: playerBar;
            thePlayer: player;
            theProber: fakePlayer;
            theMemStorage: memStorage;
            sidebarSpreaded: leftSidebar.spreaded;
            ownsPlayerSideEffects: true;
            anchors {left:leftSidebar.right; right:parent.right; bottom:parent.bottom;}
            anchors.rightMargin: Define.windowPadding;
            anchors.bottomMargin: Define.windowPadding;
            onLyricsOpenerClicked: lyricsSubTab.tshow();
            onVolumeMoved: (value)=> {
                window.outputVolume=value;
            }
        }

        /* 播放列表面板: 由播放栏的播放列表按钮呼出 */
        Rectangle {
            id: playingListArea;
            anchors {top:canvas.top; bottom:mainArea.bottom; right: canvas.right;}
            anchors.rightMargin: Define.windowPadding;
            anchors.topMargin: Define.windowPadding;
            topLeftRadius: Define.mainAreaRaduis;
            topRightRadius: Define.mainAreaRaduis;
            bottomLeftRadius: Define.mainAreaRaduis;
            bottomRightRadius: Define.mainAreaRaduis;
            color: Define.mainAreaColor;
            width: 450;
            border.color: Define.subGrey;
            border.width: 1;
            visible: playerBar.listVisible;
            PlayingListViewArea {
                anchors.fill: parent;
                thePlayer: player;
                theMemStorage: memStorage;
            }
        }
    }
    LyricsSubTab {
        /* 与 canvas 平级的整窗覆盖层: 层级由声明顺序决定, 加载进度条与完成提示仍声明在它之后;
         * 窗口与播放栏从这里注入, 由歌词页自己去操控, 互相之间不引用对方的控件 */
        id: lyricsSubTab;
        theWindow: window;
        thePlayer: player;
        thePlayerBar: playerBar;
        theMemStorage: memStorage;
        theSidebarSpreaded: leftSidebar.spreaded;
        anchors.fill: parent;
        visible: false;
    }
    /* 加载进度条: 状态由内存枢纽的加载状态驱动 */
    Rectangle {
        id: loadingRate;
        anchors {bottom:parent.bottom; left:parent.left; right:parent.right;}
        height: 5;
        color: Define.subGrey;
        bottomLeftRadius: Define.windowRadius;
        bottomRightRadius: Define.windowRadius;
        visible: memStorage.loadingState.using;
        /* 本次加载是否已提示过完成, 避免重复弹出 */
        property bool tipShown: false;
        /* 进度填充: 宽度按枢纽里的百分比换算 */
        Rectangle {
            anchors {left:parent.left; top:parent.top; bottom:parent.bottom;}
            width: parent.width*memStorage.loadingState.value/100;
            color: Define.choseCyanColor;
            bottomLeftRadius: parent.bottomLeftRadius;
            bottomRightRadius: parent.bottomRightRadius;
        }
        /* 进度满时弹一次完成提示, 并让枢纽结束本次加载 */
        Connections {
            target: memStorage;
            function onLoadingStateChanged() {
                var st=memStorage.loadingState;
                if(st.using===false) {
                    loadingRate.tipShown=false;
                    return;
                }
                Assist.dlog("进度条","加载进度: ",st.value,"% (",st.usedByWho,")");
                if(st.value>=100 && loadingRate.tipShown===false) {
                    loadingRate.tipShown=true;
                    Assist.dlog("进度条","加载完成: ",st.finishedTip);
                    loadingTip.showTip(st.finishedTip);
                    memStorage.stopLoading(st.usedByWho);
                }
            }
        }
    }
    /* 完成提示浮层: 独立于进度条, 因此进度条收起后仍短暂可见 */
    Rectangle {
        id: loadingTip;
        anchors {bottom:loadingRate.top; bottomMargin:10; horizontalCenter:parent.horizontalCenter;}
        width: loadingTipText.width+24;
        height: 26;
        radius: 5;
        color: Define.mainAreaColor;
        border.color: Define.subGrey;
        border.width: 1;
        visible: false;
        property string tipText: "";
        function showTip(t) {
            tipText=t;
            visible=true;
            loadingTipTimer.restart();
        }
        Text {
            color: Define.textColor;
            id: loadingTipText;
            anchors.centerIn: parent;
            text: loadingTip.tipText;
            font.pixelSize: 13;
            font.weight: 400;
        }
        Timer {
            id: loadingTipTimer;
            interval: 2000;
            onTriggered: {
                loadingTip.visible=false;
                loadingTip.tipText="";
            }
        }
    }
    function subsHide(scenePos) {
        /* 歌词页盖住画布时, 它自己的菜单与播放条子面板也要按同一次点击收起 */
        if(lyricsSubTab.visible===true) {
            lyricsSubTab.subsHide(scenePos);
        }
        /* 播放栏自己的子面板由它自己判断与收起; 播放列表面板在画布层, 落点判断留在主界面 */
        playerBar.subsHide(scenePos);
        if(!Assist.hitItem(playingListArea, scenePos) && !playerBar.hitsListOpener(scenePos)) {
            playerBar.sub_hideList();
        }
        mainArea.curr.subsHide(scenePos);
    }
    /* 搜索: 交给当前页面过滤它自己的列表, 结果送进搜索结果页, 并只由搜索触发换页;
     * 已经在搜索结果页时向发起搜索的页面重新取结果, 不重复入历史栈 */
    function doSearch() {
        var kw=String(searchInput.text).trim();
        if(kw==="") {
            Assist.dwarn("界面","搜索关键字为空, 忽略");
            return false;
        }
        var page=mainArea.curr;
        if(page===undefined || page===null) {
            Assist.derror("界面","搜索失败: 当前页面不存在");
            return false;
        }
        var origin=(page===mainArea_ResultPage? mainArea_ResultPage.originPage:page);
        if(origin===null || origin===undefined) {
            Assist.derror("界面","搜索失败: 找不到发起搜索的页面");
            return false;
        }
        var list=(typeof origin.search==="function"? origin.search(kw):[]);
        Assist.dlog("界面","搜索: 页面 ",mainArea.routeKeyOf(origin),", 关键字 ",kw,", 命中 ",list.length," 条");
        mainArea_ResultPage.showResult(kw,list,origin);
        mainArea.jump2(mainArea_ResultPage);
        return true;
    }
    /* 下载结果: 队列与提示都由内存枢纽统一处理, 供首页推荐与本地和下载页共用 */
    Connections {
        target: AppNetHelper;
        function onDownloadProgress(taskKey,received,total) {
            memStorage.onDownloadProgress(taskKey,received,total);
        }
        function onDownloadFinished(taskKey,localPath) {
            memStorage.onDownloadFinished(taskKey,localPath);
        }
        function onDownloadFailed(taskKey,reason) {
            memStorage.onDownloadFailed(taskKey,reason);
        }
    }
    Connections {
        target: AppClickHelper;
        function onMousePressed(scenePos) {
            window.subsHide(scenePos);
        }
    }
    /* 元信息或清单刷新后, 让播放模块重新解析当前在线歌曲的取用地址 */
    Connections {
        target: Server;
        function onManifestUpdated() {
            player.recheckOnlineSource();
        }
    }
    Component.onCompleted: {
        Assist.dlog("界面","UI 加载成功, 开始读取程序储存");
        /* 先确定存储目录, 再读取落盘数据; 子项先于本处理器完成构建, 因此列表需在读盘后重建一次 */
        GlobalFileStorage.verifyStorageDir();
        GlobalFileStorage.load();
        /* 登录记录跟着读盘一起复核: 签名不符或已过保留期的一律在窗口显示前清掉 */
        Assist.dlog("用户","启动时复核登录记录: ",Account.refresh());
        /* 按界面偏好恢复预设主题: 只把选定主题的配色写进设计常量的内存值, 主题数据本身不改;
         * 必须在窗口显示前完成, 避免先按默认配色闪一帧 */
        Assist.dlog("界面","恢复预设主题: ",GlobalFileStorage.themeId(),", 结果 ",
                   Define.applyTheme(GlobalFileStorage.themeId()));
        /* 在线曲库先用磁盘缓存立即可用, 再在后台静默刷新, 这一过程不改界面加载状态 */
        Assist.dlog("在线","启动时恢复在线曲库缓存: ",Server.bootstrap());
        Assist.dlog("界面","恢复上次停留的页面: ",mainArea.applyStoredPage());
        mainArea_LocalPage.refresh();
        mainArea_HomePage.refresh();
        Assist.dlog("播放","恢复上次的播放状态: ",player.restoreFromState());
        window.visible=true;
        Assist.dlog("界面","窗口已显示");
    }
    Component.onDestruction: {
        /* 退出前把当前播放进度与全部数据落盘 */
        Assist.dlog("界面","窗口销毁, 退出前保存进度与全部数据");
        player.syncPlayPosition(Math.floor(player.position));
        GlobalFileStorage.save();
    }
}