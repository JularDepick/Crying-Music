pragma Singleton
import QtQuick

Item {
    /* 调试输出的分类清单与开关取自设计常量 Define.debugCategoryOn */
    function debugOn(category) {
        return (Define.debugCategoryOn[category]===true);
    }
    /* 调试输出: 该分类关闭时直接短路, 参数不参与求值;
     * 统一格式为 [分类标签]<具体信息> */
    function dlog(category) {
        if(debugOn(category)===false) {
            return;
        }
        console.log("["+category+"]",...Array.prototype.slice.call(arguments,1));
    }
    /* 可恢复异常的调试输出, 分类开关与格式同 dlog */
    function dwarn(category) {
        if(debugOn(category)===false) {
            return;
        }
        console.warn("["+category+"]",...Array.prototype.slice.call(arguments,1));
    }
    /* 致命与退出路径的调试输出, 分类开关与格式同 dlog */
    function derror(category) {
        if(debugOn(category)===false) {
            return;
        }
        console.error("["+category+"]",...Array.prototype.slice.call(arguments,1));
    }
    /* 秒数转 mm:ss 文本, 非正数按 00:00 处理 */
    function int2mmss(num) {
        num=Math.floor(num);
        if(num<=0) {
            return "00:00";
        }
        var ss=num%60;
        var mm=Math.floor(num/60);
        var res="";
        if(mm<10) {
            res+="0";
        }
        res+=String(mm)+":";
        if(ss<10) {
            res+="0";
        }
        res+=String(ss);
        if(mm>=60) {
            dwarn("播放","警告: 出现超出常规范围的音频时长",res,"!");
        }
        return res;
    }
    /* 字节数转带单位的可读文本, 保留两位小数; 非正数视为读取失败 */
    function fileSize2text(bytes) {
        if(!(bytes>0)) {
            return "--";
        }
        var units=["B","KB","MB","GB","TB"];
        var v=bytes;
        var i=0;
        while(v>=1024 && i<units.length-1) {
            v=v/1024;
            i=i+1;
        }
        return (i===0? String(bytes)+" B":v.toFixed(2)+" "+units[i]);
    }
    /* 命中判定: 场景坐标是否落在该可见项的矩形内 */
    function hitItem(item, scenePos) {
        if(item===null || !item.visible || scenePos===undefined) {
            return false;
        }
        var p=item.mapFromItem(null, scenePos.x, scenePos.y);
        return (p.x>=0 && p.y>=0 && p.x<=item.width && p.y<=item.height);
    }
}