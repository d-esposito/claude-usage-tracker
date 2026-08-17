import Foundation

@MainActor
final class DesktopUsageController: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isRefreshing = false

    private static let cacheKey = "desktopUsageSnapshot"
    private let service = ClaudeUsageService()
    private var pollingTask: Task<Void, Never>?

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.cacheKey) {
            snapshot = try? JSONDecoder().decode(UsageSnapshot.self, from: data)
        }
    }

    func start() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            guard let self else { return }
            await refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(180))
                guard !Task.isCancelled else { return }
                await refresh()
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let updated = try await service.fetch()
            snapshot = updated
            errorMessage = nil
            if let data = try? JSONEncoder().encode(updated) {
                UserDefaults.standard.set(data, forKey: Self.cacheKey)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
