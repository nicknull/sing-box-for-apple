//
//  UserView.swift
//  Pomelo
//
//  Created by xiaokang chen on 2023/3/22.
//

import SwiftUI
import Kingfisher
import DynamicColor
import Defaults
import StoreKit
import Library
import CodeScanner
#if DEBUG
import SharedCrashKit
#endif

struct UserView: View {
  @EnvironmentObject private var environments: ExtensionEnvironments
  @EnvironmentObject var userManager: UserManager
  @EnvironmentObject var appStateManager: AppStateManager
  
  @State var signOut = false
  @State private var copyToast: Bool = false
  @Environment(\.scenePhase) private var scenePhase

  @ObservedObject var purchaseXManager: PurchaseXManager = PurchaseXManager()
  @State public var products: [Product]?

  @AppStorage(ConstantKey.auth_data) private var auth_data = ""
  @AppStorage(ConstantKey.userInfojson) private var userInfoJsonStr = ""
  @AppStorage(ConstantKey.subscribeInfojson) private var subscribeInfoJsonStr = ""

  @State var errorAlert: Bool = false
  @State var errorTitle: String = ""
  @State var errorSubTitle: String = ""
  @State var successAlert: Bool = false
  @State var successMessage: String = ""

  @State var logOff = false
  @State var showScan = false
  @State private var isNavigatingToTickets = false
  var userInfo: UserInfoModel? {
    let decoder: JSONDecoder = JSONDecoder()
    decoder.allowsJSON5 = true
    let result = try? decoder.decode(UserInfoModel.self, from: userInfoJsonStr.data(using: .utf8)!)
    return result

  }
  var subscribe: SubscribeModel? {
    let decoder: JSONDecoder = JSONDecoder()
    decoder.allowsJSON5 = true
    let result = try? decoder.decode(
      SubscribeModel.self, from: subscribeInfoJsonStr.data(using: .utf8)!)
    return result
  }
  var webSite: URL = URL(string: "\(Defaults[.host])")!
  @Environment(\.trafficFormatter) private var formatter: NumberFormatter
  @Environment(\.dismiss) private var dismiss

