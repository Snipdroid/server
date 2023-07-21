import Vapor

class LogPipe {
    private var logs: [Logger.Message]
    private let maxCapacity: Int

    init(maxCapacity: Int = 3) {
        self.logs = []
        self.maxCapacity = maxCapacity
    }

    func addLog(_ log: Logger.Message) {
        logs.append(log)
        if logs.count > maxCapacity {
            logs.removeFirst()
        }
    }

    func newLog() -> Logger.Message? {
        return logs.popLast()
    }
}

struct LogPipeConfigurationKey: StorageKey {
	typealias Value = LogPipe
}

extension Application {
	var logPipe: LogPipe {
		get {
			self.storage[LogPipeConfigurationKey.self] ?? LogPipe()
		}
		set {
			self.storage[LogPipeConfigurationKey.self] = newValue
		}
	}
}