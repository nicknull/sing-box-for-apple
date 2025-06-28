//
//  SyncView.swift
//  SFI
//
//  Created by xiaokang chen on 2024/3/12.
//

import SwiftUI
import FirebaseRemoteConfig
import Defaults
import Lottie
import NetworkExtension
#if os(iOS)
import SPIndicator
#elseif os(tvOS)
import ExytePopupView

#endif

struct SyncView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var monitor = MonitoringNetworkState()
    @State var showingPopup: Bool = false
    @State var errorStr:String = ""

    var body: some View {
        VStack{
            LottieView(animation: .named("Sync"))
                .looping()
                .padding(.horizontal,40)
                .onChange(of: monitor.isConnected, perform: { newValue in
                    if newValue == true  {
                        getService()
                    }
                })
//                .popup(isPresented: $showingPopup) { 
//                    HStack{
//                        Text(errorStr)
//                            .padding(40)
//                    }
//                    .background(.gray)
//                    .cornerRadius(30.0)
//                    
//                }customize: {
//                    $0.autohideIn(2)
//                }
            Spacer()
            Text("正在更新配置信息...")
                .padding()
            Text("如遇更新失败，可尝试重启APP")
                .font(.footnote)
                .padding()
        }.background(.gray)

    }
    
    func getService()  {
        NewNetWorkRequest(AQAPIService.getService, successCallback: {responseModel in
            if let data = Data(base64Encoded: responseModel.dataString ?? "") {
                if let decodedString = String(data: data, encoding: .utf8)?.removingPercentEncoding {
                    let components = decodedString.components(separatedBy: "|")
                    for (index, element) in components.enumerated() {
                        let urlStr = element.removingPercentEncoding!
                        // 将 Data 转换为字符串
                        if( index == 0 )
                        {
                            if (URL(string: urlStr) != nil) && ((URL(string: urlStr)?.scheme) != nil) {
                                Defaults[.host] = urlStr
                                Defaults[.getServiceTime] = Date().timeIntervalSince1970
                                errorStr = "服务地址已更新"
                                showingPopup.toggle()
                            }
                        }
                        if( index == 2 )
                        {
                            if (URL(string: urlStr) != nil) && ((URL(string: urlStr)?.scheme) != nil) {
//                                        Defaults[.repair] = urlStr
                            }
                        }

                    }
                }
            }else{
                errorStr = "服务地址更新出错"
                showingPopup.toggle()
            }
            dismiss()
        },failureCallback: { responseModel in
            errorStr = "服务地址更新出错"
            showingPopup.toggle()
            dismiss()
        })
    }
}