  var body: some View {

    VStack {
      List {
        if (userInfo != nil) {
          Section {
            LabeledContent {
            } label: {
              HStack(spacing: 12) {
                KFImage(URL(string: (userInfo?.avatar_url)!)!)
                  .resizable()
                  .aspectRatio(contentMode: .fill)
                  .frame(width: 56, height: 56)
                  .clipShape(Circle())
                  .shadow(radius: 1)
                  .padding(.vertical, 8)
                VStack(alignment: .leading, spacing: 6) {
                  Text(userInfo?.email ?? "火星用户")
                    .font(.headline)
                    .foregroundColor(Color(hexString: "#EF8427"))
                  let date = Date(timeIntervalSince1970: userInfo?.expired_at ?? 100 * 365 * 24 * 60 * 60)
                  Text("到期：" + date.date2string())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                Spacer()
                Link(
                  destination: URL(
                    string:
                      "mailto:LightningVPN888@gmail.com?subject=地址修复&body=请回复我最新的可访问的网址\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\(userInfo?.email ?? "火星用户")\n\(userInfo?.plan_id ?? -1 )"
                  )!
                ) {
                  Text("修复")
                    .font(.subheadline)
                }
              }
            }

          } header: {
            Text("个人信息")
          }

          // 试用状态信息
          TrialStatusSection()

          Section {

              if(userManager.is_admin){
                  NavigationLink(destination: TicketListView_admin()) {
                      HStack {
                          IVYIcon(systemName: "questionmark.circle.fill", backgroundColor: Color(hexString: "#F78770"))

                          Text("工单管理")
                      }
                  }
                  .padding(.vertical,4)

              }else{
                  NavigationLink(destination: TicketListView()) {
                      HStack {
                          IVYIcon(systemName: "questionmark.circle.fill", backgroundColor: Color(hexString: "#F78770"))

                          Text("我的工单")
                      }
                  }
                  .padding(.vertical,4)

              }
              
          } header: {
            Text("工单")
          }

        } else {
          EmptyView()
        }

        Section {
          Button {
            showScan.toggle()

          } label: {
            LabeledContent {
              Image(systemName: "chevron.forward")
                .foregroundColor(.secondary)
                .opacity(0.7)

            } label: {
              Label {
                Text("扫码修复")
              } icon: {
                IVYIcon(systemName: "qrcode.viewfinder", backgroundColor: .brown)
              }
            }
          }

          .fullScreenCover(
            isPresented: $showScan,
            content: {
              NavigationView {
                CodeScannerView(
                  codeTypes: [.qr],
                  scanMode: .once,
                  showViewfinder: true,
                  completion: { result in
                    handleScanResult(result)
                  }
                )
                .navigationTitle("扫描二维码")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                  ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                      showScan = false
                    }
                  }
                }
                .overlay(
                  VStack {
                    Spacer()
                    Text("将二维码对准扫描框")
                      .font(.headline)
                      .foregroundColor(.white)
                      .padding()
                      .background(Color.black.opacity(0.7))
                      .cornerRadius(10)
                      .padding(.bottom, 50)
                  }
                )
              }
            })

        } header: {
          Text("修复Apple TV端")
        }
        // 使用专用的 PurchaseView 完整处理 IAP 购买流程
        Section {
          NavigationLink(destination: PurchaseView().environmentObject(userManager)) {
            Text("购买套餐")

//            LabeledContent {
//              Image(systemName: "chevron.forward").foregroundColor(.secondary).opacity(0.7)
//            } label: {
//              Text("购买套餐")
//            }
          }
        } header: {
          Text("购买套餐")
        }
        // 恢复购买入口已迁移到支付页，此处移除
        if ((self.subscribe) != nil) {
          Section {
            LabeledContent {
              Text(self.subscribe?.name ?? "-")
            } label: {
              Label {
                Text("套餐")
              } icon: {
                IVYIcon(systemName: "info", backgroundColor: .indigo)
              }
          }
          .padding(.vertical,4)

          // 测试推送
          Button {
            testPush()
          } label: {
            LabeledContent {
              Image(systemName: "chevron.forward")
                .foregroundColor(.secondary)
                .opacity(0.7)
            } label: {
              Label {
                Text("测试推送")
              } icon: {
                IVYIcon(systemName: "bell.badge.fill", backgroundColor: .teal)
              }
            }
          }
          .padding(.vertical,4)

#if DEBUG
          Button {
            triggerTestCrashRequest()
          } label: {
            LabeledContent {
              Image(systemName: "chevron.forward")
                .foregroundColor(.secondary)
                .opacity(0.7)
            } label: {
              Label {
                Text("触发测试崩溃")
              } icon: {
                IVYIcon(systemName: "flame.fill", backgroundColor: .red)
              }
            }
          }
          .padding(.vertical,4)
#endif

            LabeledContent {
              Text(formatter.string(from: self.subscribe!.u! as NSNumber) ?? "-")
            } label: {
              Label {
                Text("上行")
              } icon: {
                IVYIcon(systemName: "arrow.up.right", backgroundColor: .purple)
              }
            }
            .padding(.vertical,4)


            LabeledContent {
              Text(formatter.string(from: self.subscribe!.d! as NSNumber) ?? "-")
            } label: {
              Label {
                Text("下行")
              } icon: {
                IVYIcon(systemName: "arrow.down.right", backgroundColor: .orange)
              }
            }
            .padding(.vertical,4)


            LabeledContent {
              Text(formatter.string(from: self.subscribe!.transfer_enable! as NSNumber) ?? "-")
            } label: {
              Label {
                Text("总计")
              } icon: {
                IVYIcon(
                  systemName: "arrow.triangle.branch", backgroundColor: Color(hexString: "#01E905"))
              }
            }
            .padding(.vertical,4)


          } header: {
            Text("套餐信息")
          }
          Section {
            LabeledContent {
              let org = (subscribe?.sing_url ?? subscribe?.subscribe_url)
              if org != nil {
                let remoteURL = org! + "&flag=singbox"
                Text(remoteURL)
                  .lineLimit(1)

              } else {
                Text("暂不支持")
              }
            } label: {
              Label {
                Text("地址")
              } icon: {
                IVYIcon(systemName: "doc.on.doc", backgroundColor: .green)
              }
            }.onTapGesture {
              copyToast.toggle()
              let pastboard = UIPasteboard.general
              let org = (subscribe?.sing_url ?? subscribe?.subscribe_url)
              if org != nil {
                let remoteURL = org! + "&flag=singbox"
                pastboard.string = remoteURL
              } else {
                pastboard.string = subscribe!.subscribe_url
              }

            }
          } header: {
            Text("复制订阅")
          }

        } else {
          EmptyView()
        }
        Section {
          Link(
            destination: webSite,
            label: {
              HStack {
                Label {
                  Text("官方网站")
                } icon: {
                  IVYIcon(systemName: "mug", backgroundColor: Color(hexString: "#F78770"))
                }.foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.forward")
                  .foregroundColor(.secondary)
                  .opacity(0.7)
              }
            }
          ).foregroundColor(.secondary)

          Link(
            destination: URL(string: "mailto:LightningVPN888@gmail.com")!,
            label: {
              HStack {
                Label {
                  Text("联系我们")
                } icon: {
                  IVYIcon(
                    systemName: "envelope.badge", backgroundColor: Color(hexString: "#F2DD63"))
                }.foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.forward")
                  .foregroundColor(.secondary)
                  .opacity(0.7)
              }
            }
          ).foregroundColor(.secondary)

          Link(
            destination: URL(string: "\(Defaults[.host])/agreement.html")!,
            label: {
              HStack {
                Label {
                  Text("用户协议")
                } icon: {
                  IVYIcon(systemName: "lamp.floor", backgroundColor: Color(hexString: "#57E061"))
                }.foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.forward")
                  .foregroundColor(.secondary)
                  .opacity(0.7)
              }
            }
          ).foregroundColor(.secondary)
          Link(
            destination: URL(string: "\(Defaults[.host])/protocol.html")!,
            label: {
              HStack {
                Label {
                  Text("隐私政")
                } icon: {
                  IVYIcon(systemName: "lightbulb", backgroundColor: Color(hexString: "#EA1E5C"))
                }.foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.forward")
                  .foregroundColor(.secondary)
                  .opacity(0.7)
              }
            }
          ).foregroundColor(.secondary)

          Link(
            destination: URL(
              string: "https://apps.apple.com/app/id1615510722?action=write-review")!,
            label: {
              HStack {
                Label {
                  Text("五星好评")
                } icon: {
                  IVYIcon(systemName: "star", backgroundColor: Color(hexString: "#5FEAE1"))
                }.foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.forward")
                  .foregroundColor(.secondary)
                  .opacity(0.7)
              }
            }
          ).foregroundColor(.secondary)

          Link(
            destination: URL(string: "https://apps.apple.com/app/id1615510722")!,
            label: {
              HStack {
                Label {
                  Text("检测更新")
                } icon: {
                  IVYIcon(systemName: "sun.max", backgroundColor: Color(hexString: "#42BAE9"))
                }.foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.forward")
                  .foregroundColor(.secondary)
                  .opacity(0.7)
              }
            }
          ).foregroundColor(.secondary)

        } header: {
          Text("其它")
        }
        if (userInfo != nil) {
          Section {
            Button {
              signOut.toggle()
            } label: {
              Text("登出")
            }

          }

          Section {
            Button {
              signOut.toggle()
            } label: {
              Text("注销账户")
            }

          }

        }

      }
      .listStyle(.grouped)
    }

    .onAppear() {
      // 记录用户页面访问
       SharedAnalyticsKit.shared.logScreenView(screenName: "UserView")

      refresh()

      Task {
        products = await purchaseXManager.requestProductsFromAppstore(productIds: [
          "com.gy.iflash.7", "com.gy.iflash.30", "com.gy.iflash.365",
        ])
      }
    }
    .background(Color(hexString: "#F2F1F5"))
    .navigationBarTitle("个人中心")

    .toast(isPresenting: $copyToast, duration: 1.5, tapToDismiss: false) {
      ToastNotification(type: .complete(.green), title: "复制成功!", subTitle: nil)
    }

    .onChange(
      of: auth_data,
      perform: { newValue in
        refresh()
      }
    )
    .onChange(of: scenePhase) { phase in
      switch phase {
      case .active:
        refresh()
        print("App is active")
      default:
        break
      }
    }
    .alert(
      isPresented: $signOut,
      content: {
        Alert(
          title: Text("确定登出吗?"),
          message: Text("登出后需要重新登录以继续使用"),
          primaryButton: .destructive(Text("确定")) {
            // 登出用户
            Task {
                await userManager.logout()

                // 通知 AppStateManager 用户已登出
                await MainActor.run {
                    appStateManager.userLoggedOut()
                }
            }
          },
          secondaryButton: .cancel()
        )
      })
    .alert("错误", isPresented: $errorAlert) {
      Button("确定", role: .cancel) {}
    } message: {
      Text(errorSubTitle)
    }
    .alert("成功", isPresented: $successAlert) {
      Button("确定", role: .cancel) {}
    } message: {
      Text(successMessage)
    }

  }

  // MARK: - Test Push
  private func testPush() {
    HUDManager.showLoading("正在发送测试推送…")
    NetworkService.shared.request(
      AQAPIService.testPush(title: "测试推送", body: "Hello from server"),
      decodeTo: SimpleResponse.self
    ) { result in
      switch result {
      case .success(let payload):
        if payload.context.httpStatusCode == 200 {
          HUDManager.showSuccess("测试推送已发送")
        } else {
          let message = payload.model?.msg ?? payload.model?.data?.message ?? payload.context.message ?? "未知错误"
          HUDManager.showFailure(message)
        }
      case .failure(let error):
        HUDManager.showFailure(error.message)
      }
    }
  }
  
