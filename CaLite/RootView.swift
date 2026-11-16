import SwiftUI

/// 底部只留三个入口，轨迹 / 记录 / 全景照片从首页进入（与源码单一首页 + 二级页一致）
struct RootView: View {
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            CarHomeView()
                .tabItem { Label("车控", systemImage: "car.fill") }
                .tag(0)

            NavigationView { CarStatusView() }
                .navigationViewStyle(.stack)
                .tabItem { Label("车况", systemImage: "speedometer") }
                .tag(1)

            NavigationView { MoreView() }
                .navigationViewStyle(.stack)
                .tabItem { Label("我的", systemImage: "person.crop.circle.fill") }
                .tag(2)
        }
        .tint(KH.blue)
    }
}
