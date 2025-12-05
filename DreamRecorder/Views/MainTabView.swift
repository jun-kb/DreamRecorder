import SwiftUI

// タブの種類を定義
enum TabItem: Int, CaseIterable {
    case home
    case allDreams
    case aiAnalysis
    case settings
    
    var title: String {
        switch self {
        case .home: return "ホーム"
        case .allDreams: return "一覧"
        case .aiAnalysis: return "AI分析"
        case .settings: return "設定"
        }
    }
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .allDreams: return "list.bullet"
        case .aiAnalysis: return "brain.head.profile"
        case .settings: return "gearshape.fill"
        }
    }
}

// メインのタブビュー
struct MainTabView: View {
    @EnvironmentObject var dreamService: DreamService
    @EnvironmentObject var reflectionService: ReflectionService
    @EnvironmentObject var authManager: AuthManager
    
    @State private var selectedTab: TabItem = .home
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // ホーム（カレンダー＋当日の記録）
            HomeView()
                .tabItem {
                    Label(TabItem.home.title, systemImage: TabItem.home.icon)
                }
                .tag(TabItem.home)
            
            // 夢一覧
            AllDreamsView()
                .tabItem {
                    Label(TabItem.allDreams.title, systemImage: TabItem.allDreams.icon)
                }
                .tag(TabItem.allDreams)
            
            // AI分析
            AIAnalysisView()
                .tabItem {
                    Label(TabItem.aiAnalysis.title, systemImage: TabItem.aiAnalysis.icon)
                }
                .tag(TabItem.aiAnalysis)
            
            // 設定
            SettingsView()
                .tabItem {
                    Label(TabItem.settings.title, systemImage: TabItem.settings.icon)
                }
                .tag(TabItem.settings)
        }
        .tint(.dreamAccent)
    }
}

