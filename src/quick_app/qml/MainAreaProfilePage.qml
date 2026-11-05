import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic
import "./"

/* 用户页: 邮箱验证码登录, 无需注册
 * 未登录时给出发送验证码与校验验证码的表单; 已登录时展示头像, 邮箱, 登录时间与到期时间.
 * 登录状态由 Account 单例持有, 本页只负责输入与显示, 不自行读写落盘记录 */
MainAreaFatherPage {
    id: mainArea_ProfilePage;
    visible: false;

    /* 把毫秒时刻格式化为 yyyy-MM-dd HH:mm:ss+HH:mm, 时区偏移取自本机 */
    function pad2(n) {
        return (n<10? "0"+String(n):String(n));
    }
    function stampOf(ms) {
        if(!(ms>0)) {
            return "--";
        }
        var d=new Date(ms);
        var off=-d.getTimezoneOffset();
        var abs=Math.abs(off);
        return String(d.getFullYear())+"-"+pad2(d.getMonth()+1)+"-"+pad2(d.getDate())+" "
             + pad2(d.getHours())+":"+pad2(d.getMinutes())+":"+pad2(d.getSeconds())
             + (off>=0? "+":"-")+pad2(Math.floor(abs/60))+":"+pad2(abs%60);
    }
    /* 剩余天数: 已过期时为 0 */
    function leftDays() {
        if(!(Account.expireAt>0)) {
            return 0;
        }
        var ms=Account.expireAt-Account.nowMs;
        return (ms>0? Math.ceil(ms/86400000):0);
    }
    /* 累计听歌时长: 按时分秒格式化, 不足一小时只给分秒 */
    function listenStamp(totalSeconds) {
        var sec=Math.floor(Number(totalSeconds));
        if(!(sec>0)) {
            return "0 秒";
        }
        var h=Math.floor(sec/3600);
        var m=Math.floor((sec%3600)/60);
        var s=sec%60;
        if(h>0) {
            return String(h)+" 小时 "+String(m)+" 分 "+String(s)+" 秒";
        }
        if(m>0) {
            return String(m)+" 分 "+String(s)+" 秒";
        }
        return String(s)+" 秒";
    }
    /* 发送按钮的文案: 依次覆盖发送中, 冷却中与已有验证码三种情况 */
    function sendLabel() {
        if(Account.phase===1) {
            return "正在发送";
        }
        if(Account.resendLeftSeconds>0) {
            return "重新发送 "+String(Account.resendLeftSeconds)+" 秒";
        }
        return (Account.codeSent? "重新发送":"发送验证码");
    }
    /* 提交邮箱: 只发验证码, 不发登录请求 */
    function submitEmail() {
        if(Account.sendCode(emailField.text)===true) {
            Assist.dlog("用户","已请求发送验证码: ",emailField.text);
        }
    }
    /* 提交验证码: 校验通过后由 Account 落盘并缓存头像 */
    function submitCode() {
        Account.verifyCode(emailField.text,codeField.text);
    }
    /* 顶部刷新与进入本页都复核一次登录状态: 签名不符或已过保留期会在这里被清掉 */
    function refresh() {
        Account.refresh();
    }
    function subsHide(scenePos) {
    }
    onVisibleChanged: {
        if(visible===true) {
            Account.refresh();
        }
    }

    /* 页头: 与兄弟页面同一套内边距, 标题 32/700, 说明 13 取图标色 */
    Column {
        id: profileHeader;
        anchors {left:parent.left; right:parent.right; top:parent.top;}
        leftPadding: 40;
        rightPadding: 40;
        bottomPadding: 10;
        spacing: 10;
        Text {
            color: Define.textColor;
            text: "用户";
            font.pixelSize: 32;
            font.weight: 700;
        }
        Text {
            text: "邮箱验证码登录, 无需注册";
            font.pixelSize: 13;
            color: Define.btnIconColor;
            wrapMode: Text.WordWrap;
            width: parent.width-parent.leftPadding-parent.rightPadding;
        }
    }

    Flickable {
        id: profileFlick;
        anchors {left:parent.left; right:parent.right; top:profileHeader.bottom; bottom:parent.bottom;}
        anchors.topMargin: 5;
        clip: true;
        boundsBehavior: Flickable.StopAtBounds;
        DragHandler {
            acceptedDevices: PointerDevice.Mouse;
            target: null;
        }
        contentWidth: width;
        contentHeight: ((Account.loggedIn? accountPanel.height:loginForm.height)+48);

        /* 未登录: 邮箱加验证码的表单 */
        Column {
            id: loginForm;
            visible: (Account.loggedIn!==true);
            x: 40;
            width: profileFlick.width-80;
            spacing: 10;

            Text {
                color: Define.textColor;
                text: "邮箱";
                font.pixelSize: 15;
                font.weight: 400;
            }
            TextField {
                id: emailField;
                width: 360;
                height: 36;
                font.pixelSize: 14;
                color: Define.textColor;
                /* 初次进入用已登录的邮箱预填; 用户开始输入后绑定断开, 内容以输入为准 */
                text: Account.email;
                placeholderText: "QQ 邮箱, 例如 123456789@qq.com";
                placeholderTextColor: Define.btnIconColor;
                selectByMouse: true;
                leftPadding: 12;
                rightPadding: 12;
                selectionColor: Define.choseCyanColor;
                selectedTextColor: "white";
                background: Rectangle {
                    anchors.fill: parent;
                    radius: 8;
                    color: Define.forbdDarkColor;
                    border.width: 1;
                    border.color: (emailField.activeFocus? Define.choseCyanColor:Define.subGrey);
                }
                onAccepted: {
                    mainArea_ProfilePage.submitEmail();
                }
            }
            CustomButtonA {
                id: sendBtn;
                width: 120;
                height: 30;
                transEnabled: false;
                enabled: (Account.phase===0 && Account.resendLeftSeconds===0);
                opacity: (enabled? 1:0.5);
                background: Rectangle {
                    anchors.fill: parent;
                    radius: 15;
                    color: (parent.hovered? Define.choseDarkColor:Define.hoverDarkColor);
                    Text {
                        anchors.centerIn: parent;
                        text: mainArea_ProfilePage.sendLabel();
                        font.pixelSize: 13;
                        color: Define.textColor;
                    }
                }
                onClicked: {
                    mainArea_ProfilePage.submitEmail();
                }
            }
            /* 分隔线与验证码区一起出现: 没发过验证码时不留一条悬空的分隔线 */
            Rectangle {
                visible: (Account.codeSent===true);
                width: parent.width;
                height: 2;
                radius: 1;
                color: Define.subGrey;
            }
            /* 验证码只在发出过验证码之后出现: 没发过就没有可填的内容 */
            Text {
                visible: (Account.codeSent===true);
                color: Define.textColor;
                text: "验证码";
                font.pixelSize: 15;
                font.weight: 400;
            }
            TextField {
                id: codeField;
                visible: (Account.codeSent===true);
                width: 360;
                height: 36;
                font.pixelSize: 14;
                color: Define.textColor;
                placeholderText: "六位数字验证码";
                placeholderTextColor: Define.btnIconColor;
                selectByMouse: true;
                leftPadding: 12;
                rightPadding: 12;
                maximumLength: 6;
                selectionColor: Define.choseCyanColor;
                selectedTextColor: "white";
                /* 只接受数字: 邮箱里收到的验证码一定是六位数字 */
                validator: RegularExpressionValidator { regularExpression: /[0-9]{0,6}/ }
                background: Rectangle {
                    anchors.fill: parent;
                    radius: 8;
                    color: Define.forbdDarkColor;
                    border.width: 1;
                    border.color: (codeField.activeFocus? Define.choseCyanColor:Define.subGrey);
                }
                onAccepted: {
                    mainArea_ProfilePage.submitCode();
                }
            }
            CustomButtonA {
                id: loginBtn;
                visible: (Account.codeSent===true);
                width: 100;
                height: 30;
                transEnabled: false;
                enabled: (Account.phase===0);
                opacity: (enabled? 1:0.5);
                background: Rectangle {
                    anchors.fill: parent;
                    radius: 15;
                    color: (parent.hovered? Qt.darker(Define.choseCyanColor,1.1):Define.choseCyanColor);
                    Text {
                        anchors.centerIn: parent;
                        text: (Account.phase===2? "登录中":"登录");
                        font.pixelSize: 13;
                        color: "white";
                    }
                }
                onClicked: {
                    mainArea_ProfilePage.submitCode();
                }
            }
            /* 提示行: 错误为红, 正常为选中青 */
            Text {
                id: hintText;
                visible: (Account.hint!=="");
                text: Account.hint;
                font.pixelSize: 13;
                color: (Account.hintError? Define.btnIconRed:Define.choseCyanColor);
                wrapMode: Text.WordWrap;
                width: loginForm.width;
            }
        }

        /* 已登录: 头像, 邮箱与登录时间 */
        Column {
            id: accountPanel;
            visible: (Account.loggedIn===true);
            x: 40;
            width: profileFlick.width-80;
            spacing: 10;
            Row {
                id: avatarRow;
                spacing: 20;
                CoverImage {
                    id: bigAvatar;
                    width: 120;
                    height: 120;
                    cornerRadius: width/2;
                    outlineWidth: 1;
                    outlineColor: Define.subGrey;
                    source: (Account.avatarSource(Define.avatarSpecLarge)===""
                             ? "qrc:/favicon.jpg":Account.avatarSource(Define.avatarSpecLarge));
                    HoverHandler {
                        id: avatarHh;
                    }
                    /* 非纯数字 QQ 邮箱没有头像可缓存, 用悬停提示代替常驻说明文字 */
                    ToolTip.visible: (avatarHh.hovered && Account.qqNumber==="");
                    ToolTip.text: "该邮箱不是纯数字 QQ 邮箱, 不展示 QQ 头像";
                    ToolTip.delay: 600;
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter;
                    spacing: 8;
                    Text {
                        text: Account.email;
                        font.pixelSize: 18;
                        font.weight: 500;
                        color: Define.textColor;
                    }
                    Text {
                        text: "登录时间 " + mainArea_ProfilePage.stampOf(Account.loginAt);
                        font.pixelSize: 13;
                        color: Define.btnIconColor;
                    }
                    Text {
                        text: "登录状态保留至 " + mainArea_ProfilePage.stampOf(Account.expireAt)
                              + " (剩余 " + String(mainArea_ProfilePage.leftDays()) + " 天)";
                        font.pixelSize: 13;
                        color: Define.btnIconColor;
                    }
                    Text {
                        text: "累计听歌 " + mainArea_ProfilePage.listenStamp(Account.totalListenSeconds)
                              + ", 等级 Lv." + String(Account.levelOf(Account.totalListenSeconds));
                        font.pixelSize: 13;
                        color: Define.btnIconColor;
                    }
                }
            }
            Rectangle {
                width: parent.width;
                height: 2;
                radius: 1;
                color: Define.subGrey;
            }
            Row {
                spacing: 10;
                CustomButtonA {
                    id: logoutBtn;
                    width: 100;
                    height: 30;
                    transEnabled: false;
                    background: Rectangle {
                        anchors.fill: parent;
                        radius: 15;
                        color: (parent.hovered? Define.choseDarkColor:Define.hoverDarkColor);
                        Text {
                            anchors.centerIn: parent;
                            text: "退出登录";
                            font.pixelSize: 13;
                            color: Define.textColor;
                        }
                    }
                    onClicked: {
                        Account.logout();
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter;
                    text: Account.hint;
                    font.pixelSize: 13;
                    color: (Account.hintError? Define.btnIconRed:Define.choseCyanColor);
                }
            }
        }
    }
    /* 正文滚动条: 与列表页共用同一个组件, 内容不超出时隐藏 */
    CustomSliderC {
        id: profileScrollBar;
        anchors {top:profileFlick.top; bottom:profileFlick.bottom; right:parent.right;}
        width: 4;
        visible: (profileFlick.contentHeight>profileFlick.height);
        handleRatio: Math.max(0.1,profileFlick.height/profileFlick.contentHeight);
        hoverHandlerEnabled: false;
        value: from*(profileFlick.contentY/Math.max(1,profileFlick.contentHeight-profileFlick.height));
        onMoved: {
            profileFlick.contentY=(value/from)*Math.max(0,profileFlick.contentHeight-profileFlick.height);
            value=Qt.binding(function() {
                return from*(profileFlick.contentY/Math.max(1,profileFlick.contentHeight-profileFlick.height));
            });
        }
    }
}
