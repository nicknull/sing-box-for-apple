import Foundation
import Library
import SwiftUI
import Defaults
@main
struct Application: App {
    
    @UIApplicationDelegateAdaptor private var appDelegate: ApplicationDelegate
    @StateObject private var environments = ExtensionEnvironments()
    @StateObject private var userManager = UserManager()
    @State var showSyncView:Bool = false
    let serviceInterval: TimeInterval = 3 * 24 * 60 * 60 // 3 days in seconds

    var body: some Scene {
        WindowGroup {
            TabView{
                DashBoardView()
                    .tabItem {
                        Image(systemName: "house")
                        Text("闪电加速器")
                    }
                    .tag(0)
                    .environment(\.trafficFormatter, ClashTrafficFormatterKey.defaultValue)
                    .environmentObject(environments)
                    .environmentObject(userManager)
                    .navigationTitle("闪电加速器");
                
            }
            .fullScreenCover(isPresented: $showSyncView, content: {
                SyncView()
            })
            .onAppear(){
                let getService = Defaults[.getService];
                let timeInterval =  Date().timeIntervalSince1970

                if(timeInterval-getService>serviceInterval){
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { // 延迟2秒
                        withAnimation {
                            showSyncView.toggle()
                        }
                    }

                }

            }
        }
    }
}
