//
//  IndicatorPresetModel.swift
//  sing-box
//
//  Created by xiaokang chen on 2024/1/28.
//

import UIKit
import SPIndicator
struct IndicatorPresetModel {
    
    var name: String
    var title: String
    var message: String?
    var duration:TimeInterval = 2.0
    var presentSide: SPIndicatorPresentSide = .top
    var dismissByDrag: Bool = true
    var preset: SPIndicatorIconPreset = .done
    var haptic: SPIndicatorHaptic = .none
    var layout: SPIndicatorLayout? = nil
    var completion: (()-> Void)? = nil
    
    var id: String {
        return name
    }
}
