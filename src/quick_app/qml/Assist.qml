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
}