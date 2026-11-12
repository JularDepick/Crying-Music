import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic
import "./"

/* 用户页: 邮箱验证码登录, 无需注册
 * 未登录时是一段紧凑的行内表单: 标签在上, 输入框与按钮同一行, 宽度受限不铺满,
 * 发送验证码后原地加出验证码行, 重发做成文字链接, 只在需要时出现提示.
 * 已登录时只留头像, 邮箱, 等级与累计听歌, 以及退出按钮, 不放时间与说明类文字.
 * 登录状态由 Account 单例持有, 本页只负责输入与显示, 不自行读写落盘记录 */
MainAreaFatherPage {
    id: mainArea_ProfilePage;
    visible: false;

    /* 累计听歌时长: 只精确到分钟, 不再显示秒;
     * 不足一分钟按 0 分钟计, 整小时时省略多余的 0 分 */
    function listenStamp(totalSeconds) {
        var sec=Math.floor(Number(totalSeconds));
        if(!(sec>0)) {
            return "0 分钟";
        }
        var h=Math.floor(sec/3600);
        var m=Math.floor((sec%3600)/60);
        if(h>0 && m>0) {
            return String(h)+" 小时 "+String(m)+" 分";
        }
        if(h>0) {
            return String(h)+" 小时";
        }
        return String(m)+" 分钟";
    }
    /* 重发链接的文案: 依次覆盖发送中, 冷却中与可重发三种情况 */
    function resendLabel() {
        if(Account.phase===1) {
            return "正在发送";
        }
        if(Account.resendLeftSeconds>0) {
            return "重新发送 ("+String(Account.resendLeftSeconds)+" 秒)";
        }
        return "重新发送验证码";
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
    /* 退出按钮的确认态复位: 页面隐藏或登录状态变化时都回到空闲文案 */
    function resetLogoutConfirm() {
        if(logoutBtn!==null) {
            logoutBtn.reset();
        }
    }
    onVisibleChanged: {
        if(visible===true) {
            Account.refresh();
        }
        resetLogoutConfirm();
    }
    /* 验证码发出后把焦点交给验证码框: 少一次点击, 键盘一路走完整个流程;
     * 延后一拍, 等验证码行完成可见性与布局再抢焦点 */
    Connections {
        target: Account;
        function onCodeSentChanged() {
            if(Account.codeSent===true && loginForm.visible===true) {
                Qt.callLater(function() {
                    codeField.forceActiveFocus();
                });
            }
        }
        /* 登录状态变化后退出按钮不再处于确认态 */
        function onLoggedInChanged() {
            mainArea_ProfilePage.resetLogoutConfirm();
        }
    }

    /* 页头: 与兄弟页面同一套内边距, 标题 32/700 */
    Column {
        id: profileHeader;
        anchors {left:parent.left; right:parent.right; top:parent.top;}
        leftPadding: 40;
        rightPadding: 40;
        bottomPadding: 10;
        spacing: 8;
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
        }
    }

    /* 未登录: 紧凑的行内表单, 左对齐, 宽度受限; 输入框与按钮同一行 */
    Column {
        id: loginForm;
        visible: (Account.loggedIn!==true);
        anchors {left:parent.left; top:profileHeader.bottom;}
        anchors.leftMargin: 40;
        anchors.topMargin: Define.loginFormTopMargin;
        width: Define.loginFormWidth;
        spacing: 20;

        Column {
            width: parent.width;
            spacing: 8;
            Text {
                text: "邮箱";
                font.pixelSize: 13;
                color: Define.textColor;
            }
            Row {
                width: parent.width;
                spacing: 10;
                CustomTextField {
                    id: emailField;
                    width: Math.max(0,loginForm.width-Define.loginActionWidth-10);
                    height: Define.loginFieldHeight;
                    placeholderText: "QQ 邮箱, 例如 123456789@qq.com";
                    text: Account.email;
                    onAccepted: {
                        mainArea_ProfilePage.submitEmail();
                    }
                }
                CustomButtonA {
                    id: sendBtn;
                    width: Define.loginActionWidth;
                    height: Define.loginFieldHeight;
                    transEnabled: false;
                    enabled: (Account.phase===0);
                    opacity: (enabled? 1:0.5);
                    background: Rectangle {
                        anchors.fill: parent;
                        radius: 8;
                        color: (parent.hovered? Define.choseDarkColor:Define.hoverDarkColor);
                        Text {
                            anchors.centerIn: parent;
                            text: "发送验证码";
                            font.pixelSize: 13;
                            color: Define.textColor;
                        }
                    }
                    onClicked: {
                        mainArea_ProfilePage.submitEmail();
                    }
                }
            }
        }

        /* 验证码行: 只在发出验证码之后出现 */
        Column {
            id: codeBlock;
            visible: (Account.codeSent===true);
            width: parent.width;
            spacing: 8;
            Text {
                text: "验证码";
                font.pixelSize: 13;
                color: Define.textColor;
            }
            Row {
                width: parent.width;
                spacing: 10;
                CustomTextField {
                    id: codeField;
                    width: Math.max(0,loginForm.width-Define.loginActionWidth-10);
                    height: Define.loginFieldHeight;
                    placeholderText: "六位数字";
                    maximumLength: 6;
                    /* 只接受数字: 邮箱里收到的验证码一定是六位数字 */
                    validator: RegularExpressionValidator { regularExpression: /[0-9]{0,6}/ }
                    onAccepted: {
                        mainArea_ProfilePage.submitCode();
                    }
                }
                CustomButtonA {
                    id: loginBtn;
                    width: Define.loginActionWidth;
                    height: Define.loginFieldHeight;
                    transEnabled: false;
                    enabled: (Account.phase===0);
                    opacity: (enabled? 1:0.5);
                    background: Rectangle {
                        anchors.fill: parent;
                        radius: 8;
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
            }
            /* 重发做成文字链接, 不占一条按钮的位置; 冷却期内不可点 */
            Text {
                property bool canResend: (Account.phase===0 && Account.resendLeftSeconds===0);
                text: mainArea_ProfilePage.resendLabel();
                font.pixelSize: 12;
                color: (canResend? Define.choseCyanColor:Define.forbdDarkColor);
                MouseArea {
                    anchors.fill: parent;
                    enabled: (parent.canResend===true);
                    cursorShape: (parent.canResend===true? Qt.PointingHandCursor:Qt.ArrowCursor);
                    onClicked: {
                        mainArea_ProfilePage.submitEmail();
                    }
                }
            }
        }

        /* 提示行: 只在确实有内容时出现 */
        Text {
            id: hintText;
            width: parent.width;
            visible: (Account.hint!=="");
            text: Account.hint;
            font.pixelSize: 12;
            color: (Account.hintError? Define.btnIconRed:Define.choseCyanColor);
            wrapMode: Text.WordWrap;
        }
    }

    /* 已登录: 头像与身份信息一行, 分隔线之后是退出 */
    Flickable {
        id: profileFlick;
        visible: (Account.loggedIn===true);
        anchors {left:parent.left; right:parent.right; top:profileHeader.bottom; bottom:parent.bottom;}
        anchors.topMargin: 5;
        clip: true;
        boundsBehavior: Flickable.StopAtBounds;
        contentWidth: width;
        contentHeight: (accountPanel.height+48);

        Column {
            id: accountPanel;
            x: 40;
            width: profileFlick.width-80;
            spacing: 20;
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
                    spacing: 10;
                    Text {
                        text: Account.email;
                        font.pixelSize: 18;
                        font.weight: 500;
                        color: Define.textColor;
                        elide: Text.ElideRight;
                        width: Math.max(0,accountPanel.width-bigAvatar.width-avatarRow.spacing);
                    }
                    Row {
                        spacing: 8;
                        CustomButtonA {
                            id: levelIcon;
                            width: 28;
                            height: 28;
                            icon.source: Account.levelIconOf(Account.levelOf(Account.totalListenSeconds));
                            icon.color: Define.vipRed;
                            transEnabled: false;
                            hoverHandlerEnabled: false;
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter;
                            text: "Lv." + String(Account.levelOf(Account.totalListenSeconds))
                                  + " · 听歌 " + mainArea_ProfilePage.listenStamp(Account.totalListenSeconds);
                            font.pixelSize: 13;
                            color: Define.btnIconColor;
                        }
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
                /* 二次确认落在按钮上: 首击进入确认态, 三秒内再击才退出登录, 超时回归 */
                ConfirmButton {
                    id: logoutBtn;
                    width: 100;
                    height: 36;
                    label: "退出登录";
                    confirmLabel: "确认退出";
                    cornerRadius: 8;
                    fontSize: 13;
                    onConfirmed: {
                        Account.logout();
                        logoutBtn.reset();
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter;
                    visible: (Account.hint!=="");
                    text: Account.hint;
                    font.pixelSize: 12;
                    color: (Account.hintError? Define.btnIconRed:Define.choseCyanColor);
                }
            }
        }
    }
    /* 正文滚动条: 与列表页共用同一个组件, 内容不超出时隐藏; 只有登录后才存在可滚动内容 */
    CustomSliderC {
        id: profileScrollBar;
        anchors {top:profileFlick.top; bottom:profileFlick.bottom; right:parent.right;}
        width: 4;
        visible: (profileFlick.visible && profileFlick.contentHeight>profileFlick.height);
        handleRatio: Math.max(0.1,profileFlick.height/Math.max(1,profileFlick.contentHeight));
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
