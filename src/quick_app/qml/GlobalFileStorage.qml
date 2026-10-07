pragma Singleton
import QtQuick

import "./"

Item {
    property var localScan:
    ({
        singleFiles: [],
        scanDirs: [],
        scanFmts: [],
        scanRadio: 0,
        excludedFiles: []
    });
    /* 与 localScan 相独立的歌曲路径列表, 只存内存 */
    property var likedFiles: [];
    property var recentFiles: [];
    /* 音频元数据缓存: 标准化路径 -> {duration:秒, title:曲名, artist:歌手}, 只存内存 */
    property var metaCache: ({});
    /* 播放状态枢纽: 播放队列, 当前播放项路径与下标, 播放顺序; 跨模块只经此处交换 */
    property var playState:
    ({
        sortlist: [],
        playingWhich: "",
        playingIndex: -1,
        playMode: 1
    });
    /* 加载进度枢纽: 供各模块共用的加载反馈, 同一时刻只服务一个使用者 */
    property var loadingState:
    ({
        using: false,
        value: 0,
        finishedTip: "",
        usedByWho: ""
    });
    function load() {
    }
    function save() {
    }
    function setMALocalP(a,b,c) {
        localScan.scanDirs=a;
        localScan.scanFmts=b;
        localScan.scanRadio=c;
    }
    /* 判断列表中是否含有指定路径 */
    function hasPath(list,absfpath) {
        var l=list.length;
        for(var i=0;i<l;i++) {
            if(list[i]===absfpath) {
                return true;
            }
        }
        return false;
    }
    /* 从列表中剔除指定路径, 返回新列表 */
    function removePaths(list,absfpaths) {
        var l=list.length;
        var res=[];
        for(var i=0;i<l;i++) {
            if(hasPath(absfpaths,list[i])===false) {
                res.push(list[i]);
            }
        }
        return res;
    }
    /* 在列表中添加或移除单个路径, 返回新列表 */
    function setPath(list,absfpath,on) {
        var res=removePaths(list,[absfpath]);
        if(on===true) {
            res.push(absfpath);
        }
        return res;
    }
    /* 添加手动歌曲: 去重写入, 并解除这些路径的移除标记 */
    function addSingleFiles(files) {
        var vg=localScan.singleFiles;
        var ls=files.length;
        var newvg=vg.slice();
        for(var i=0;i<ls;i++) {
            var one=files[i];
            if(one===undefined || one==="") {
                continue;
            }
            if(hasPath(newvg,one)===false) {
                newvg.push(one);
            }
            removeExclude(one);
        }
        localScan.singleFiles=newvg;
    }
    /* 移除歌曲: 手动添加项直接移除, 扫描得到的项记为移除项 */
    function removeSongs(absfpaths) {
        localScan.singleFiles=removePaths(localScan.singleFiles,absfpaths);
        var newe=localScan.excludedFiles.slice();
        var ls=absfpaths.length;
        for(var i=0;i<ls;i++) {
            if(hasPath(newe,absfpaths[i])===false) {
                newe.push(absfpaths[i]);
            }
        }
        localScan.excludedFiles=newe;
    }
    /* 解除单个路径的移除标记 */
    function removeExclude(absfpath) {
        localScan.excludedFiles=removePaths(localScan.excludedFiles,[absfpath]);
    }
    /* 判断路径是否已被移除 */
    function isExcluded(absfpath) {
        return hasPath(localScan.excludedFiles,absfpath);
    }
    /* 设置喜欢状态 */
    function setLiked(absfpath,on) {
        likedFiles=setPath(likedFiles,absfpath,on);
    }
    /* 判断路径是否已喜欢 */
    function isLiked(absfpath) {
        return hasPath(likedFiles,absfpath);
    }
    /* 批量取消喜欢 */
    function removeLiked(absfpaths) {
        likedFiles=removePaths(likedFiles,absfpaths);
    }
    /* 记录最近播放: 去重后最新在前, 超出上限丢弃最旧 */
    function addRecent(absfpath) {
        if(absfpath===undefined || absfpath==="") {
            return;
        }
        var v=[absfpath];
        var l=recentFiles.length;
        for(var i=0;i<l;i++) {
            if(recentFiles[i]!==absfpath) {
                v.push(recentFiles[i]);
            }
        }
        while(v.length>Define.recentListSize) {
            v.pop();
        }
        recentFiles=v;
    }
    /* 批量移除最近播放记录 */
    function removeRecent(absfpaths) {
        recentFiles=removePaths(recentFiles,absfpaths);
    }
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
    /* 写入播放状态: 整体替换对象, 使各模块都能收到变更通知 */
    function setPlayState(list,which,index,mode) {
        playState=({"sortlist":list,"playingWhich":which,"playingIndex":index,"playMode":mode});
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
}
