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
        if(mm>=60) {
            console.error("出现错误: 音频长度达到一小时上限!");
            return "00:00";
        }
        var res="";
        if(mm<10) {
            res+="0";
        }
        res+=String(mm)+":";
        if(ss<10) {
            res+="0";
        }
        res+=String(ss);
        return res;
    }
}