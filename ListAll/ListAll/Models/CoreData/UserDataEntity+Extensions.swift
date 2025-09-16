import Foundation
import CoreData

extension UserDataEntity {
    func toUserData() -> UserData {
        var userData = UserData(userID: self.userID ?? "unknown")
        userData.id = self.id ?? UUID()
        userData.showCrossedOutItems = self.showCrossedOutItems
        userData.exportPreferences = self.exportPreferences
        userData.lastSyncDate = self.lastSyncDate
        userData.createdAt = self.createdAt ?? Date()
        return userData
    }
    
    static func fromUserData(_ userData: UserData, context: NSManagedObjectContext) -> UserDataEntity {
        let userEntity = UserDataEntity(context: context)
        userEntity.id = userData.id
        userEntity.userID = userData.userID
        userEntity.showCrossedOutItems = userData.showCrossedOutItems
        userEntity.exportPreferences = userData.exportPreferences
        userEntity.lastSyncDate = userData.lastSyncDate
        userEntity.createdAt = userData.createdAt
        return userEntity
    }
}
