import Combine
import CoreData
import Foundation

private enum DanbooruPersistenceEntity {
    static let settings = "DanbooruSettingsEntity"
    static let userCache = "DanbooruUserCacheEntity"
    static let postInteraction = "DanbooruPostInteractionEntity"
}

struct DanbooruSettings: Equatable {
    var baseURLString: String = ""
    var login: String = ""
    var apiKey: String = ""
    var atfAntiBotCookie: String = ""
    var postCommentSortOrderRawValue: String = DanbooruCommentSortOrder.oldestFirst.rawValue
    var forumPostSortOrderRawValue: String = DanbooruCommentSortOrder.oldestFirst.rawValue

    var configuration: DanbooruClientConfiguration? {
        let trimmedURL = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLogin = login.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCookie = atfAntiBotCookie.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedURL.isEmpty,
              !trimmedLogin.isEmpty,
              !trimmedAPIKey.isEmpty,
              !trimmedCookie.isEmpty,
              let url = URL(string: trimmedURL) else {
            return nil
        }

        return DanbooruClientConfiguration(
            baseURL: url,
            login: trimmedLogin,
            apiKey: trimmedAPIKey,
            atfAntiBotCookie: trimmedCookie
        )
    }

    var isConfigured: Bool {
        configuration != nil
    }

    var postCommentSortOrder: DanbooruCommentSortOrder {
        get { DanbooruCommentSortOrder(rawValue: postCommentSortOrderRawValue) ?? .oldestFirst }
        set { postCommentSortOrderRawValue = newValue.rawValue }
    }

    var forumPostSortOrder: DanbooruCommentSortOrder {
        get { DanbooruCommentSortOrder(rawValue: forumPostSortOrderRawValue) ?? .oldestFirst }
        set { forumPostSortOrderRawValue = newValue.rawValue }
    }
}

final class DanbooruPersistenceController: @unchecked Sendable {
    static let shared = DanbooruPersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(
            name: "DanbooruSettings",
            managedObjectModel: Self.makeManagedObjectModel()
        )

        let description = NSPersistentStoreDescription()
        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        } else {
            let applicationSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let folderURL = applicationSupportDirectory.appendingPathComponent("PickleClickerNative", isDirectory: true)
            try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            description.url = folderURL.appendingPathComponent("DanbooruSettings.sqlite")
        }

        description.shouldInferMappingModelAutomatically = true
        description.shouldMigrateStoreAutomatically = true
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Failed to load Danbooru persistent store: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    private static func makeManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = DanbooruPersistenceEntity.settings
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let baseURL = NSAttributeDescription()
        baseURL.name = "baseURLString"
        baseURL.attributeType = .stringAttributeType
        baseURL.isOptional = true

        let login = NSAttributeDescription()
        login.name = "login"
        login.attributeType = .stringAttributeType
        login.isOptional = true

        let apiKey = NSAttributeDescription()
        apiKey.name = "apiKey"
        apiKey.attributeType = .stringAttributeType
        apiKey.isOptional = true

        let atfAntiBotCookie = NSAttributeDescription()
        atfAntiBotCookie.name = "atfAntiBotCookie"
        atfAntiBotCookie.attributeType = .stringAttributeType
        atfAntiBotCookie.isOptional = true

        let updatedAt = NSAttributeDescription()
        updatedAt.name = "updatedAt"
        updatedAt.attributeType = .dateAttributeType
        updatedAt.isOptional = true
        
        let postCommentSortOrder = NSAttributeDescription()
        postCommentSortOrder.name = "postCommentSortOrderRawValue"
        postCommentSortOrder.attributeType = .stringAttributeType
        postCommentSortOrder.isOptional = true

        let forumPostSortOrder = NSAttributeDescription()
        forumPostSortOrder.name = "forumPostSortOrderRawValue"
        forumPostSortOrder.attributeType = .stringAttributeType
        forumPostSortOrder.isOptional = true

        entity.properties = [baseURL, login, apiKey, atfAntiBotCookie, postCommentSortOrder, forumPostSortOrder, updatedAt]

        let userCacheEntity = NSEntityDescription()
        userCacheEntity.name = DanbooruPersistenceEntity.userCache
        userCacheEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let host = NSAttributeDescription()
        host.name = "host"
        host.attributeType = .stringAttributeType
        host.isOptional = false

        let userID = NSAttributeDescription()
        userID.name = "userID"
        userID.attributeType = .integer64AttributeType
        userID.isOptional = false

        let username = NSAttributeDescription()
        username.name = "username"
        username.attributeType = .stringAttributeType
        username.isOptional = false

        let cachedAt = NSAttributeDescription()
        cachedAt.name = "cachedAt"
        cachedAt.attributeType = .dateAttributeType
        cachedAt.isOptional = false

        userCacheEntity.properties = [host, userID, username, cachedAt]

        let postInteractionEntity = NSEntityDescription()
        postInteractionEntity.name = DanbooruPersistenceEntity.postInteraction
        postInteractionEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let interactionHost = NSAttributeDescription()
        interactionHost.name = "host"
        interactionHost.attributeType = .stringAttributeType
        interactionHost.isOptional = false

        let interactionLogin = NSAttributeDescription()
        interactionLogin.name = "login"
        interactionLogin.attributeType = .stringAttributeType
        interactionLogin.isOptional = false

        let interactionPostID = NSAttributeDescription()
        interactionPostID.name = "postID"
        interactionPostID.attributeType = .integer64AttributeType
        interactionPostID.isOptional = false

        let interactionScore = NSAttributeDescription()
        interactionScore.name = "score"
        interactionScore.attributeType = .integer64AttributeType
        interactionScore.isOptional = false

        let interactionFavoriteCount = NSAttributeDescription()
        interactionFavoriteCount.name = "favoriteCount"
        interactionFavoriteCount.attributeType = .integer64AttributeType
        interactionFavoriteCount.isOptional = false

        let interactionIsFavorited = NSAttributeDescription()
        interactionIsFavorited.name = "isFavorited"
        interactionIsFavorited.attributeType = .booleanAttributeType
        interactionIsFavorited.isOptional = false

        let interactionVoteDirection = NSAttributeDescription()
        interactionVoteDirection.name = "voteDirection"
        interactionVoteDirection.attributeType = .integer16AttributeType
        interactionVoteDirection.isOptional = false

        let interactionUpdatedAt = NSAttributeDescription()
        interactionUpdatedAt.name = "updatedAt"
        interactionUpdatedAt.attributeType = .dateAttributeType
        interactionUpdatedAt.isOptional = false

        postInteractionEntity.properties = [
            interactionHost,
            interactionLogin,
            interactionPostID,
            interactionScore,
            interactionFavoriteCount,
            interactionIsFavorited,
            interactionVoteDirection,
            interactionUpdatedAt
        ]

        model.entities = [entity, userCacheEntity, postInteractionEntity]
        return model
    }
}

