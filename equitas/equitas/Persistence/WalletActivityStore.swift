import Foundation

struct WalletActivity: Codable, Identifiable {
    enum Kind: String, Codable {
        case funding
        case purchase
    }

    enum Status: String, Codable {
        case pending
        case completed
        case failed
    }

    let id: UUID
    let kind: Kind
    let status: Status
    let title: String
    let subtitle: String
    let amountAtomic: String
    let txHash: String
    let txExplorerURL: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case status
        case title
        case subtitle
        case amountAtomic
        case txHash
        case txExplorerURL
        case createdAt
    }

    init(
        id: UUID,
        kind: Kind,
        status: Status,
        title: String,
        subtitle: String,
        amountAtomic: String,
        txHash: String,
        txExplorerURL: String?,
        createdAt: Date
    ) {
        self.id = id
        self.kind = kind
        self.status = status
        self.title = title
        self.subtitle = subtitle
        self.amountAtomic = amountAtomic
        self.txHash = txHash
        self.txExplorerURL = txExplorerURL
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(Kind.self, forKey: .kind)
        status = try container.decodeIfPresent(Status.self, forKey: .status) ?? .completed
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decode(String.self, forKey: .subtitle)
        amountAtomic = try container.decode(String.self, forKey: .amountAtomic)
        txHash = try container.decode(String.self, forKey: .txHash)
        txExplorerURL = try container.decodeIfPresent(String.self, forKey: .txExplorerURL)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

struct WalletActivityStore {
    private let defaults = UserDefaults.standard
    private let storageKey = "walletActivities"

    func load() -> [WalletActivity] {
        guard let data = defaults.data(forKey: storageKey),
              let activities = try? JSONDecoder().decode([WalletActivity].self, from: data) else {
            return []
        }
        return activities.sorted { $0.createdAt > $1.createdAt }
    }

    func recordFunding(amountAtomic: String, txHash: String, txExplorerURL: String?, benefitTier: String) {
        append(
            WalletActivity(
                id: UUID(),
                kind: .funding,
                status: .completed,
                title: "Benefits funded",
                subtitle: benefitTier.replacingOccurrences(of: "_", with: " "),
                amountAtomic: amountAtomic,
                txHash: txHash,
                txExplorerURL: txExplorerURL,
                createdAt: Date()
            )
        )
    }

    func recordPurchase(
        amountAtomic: String,
        txHash: String,
        txExplorerURL: String?,
        merchantName: String,
        merchantAddress: String
    ) {
        append(
            WalletActivity(
                id: UUID(),
                kind: .purchase,
                status: .completed,
                title: merchantName,
                subtitle: merchantAddress,
                amountAtomic: amountAtomic,
                txHash: txHash,
                txExplorerURL: txExplorerURL,
                createdAt: Date()
            )
        )
    }

    @discardableResult
    func recordPendingPurchase(amountAtomic: String, merchantName: String, merchantAddress: String) -> UUID {
        let id = UUID()
        append(
            WalletActivity(
                id: id,
                kind: .purchase,
                status: .pending,
                title: merchantName,
                subtitle: merchantAddress,
                amountAtomic: amountAtomic,
                txHash: "",
                txExplorerURL: nil,
                createdAt: Date()
            )
        )
        return id
    }

    func completePendingPurchase(
        id: UUID,
        txHash: String,
        txExplorerURL: String?,
        merchantName: String,
        merchantAddress: String
    ) {
        update(id: id) { current in
            WalletActivity(
                id: current.id,
                kind: current.kind,
                status: .completed,
                title: merchantName,
                subtitle: merchantAddress,
                amountAtomic: current.amountAtomic,
                txHash: txHash,
                txExplorerURL: txExplorerURL,
                createdAt: current.createdAt
            )
        }
    }

    func failPendingPurchase(id: UUID, merchantName: String, merchantAddress: String) {
        update(id: id) { current in
            WalletActivity(
                id: current.id,
                kind: current.kind,
                status: .failed,
                title: merchantName,
                subtitle: merchantAddress,
                amountAtomic: current.amountAtomic,
                txHash: current.txHash,
                txExplorerURL: current.txExplorerURL,
                createdAt: current.createdAt
            )
        }
    }

    private func append(_ activity: WalletActivity) {
        var activities = load()
        if !activity.txHash.isEmpty {
            activities.removeAll { !$0.txHash.isEmpty && $0.txHash.caseInsensitiveCompare(activity.txHash) == .orderedSame }
        }
        activities.insert(activity, at: 0)
        persist(activities)
    }

    private func update(id: UUID, transform: (WalletActivity) -> WalletActivity) {
        var activities = load()
        guard let index = activities.firstIndex(where: { $0.id == id }) else { return }
        activities[index] = transform(activities[index])
        persist(activities)
    }

    private func persist(_ activities: [WalletActivity]) {
        if let data = try? JSONEncoder().encode(Array(activities.prefix(20))) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
