//
//  List.swift
//  ListAll
//
//  Created by Sutela Aleksi on 15.9.2025.
//

import Foundation
import CoreData

@objc(List)
public class List: NSManagedObject {
    
}

// MARK: - Generated accessors for items
extension List {
    
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var orderNumber: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var modifiedAt: Date?
    @NSManaged public var items: NSSet?
    
}

// MARK: - Generated accessors for items
extension List {
    
    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: Item)
    
    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: Item)
    
    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSSet)
    
    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSSet)
    
}

extension List: Identifiable {
    
}
