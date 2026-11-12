import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import "./"

/* 就地二次确认按钮: 空闲态显示正常文案或图标, 第一次点击只进入确认态,
 * 确认态内 timeoutMs 内再次点击才发出 confirmed(), 超时, 外部复位或按钮隐藏都回到空闲态;
 * 组件只负责确认态的显示与计时, 不做任何业务判断 */
CustomButtonA {
    id: root;
    /* 空闲态文案: 空串时只显示图标 */
    property string label: "";
    /* 确认态文案: 空串时沿用空闲态文案, 只换颜色 */
    property string confirmLabel: "";
    /* 确认态持续时长(毫秒): 超时自动回到空闲态 */
    property int timeoutMs: Define.confirmTimeoutMs;
    /* 确认态状态: 外部置 false 即复位, 置 true 即进入确认态 */
    property bool confirming: false;
    /* 双击防穿透窗口(毫秒): 首击之后这段时间内的第二次点击一律忽略, 否则连点两下就是
     * "进入确认态 + 执行"; 取值优先用平台的双击间隔, 取不到时回退 400, 不改 3 秒确认窗口 */
    property int doubleClickGuardMs: 400;
    /* 上一次被采纳的点击时刻(毫秒时间戳) */
    property real _lastClickMs: 0;
    /* 空闲态底色与悬停底色: 确认态沿用同一套底色, 只把文字, 图标与边框换成警示色 */
    property color idleColor: Define.hoverDarkColor;
    property color idleHoverColor: Define.choseDarkColor;
    /* 确认态的警示色: 取全局设计常量, 不另造色值 */
    property color warnColor: Define.warnRed;
    /* 圆角与空闲态边框: 确认态强制显示 1 像素警示色边框 */
    property int cornerRadius: 15;
    property int idleBorderWidth: 0;
    property color idleBorderColor: Define.subGrey;
    /* 图标边长: 与批量按钮的图标共用同一个设计常量 */
    property int iconSize: Define.batchIconSize;
    /* 文案字号: 缺省取设置页与账户页那档按钮字号 */
    property int fontSize: 13;
    /* 是否为图标形态: 有图标源即图标形态, 确认态保留图标并显示确认文案 */
    readonly property bool iconForm: (String(icon.source)!=="");
    /* 当前应显示的文案 */
    readonly property string shownLabel: (confirming===true? (confirmLabel!==""? confirmLabel:label):label);
    signal confirmed();
    /* 复位到空闲态: 供外部在面板关闭或列表变化时调用 */
    function reset() {
        confirming=false;
    }
    /* 第一次点击进入确认态, 确认态内再次点击才发出 confirmed();
     * 双击间隔内的第二次点击是误触, 直接忽略, 确认态与计时都不动 */
    onClicked: {
        var now=Date.now();
        if(confirming===true) {
            if(now-root._lastClickMs<root.doubleClickGuardMs) {
                return;
            }
            root._lastClickMs=now;
            confirming=false;
            confirmed();
            return;
        }
        root._lastClickMs=now;
        confirming=true;
    }
    Component.onCompleted: {
        var iv=0;
        try {
            iv=Number(Qt.styleHints.mouseDoubleClickInterval);
        } catch(e) {
            iv=0;
        }
        if(isNaN(iv)!==true && iv>0) {
            root.doubleClickGuardMs=iv;
        }
    }
    /* 按钮不可见时立即回到空闲态 */
    onVisibleChanged: {
        if(visible!==true) {
            confirming=false;
        }
    }
    /* 确认态计时: 进入时重新计时, 复位时停表 */
    onConfirmingChanged: {
        if(confirming===true) {
            confirmTimer.restart();
        } else {
            confirmTimer.stop();
        }
    }
    Timer {
        id: confirmTimer;
        interval: root.timeoutMs;
        repeat: false;
        onTriggered: {
            root.confirming=false;
        }
    }
    contentItem: Item {
        Row {
            anchors.centerIn: parent;
            spacing: 5;
            ColorImage {
                anchors.verticalCenter: parent.verticalCenter;
                visible: root.iconForm;
                width: root.iconSize;
                height: root.iconSize;
                source: root.icon.source;
                color: (root.confirming===true? root.warnColor
                                              :(root.hovered===true? Define.btnHoverColor:Define.btnIconColor));
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter;
                visible: (root.shownLabel!=="");
                text: root.shownLabel;
                font.pixelSize: root.fontSize;
                color: (root.confirming===true? root.warnColor:Define.textColor);
            }
        }
    }
    background: Rectangle {
        anchors.fill: parent;
        radius: root.cornerRadius;
        color: (root.hovered===true? root.idleHoverColor:root.idleColor);
        border.width: (root.confirming===true? Math.max(1,root.idleBorderWidth):root.idleBorderWidth);
        border.color: (root.confirming===true? root.warnColor:root.idleBorderColor);
    }
}
