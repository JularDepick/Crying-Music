pragma Singleton
import QtQuick

Item {
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
            console.warn(`警告: 出现超出常规范围的音频时长 ${res} !`);
        }
        return res;
    }
    /* 判断场景坐标是否落在某个可见项的矩形内 */
    function hitItem(item, scenePos) {
        if(item===null || !item.visible || scenePos===undefined) {
            return false;
        }
        var p=item.mapFromItem(null, scenePos.x, scenePos.y);
        return (p.x>=0 && p.y>=0 && p.x<=item.width && p.y<=item.height);
    }
}