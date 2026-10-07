pragma Singleton
import QtQuick

Item {
    property var localScan:
    ({
        singleFiles: [],
        scanDirs: [],
        scanFmts: [],
        scanRadio: 0,
        excludedFiles: [],
        likedFiles: []
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
        var vg=localScan.singleFiles;
        var lg=vg.length;
        var newvg=[];
        for(var i=0;i<lg;i++) {
            if(hasPath(absfpaths,vg[i])===false) {
                newvg.push(vg[i]);
            }
        }
        localScan.singleFiles=newvg;
        var ls=absfpaths.length;
        var newe=localScan.excludedFiles.slice();
        for(var j=0;j<ls;j++) {
            if(hasPath(newe,absfpaths[j])===false) {
                newe.push(absfpaths[j]);
            }
        }
        localScan.excludedFiles=newe;
    }
    /* 解除单个路径的移除标记 */
    function removeExclude(absfpath) {
        var ve=localScan.excludedFiles;
        var le=ve.length;
        var newve=[];
        for(var i=0;i<le;i++) {
            if(ve[i]!==absfpath) {
                newve.push(ve[i]);
            }
        }
        localScan.excludedFiles=newve;
    }
    /* 判断路径是否已被移除 */
    function isExcluded(absfpath) {
        return hasPath(localScan.excludedFiles,absfpath);
    }
    /* 设置喜欢状态 */
    function setLiked(absfpath,on) {
        var vl=localScan.likedFiles;
        var ll=vl.length;
        var newvl=[];
        for(var i=0;i<ll;i++) {
            if(vl[i]!==absfpath) {
                newvl.push(vl[i]);
            }
        }
        if(on===true) {
            newvl.push(absfpath);
        }
        localScan.likedFiles=newvl;
    }
    /* 判断路径是否已喜欢 */
    function isLiked(absfpath) {
        return hasPath(localScan.likedFiles,absfpath);
    }
}
