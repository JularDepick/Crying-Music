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
}
