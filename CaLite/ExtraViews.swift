import SwiftUI
import MapKit

// MARK: - 今日行车轨迹
struct TrackView: View {
    @State private var pts: [CLLocationCoordinate2D] = []
    @State private var loading = true
    @State private var err = ""

    var body: some View {
        ZStack {
            TrackMap(points: pts)
                .ignoresSafeArea(edges: .bottom)
            if loading {
                ProgressView("加载轨迹…")
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else if pts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.system(size: 34)).foregroundColor(C.faint)
                    Text(err.isEmpty ? "今天还没有行车轨迹" : err)
                        .font(.system(size: 13)).foregroundColor(C.muted)
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .navigationTitle("今日行车轨迹")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { load() } label: {
                    Image(systemName: "arrow.clockwise").foregroundColor(C.blue)
                }
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        loading = true
        CarAPI.shared.trackPoints { p in
            pts = p.map { CLLocationCoordinate2D(latitude: $0.0, longitude: $0.1) }
            if p.isEmpty { err = "" }
            loading = false
        }
    }
}

/// MKMapView 包装（iOS 16 没有 MapPolyline）
struct TrackMap: UIViewRepresentable {
    let points: [CLLocationCoordinate2D]

    func makeUIView(context: Context) -> MKMapView {
        let v = MKMapView()
        v.delegate = context.coordinator
        v.showsUserLocation = false
        return v
    }

    func updateUIView(_ v: MKMapView, context: Context) {
        v.removeOverlays(v.overlays)
        v.removeAnnotations(v.annotations)
        guard points.count > 1 else {
            if let p = points.first {
                v.setRegion(MKCoordinateRegion(center: p, latitudinalMeters: 1200,
                                               longitudinalMeters: 1200), animated: true)
                v.addAnnotation(MKPointAnnotation.custom(p, "车辆"))
            }
            return
        }
        let line = MKPolyline(coordinates: points, count: points.count)
        v.addOverlay(line)
        let a = MKPointAnnotation.custom(points[0], "起点")
        let b = MKPointAnnotation.custom(points[points.count - 1], "终点")
        v.addAnnotations([a, b])
        v.setVisibleMapRect(line.boundingMapRect,
                            edgePadding: UIEdgeInsets(top: 60, left: 40, bottom: 60, right: 40),
                            animated: true)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let l = overlay as? MKPolyline else { return MKOverlayRenderer() }
            let r = MKPolylineRenderer(polyline: l)
            r.strokeColor = UIColor(red: 47/255, green: 111/255, blue: 181/255, alpha: 1)
            r.lineWidth = 5
            r.lineCap = .round
            return r
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let id = "pin"
            let v = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            v.annotation = annotation
            v.canShowCallout = true
            return v
        }
    }
}

extension MKPointAnnotation {
    static func custom(_ c: CLLocationCoordinate2D, _ title: String) -> MKPointAnnotation {
        let a = MKPointAnnotation()
        a.coordinate = c
        a.title = title
        return a
    }
}

// MARK: - 操作记录（本机执行结果 + 服务器全量，对齐源码 HistoryActivity）
struct HistoryView: View {
    @State private var rows: [[String: Any]] = []
    @State private var local: [OpLog] = []
    @State private var loading = true
    @State private var errMsg = ""

