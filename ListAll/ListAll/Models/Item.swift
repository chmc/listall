//
//  Item.swift
//  ListAll
//
//  Created by Sutela Aleksi on 15.9.2025.
//

import Foundation
import CoreData

@objc(Item)
public class Item: NSManagedObject {
    
}

// MARK: - Generated accessors for images
extension Item {
    
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var itemDescription: String?
    @NSManaged public var quantity: Int32
    @NSManaged public var orderNumber: Int32
    @NSManaged public var isCrossedOut: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var modifiedAt: Date?
    @NSManaged public var list: List?
    @NSManaged public var images: NSSet?
    
}

// MARK: - Generated accessors for images
extension Item {
    
    @objc(addImagesObject:)
    @NSManaged public func addToImages(_ value: ItemImage)
    
    @objc(removeImagesObject:)
    @NSManaged public func removeFromImages(_ value: ItemImage)
    
    @objc(addImages:)
    @NSManaged public func addToImages(_ values: NSSet)
    
    @objc(removeImages:)
    @NSManaged public func removeFromImages(_ values: NSSet)
    
}

extension Item: Identifiable {
    
}
