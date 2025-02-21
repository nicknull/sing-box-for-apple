//
//  RepairView.swift
//  SFT
//
//  Created by xiaokang chen on 2024/1/28.
//

import SwiftUI
import Combine
import Defaults
import ExytePopupView
#if os(iOS)
import SafariServices
import BetterSafariView
#elseif os(tvOS)
import GCDWebServer
import QRCode
#endif
import SPIndicator


struct RepairView: View {
    @State var errorStr:String = ""
    @State var showingPopup: Bool = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userManager: UserManager

    @State var showLink:Bool = false
    @State var link:String = ""
    let webServer = GCDWebServer()

    var body: some View {
        NavigationStack {
            HStack{
                VStack{
                    Text("修复步骤：")
                        .font(.title)
                        .bold()
                    Spacer()
                        .frame(height: 140)
                    HStack{
                        
                        VStack(alignment: .leading, content: {
                            Text("①  下载闪电加速器iOS版")
                                .font(.subheadline)
                                .frame(height: 40)
                            Text("②  打开闪电加速器iOS版")
                                .font(.subheadline)
                                .frame(height: 40)
                            Text("③  点击左上角按钮进入个人中心")
                                .font(.subheadline)
                                .frame(height: 40)
                            Text("④  点击“扫码修复”")
                                .font(.subheadline)
                                .frame(height: 40)
                            Text("⑤  修复完成")
                                .font(.subheadline)
                                .frame(height: 40)
                        })


                    }
                    Spacer()
                    Text("请先确保您的iOS客户端能够正常的开启加速功能")
                        .font(.footnote)

                }
                    .frame(width: 800)
                VStack{
                    Spacer()
                    Rectangle()
                        .frame(width: 2) // 根据需要调整分割线的长度
                        .foregroundColor(.white) // 分割线的颜色
                        .border(Color.gray, width: 1) // 设置边框颜色和宽度
                    Spacer()

                }

                VStack{       
                    Spacer()

                    HStack{
                        Spacer()

                        Image(uiImage: UIImage(cgImage: getQRImage()))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 400)
                            .padding(.horizontal, 50)
                        Spacer()

                    }
                    
                    Spacer()

                    Text("请对准二维码")
                        .foregroundStyle(.secondary)
                        .frame(height: 100)
                }
                
            }
            .navigationBarItems(trailing: Button("取消") {
                dismiss()
            })
#if os(iOS)
            .navigationTitle("修复")
            .navigationBarTitleDisplayMode(.inline)
#endif
            
            .popup(isPresented: $showingPopup) {
                HStack{
                    Text(errorStr)
#if os(iOS)
                        .padding(10)
#elseif os(tvOS)
                        .padding(40)
#endif
                    
                }
                .background(.gray)
#if os(iOS)
                .cornerRadius(10.0)
#elseif os(tvOS)
                .cornerRadius(30.0)
#endif
                
            } customize: {
                $0.autohideIn(2)
            }
            
        }
        .onAppear(){
            startServer()
        }
        .onDisappear(){
            if(webServer.isRunning){
                webServer.stop()
            }
        }
    }
    
    func repair() {        
    }
    
    func getQRImage() -> CGImage {
        do {
            let doc = try QRCode.Document(utf8String:link)
            let cgImage = try doc.cgImage(dimension: 400)
            return cgImage
        } catch {
            let defaultIcon = UIImage(named: "defaultIcon") // 假设您有一个名为"defaultIcon"的图标资源
            return defaultIcon!.cgImage!
        }
    }

     func startServer() {
        webServer.addHandler(forMethod: "GET", path: "/repair", request: GCDWebServerRequest.self, processBlock: { request in
            switch request.path {
            case "/repair":
                guard let query = request.query else{
                    errorStr = "无参数"
                    showingPopup.toggle()
                    return GCDWebServerDataResponse(jsonObject: ["error":1,"msg":"无参数"])
                }
                guard let address = query["address"] else{
                    errorStr = "无有效参数"
                    showingPopup.toggle()
                    return GCDWebServerDataResponse(jsonObject: ["error":1,"msg":"无有效参数"])
                }
                Defaults[.host] = address
                userManager.reload()
                dismiss()
                errorStr = "修复成功，请您重启后继续使用"
                showingPopup.toggle()
                return GCDWebServerDataResponse(jsonObject: ["error":0,"msg":"修复成功"])
            default:
                errorStr = "unknown request"
                showingPopup.toggle()

                return GCDWebServerDataResponse(jsonObject: ["error":1,"msg":"unknown request"])
            }
        })
         webServer.start(withPort: UInt(UInt16(arc4random_uniform(40000) + 1024)), bonjourName: "MyLocalServer")
         link = "http://" + webServer.serverURL!.host()!+":\(webServer.port)"

    }

}

#Preview {
    RepairView()
}
