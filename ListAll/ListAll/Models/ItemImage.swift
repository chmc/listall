//
//  ItemImage.swift
//  ListAll
//
//  Created by Sutela Aleksi on 15.9.2025.
//

import Foundation
import CoreData

@objc(ItemImage)
public class ItemImage: NSManagedObject {
    
}

extension ItemImage {
    
    @NSManaged public var id: UUID?
    @NSManaged public var imageData: Data?
    @NSManaged public var orderNumber: Int32
    @NSManaged public var item: Item?
    
}

extension ItemImage: Identifiable {
    
}
