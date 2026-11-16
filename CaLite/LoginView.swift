import SwiftUI

/// 登录：两步，与源码 LoginActivity → AcAuthActivity 一致
/// 1) 手机号 + 短信验证码 + 控车码 → m.iov 令牌（车况/控车必需）
/// 2) 扫码授权 → 开放平台 access_token + secret_key（车型、空调、VCS 签名接口需要）
struct LoginView: View {
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss

    private enum Step { case sms, qr }
    @State private var step: Step = .sms

    // 短信登录
    @State private var phone = ""
    @State private var code = ""
    @State private var pin = ""
    @State private var countdown = 0
    @State private var busy = false
    @State private var status = ""
    @State private var isError = false
    @State private var timer: Timer?

    // 扫码授权
    @State private var qrImage: UIImage?
    @State private var qrId = ""
    @State private var qrText = "正在生成二维码…"
    @State private var polling = false
    @State private var pollTimer: Timer?

    @State private var showTokenSheet = false
    @State private var tokenText = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    if step == .sms { smsForm } else { qrPanel }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
            }
            .background(KH.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }.foregroundColor(KH.grey)
                }
            }
            .sheet(isPresented: $showTokenSheet) { tokenSheet }
        }
        .onDisappear {
            timer?.invalidate()
            pollTimer?.invalidate()
            polling = false
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(KH.blue)
                    .frame(width: 58, height: 58)
                Image(systemName: "car.side.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white)
            }
            Text(step == .sms ? "远程控车" : "扫码授权")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(KH.text)
            Text(step == .sms ? "手机号验证码登录，与官方 App 同账号"
                              : "空调与车型需要开放平台授权")
                .font(.system(size: 12.5))
                .foregroundColor(KH.grey)
        }
        .padding(.top, 20)
    }

    // MARK: - 短信登录

    private var smsForm: some View {
        VStack(spacing: 12) {
            fieldBox(icon: "phone", placeholder: "手机号", text: $phone, keyboard: .numberPad)

            HStack(spacing: 8) {
                fieldBox(icon: "checkmark.shield", placeholder: "短信验证码",
                         text: $code, keyboard: .numberPad)
                Button { sendCode() } label: {
                    Text(countdown > 0 ? "\(countdown)s" : "获取验证码")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(KH.blue)
                        .frame(width: 100, height: 50)
                        .background(KH.blue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(KH.blue.opacity(0.28), lineWidth: 1))
                }
                .disabled(countdown > 0 || busy)
            }

            fieldBox(icon: "lock.shield", placeholder: "控车码（6 位，控车加密用）",
                     text: $pin, keyboard: .numberPad, secure: true)

            Button { doLogin() } label: {
                HStack(spacing: 6) {
                    if busy { ProgressView().tint(.white) }
                    Text(busy ? "登录中…" : "登录")
                        .font(.system(size: 15.5, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(busy ? KH.blue.opacity(0.6) : KH.blue)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .disabled(busy)

            if !status.isEmpty {
                Text(status)
                    .font(.system(size: 12))
                    .foregroundColor(isError ? KH.red : KH.grey)
                    .multilineTextAlignment(.center)
            }

            Divider().padding(.vertical, 2)

            HStack(spacing: 16) {
                Button { step = .qr; loadQr() } label: {
                    Text("扫码授权").font(.system(size: 12.5)).foregroundColor(KH.blue)
                }
                Button { showTokenSheet = true } label: {
                    Text("粘贴 token").font(.system(size: 12.5)).foregroundColor(KH.blue)
                }
            }
        }
    }

    // MARK: - 扫码授权（照 AcAuthActivity）

    private var qrPanel: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                ZStack {
                    if let img = qrImage {
                        Image(uiImage: img)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 240, height: 240)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(KH.bg)
                            .frame(width: 240, height: 240)
                            .overlay {
                                if qrText.contains("失败") {
                                    Image(systemName: "wifi.exclamationmark")
                                        .font(.system(size: 30)).foregroundColor(KH.grey)
                                } else {
                                    ProgressView()
                                }
                            }
                    }
                }
                .padding(.top, 18)

                Text(qrText)
                    .font(.system(size: 13))
                    .foregroundColor(KH.grey)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                    .padding(.horizontal, 10)
                Spacer().frame(height: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: 0xE6EBF1), lineWidth: 1))
            .padding(.top, 20)

            Button { loadQr() } label: {
                Text("刷新二维码")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(KH.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.top, 16)

            Button { finish() } label: {
                Text("暂不授权，先进入")
                    .font(.system(size: 13))
                    .foregroundColor(KH.blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .padding(.top, 4)

            if !status.isEmpty {
                Text(status)
                    .font(.system(size: 12))
                    .foregroundColor(isError ? KH.red : KH.grey)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }

            Text("截图保存上方二维码，打开「引力域」App → 我的爱车右上角「扫一扫」→ 选本地图片完成授权。")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: 0x8A94A3))
                .lineSpacing(3)
                .padding(.top, 16)

            Button { step = .sms } label: {
                Text("← 返回短信登录").font(.system(size: 12.5)).foregroundColor(KH.grey)
            }
            .padding(.top, 14)
        }
    }

    // MARK: - 组件

    private func fieldBox(icon: String, placeholder: String, text: Binding<String>,
                          keyboard: UIKeyboardType = .default, secure: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(Color(hex: 0xA9B3BE))
                .frame(width: 20)
            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .font(.system(size: 15))
            .keyboardType(keyboard)
            .autocapitalization(.none)
            .disableAutocorrection(true)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Color(hex: 0xE6EBF1), lineWidth: 1))
    }

    private var tokenSheet: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 14) {
                Text("格式：access_token|refresh_token|carId")
                    .font(.system(size: 11.5)).foregroundColor(KH.grey)
                TextEditor(text: $tokenText)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(height: 120)
                    .padding(10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: 0xE6EBF1)))
                Button { applyToken() } label: {
                    Text("使用这组凭证")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(KH.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Spacer()
            }
            .padding(20)
            .background(KH.bg.ignoresSafeArea())
            .navigationTitle("粘贴凭证")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showTokenSheet = false }
                }
            }
        }
    }

    // MARK: - 短信登录动作

    private func sendCode() {
        guard phone.count == 11 else {
            status = "手机号需要 11 位"; isError = true; return
        }
        busy = true
        status = "正在发送…"; isError = false
        CarAPI.shared.sendSms(phone: phone) { ok, msg in
            busy = false
            status = msg; isError = !ok
            if ok { startCountdown() }
        }
    }

    private func startCountdown() {
        countdown = 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if countdown > 0 { countdown -= 1 } else { timer?.invalidate() }
        }
    }

    private func doLogin() {
        guard phone.count == 11 else { status = "手机号需要 11 位"; isError = true; return }
        guard code.count >= 4 else { status = "请填写短信验证码"; isError = true; return }
        guard pin.count == 6 else { status = "控车码是 6 位数字"; isError = true; return }

        busy = true
        status = "登录中…"; isError = false
        CarAPI.shared.login(phone: phone, code: code, pin: pin) { ok, msg in
            busy = false
            status = msg; isError = !ok
            guard ok else { return }
            timer?.invalidate()
            // 与源码一致：没有开放平台令牌就进扫码授权页
            if CarAPI.shared.openToken.isEmpty {
                status = "已登录，接着扫码授权空调"
                step = .qr
                loadQr()
            } else {
                finish()
            }
        }
    }

    // MARK: - 扫码动作

    private func loadQr() {
        polling = false
        pollTimer?.invalidate()
        qrId = ""
        qrImage = nil
        qrText = "正在生成二维码…"
        CarAPI.shared.qrCreate { data, id in
            guard let data = data, !id.isEmpty, let img = UIImage(data: data) else {
                qrText = "二维码生成失败，请检查网络后点刷新"
                return
            }
            qrImage = img
            qrId = id
            qrText = "请扫码授权（二维码 10 分钟内有效）"
            startPoll()
        }
    }

    private func startPoll() {
        polling = true
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.8, repeats: true) { _ in
            guard polling, !qrId.isEmpty else { return }
            CarAPI.shared.qrStatus(qrId) { st in
                guard polling else { return }
                if st.hasPrefix("error:") {
                    qrText = "网络异常，请点刷新"
                    polling = false
                    pollTimer?.invalidate()
                    return
                }
                switch st {
                case "scanned":
                    qrText = "已扫码，请在手机上确认授权"
                case "authorized":
                    polling = false
                    pollTimer?.invalidate()
                    qrText = "授权成功，正在换取令牌…"
                    CarAPI.shared.qrExchange { err in
                        if let err = err {
                            qrText = err
                        } else {
                            qrText = "授权完成"
                            finish()
                        }
                    }
                case "expired":
                    qrText = "二维码已失效，正在重新生成…"
                    loadQr()
                default:
                    break   // unauthorized：继续轮询
                }
            }
        }
    }

    private func finish() {
        pollTimer?.invalidate()
        polling = false
        timer?.invalidate()
        // 立刻把凭据推给小组件，不等首页刷新
        AppGroupStore.syncCredentials()
        DispatchQueue.global(qos: .userInitiated).async {
            _ = CarAPI.shared.fetchStatus()
            AppGroupStore.syncFromPrefs()
        }
        dismiss()
        onDone()
    }

    // MARK: - 粘贴 token

    private func applyToken() {
        let raw = tokenText.trimmingCharacters(in: .whitespacesAndNewlines)
        var at = "", rt = "", cid = ""
        if raw.contains("{") {
            if let d = raw.data(using: .utf8),
               let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                at = (o["real_access_token"] as? String) ?? (o["access_token"] as? String) ?? ""
                rt = (o["real_refresh_token"] as? String) ?? (o["refresh_token"] as? String) ?? ""
                cid = (o["real_car_id"] as? String) ?? (o["car_id"] as? String) ?? ""
            }
        } else {
            let p = raw.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }
            if p.count >= 3 { at = p[0]; rt = p[1]; cid = p[2] }
            else if p.count == 1 { at = p[0] }
        }
        guard !at.isEmpty else {
            status = "没解析出 access_token"; isError = true
            showTokenSheet = false
            return
        }
        CarAPI.shared.accessToken = at
        if !rt.isEmpty { CarAPI.shared.refreshToken = rt }
        if !cid.isEmpty { CarAPI.shared.carId = cid }
        showTokenSheet = false
        busy = true
        status = "校验中…"; isError = false
        CarAPI.shared.loadCar { ok, name in
            busy = false
            if ok {
                status = "已登录 · \(name)"
                finish()
            } else if !cid.isEmpty {
                status = "凭证已保存，进入后手动刷新"
                finish()
            } else {
                status = "token 无效或已过期"; isError = true
            }
        }
    }
}