#if DEBUG
  private func triggerTestCrashRequest() {
    HUDManager.showLoading("即将触发测试崩溃…")
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      CrashManager.shared.triggerTestCrash(reason: "手动触发测试崩溃")
    }
  }
#endif

  // MARK: - 二维码扫描结果处理
  private func handleScanResult(_ result: Result<ScanResult, ScanError>) {
    showScan = false
    
    switch result {
    case .success(let scanResult):
      // 扫描成功
      let scannedString = scanResult.string
      Defaults[.local] = scannedString
      
      // 发送网络请求
      NetworkService.shared.request(
        AQAPIService.local(address: Defaults[.host])
      ) { result in
        switch result {
        case .success:
          DispatchQueue.main.async {
            successMessage = "扫码修复成功"
            successAlert = true
          }
        case .failure(let error):
          DispatchQueue.main.async {
            errorTitle = "扫码修复失败"
            errorSubTitle = error.message
            errorAlert = true
          }
        }
      }
      
    case .failure(let error):
      // 扫描失败
      DispatchQueue.main.async {
        errorTitle = "扫描失败"
        errorSubTitle = "无法识别二维码，请重试"
        errorAlert = true
      }
    }
  }
  
  func makeOrder(product: Product) async {
    let uuid = Product.PurchaseOption.appAccountToken(UUID())
    do {

      let (transaction, purchaseState) = try await purchaseXManager.purchase(
        product: product, options: [uuid])
      if let txn = transaction, purchaseState == .complete {
        try? await txn.finish()
      }
    } catch {}
  }
  // 恢复购买逻辑：采集交易快照并上报后端
  @MainActor
  private func restorePurchases() async {
    guard userManager.isLoggedIn else {
      DispatchQueue.main.async {
        errorTitle = "请先登录"
        errorSubTitle = "登录后可恢复购买"
        errorAlert = true
      }
      return
    }
    let appTokenRaw = (userManager.userInfo?.app_account_token?.isEmpty == false)
      ? userManager.userInfo?.app_account_token
      : (userManager.auth_data.isEmpty ? nil : userManager.auth_data)

    guard let appToken = appTokenRaw else {
      DispatchQueue.main.async {
        errorTitle = "恢复失败"
        errorSubTitle = "账户标识缺失，请重新登录"
        errorAlert = true
      }
      return
    }

    let snapshot = await purchaseXManager.transactionsSnapshot(appAccountToken: appToken)
    IAPOrderManager.restorePurchases(appAccountToken: appToken, transactions: snapshot) { success, error in
      DispatchQueue.main.async {
        if success {
          Task { await userManager.reload() }
          successMessage = "恢复完成"
          successAlert = true
        } else {
          errorTitle = "恢复失败"
          errorSubTitle = error ?? "请稍后重试"
          errorAlert = true
        }
      }
    }
  }
  func refresh() {
    guard auth_data.count > 0 else {
      return
    }
    userManager.refreshUserInfo()
    userManager.getSubscribe()
    environments.profileUpdate.send()
        environments.selectedProfileUpdate.send()

        guard self.userInfoJsonStr.count>0 else{
            return
        }
        
    }
}


extension Date{
    func date2string()->String{
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.string(from: self)
    }
}
