import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic
import "./"

/* 用户页: 邮箱验证码登录, 无需注册
 * 未登录时是一张居中的登录卡片: 表单纵向单列, 标签在输入框上方, 主按钮全宽;
 * 发送验证码后不换页, 就地展开验证码字段与登录按钮, 重发做成次要动作放在最下方,
 * 邮箱框始终可编辑, 改完邮箱直接点重发即可换一个地址继续.
 * 已登录时展示头像, 邮箱, 登录时间与到期时间, 以及听歌与等级.
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
    /* 重发按钮的文案: 依次覆盖发送中, 冷却中与可重发三种情况 */
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
    function subsHide(scenePos) {
    }
    onVisibleChanged: {
        if(visible===true) {
            Account.refresh();
        }
    }
    /* 验证码发出后把焦点交给验证码框: 少一次点击, 键盘一路走完整个流程;
     * 延后一拍, 等验证码区块完成可见性与布局再抢焦点 */
    Connections {
        target: Account;
        function onCodeSentChanged() {
            if(Account.codeSent===true && loginArea.visible===true) {
                Qt.callLater(function() {
                    codeField.forceActiveFocus();
                });
            }
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

    /* 未登录: 居中的登录卡片, 表单纵向单列, 标签在输入框上方, 主按钮全宽 */
    Item {
        id: loginArea;
        visible: (Account.loggedIn!==true);
        anchors {left:parent.left; right:parent.right; top:profileHeader.bottom; bottom:parent.bottom;}

        Rectangle {
            id: loginCard;
            anchors.horizontalCenter: parent.horizontalCenter;
            anchors.verticalCenter: parent.verticalCenter;
            /* 略高于正中: 视觉重心比几何重心更舒服, 也不会顶到页头 */
            anchors.verticalCenterOffset: -16;
            width: Define.loginCardWidth;
            height: loginColumn.implicitHeight+Define.loginCardPadding*2;
            radius: 10;
            color: Define.mainAreaColor;
            border.color: Define.subGrey;
            border.width: 1;

            Column {
                id: loginColumn;
                anchors {
                    left: parent.left;
                    right: parent.right;
                    leftMargin: Define.loginCardPadding;
                    rightMargin: Define.loginCardPadding;
                    verticalCenter: parent.verticalCenter;
                }
                spacing: 16;

                /* 标题与一句话说明: 说清这里是做什么的, 以及不需要注册 */
                Column {
                    width: parent.width;
                    spacing: 6;
                    Text {
                        width: parent.width;
                        text: "登录";
                        font.pixelSize: 20;
                        font.weight: 600;
                        color: Define.textColor;
                    }
                    Text {
                        width: parent.width;
                        text: "用邮箱验证码登录, 无需注册";
                        font.pixelSize: 13;
                        color: Define.btnIconColor;
                        wrapMode: Text.WordWrap;
                    }
                }

                /* 邮箱: 标签在输入框上方, 输入框与按钮都占满整行 */
                Column {
                    width: parent.width;
                    spacing: 6;
                    Text {
                        text: "邮箱";
                        font.pixelSize: 13;
                        color: Define.textColor;
                    }
                    CustomTextField {
                        id: emailField;
                        width: parent.width;
                        placeholderText: "例如 123456789@qq.com";
                        text: Account.email;
                        onAccepted: {
                            mainArea_ProfilePage.submitEmail();
                        }
                    }
                }

                /* 未发过验证码: 只露出发送按钮, 避免出现一个还不能用的验证码框 */
                CustomButtonA {
                    id: sendBtn;
                    visible: (Account.codeSent!==true);
                    width: parent.width;
                    height: Define.loginButtonHeight;
                    transEnabled: false;
                    enabled: (Account.phase===0);
                    opacity: (enabled? 1:0.5);
                    background: Rectangle {
                        anchors.fill: parent;
                        radius: 8;
                        color: (parent.hovered? Qt.darker(Define.choseCyanColor,1.1):Define.choseCyanColor);
                        Text {
                            anchors.centerIn: parent;
                            text: "发送验证码";
                            font.pixelSize: 14;
                            color: "white";
                        }
                    }
                    onClicked: {
                        mainArea_ProfilePage.submitEmail();
                    }
                }

                /* 已发出验证码: 就地展开验证码字段与登录主按钮 */
                Column {
                    id: codeBlock;
                    visible: (Account.codeSent===true);
                    width: parent.width;
                    spacing: 6;
                    Text {
                        text: "验证码";
                        font.pixelSize: 13;
                        color: Define.textColor;
                    }
                    CustomTextField {
                        id: codeField;
                        width: parent.width;
                        placeholderText: "六位数字验证码";
                        maximumLength: 6;
                        /* 只接受数字: 邮箱里收到的验证码一定是六位数字 */
                        validator: RegularExpressionValidator { regularExpression: /[0-9]{0,6}/ }
                        onAccepted: {
                            mainArea_ProfilePage.submitCode();
                        }
                    }
                }

                CustomButtonA {
                    id: loginBtn;
                    visible: (Account.codeSent===true);
                    width: parent.width;
                    height: Define.loginButtonHeight;
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
                            font.pixelSize: 14;
                            color: "white";
                        }
                    }
                    onClicked: {
                        mainArea_ProfilePage.submitCode();
                    }
                }

                /* 次要动作: 重发验证码, 冷却期内不可点; 邮箱框始终可编辑, 改完直接重发 */
                CustomButtonA {
                    id: resendBtn;
                    visible: (Account.codeSent===true);
                    width: parent.width;
                    height: 28;
                    transEnabled: false;
                    enabled: (Account.phase===0 && Account.resendLeftSeconds===0);
                    opacity: (enabled? 1:0.5);
                    background: Rectangle {
                        anchors.fill: parent;
                        radius: 6;
                        color: (parent.hovered? Define.hoverDarkColor:Define.mainAreaColor);
                        Text {
                            anchors.centerIn: parent;
                            text: mainArea_ProfilePage.resendLabel();
                            font.pixelSize: 13;
                            color: Define.btnIconColor;
                        }
                    }
                    onClicked: {
                        mainArea_ProfilePage.submitEmail();
                    }
                }

                /* 提示行: 错误为红, 正常为选中青 */
                Text {
                    id: hintText;
                    width: parent.width;
                    visible: (Account.hint!=="");
                    text: Account.hint;
                    font.pixelSize: 13;
                    color: (Account.hintError? Define.btnIconRed:Define.choseCyanColor);
                    wrapMode: Text.WordWrap;
                }

                /* 底部小字: 说明登录只是可选, 不影响听歌 */
                Text {
                    width: parent.width;
                    text: "未登录也可以正常听歌";
                    font.pixelSize: 12;
                    color: Define.btnIconColor;
                    horizontalAlignment: Text.AlignHCenter;
                }
            }
        }
    }

    /* 已登录: 头像与身份信息在上, 累计听歌与等级在下; 内容可滚动 */
    Flickable {
        id: profileFlick;
        visible: (Account.loggedIn===true);
        anchors {left:parent.left; right:parent.right; top:profileHeader.bottom; bottom:parent.bottom;}
        anchors.topMargin: 5;
        clip: true;
        boundsBehavior: Flickable.StopAtBounds;
        DragHandler {
            acceptedDevices: PointerDevice.Mouse;
            target: null;
        }
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
                    spacing: 8;
                    Text {
                        text: Account.email;
                        font.pixelSize: 18;
                        font.weight: 500;
                        color: Define.textColor;
                        elide: Text.ElideRight;
                        width: Math.max(0,accountPanel.width-bigAvatar.width-avatarRow.spacing);
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
                }
            }
            Rectangle {
                width: parent.width;
                height: 2;
                radius: 1;
                color: Define.subGrey;
            }
            Column {
                width: parent.width;
                spacing: 10;
                Text {
                    color: Define.textColor;
                    text: "听歌与等级";
                    font.pixelSize: 15;
                    font.weight: 400;
                }
                Row {
                    id: levelRow;
                    spacing: 20;
                    /* 等级徽标: 与左侧栏同一套取档, 等级为 0 时给第一档 */
                    CustomButtonA {
                        id: levelIcon;
                        width: 40;
                        height: 40;
                        icon.source: Account.levelIconOf(Account.levelOf(Account.totalListenSeconds));
                        icon.color: Define.vipRed;
                        transEnabled: false;
                        hoverHandlerEnabled: false;
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter;
                        spacing: 4;
                        Text {
                            text: "Lv." + String(Account.levelOf(Account.totalListenSeconds));
                            font.pixelSize: 20;
                            font.weight: 700;
                            color: Define.textColor;
                        }
                        Text {
                            text: "累计听歌 " + mainArea_ProfilePage.listenStamp(Account.totalListenSeconds);
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
                CustomButtonA {
                    id: logoutBtn;
                    width: 100;
                    height: 36;
                    transEnabled: false;
                    background: Rectangle {
                        anchors.fill: parent;
                        radius: 8;
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
