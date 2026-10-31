import QtQuick
import QtQuick.Controls

import AppHelper 1.0

import "./"

MainAreaFatherPage {
    id: mainArea_SettingsPage;
    visible: false;
    /* 命名模板的编辑草稿: 失焦或点保存时写回存储的界面偏好 */
    property string draft: GlobalFileStorage.downloadNameTemplate();
    /* 用清单里的第一首做示例, 清单未就绪时用占位示例 */
    function previewName() {
        var rows=Server.manifestRows();
        var loaded=(Server.loadState===2 && rows.length>0);
        var song=(loaded? String(rows[0]["songname"]):"示例歌曲");
        var singer=(loaded? Server.singersText(rows[0]["singers"]):"示例歌手");
        var ext=".mp3";
        var id="demo.mp3";
        if(loaded) {
            id=String(rows[0]["filename"]);
            var dot=id.lastIndexOf(".");
            if(dot>0) {
                ext=id.substring(dot);
                id="demo"+ext;
            }
        }
        var name=Assist.composeDownloadName(draft,song,singer,id);
        return name;
    }
    /* 写回命名模板: 空值由存储回落到默认值 */
    function saveTemplate() {
        GlobalFileStorage.setDownloadNameTemplate(draft);
        draft=GlobalFileStorage.downloadNameTemplate();
        Assist.dlog("界面","下载文件命名模板: ",draft);
    }
    /* 恢复默认模板并立即保存 */
    function resetTemplate() {
        draft=Define.downloadNameTemplate;
        saveTemplate();
    }
    Column {
        anchors {left:parent.left; right:parent.right; top:parent.top;}
        anchors.leftMargin: 40;
        anchors.rightMargin: 40;
        topPadding: 40;
        spacing: 15;
        Text {
            text: "设置";
            font.pixelSize: 32;
            font.weight: 700;
        }
        Rectangle {
            width: parent.width-parent.leftMargin-parent.rightMargin;
            height: 1;
            color: Define.subGrey;
        }
        Text {
            text: "下载文件命名";
            font.pixelSize: 15;
            font.weight: 500;
        }
        Text {
            text: "下载在线歌曲时按该模板生成文件名, 可用占位符 {songname} 与 {singer}; 非法字符会自动替换为下划线";
            font.pixelSize: 13;
            color: Define.btnIconColor;
            wrapMode: Text.WordWrap;
            width: parent.width-parent.leftMargin-parent.rightMargin;
        }
        Row {
            spacing: 10;
            TextField {
                id: templateInput;
                width: 320;
                height: 30;
                text: mainArea_SettingsPage.draft;
                placeholderText: Define.downloadNameTemplate;
                selectByMouse: true;
                font.pixelSize: 13;
                background: Rectangle {
                    color: "#d5d5d5";
                    radius: 8;
                }
                onTextChanged: {
                    mainArea_SettingsPage.draft=text;
                }
                onEditingFinished: {
                    mainArea_SettingsPage.saveTemplate();
                }
            }
            CustomButtonA {
                id: saveTemplateBtn;
                width: 70;
                height: 30;
                transEnabled: false;
                background: Rectangle {
                    anchors.fill: parent;
                    radius: 15;
                    color: (parent.hovered? Define.choseDarkColor:Define.hoverDarkColor);
                    Text {
                        anchors.centerIn: parent;
                        text: "保存";
                        font.pixelSize: 13;
                    }
                }
                onClicked: {
                    mainArea_SettingsPage.saveTemplate();
                }
            }
            CustomButtonA {
                id: resetTemplateBtn;
                width: 90;
                height: 30;
                transEnabled: false;
                background: Rectangle {
                    anchors.fill: parent;
                    radius: 15;
                    color: (parent.hovered? Define.choseDarkColor:Define.hoverDarkColor);
                    Text {
                        anchors.centerIn: parent;
                        text: "恢复默认";
                        font.pixelSize: 13;
                    }
                }
                onClicked: {
                    mainArea_SettingsPage.resetTemplate();
                }
            }
        }
        Text {
            text: "示例: "+mainArea_SettingsPage.previewName();
            font.pixelSize: 13;
            color: Define.btnIconColor;
        }
        Rectangle {
            width: parent.width-parent.leftMargin-parent.rightMargin;
            height: 1;
            color: Define.subGrey;
        }
        Text {
            text: "下载目录: "+(GlobalFileStorage.downloadsDir()===""? "(存储目录未确定)":AppFileHelper.clearPath(GlobalFileStorage.downloadsDir()));
            font.pixelSize: 13;
            color: Define.btnIconColor;
            wrapMode: Text.WordWrap;
            width: parent.width-parent.leftMargin-parent.rightMargin;
        }
    }
    function subsHide(scenePos) {
    }
    function refresh() {
        draft=GlobalFileStorage.downloadNameTemplate();
    }
}
