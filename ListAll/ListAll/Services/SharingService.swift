//
//  SharingService.swift
//  ListAll
//
//  Created by Sutela Aleksi on 15.9.2025.
//

import Foundation
import UIKit
import SwiftUI

class SharingService: ObservableObject {
    @Published var isSharing = false
    @Published var shareError: String?
    
    func shareList(_ list: List) {
        isSharing = true
        shareError = nil
        
        // TODO: Implement list sharing functionality
        // This will include creating shareable formats and using system share sheet
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isSharing = false
        }
    }
    
    func shareAllData() {
        isSharing = true
        shareError = nil
        
        // TODO: Implement full data sharing functionality
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isSharing = false
        }
    }
}
