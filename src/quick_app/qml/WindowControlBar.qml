import QtQuick
import "./"

/* 右上角窗口操控栏: 顶栏与歌词页各放一份副本, 两处都能操控同一个窗口.
 * 行内几何按顶栏的行参数硬编码, 使用方只负责给整行定位;
 * 画中画按钮的状态由窗口持有, 本组件只做镜像, 因此两份副本的显示始终一致 */
Row {
    id: root;
    /* 被操控的窗口, 由使用方注入 */
    property var theWindow: null;
    /* 行上边距, 行高与右侧留白: 供使用方按同一条基准定位, 也用于与顶栏的对齐 */
    readonly property int rowsTopMargin: 10;
    readonly property int rowsHeight: 30;
    readonly property int rowsRightPadding: 20;
    height: rowsHeight;
    spacing: Define.btnSpacing;
    rightPadding: rowsRightPadding;
    TopNavBarButton {
        id: flowCardWinBtn;
        icon.source: "qrc:/assets/iconfont/topnavbar/flowized.svg";
        icon.color: (((hovered&&hoverColorEnabled)||showed)? Define.btnHoverColor:Define.btnIconColor);
        /* 画中画占位: 状态由窗口持有, 这里保留本地变量并镜像窗口状态, 保持状态链可被各处引用 */
        property bool showed: (root.theWindow!==null && root.theWindow.flowCardShowed);
        Connections {
            target: root.theWindow;
            function onFlowCardShowedChanged() {
                if(root.theWindow!==null && flowCardWinBtn.showed!==root.theWindow.flowCardShowed) {
                    flowCardWinBtn.showed=root.theWindow.flowCardShowed;
                }
            }
        }
        onClicked: {
            /* 画中画窗口尚未实现: 首次点击先隐藏主窗口, 与顶栏原有的占位行为一致 */
            if(!showed && root.theWindow!==null) {
                root.theWindow.hide();
            }
            showed=!showed;
            if(root.theWindow!==null) {
                root.theWindow.flowCardShowed=showed;
            }
        }
    }
    TopNavBarButton {
        id: minWindowBtn;
        icon.source: "qrc:/assets/iconfont/topnavbar/minimized.svg";
        onClicked: {
            if(root.theWindow!==null) {
                root.theWindow.showMinimized();
            }
        }
    }
    TopNavBarButton {
        id: maxWindowBtn;
        icon.source: ((root.theWindow!==null && root.theWindow.visibility===Window.Maximized)
                      ? "qrc:/assets/iconfont/topnavbar/normalized.svg"
                      : "qrc:/assets/iconfont/topnavbar/maximized.svg");
        onClicked: {
            if(root.theWindow===null) {
                return;
            }
            if(root.theWindow.visibility!==Window.Maximized) {
                root.theWindow.showMaximized();
            } else {
                root.theWindow.showNormal();
            }
        }
    }
    TopNavBarButton {
        id: closeWindowBtn;
        icon.source: "qrc:/assets/iconfont/topnavbar/closewin.svg";
        onClicked: {
            if(root.theWindow!==null) {
                root.theWindow.hide();
            }
        }
    }
}
