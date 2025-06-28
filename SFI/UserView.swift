//
//  UserView.swift
//  Pomelo
//
//  Created by xiaokang chen on 2023/3/22.
//

import SwiftUI
import Kingfisher
import DynamicColor
import AlertToast
import Defaults
import StoreKit
import Library
import CodeScanner
struct UserView: View {
  @EnvironmentObject private var environments: ExtensionEnvironments
  @State var signOut = false
  @State private var copyToast: Bool = false
  @Environment(\.scenePhase) private var scenePhase
  @EnvironmentObject var userManager: UserManager

  @ObservedObject var purchaseXManager: PurchaseXManager = PurchaseXManager()
  @State public var products: [Product]?

  @AppStorage(ConstantKey.auth_data) private var auth_data = ""
  @AppStorage(ConstantKey.userInfojson) private var userInfoJsonStr = ""
  @AppStorage(ConstantKey.subscribeInfojson) private var subscribeInfoJsonStr = ""

  @State var errorAlert: Bool = false
  @State var errorTitle: String = ""
  @State var errorSubTitle: String = ""

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
              HStack {
                KFImage(URL(string: (userInfo?.avatar_url)!)!)
                  .cornerRadius(25)
                  .frame(width: 40, height: 40)
                  .padding(15)
                VStack {
                  Text(userInfo?.email ?? "火星用户")
                    .foregroundColor(Color(hexString: "#EF8427"))
                    .padding(.vertical, 5)
                  let date = Date(
                    timeIntervalSince1970: userInfo?.expired_at ?? 100 * 365 * 24 * 60 * 60)
                  Text(date.date2string() + "到期")
                    .foregroundColor(Color.secondary)
                    .padding(.vertical, 5)
                }
                Spacer()
                Link(
                  destination: URL(
                    string:
                      "mailto:LightningVPN888@gmail.com?subject=地址修复&body=请回复我最新的可访问的网址\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\(userInfo?.email ?? "火星用户")\n\(userInfo?.plan_id ?? -1 )"
                  )!
                ) {
                  Text("修复")
                }
              }
            }

          } header: {
            Text("个人信息")
          }

          Section {

            Section {
              Button {
                isNavigatingToTickets = true
              } label: {
                LabeledContent {
                  Image(systemName: "chevron.forward")
                } label: {
                  Text("我的工单")
                }
              }
            }

            NavigationLink(
              destination: TicketListView(),
              isActive: $isNavigatingToTickets,
              label: { EmptyView() }
            )

            Button {

            } label: {
              LabeledContent {
                Image(systemName: "chevron.forward")
                  .foregroundColor(.secondary)
                  .opacity(0.7)

              } label: {
                Label {
                  Text("我的工单")
                } icon: {
                  IVYIcon(systemName: "command", backgroundColor: .brown)
                }
              }
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
              CodeScannerView(codeTypes: [.qr]) { response in
                if case let .success(result) = response {
                  showScan = false
                  Defaults[.local] = result.string;
                  NewNetWorkRequest(
                    AQAPIService.local(address: Defaults[.host]),
                    successCallback: { responseModel in
                      print(responseModel)
                    })
                }
              }
            })

        } header: {
          Text("修复Apple TV端")
        }
        if (products != nil && products!.count > 0) {
          Section {
            ForEach(products!, id: \.id) { product in
              Button {
                Task {
                  do {
                    NewNetWorkRequest(
                      AQAPIService.getVersion(token: userManager.token), modelType: AppVersion.self
                    ) { appVersion, responseModel in

                      if ((appVersion) != nil) {
                        if (VersionComparator.compare(Bundle.appVersion, appVersion!.ios_version)
                          > 0)
                        {
                          Task {
                            await self.makeOrder(product: product)
                          }
                        } else {
                          self.errorTitle = "当前服务不可用"
                          self.errorSubTitle = "请从官网获取开通相关服务"
                          self.errorAlert.toggle()
                        }
                      } else {
                        self.errorTitle = "当前服务不可用"
                        self.errorSubTitle = "请从官网获取开通相关服务"
                        self.errorAlert.toggle()
                      }
                    }
                  }
                }

              } label: {
                LabeledContent {
                  Text("\(product.displayPrice)")

                } label: {
                  Text("\(product.displayName)")
                }

              }
              .alert(
                isPresented: $errorAlert,
                content: {
                  Alert(
                    title: Text(errorTitle),
                    message: Text(errorSubTitle),
                    primaryButton: .destructive(Text("前往")) {

                      UIApplication.shared.open(webSite)
                    },
                    secondaryButton: .cancel(
                      Text("取消"),
                      action: {

                      })
                  )
                })

            }
          } header: {
            Text("购买套餐")
          }

        }
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
            LabeledContent {
              Text(formatter.string(from: self.subscribe!.u! as NSNumber) ?? "-")
            } label: {
              Label {
                Text("上行")
              } icon: {
                IVYIcon(systemName: "arrow.up.right", backgroundColor: .purple)
              }
            }

            LabeledContent {
              Text(formatter.string(from: self.subscribe!.d! as NSNumber) ?? "-")
            } label: {
              Label {
                Text("下行")
              } icon: {
                IVYIcon(systemName: "arrow.down.right", backgroundColor: .orange)
              }
            }

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
      AlertToast(type: .complete(.green), title: "复制成功!", subTitle: nil)
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
            dismiss()
            userManager.logout()
            //                    auth_data = ""
            //                    userInfoJsonStr = ""
            //                    subscribeInfoJsonStr = ""
            //                    print("Deleting...")
          },
          secondaryButton: .cancel()
        )
      })

  }
  func makeOrder(product: Product) async {
    let uuid = Product.PurchaseOption.appAccountToken(UUID())
    do {

      let (transaction, purchaseState) = try await purchaseXManager.purchase(
        product: product, options: [uuid])
      if (transaction != nil && purchaseState == .complete) {

      }
    } catch {}
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


