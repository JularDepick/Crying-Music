pragma Singleton
import QtQuick

import AppHelper 1.0

import "./"

/* 用户登录: 验证码的收发, 登录凭证的复核与落盘, QQ 头像缓存
 * 流程: 页面交出邮箱 -> 这里请求接口发送验证码 -> 页面交出验证码 -> 这里请求校验 ->
 * 通过后复核签名并把邮箱, 登录时刻与签名写进存储单例, 本地保留 Define.loginKeepDays 天.
 * 登录与否不影响听歌, 其余模块只读 loggedIn 与头像地址, 不参与登录逻辑 */
Item {
    id: accountRoot;

    /* 请求阶段: 0 空闲, 1 发送验证码中, 2 校验验证码中 */
    property int phase: 0;
    /* 页面上显示的提示文本与是否为错误 */
    property string hint: "";
    property bool hintError: false;
    /* 本次会话是否已经发出过验证码: 页面据此露出验证码输入与登录按钮 */
    property bool codeSent: false;
    /* 下一次允许重发验证码的时刻(毫秒), 0 表示没有冷却 */
    property double resendAt: 0;
    /* 时间基准: 由两个定时器推进, 供冷却倒计时与保留期判定绑定 */
    property double nowMs: Date.now();
    /* 小图与大图的本地缓存地址: 未登录或不是 QQ 邮箱时为空串 */
    property string avatarSmall: "";
    property string avatarLarge: "";
    /* 头像缓存版本: 重新缓存后加一, 页面把它拼进地址以绕开图片缓存 */
    property int avatarRev: 0;
    /* 在途请求: 同一时刻只允许一个, 超时或新请求到来时中止它 */
    property var pendingXhr: null;

    /* 落盘记录里的字段: 邮箱, 登录时刻, 签名与登录状态秘钥 */
    readonly property string email:
        (typeof GlobalFileStorage.account.email==="string"? GlobalFileStorage.account.email:"");
    readonly property double loginAt:
        (typeof GlobalFileStorage.account.loginAt==="number"? GlobalFileStorage.account.loginAt:0);
    readonly property string sign:
        (typeof GlobalFileStorage.account.sign==="string"? GlobalFileStorage.account.sign:"");
    readonly property string sessionKey:
        (typeof GlobalFileStorage.account.sessionKey==="string"? GlobalFileStorage.account.sessionKey:"");
    /* 保留期截止时刻: 未登录时为 0 */
    readonly property double expireAt: (loginAt>0? loginAt+Define.loginKeepDays*86400000:0);
    /* 签名复核: 用内置密钥按服务端的同一口径重算, 与落盘值一致才算可信 */
    readonly property bool signOk: verifySign(email,loginAt,sign);
    /* 是否已登录: 记录完整, 签名相符且未过保留期, 且服务端签发过登录状态秘钥;
     * 缺秘钥说明这次登录早于秘钥机制, 涉及用户的操作一律拒绝 */
    readonly property bool loggedIn: (email!=="" && loginAt>0 && signOk===true
                                      && sessionKey!=="" && nowMs<expireAt);
    /* 服务端给出的累计听歌秒数: 用户等级由它派生 */
    readonly property int totalListenSeconds:
        (typeof GlobalFileStorage.listenState.totalSeconds==="number"
         ? GlobalFileStorage.listenState.totalSeconds:0);
    /* 冷却剩余的秒数: 页面据此显示"重新发送(nn 秒)" */
    readonly property int resendLeftSeconds: (resendAt>nowMs? Math.ceil((resendAt-nowMs)/1000):0);
    /* 纯数字的 QQ 邮箱里的 QQ 号: 其余邮箱为空串 */
    readonly property string qqNumber: qqNumberOf(email);

    /* 归一化邮箱: 去掉首尾空白并统一小写, 与服务端的口径一致 */
    function normalizeEmail(raw) {
        return String(raw===undefined || raw===null? "":raw).trim().toLowerCase();
    }
    /* 邮箱形状校验: 与服务端同一套基本规则, 只挡明显的错误输入 */
    function isMailValid(email) {
        if(email==="" || email.length>254) {
            return false;
        }
        return /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,24}$/.test(email);
    }
    /* 取 QQ 号: 形如 123456789@qq.com 的纯数字前缀才有, 其余返回空串 */
    function qqNumberOf(email) {
        var one=String(email===undefined || email===null? "":email).trim().toLowerCase();
        var at=one.indexOf("@qq.com");
        if(at<=0 || at!==one.length-7) {
            return "";
        }
        var head=one.substring(0,at);
        return (/^[0-9]{5,12}$/.test(head)? head:"");
    }
    /* 登录凭证签名复核: 与服务端 loginSignOf 同一口径 */
    function verifySign(email,issuedAt,sign) {
        if(String(email)==="" || !(issuedAt>0) || String(sign)==="") {
            return false;
        }
        var key=String(Server.api.client_secret);
        if(key==="") {
            return false;
        }
        var want=AppFileHelper.hmacSha256Hex(key,"login|"+String(email)+"|"+String(issuedAt));
        return (String(want).toLowerCase()===String(sign).toLowerCase());
    }
    /* 累计听歌秒数换算等级: 与服务端 levelOf 同一套公式,
     * t = 累计秒数 / levelScaleSeconds, 结果按 levelMax 封顶 */
    function levelOf(totalSeconds) {
        var sec=Math.floor(Number(totalSeconds));
        if(!(sec>0)) {
            return 0;
        }
        var t=sec/Define.levelScaleSeconds;
        var n=Math.floor(Define.levelBase*Math.log(t/Define.levelDivisor+1));
        if(n<0) {
            return 0;
        }
        return (n>Define.levelMax? Define.levelMax:n);
    }
    /* 等级徽标图标: 按等级落在哪一档取, 高于末档用末档; 等级为 0 时也给第一档,
     * 与未上线时的静态末档观感不同但同样保留徽标, 未登录时返回空串由调用方回退应用图标 */
    function levelIconOf(level) {
        if(loggedIn!==true) {
            return "";
        }
        var n=Math.floor(Number(level));
        if(!(n>0)) {
            n=1;
        }
        var steps=Define.levelIconSteps;
        for(var i=0;i<steps.length;i++) {
            if(n<=steps[i]) {
                return "qrc:/assets/iconfont/vip/vip"+String(i+1)+".svg";
            }
        }
        return "qrc:/assets/iconfont/vip/vip"+String(steps.length)+".svg";
    }
    /* 接口地址: 基址与路径都来自 Server 的 api 配置, 末尾统一补斜杠 */
    function apiUrlOf(path) {
        var base=String(Server.api.base_url);
        var sub=String(Server.api.path);
        if(base!=="" && base.charAt(base.length-1)!=="/") {
            base=base+"/";
        }
        if(sub.charAt(0)==="/") {
            sub=sub.substring(1);
        }
        return base+sub+String(path);
    }
    /* 头像地址: 按模板拼出 QQ 号与清晰度, QQ 号为空时返回空串 */
    function avatarUrlOf(spec) {
        if(qqNumber==="") {
            return "";
        }
        return String(Define.avatarUrlTemplate).replace("{qq}",qqNumber)
                                               .replace("{spec}",String(spec));
    }
    /* 头像缓存文件名: 按 QQ 号与清晰度定名, 重复登录覆盖同一份 */
    function avatarCacheNameOf(spec) {
        return "qq_"+qqNumber+"_"+String(spec)+".jpg";
    }
    /* 头像地址: 供界面取用, 重新缓存过就带上版本串绕开图片缓存 */
    function avatarSource(spec) {
        var one=(Number(spec)===Define.avatarSpecSmall? avatarSmall:avatarLarge);
        if(one==="") {
            return "";
        }
        return (avatarRev>0? one+"?v="+String(avatarRev):one);
    }
    /* 设置提示: 提示文本与是否为错误一起换 */
    function setHint(isError,text) {
        hint=String(text===undefined || text===null? "":text);
        hintError=(isError===true);
    }
    /* 失败原因: 优先用服务端给的文案, 没有时按状态码给一句人话 */
    function messageOf(status,body) {
        if(body!==null && body!==undefined && typeof body.message==="string" && body.message!=="") {
            return body.message;
        }
        if(status===0) {
            return "无法连接服务器, 请检查网络";
        }
        if(status===401) {
            return "客户端密钥无效, 请更新应用";
        }
        if(status===429) {
            return "操作过于频繁, 请稍后再试";
        }
        if(status>=500) {
            return "服务器暂时不可用, 请稍后再试";
        }
        return "请求失败(状态 "+String(status)+")";
    }
    /* 发一次 JSON POST: 无论成败都回一次 onDone(是否收到响应, 状态码, 解析后的对象);
     * 同一时刻只允许一个在途请求, 新请求会先中止旧的 */
    function post(path,payload,onDone) {
        return sendJson("POST",path,payload,false,onDone);
    }
    /* 发一次 GET: 不带请求体, 供资料查询使用 */
    function get(path,onDone) {
        return sendJson("GET",path,null,false,onDone);
    }
    /* 带登录状态秘钥的 POST: 涉及用户的操作一律走这里, 秘钥放在请求头里 */
    function postWithSession(path,payload,onDone) {
        return sendJson("POST",path,payload,true,onDone);
    }
    /* 带登录状态秘钥的 GET */
    function getWithSession(path,onDone) {
        return sendJson("GET",path,null,true,onDone);
    }
    /* 发送 JSON 请求的公共实现: withSession 为真时把登录状态秘钥放进 X-Session-Key */
    function sendJson(method,path,payload,withSession,onDone) {
        var old=pendingXhr;
        if(old!==null) {
            old.__aborted=true;
            try {
                old.abort();
            } catch(e0) {
            }
            pendingXhr=null;
            /* 被中止的请求同样要回调, 否则调用方的在途状态(登录 phase, 待补报秒数)
             * 会永远停在中间态; 延后一拍执行, 避免回调里再发请求时覆盖本函数新建的请求 */
            var oldDone=old.__onDone;
            old.__onDone=null;
            if(typeof oldDone==="function") {
                Qt.callLater(function() {
                    oldDone(false,0,null);
                });
            }
        }
        var xhr=null;
        try {
            xhr=new XMLHttpRequest();
        } catch(e1) {
            Assist.derror("用户","请求对象不可用: ",e1);
            onDone(false,0,null);
            return false;
        }
        pendingXhr=xhr;
        xhr.__onDone=onDone;
        var settled=false;
        xhr.onreadystatechange=function() {
            if(settled===true || xhr.__aborted===true || xhr.readyState!==XMLHttpRequest.DONE) {
                return;
            }
            settled=true;
            xhr.__onDone=null;
            if(accountRoot.pendingXhr===xhr) {
                accountRoot.pendingXhr=null;
            }
            reqTimer.stop();
            var body=null;
            try {
                body=JSON.parse(xhr.responseText);
            } catch(e2) {
                body=null;
            }
            onDone(true,xhr.status,body);
        };
        try {
            xhr.open(method,apiUrlOf(path));
            if(method==="POST") {
                xhr.setRequestHeader("Content-Type","application/json");
            }
            xhr.setRequestHeader("X-Client-Secret",String(Server.api.client_secret));
            if(withSession===true) {
                xhr.setRequestHeader("X-Session-Key",sessionKey);
            }
        } catch(e3) {
            Assist.dwarn("用户","请求发起失败: ",path,", ",e3);
            pendingXhr=null;
            xhr.__onDone=null;
            onDone(false,0,null);
            return false;
        }
        reqTimer.restart();
        Assist.dlog("用户","请求: ",method," ",apiUrlOf(path));
        try {
            xhr.send((method==="POST" && payload!==null && payload!==undefined)
                     ? JSON.stringify(payload):null);
        } catch(e4) {
            Assist.dwarn("用户","请求发送失败: ",path,", ",e4);
            pendingXhr=null;
            xhr.__onDone=null;
            reqTimer.stop();
            onDone(false,0,null);
            return false;
        }
        return true;
    }
    /* 发送验证码: 通过后进入冷却, 页面露出验证码输入 */
    function sendCode(rawEmail) {
        if(phase!==0) {
            return false;
        }
        var emailOne=normalizeEmail(rawEmail);
        if(isMailValid(emailOne)!==true) {
            setHint(true,"邮箱地址格式不正确");
            return false;
        }
        /* 先按成功展开: 验证码输入与冷却立即出现, 请求回来再决定保留还是回退,
         * 因此点发送之后界面不等网络; 回退时把这两项还原成发送前的样子 */
        var wasSent=codeSent;
        var wasResendAt=resendAt;
        codeSent=true;
        nowMs=Date.now();
        resendAt=nowMs+Define.loginResendFallbackSeconds*1000;
        phase=1;
        setHint(false,"");
        post("code/send",{"email":emailOne},function(sent,status,body) {
            accountRoot.phase=0;
            if(sent!==true) {
                accountRoot.codeSent=wasSent;
                accountRoot.resendAt=wasResendAt;
                accountRoot.nowMs=Date.now();
                accountRoot.setHint(true,"无法连接服务器, 请检查网络");
                return;
            }
            if(status>=200 && status<300 && body!==null && body.ok===true) {
                var cool=(typeof body.cooldown==="number"
                          ? body.cooldown:Define.loginResendFallbackSeconds);
                accountRoot.codeSent=true;
                accountRoot.nowMs=Date.now();
                accountRoot.resendAt=accountRoot.nowMs+cool*1000;
                accountRoot.setHint(false,(typeof body.message==="string"
                                           ? body.message:"验证码已发送"));
                Assist.dlog("用户","验证码已发送: ",emailOne);
                return;
            }
            /* 服端明确拒绝时同样回退: 冷却不白占, 验证码区回到发送前 */
            accountRoot.codeSent=wasSent;
            accountRoot.resendAt=wasResendAt;
            accountRoot.nowMs=Date.now();
            Assist.dwarn("用户","验证码发送失败: 状态 ",status);
            accountRoot.setHint(true,accountRoot.messageOf(status,body));
        });
        return true;
    }
    /* 校验验证码: 通过后复核签名并落盘, 随后按 QQ 号缓存两档头像 */
    function verifyCode(rawEmail,rawCode) {
        if(phase!==0) {
            return false;
        }
        var emailOne=normalizeEmail(rawEmail);
        var code=String(rawCode===undefined || rawCode===null? "":rawCode).trim();
        if(isMailValid(emailOne)!==true) {
            setHint(true,"邮箱地址格式不正确");
            return false;
        }
        if(/^[0-9]{6}$/.test(code)!==true) {
            setHint(true,"验证码为六位数字");
            return false;
        }
        phase=2;
        setHint(false,"");
        post("code/verify",{"email":emailOne,"code":code},function(sent,status,body) {
            accountRoot.phase=0;
            if(sent!==true) {
                accountRoot.setHint(true,"无法连接服务器, 请检查网络");
                return;
            }
            var ok=(status>=200 && status<300 && body!==null && body.ok===true
                    && typeof body.email==="string" && typeof body.issuedAt==="number"
                    && typeof body.sign==="string");
            if(ok!==true) {
                Assist.dwarn("用户","验证码校验未通过: 状态 ",status);
                accountRoot.setHint(true,accountRoot.messageOf(status,body));
                return;
            }
            if(accountRoot.verifySign(body.email,body.issuedAt,body.sign)!==true) {
                Assist.dwarn("用户","登录凭证签名校验失败: ",body.email);
                accountRoot.setHint(true,"登录凭证签名校验失败");
                return;
            }
            /* 登录状态秘钥: 服务端没给就视为登录失败, 没有秘钥的后续用户操作一律被拒 */
            if(typeof body.sessionKey!=="string" || body.sessionKey==="") {
                Assist.dwarn("用户","服务端未下发登录状态秘钥: ",body.email);
                accountRoot.setHint(true,"服务端未下发登录状态秘钥");
                return;
            }
            var saved=GlobalFileStorage.setAccount(body.email,body.issuedAt,body.sign,body.sessionKey);
            accountRoot.codeSent=false;
            accountRoot.resendAt=0;
            accountRoot.nowMs=Date.now();
            accountRoot.setHint(saved!==true,(saved===true
                ? "登录成功, 登录状态保留 "+String(Define.loginKeepDays)+" 天":"登录记录保存失败"));
            /* 头像只在 onLoggedInChanged 里取一次: 上面的 setAccount 已把登录状态置真,
             * 那里会随状态变化发起同一键的请求, 这里不再重复发起 */
            if(saved===true) {
                Assist.dlog("用户","登录成功: ",body.email);
            }
        });
        return true;
    }
    /* 退出登录: 先请求服务端作废登录状态秘钥, 再清本地记录与头像;
     * 服务端不在或拒绝也照常清本地, 本地清完之后这把秘钥没有再用的地方 */
    function logout() {
        if(email==="") {
            return false;
        }
        /* 先留存邮箱: 下面的回调在清账号之后才执行, 届时 email 已为空串 */
        var emailOne=email;
        Assist.dlog("用户","退出登录: ",emailOne);
        if(sessionKey!=="") {
            postWithSession("user/logout",{},function(sent,status,body) {
                if(sent!==true || status<200 || status>=300) {
                    Assist.dwarn("用户","服务端退出失败: 状态 ",status,", 本地记录仍按已退出处理");
                    return;
                }
                Assist.dlog("用户","服务端已作废登录状态: ",emailOne);
            });
        }
        GlobalFileStorage.clearAccount();
        codeSent=false;
        resendAt=0;
        nowMs=Date.now();
        setHint(false,"已退出登录");
        return true;
    }
    /* 拉取用户资料: 服务端给出的累计听歌秒数落到本地, 等级由本地按公式派生;
     * 登录后与每次成功上报后各拉一次 */
    function requestProfile() {
        if(loggedIn!==true || sessionKey==="") {
            return false;
        }
        getWithSession("user/profile",function(sent,status,body) {
            if(sent!==true || status<200 || status>=300 || body===null || body.ok!==true) {
                if(status===401) {
                    /* 秘钥被服务端判定无效: 本地登录状态立即失效 */
                    Assist.dwarn("用户","登录状态已失效, 本地退出: ",status);
                    GlobalFileStorage.clearAccount();
                    nowMs=Date.now();
                    setHint(true,"登录状态已失效, 请重新登录");
                }
                return;
            }
            if(typeof body.totalSeconds==="number") {
                GlobalFileStorage.setListenTotalSeconds(body.totalSeconds);
                Assist.dlog("用户","累计听歌: ",body.totalSeconds," 秒, 等级 ",levelOf(body.totalSeconds));
            }
        });
        return true;
    }
    /* 上报一段听歌秒数: seconds 为本次要计入的秒数, 服务端按当日上限截断并回执累计值;
     * 失败时把这段秒数暂存为待补报, 下次成功时随下一段一起上报 */
    function reportListenSeconds(seconds) {
        var chunk=Math.floor(Number(seconds));
        if(!(chunk>0)) {
            return false;
        }
        if(loggedIn!==true || sessionKey==="") {
            return false;
        }
        var carry=(typeof GlobalFileStorage.listenState.pendingSeconds==="number"
                   ? GlobalFileStorage.listenState.pendingSeconds:0);
        var reportSeconds=chunk+carry;
        postWithSession("user/listen",{"seconds":reportSeconds},function(sent,status,body) {
            if(sent!==true) {
                /* 网络不通: 这段先记在本地, 服务端恢复后补报 */
                GlobalFileStorage.addListenPendingSeconds(chunk);
                Assist.dwarn("用户","听歌上报未送达, 暂存 ",chunk," 秒待补报");
                return;
            }
            if(status<200 || status>=300 || body===null || body.ok!==true) {
                if(status===401) {
                    Assist.dwarn("用户","登录状态已失效, 本地退出: ",status);
                    GlobalFileStorage.clearAccount();
                    nowMs=Date.now();
                    setHint(true,"登录状态已失效, 请重新登录");
                    return;
                }
                /* 服务端明确拒绝(如冷却中): 段落保留待补报 */
                GlobalFileStorage.addListenPendingSeconds(chunk);
                Assist.dwarn("用户","听歌上报被拒: 状态 ",status,", 暂存 ",chunk," 秒待补报");
                return;
            }
            GlobalFileStorage.clearListenPending();
            if(typeof body.totalSeconds==="number") {
                GlobalFileStorage.setListenTotalSeconds(body.totalSeconds);
            }
            Assist.dlog("用户","听歌上报: 服务端确认 ",(typeof body.accepted==="number"? body.accepted:0),
                        " 秒, 累计 ",(typeof body.totalSeconds==="number"? body.totalSeconds:0)," 秒");
        });
        return true;
    }
    /* 拉取头像: 两种清晰度各一次, force 为真时忽略本地已有的文件;
     * 不是纯数字 QQ 邮箱时不发请求, 并把旧头像清掉 */
    function requestAvatars(force) {
        var dir=GlobalFileStorage.avatarCacheDir();
        if(qqNumber==="" || dir==="" || loggedIn!==true) {
            if(qqNumber==="") {
                avatarSmall="";
                avatarLarge="";
            }
            return false;
        }
        AppNetHelper.fetchCachedFile(avatarUrlOf(Define.avatarSpecSmall),
                                     "avatar:small:"+qqNumber,dir,force===true,
                                     avatarCacheNameOf(Define.avatarSpecSmall));
        AppNetHelper.fetchCachedFile(avatarUrlOf(Define.avatarSpecLarge),
                                     "avatar:large:"+qqNumber,dir,force===true,
                                     avatarCacheNameOf(Define.avatarSpecLarge));
        return true;
    }
    /* 起跑: 核对落盘记录, 该清就清, 有效就补一次头像 */
    function refresh() {
        nowMs=Date.now();
        if(email==="" ) {
            return false;
        }
        if(signOk!==true) {
            Assist.dwarn("用户","登录记录签名不符, 视为未登录: ",email);
            GlobalFileStorage.clearAccount();
            setHint(true,"本地登录记录被改动过, 请重新登录");
            return false;
        }
        if(nowMs>=expireAt) {
            Assist.dlog("用户","登录状态已过期: ",email);
            GlobalFileStorage.clearAccount();
            setHint(true,"登录状态已保留满 "+String(Define.loginKeepDays)+" 天, 请重新登录");
            return false;
        }
        requestAvatars(false);
        return true;
    }

    /* QQ 号变化(切换账号或退出): 先清掉上一份头像地址, 免得新账号短暂显示旧头像 */
    onQqNumberChanged: {
        avatarSmall="";
        avatarLarge="";
    }
    /* 登录状态变化: 刚登录时补头像(登录路径上的唯一取头像处), 退出或过期时清掉头像地址 */
    onLoggedInChanged: {
        if(loggedIn===true) {
            requestAvatars(false);
        } else {
            avatarSmall="";
            avatarLarge="";
        }
    }
    /* 请求超时: 中止在途请求并给出提示, 避免界面一直停在"发送中" */
    Timer {
        id: reqTimer;
        interval: Define.loginRequestTimeoutMs;
        repeat: false;
        onTriggered: {
            var one=accountRoot.pendingXhr;
            accountRoot.pendingXhr=null;
            if(one!==null) {
                one.__aborted=true;
                try {
                    one.abort();
                } catch(e) {
                }
            }
            accountRoot.phase=0;
            accountRoot.setHint(true,"请求超时, 请检查网络后重试");
            Assist.dwarn("用户","请求超时");
        }
    }
    /* 冷却倒计时: 只在冷却期内每秒推进, 供页面显示"重新发送(nn 秒)" */
    Timer {
        interval: 1000;
        repeat: true;
        running: (accountRoot.resendLeftSeconds>0);
        onTriggered: {
            accountRoot.nowMs=Date.now();
        }
    }
    /* 保留期复核: 已登录时每 30 秒推进一次时间基准 */
    Timer {
        interval: 30000;
        repeat: true;
        running: (accountRoot.loginAt>0);
        onTriggered: {
            accountRoot.nowMs=Date.now();
        }
    }
    /* 头像就绪与失败: 只认本次 QQ 号的两条请求, 失败只记日志 */
    Connections {
        target: AppNetHelper;
        function onCachedFileReady(cacheKey,localPath) {
            if(cacheKey==="avatar:small:"+accountRoot.qqNumber) {
                accountRoot.avatarSmall=String(localPath);
                accountRoot.avatarRev=accountRoot.avatarRev+1;
            } else if(cacheKey==="avatar:large:"+accountRoot.qqNumber) {
                accountRoot.avatarLarge=String(localPath);
                accountRoot.avatarRev=accountRoot.avatarRev+1;
            }
        }
        function onCachedFileFailed(cacheKey,reason) {
            if(String(cacheKey).indexOf("avatar:")!==0) {
                return;
            }
            Assist.dwarn("用户","头像缓存失败: ",cacheKey,", ",reason);
        }
    }
    Component.onCompleted: {
        refresh();
    }
}