    var body: some View {
        List {
            Section {
                if local.isEmpty {
                    Text("还没有本机记录").foregroundColor(C.muted).font(.system(size: 12))
                } else {
                    ForEach(local) { log in
                        HStack(spacing: 10) {
                            Image(systemName: log.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(log.ok ? C.green : C.red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(log.cmd)
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundColor(C.txt)
                                Text(timeText(log.time))
                                    .font(.system(size: 11)).foregroundColor(C.faint)
                            }
                            Spacer()
                            if !log.ok && !log.msg.isEmpty {
                                Text(log.msg)
                                    .font(.system(size: 10.5))
                                    .foregroundColor(C.red)
                                    .lineLimit(2)
                                    .frame(maxWidth: 130, alignment: .trailing)
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("本机执行结果")
                    Spacer()
                    if !local.isEmpty {
                        Button("清空") { OpLogStore.clear(); local = [] }
                            .font(.system(size: 11))
                    }
                }
            }

            Section {
                if loading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if !errMsg.isEmpty {
                    Text(errMsg).font(.system(size: 12)).foregroundColor(C.muted)
                } else if rows.isEmpty {
                    Text("服务器没有记录").foregroundColor(C.muted).font(.system(size: 12))
                } else {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                        HStack(spacing: 10) {
                            Image(systemName: icon((r["name"] as? String) ?? ""))
                                .font(.system(size: 14))
                                .foregroundColor(C.blue)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text((r["name"] as? String) ?? "控车操作")
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundColor(C.txt)
                                Text((r["time"] as? String) ?? "")
                                    .font(.system(size: 11)).foregroundColor(C.faint)
                            }
                            Spacer()
                            let st = (r["status"] as? String) ?? ""
                            Text(statusText(st))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(statusColor(st))
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: {
                Text("长安服务器记录（近 6 个月）")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("操作记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { load() } label: {
                    Image(systemName: "arrow.clockwise").foregroundColor(C.blue)
                }
            }
        }
        .onAppear {
            local = OpLogStore.load()
            load()
        }
    }

    private func timeText(_ t: Double) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm:ss"
        return f.string(from: Date(timeIntervalSince1970: t))
    }

    private func load() {
        loading = true
        errMsg = ""
        CarAPI.shared.controlHistory { r in
            rows = r
            loading = false
            if r.isEmpty { errMsg = "" }
        }
    }

    private func statusText(_ s: String) -> String {
        if s.isEmpty { return "" }
        if s == "1" || s.lowercased() == "true" || s == "成功" || s.lowercased() == "success" { return "成功" }
        if s == "0" || s.lowercased() == "false" { return "失败" }
        return s
    }

    private func statusColor(_ s: String) -> Color {
        let t = statusText(s)
        if t == "成功" { return C.green }
        if t == "失败" { return C.red }
        return C.muted
    }

    private func icon(_ name: String) -> String {
        if name.contains("解") && name.contains("锁") { return "lock.open" }
        if name.contains("锁") { return "lock.fill" }
        if name.contains("天窗") { return "sun.max" }
        if name.contains("窗") { return "rectangle.split.3x1" }
        if name.contains("空调") { return "snowflake" }
        if name.contains("发动机") || name.contains("启动") { return "power" }
        if name.contains("笛") { return "speaker.wave.2.fill" }
        if name.contains("灯") { return "lightbulb" }
        return "car"
    }
}

// MARK: - 全景照片（支持拍摄 + 全屏预览可关闭）
struct PhotoView: View {
    @State private var items: [[String: Any]] = []
    @State private var loading = true
    @State private var shooting = false
    @State private var preview: PhotoItem?
    @State private var toast: String?
    @State private var errMsg = ""

    private let cols = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                shootBar
                if loading {
                    ProgressView("加载中…").padding(.top, 50)
                } else if items.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 34)).foregroundColor(C.faint)
                        Text(errMsg.isEmpty ? "还没有全景照片" : errMsg)
                            .font(.system(size: 13)).foregroundColor(C.muted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                    .padding(.horizontal, 30)
                } else {
                    LazyVGrid(columns: cols, spacing: 8) {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                            let thumb = (it["thumb"] as? String) ?? ""
                            let full = (it["url"] as? String) ?? thumb
                            Button {
                                if let u = URL(string: full) {
                                    preview = PhotoItem(url: u,
                                                        thumb: URL(string: thumb),
                                                        time: (it["time"] as? String) ?? "")
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    AsyncImage(url: URL(string: thumb)) { ph in
                                        if let img = ph.image {
                                            img.resizable().scaledToFill()
                                        } else if ph.error != nil {
                                            Rectangle().fill(C.bg)
                                                .overlay(Image(systemName: "photo")
                                                    .foregroundColor(C.faint))
                                        } else {
                                            Rectangle().fill(C.bg).overlay(ProgressView())
                                        }
                                    }
                                    .frame(height: 130)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    Text((it["time"] as? String) ?? "")
                                        .font(.system(size: 10.5)).foregroundColor(C.faint)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(C.bg.ignoresSafeArea())
        .navigationTitle("全景照片")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { load() } label: {
                    Image(systemName: "arrow.clockwise").foregroundColor(C.blue)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let t = toast {
                Text(t)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(C.txt.opacity(0.9))
                    .clipShape(Capsule())
                    .padding(.bottom, 30)
            }
        }
        .fullScreenCover(item: $preview) { p in
            PhotoPreview(item: p)
        }
        .onAppear(perform: load)
    }

    private var shootBar: some View {
        Button { shoot() } label: {
            HStack(spacing: 8) {
                if shooting {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "camera.fill").font(.system(size: 14))
                }
                Text(shooting ? "正在拍照，请稍候…" : "拍摄全景照片")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(shooting ? C.blue.opacity(0.6) : C.blue)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(shooting)
    }

    private func shoot() {
        if CarAPI.shared.controlPin.isEmpty {
            toast = "请先在首页右上角设置控车码"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { toast = nil }
            return
        }
        shooting = true
        // 源码 PhotoActivity：Api.execute("photograph")
        CarAPI.shared.control(cmd: "photograph") { ok, msg in
            shooting = false
            toast = ok ? "拍照指令已发送，等 5 秒后自动刷新" : "拍照失败：\(msg)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { toast = nil }
            if ok {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { load() }
            }
        }
    }

    private func load() {
        loading = true
        CarAPI.shared.panorama { r in
            items = r
            loading = false
        }
    }
}

struct PhotoItem: Identifiable {
    let url: URL
    let thumb: URL?
    let time: String
    var id: String { url.absoluteString }
}

/// 全屏预览：顶部有关闭按钮；原图失败自动回落缩略图（与源码 WebView 的 onerror 一致）
struct PhotoPreview: View {
    let item: PhotoItem
    @Environment(\.dismiss) private var dismiss
    @State private var saved = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RemoteImage(primary: item.url, fallback: item.thumb)
                .padding(.vertical, 60)

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text(item.time)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Button { saveImage() } label: {
                        Image(systemName: saved ? "checkmark" : "square.and.arrow.down")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer()
            }
        }
    }

    private func saveImage() {
        URLSession.shared.dataTask(with: item.url) { data, _, _ in
            if let data = data, let img = UIImage(data: data) {
                DispatchQueue.main.async {
                    UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                    saved = true
                }
                return
            }
            // 原图失败就用缩略图
            guard let t = item.thumb else { return }
            URLSession.shared.dataTask(with: t) { d2, _, _ in
                guard let d2 = d2, let img2 = UIImage(data: d2) else { return }
                DispatchQueue.main.async {
                    UIImageWriteToSavedPhotosAlbum(img2, nil, nil, nil)
                    saved = true
                }
            }.resume()
        }.resume()
    }
}

/// 先原图、失败回落缩略图；都失败才报错，可重试
struct RemoteImage: View {
    let primary: URL?
    let fallback: URL?

    @State private var image: UIImage?
    @State private var failed = false
    @State private var attempt = 0

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            } else if failed {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 30)).foregroundColor(.gray)
                    Text("图片加载失败")
                        .font(.system(size: 13)).foregroundColor(.gray)
                    Button("重试") {
                        failed = false
                        attempt += 1
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())
                }
            } else {
                ProgressView().tint(.white)
            }
        }
        .task(id: attempt) { await load() }
    }

    private func load() async {
        if let d = await fetch(primary), let img = UIImage(data: d) {
            await MainActor.run { image = img }
            return
        }
        if let f = fallback, let d = await fetch(f), let img = UIImage(data: d) {
            await MainActor.run { image = img }
            return
        }
        await MainActor.run { failed = true }
    }

    private func fetch(_ u: URL?) async -> Data? {
        guard let u = u else { return nil }
        var req = URLRequest(url: u)
        req.timeoutInterval = 20
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        do {
            let (d, resp) = try await URLSession.shared.data(for: req)
            if let code = (resp as? HTTPURLResponse)?.statusCode, code >= 400 { return nil }
            return d
        } catch {
            return nil
        }
    }
}
