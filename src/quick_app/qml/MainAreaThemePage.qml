import QtQuick
import "./"

/* 主题页: 展示 Theme 里的预设配色, 点选即把配色写进 Define 的内存值并记为界面偏好;
 * 本页只读 Theme 的数据, 不修改它 */
MainAreaFatherPage {
    id: mainArea_ThemePage;
    visible: false;
    /* 当前生效的预设: 读存储偏好, 换肤后偏好变化会带着刷新选中态 */
    readonly property string currentId: GlobalFileStorage.themeId();
    /* 点选预设: 先校验主题存在, 再把配色写进 Define 的内存值, 最后把主题 id 记为界面偏好;
     * 主题不存在时什么都不改, 避免配色与偏好不一致 */
    function chooseTheme(id) {
        if(Theme.presetById(id)===null) {
            Assist.dwarn("界面","切换预设主题失败: 未知主题 ",id);
            return false;
        }
        if(Define.applyTheme(id)!==true) {
            return false;
        }
        var saved=GlobalFileStorage.setThemeId(id);
        Assist.dlog("界面","切换预设主题: ",id,", 落盘结果 ",saved);
        return (saved===true);
    }
    Column {
        anchors {left:parent.left; right:parent.right; top:parent.top;}
        anchors.leftMargin: 40;
        anchors.rightMargin: 40;
        topPadding: 40;
        spacing: 14;
        Text {
            color: Define.textColor;
            text: "主题";
            font.pixelSize: 32;
            font.weight: 700;
        }
        Rectangle {
            width: parent.width;
            height: 1;
            color: Define.subGrey;
        }
        Text {
            text: "选择一套预设配色, 立即生效并记为界面偏好; 应用启动时按该偏好恢复配色";
            font.pixelSize: 13;
            color: Define.btnIconColor;
            wrapMode: Text.WordWrap;
            width: parent.width;
        }
        Flow {
            id: themeFlow;
            width: parent.width;
            spacing: 16;
            Repeater {
                model: Theme.presets;
                delegate: Rectangle {
                    id: themeCard;
                    property var preset: modelData;
                    property bool isCurrent: (mainArea_ThemePage.currentId===String(preset["id"]));
                    width: 220;
                    height: 104;
                    radius: 12;
                    color: String(preset["colors"]["mainAreaColor"]);
                    border.width: (isCurrent? 2:1);
                    border.color: (isCurrent? Define.choseCyanColor:String(preset["colors"]["subGrey"]));
                    MouseArea {
                        id: cardMouse;
                        anchors.fill: parent;
                        hoverEnabled: true;
                        cursorShape: Qt.PointingHandCursor;
                        onClicked: {
                            mainArea_ThemePage.chooseTheme(themeCard.preset["id"]);
                        }
                    }
                    /* 悬停时叠一层当前主题的浅色, 选中与否只由边框表达 */
                    Rectangle {
                        anchors.fill: parent;
                        radius: themeCard.radius;
                        color: Define.hoverDarkColor;
                        opacity: (cardMouse.containsMouse? 0.3:0);
                        Behavior on opacity { NumberAnimation { duration: 120; } }
                    }
                    Row {
                        anchors {left:parent.left; right:parent.right; verticalCenter:parent.verticalCenter;}
                        anchors.margins: 14;
                        spacing: 14;
                        /* 迷你色板: 底色, 悬停底色, 强调色三层 */
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter;
                            width: 56;
                            height: 56;
                            radius: 10;
                            color: String(themeCard.preset["colors"]["canvasColor"]);
                            Column {
                                anchors.fill: parent;
                                anchors.margins: 7;
                                spacing: 3;
                                Rectangle {
                                    width: parent.width;
                                    height: 11;
                                    radius: 4;
                                    color: String(themeCard.preset["colors"]["mainAreaColor"]);
                                }
                                Rectangle {
                                    width: parent.width;
                                    height: 11;
                                    radius: 4;
                                    color: String(themeCard.preset["colors"]["hoverDarkColor"]);
                                }
                                Rectangle {
                                    width: parent.width*0.62;
                                    height: 11;
                                    radius: 4;
                                    color: String(themeCard.preset["colors"]["btnHoverColor"]);
                                }
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter;
                            spacing: 6;
                            Text {
                                text: String(themeCard.preset["label"]);
                                font.pixelSize: 15;
                                font.weight: 500;
                                color: String(themeCard.preset["colors"]["btnIconColor"]);
                            }
                            Text {
                                text: (themeCard.isCurrent? "使用中":"点击切换");
                                font.pixelSize: 12;
                                color: (themeCard.isCurrent? Define.choseCyanColor
                                                            :String(themeCard.preset["colors"]["forbdDarkColor"]));
                            }
                        }
                    }
                }
            }
        }
    }
}
