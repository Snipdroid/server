import Vapor
import Queues

struct DailySummaryJob: AsyncScheduledJob, AsyncJob {
    func dequeue(_ context: Queues.QueueContext, _ payload: Payload) async throws {
        try await generateSummary(context: context)
    }

    struct Payload: Codable {
        let id: UUID
    }

    func generateSummary(context: Queues.QueueContext) async throws {
        let designers = try await Designer.query(on: context.application.db).all()

        try await designers.compactMap { designer in 
            designer.id.map { ($0, designer) }
        }.asyncMap { id, designer in
            let calendar = Calendar(identifier: .gregorian)
            
            // TODO: Customize the timezone based on the designer's location

            let now = Date()
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
            let startOfToday = calendar.startOfDay(for: now)
            let startOfYesterday = calendar.startOfDay(for: yesterday)

            let count = try await RequestRecord.query(on: context.application.db)
                .join(parent: \.$iconPackVersion)
                .join(from: IconPackVersion.self, parent: \.$designer)
                .filter(IconPackVersion.self, \.$designer.$id, .equal, id)
                .filter(\.$createdAt, .greaterThanOrEqual, startOfYesterday)
                .filter(\.$createdAt, .lessThan, startOfToday)
                .count()

            let newSummary = DailySummary(count: count, designerId: id, date: startOfYesterday)
            return newSummary
        }.create(on: context.application.db)
    }

    func run(context: Queues.QueueContext) async throws {
        try await generateSummary(context: context)
    }
}