@MainActor
final class DanbooruSettingsStore: ObservableObject {
    @Published var settings: DanbooruSettings

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext? = nil) {
        let resolvedContext = context ?? DanbooruPersistenceController.shared.container.viewContext
        self.context = resolvedContext
        settings = Self.loadSettings(in: resolvedContext)
    }

    var configuration: DanbooruClientConfiguration? {
        settings.configuration
    }

    func reload() {
        settings = Self.loadSettings(in: context)
    }

    func save() throws {
        let entity = try fetchOrCreateSettingsEntity()
        entity.setValue(settings.baseURLString.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "baseURLString")
        entity.setValue(settings.login.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "login")
        entity.setValue(settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "apiKey")
        entity.setValue(settings.atfAntiBotCookie.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "atfAntiBotCookie")
        entity.setValue(settings.postCommentSortOrderRawValue, forKey: "postCommentSortOrderRawValue")
        entity.setValue(settings.forumPostSortOrderRawValue, forKey: "forumPostSortOrderRawValue")
        entity.setValue(Date(), forKey: "updatedAt")

        if context.hasChanges {
            try context.save()
        }

        reload()
    }

    private func fetchOrCreateSettingsEntity() throws -> NSManagedObject {
        let request = NSFetchRequest<NSManagedObject>(entityName: DanbooruPersistenceEntity.settings)
        request.fetchLimit = 1

        if let entity = try context.fetch(request).first {
            return entity
        }

        guard let entity = NSEntityDescription.insertNewObject(forEntityName: DanbooruPersistenceEntity.settings, into: context) as NSManagedObject? else {
            throw NSError(domain: "DanbooruSettingsStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create Danbooru settings entity."])
        }

        return entity
    }

    private static func loadSettings(in context: NSManagedObjectContext) -> DanbooruSettings {
        let request = NSFetchRequest<NSManagedObject>(entityName: DanbooruPersistenceEntity.settings)
        request.fetchLimit = 1

        let entity = try? context.fetch(request).first
        return DanbooruSettings(
            baseURLString: entity?.value(forKey: "baseURLString") as? String ?? "",
            login: entity?.value(forKey: "login") as? String ?? "",
            apiKey: entity?.value(forKey: "apiKey") as? String ?? "",
            atfAntiBotCookie: entity?.value(forKey: "atfAntiBotCookie") as? String ?? "",
            postCommentSortOrderRawValue: entity?.value(forKey: "postCommentSortOrderRawValue") as? String ?? DanbooruCommentSortOrder.oldestFirst.rawValue,
            forumPostSortOrderRawValue: entity?.value(forKey: "forumPostSortOrderRawValue") as? String ?? DanbooruCommentSortOrder.oldestFirst.rawValue
        )
    }
}

