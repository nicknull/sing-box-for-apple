import Foundation
import Library
import SwiftUI
import Defaults
import SPIndicator

@main
struct Application: App {
    @UIApplicationDelegateAdaptor private var appDelegate: ApplicationDelegate
    @StateObject private var environments = ExtensionEnvironments()
    @StateObject private var userManager = UserManager()
    @State var syncingConfig:Bool = false
    @State var synced:Bool = false
    @State var showSyncView:Bool = false
    let serviceInterval: TimeInterval = 3 * 24 * 60 * 60 // 3 days in seconds

    var body: some Scene {
        WindowGroup {
            NavigationStack{
                DashBoardView()
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
                    showSyncView.toggle()
                }
            }
            .onOpenURL { url in
#if os(iOS)
                guard let base64EncodedString =  url.queryItems()["repair"] else{
                    SPIndicator.present(title: "修复失败", message: "请重新获取修复邮件，当前无法修复", preset: .done)
                    return ;
                }
                guard let decodedData = Data(base64Encoded: base64EncodedString) else{
                    SPIndicator.present(title: "修复失败", message: "请重新获取修复邮件", preset: .done)

                    return ;
                }
                guard let decodedString = String(data: decodedData, encoding: .utf8)  else{
                    SPIndicator.present(title: "修复失败", message: "请重新联系我们", preset: .done)
                    return ;
                }
                guard URL(string: decodedString) != nil else{
                    SPIndicator.present(title: "修复失败", message: "您的修复地址有误", preset: .done)
                    return ;
                }
                Defaults[.host] = decodedString
                SPIndicator.present(title: "修复成功", message: "请重启后再试", preset: .done)
                userManager.reload()
#endif

            }

        }
    }
    
}
