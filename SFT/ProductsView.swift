//
//  ProductsView.swift
//  SFT
//
//  Created by xiaokang chen on 2023/12/25.
//

import SwiftUI
import StoreKit
import Defaults

struct ProductsView: View {
    @State public var products: [Product]?
    @EnvironmentObject var userManager: UserManager

    @ObservedObject var purchaseXManager:PurchaseXManager = PurchaseXManager()
    @State private var isLoading = true
    @Environment(\.dismiss) var dismiss

    @State var errorAlert: Bool = false
    @State var errorTitle:String = ""
    @State var errorSubTitle:String = ""
    
    var webSite:URL = URL(string: "\(Defaults[.host])")!

    var body: some View {
        if isLoading {
            VStack{
                Spacer()
                Text("Loading...")
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Text("返回")
                }
            }
            .onAppear(){
                Task{
                    products =  await purchaseXManager.requestProductsFromAppstore(productIds: ["com.gy.iflash.7","com.gy.iflash.30","com.gy.iflash.365"])
                    isLoading = false

                }
            }


        }else{
            List {
                if(products != nil && products!.count>0)
                {
                    Section{
                        ForEach(products!, id:\.id) { product in
                            Button {
                                Task{
                                    do{
                                        if(VersionComparator.compare(Bundle.appVersion, Defaults[.releaseVersion])>0){
                                            Task{
                                                await self.makeOrder(product: product)
                                            }
                                        }else{
                                            self.errorTitle = "当前服务不可用"
                                            self.errorSubTitle = "请稍后再试"
                                            self.errorAlert.toggle()
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
                            .alert(isPresented: $errorAlert, content: {
                                Alert(
                                    title: Text(errorTitle),
                                    message: Text(errorSubTitle),
                                    primaryButton: .destructive(Text("前往")) {
                                        
                                        UIApplication.shared.open(webSite)
                                    },
                                    secondaryButton: .cancel(Text("取消"), action: {
                                        
                                    })
                                )
                            })

                            
                            
                        }
                    }header: {
                        Text("购买套餐")
                    }
                    
                }
                Button {
                    dismiss()
                } label: {
                    Text("返回")
                }

                
            }

        }

    }
    func makeOrder(product:Product) async{
        let uuid = Product.PurchaseOption.appAccountToken(UUID())
        do{
            
            let (transaction,purchaseState) = try await purchaseXManager.purchase(product: product,options: [uuid])
            if(transaction != nil && purchaseState == .complete){
                
            }
        }catch{}
    }

}

#Preview {
    ProductsView()
}