actor DanbooruUserDirectory {
    @MainActor static let shared = DanbooruUserDirectory()

    private let cacheTTL: TimeInterval = 12 * 60 * 60
    private let container: NSPersistentContainer

    @MainActor
    init(container: NSPersistentContainer? = nil) {
        if let container {
            self.container = container
        } else {
            self.container = DanbooruPersistenceController.shared.container
        }
    }

    func cachedUsername(host: String, userID: Int) async -> String? {
        let context = container.newBackgroundContext()
        return await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: DanbooruPersistenceEntity.userCache)
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "host == %@ AND userID == %lld", host, Int64(userID))

            guard let entity = try? context.fetch(request).first,
                  let username = entity.value(forKey: "username") as? String,
                  let cachedAt = entity.value(forKey: "cachedAt") as? Date,
                  Date().timeIntervalSince(cachedAt) <= self.cacheTTL else {
                return nil
            }

            return username
        }
    }

    func storeUsername(host: String, userID: Int, username: String) async {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let context = container.newBackgroundContext()
        await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: DanbooruPersistenceEntity.userCache)
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "host == %@ AND userID == %lld", host, Int64(userID))

            let entity = (try? context.fetch(request).first)
                ?? NSEntityDescription.insertNewObject(forEntityName: DanbooruPersistenceEntity.userCache, into: context)
            entity.setValue(host, forKey: "host")
            entity.setValue(Int64(userID), forKey: "userID")
            entity.setValue(trimmed, forKey: "username")
            entity.setValue(Date(), forKey: "cachedAt")

            if context.hasChanges {
                try? context.save()
            }
        }
    }
}

struct DanbooruPostInteractionSnapshot: Equatable {
    let postID: Int
    let score: Int
    let favoriteCount: Int
    let isFavorited: Bool
    let voteDirectionRawValue: Int
}

actor DanbooruPostInteractionStore {
    @MainActor static let shared = DanbooruPostInteractionStore()

    private let container: NSPersistentContainer

    @MainActor
    init(container: NSPersistentContainer? = nil) {
        if let container {
            self.container = container
        } else {
            self.container = DanbooruPersistenceController.shared.container
        }
    }

    func interactionMap(host: String, login: String, postIDs: [Int]) async -> [Int: DanbooruPostInteractionSnapshot] {
        guard !postIDs.isEmpty else { return [:] }

        let context = container.newBackgroundContext()
        return await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: DanbooruPersistenceEntity.postInteraction)
            request.predicate = NSPredicate(
                format: "host == %@ AND login == %@ AND postID IN %@",
                host,
                login,
                postIDs.map(Int64.init)
            )

            guard let entities = try? context.fetch(request) else { return [:] }
            var result: [Int: DanbooruPostInteractionSnapshot] = [:]
            for entity in entities {
                let postID = Int(entity.value(forKey: "postID") as? Int64 ?? 0)
                guard postID != 0 else { continue }
                result[postID] = DanbooruPostInteractionSnapshot(
                    postID: postID,
                    score: Int(entity.value(forKey: "score") as? Int64 ?? 0),
                    favoriteCount: Int(entity.value(forKey: "favoriteCount") as? Int64 ?? 0),
                    isFavorited: entity.value(forKey: "isFavorited") as? Bool ?? false,
                    voteDirectionRawValue: Int(entity.value(forKey: "voteDirection") as? Int16 ?? 0)
                )
            }
            return result
        }
    }

    func save(card: DanbooruPostCardState, host: String, login: String) async {
        let context = container.newBackgroundContext()
        await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: DanbooruPersistenceEntity.postInteraction)
            request.fetchLimit = 1
            request.predicate = NSPredicate(
                format: "host == %@ AND login == %@ AND postID == %lld",
                host,
                login,
                Int64(card.id)
            )

            let entity = (try? context.fetch(request).first)
                ?? NSEntityDescription.insertNewObject(forEntityName: DanbooruPersistenceEntity.postInteraction, into: context)
            entity.setValue(host, forKey: "host")
            entity.setValue(login, forKey: "login")
            entity.setValue(Int64(card.id), forKey: "postID")
            entity.setValue(Int64(card.score), forKey: "score")
            entity.setValue(Int64(card.favoriteCount), forKey: "favoriteCount")
            entity.setValue(card.isFavorited, forKey: "isFavorited")
            entity.setValue(Int16(card.voteDirection.rawValue), forKey: "voteDirection")
            entity.setValue(Date(), forKey: "updatedAt")

            if context.hasChanges {
                try? context.save()
            }
        }
    }
}

actor DanbooruForumReadStateStore {
    static let shared = DanbooruForumReadStateStore()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isTopicRead(topicID: Int, host: String, login: String, apiIsRead: Bool?) -> Bool {
        if let apiIsRead {
            return apiIsRead
        }
        return seenTopicIDs(host: host, login: login).contains(topicID)
    }

    func markTopicRead(topicID: Int, host: String, login: String) {
        var ids = seenTopicIDs(host: host, login: login)
        ids.insert(topicID)
        defaults.set(Array(ids).sorted(), forKey: storageKey(host: host, login: login))
    }

    func reset(host: String, login: String) {
        defaults.removeObject(forKey: storageKey(host: host, login: login))
    }

    private func seenTopicIDs(host: String, login: String) -> Set<Int> {
        Set(defaults.array(forKey: storageKey(host: host, login: login)) as? [Int] ?? [])
    }

    private func storageKey(host: String, login: String) -> String {
        "danbooru.forum.read.\(host)|\(login)"
    }
}
