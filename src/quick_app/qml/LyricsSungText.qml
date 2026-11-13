import QtQuick
import QtQuick.Effects

/* 单行歌词的逐字进度显示: 底层按未唱色画整行, 上层用同一份文本与同一套排版换成已唱色,
 * 露出多少由遮罩按像素决定, 因此边界可以停在字的中间而不是整字跳变.
 * 歌词页与桌面悬浮歌词共用这一份实现.
 * 断行与遮罩在这里按需重算, 不走绑定: 逐字测量会写共享的度量对象, 放在绑定里会互相失效,
 * 表现为 layout / sungLayout 的绑定循环告警, 换行时也会明显卡顿.
 * 只有当前行参与测量, 其它行不量也不遮罩 */
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
    /* 是否显示逐字进度: 为假时只画未唱层 */
    property bool progressEnabled: true;
    /* 注入: 提供断行与遮罩算法的歌词页, 需实现 sungLayoutOf 与 sungMaskOf */
    property var measurer: null;
    /* 注入: 当前行的歌词数据(含词级时间戳与首段偏移), 为空表示不做逐字着色 */
    property var lineData: null;
    /* 注入: 当前词下标与当前词的推进比例 */
    property int currentWord: -1;
    property real wordProgress: 0;
    /* 注入: 这一行是否就是当前播放行 */
    property bool isCurrent: false;
    /* 断行结果与遮罩几何: 由下面的重算函数写入, 外部只读 */
    property var layout: null;
    property var maskGeom: null;
    /* 文本的真实行数: 供自算断行核对 */
    readonly property int textLineCount: baseText.lineCount;
    /* 遮罩是否可用: 进度关闭或几何还没算好时, 已唱层整层不出现 */
    readonly property bool maskReady: (root.progressEnabled===true
                                       && root.maskGeom!==null
                                       && root.maskGeom["ready"]===true);
    /* 文本实际占用的宽度: 不换行时可能比控件宽, 调用方据此做水平滚动 */
    readonly property real contentWidth: baseText.width;
    implicitWidth: baseText.width;
    implicitHeight: baseText.height;

    /* 断行重算: 只在文本, 字号, 字重, 列宽或"是否当前行"变化时调用 */
    function refreshLayout() {
        if(root.isCurrent!==true || root.measurer===null || root.measurer===undefined) {
            root.layout=null;
            root.maskGeom=null;
            return;
        }
        /* 列宽取文本实际宽度: 不换行时文本比控件宽, 用控件宽度会算成多行, 与 Text 的行数对不上 */
        root.layout=root.measurer.sungLayoutOf(root.text,root.pixelSize,root.bold,baseText.width);
        root.refreshMask();
    }
    /* 遮罩重算: 逐字进度变化时只走这一步, 不重排文本 */
    function refreshMask() {
        if(root.isCurrent!==true || root.layout===null
           || root.measurer===null || root.measurer===undefined) {
            root.maskGeom=null;
            return;
        }
        root.maskGeom=root.measurer.sungMaskOf(root.layout,root.lineData,root.textLineCount);
    }
    onTextChanged: refreshLayout();
    onPixelSizeChanged: refreshLayout();
    onBoldChanged: refreshLayout();
    onWidthChanged: refreshLayout();
    onMeasurerChanged: refreshLayout();
    onLineDataChanged: refreshLayout();
    onIsCurrentChanged: refreshLayout();
    onTextLineCountChanged: refreshMask();
    onCurrentWordChanged: refreshMask();
    onWordProgressChanged: refreshMask();
    Component.onCompleted: refreshLayout();

    /* 底色层: 整行按未唱色画一遍 */
    Text {
        id: baseText;
        /* 不换行时按文本自然宽度铺开(可能超出控件), 换行时按控件宽度排版 */
        width: (root.wrapMode===Text.NoWrap? Math.max(root.width,baseText.implicitWidth):root.width);
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
