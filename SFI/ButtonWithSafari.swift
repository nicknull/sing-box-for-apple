//
//  ButtonWithSafari.swift
//  SFI
//
//  Created by xiaokang chen on 2024/2/5.
//

import SwiftUI

struct ButtonWithSafari<Label: View>: View {
    let stringURL: String
    let label: () -> Label
    @State private var showSafari: Bool = false
    
    var body: some View {
        Button {
            showSafari.toggle()
        } label: {
            label()
                .frame(minHeight: 30)
        }
        .inAppSafari(isPresented: $showSafari, stringURL: stringURL)
    }
}
