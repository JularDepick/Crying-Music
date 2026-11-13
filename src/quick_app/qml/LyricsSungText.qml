import QtQuick
import QtQuick.Effects

/* 单行歌词的逐字进度显示: 底层按未唱色画整行, 上层用同一份文本与同一套排版换成已唱色,
 * 露出多少由遮罩按像素决定, 因此边界可以停在字的中间而不是整字跳变.
 * 歌词页与桌面悬浮歌词共用这一份实现; 断行与遮罩几何依赖调用方的列宽与文本度量,
 * 由调用方算好后经 layout 与 maskGeom 传入, 本组件只负责画 */
Item {
    id: root;
    /* 整行文本 */
    property string text: "";
    /* 字号与字重 */
    property int pixelSize: 16;
    property bool bold: false;
    /* 未唱色与已唱色 */
    property color baseColor: "#434343";
    property color sungColor: "#00cc65";
    /* 水平对齐与换行: 两处调用都居中, 换行由调用方按自己的版式决定 */
    property int alignment: Text.AlignHCenter;
    property int wrapMode: Text.Wrap;
    /* 断行与逐字宽度: 调用方按自己的列宽算出, 形如歌词页 sungLayoutOf 的返回值 */
    property var layout: null;
    /* 遮罩几何: {"ready":bool, "top":real, "width":real, "row":real}, 调用方按当前进度算出 */
    property var maskGeom: null;
    /* 是否显示逐字进度: 为假时只画未唱层 */
    property bool progressEnabled: true;
    /* 文本的真实行数: 供调用方核对自算断行是否与 Text 一致 */
    readonly property int textLineCount: baseText.lineCount;
    /* 遮罩是否可用: 进度关闭或几何还没算好时, 已唱层整层不出现 */
    readonly property bool maskReady: (root.progressEnabled===true
                                       && root.maskGeom!==null
                                       && root.maskGeom["ready"]===true);
    implicitWidth: baseText.width;
    implicitHeight: baseText.height;
    /* 底色层: 整行按未唱色画一遍 */
    Text {
        id: baseText;
        width: root.width;
        text: root.text;
        horizontalAlignment: root.alignment;
        wrapMode: root.wrapMode;
        font.pixelSize: root.pixelSize;
        font.bold: root.bold;
        color: root.baseColor;
    }
    /* 已唱层: 同一份文本, 同一套排版, 只换颜色; 露出多少由遮罩按像素决定 */
    Text {
        id: sungText;
        anchors.fill: baseText;
        horizontalAlignment: baseText.horizontalAlignment;
        wrapMode: baseText.wrapMode;
        text: baseText.text;
        font: baseText.font;
        color: root.sungColor;
        visible: root.maskReady;
        layer.enabled: visible;
        layer.effect: MultiEffect {
            maskEnabled: true;
            maskSource: sungMask;
        }
    }
    /* 遮罩: 已唱到的可视行整块铺白, 当前行只铺到边界, 其余透明;
     * 遮罩不可见, 只作为纹理供 MultiEffect 取用 */
    Item {
        id: sungMask;
        anchors.fill: baseText;
        visible: false;
        layer.enabled: true;
        Rectangle {
            color: "white";
            x: 0;
            y: 0;
            width: sungMask.width;
            height: (root.maskReady===true? root.maskGeom["top"]:0);
        }
        Rectangle {
            color: "white";
            x: 0;
            y: (root.maskReady===true? root.maskGeom["top"]:0);
            width: (root.maskReady===true? root.maskGeom["width"]:0);
            height: (root.maskReady===true? root.maskGeom["row"]:0);
        }
    }
}
