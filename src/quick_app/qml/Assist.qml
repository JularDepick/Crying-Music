pragma Singleton
import QtQuick

import AppHelper 1.0

Item {
    /* 运行期总开关: 只有命令行带 --debug 时为真, 由 C++ 侧在启动时设定 */
    function runtimeOn() {
        return (AppDebug.enabled===true);
    }
    /* 分类开关: 分类清单与各自的开关取自设计常量 Define.debugCategoryOn */
    function debugOn(category) {
        return (Define.debugCategoryOn[category]===true);
    }
    /* 常规调试输出: 运行期开关与分类开关同时为真才输出, 否则短路且参数不参与求值;
     * 统一格式为 [分类标签]<具体信息> */
    function dlog(category) {
        if(runtimeOn()===false || debugOn(category)===false) {
            return;
        }
        console.log("["+category+"]",...Array.prototype.slice.call(arguments,1));
    }
    /* 可恢复异常的调试输出: 只看分类开关, 不受运行期开关限制, 格式同 dlog */
    function dwarn(category) {
        if(debugOn(category)===false) {
            return;
        }
        console.warn("["+category+"]",...Array.prototype.slice.call(arguments,1));
    }
    /* 致命与退出路径的调试输出: 只看分类开关, 不受运行期开关限制, 格式同 dlog */
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
    /* 文件名安全化: 替换 Windows 非法字符与路径分隔符, 合并连续空白, 并限制长度 */
    function safeFileName(text) {
        var s=String(text===undefined || text===null? "":text);
        s=s.replace(/[\\/:*?"<>|]/g,"_");
        s=s.replace(/\s+/g," ");
        s=s.trim();
        if(s.length>80) {
            s=s.substring(0,80);
        }
        return s;
    }
    /* 按命名模板拼下载文件名: 扩展名沿用在线文件名, 去掉首尾的分隔符,
     * 结果为空时回退到在线文件名本身, 再空则用 online */
    function composeDownloadName(template,songname,singer,onlineId) {
        var id=String(onlineId===undefined? "":onlineId);
        var tag=String(Define.onlineKeyTag);
        if(id.indexOf(tag)===0) {
            id=id.substring(tag.length);
        }
        var dot=id.lastIndexOf(".");
        var ext=(dot>0? id.substring(dot):"");
        var tpl=(typeof template==="string" && template!==""? template:Define.downloadNameTemplate);
        var base=tpl.replace(/\{songname\}/g,safeFileName(songname))
                    .replace(/\{singer\}/g,safeFileName(singer));
        base=safeFileName(base);
        base=base.replace(/^[\s_.\-]+/,"").replace(/[\s_.\-]+$/,"");
        if(base==="") {
            base=safeFileName(dot>0? id.substring(0,dot):id);
        }
        if(base==="") {
            base="online";
        }
        return base+ext;
    }
    /* 关键字搜索: 预处理, 精确与模糊召回, 计分去重与排序全部交给 C++ 匹配算法,
     * 这里只把候选的三个字段递过去, 再按返回的下标把命中条目映射回原数组,
     * 保持条目引用不变, 因此结果页与来源页共用同一批条目对象 */
    function searchList(keyword,list) {
        var v=(Array.isArray(list)? list:[]);
        var cand=[];
        for(var i=0;i<v.length;i++) {
            cand.push({"songname": v[i]["songname"],
                       "singer": v[i]["singer"],
                       "path": v[i]["absfpath"]});
        }
        var r=AppSearchHelper.search(String(keyword===undefined || keyword===null? "":keyword),cand);
        var idx=r["indices"];
        var res=[];
        for(var j=0;j<idx.length;j++) {
            res.push(v[idx[j]]);
        }
        dlog("列表","搜索: 关键字 ",r["query"],", 长度 ",r["len"],", 模式 ",r["mode"],
             ", 精确 ",r["exact"],", 模糊 ",r["fuzzy"],", 命中 ",res.length);
        return res;
    }
    /* 颜色转 #RRGGBB 文本: 供富文本着色时使用 */
    function hexOf(c) {
        var r=Math.max(0,Math.min(255,Math.round(c.r*255)));
        var g=Math.max(0,Math.min(255,Math.round(c.g*255)));
        var b=Math.max(0,Math.min(255,Math.round(c.b*255)));
        var t=((1<<24)+(r<<16)+(g<<8)+b).toString(16);
        return "#"+t.substring(1);
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