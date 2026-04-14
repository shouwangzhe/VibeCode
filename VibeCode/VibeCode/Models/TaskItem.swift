import Foundation

enum TaskItemStatus: String {
    case pending
    case inProgress = "in_progress"
    case completed
    case deleted
}

@Observable
class TaskItem: Identifiable {
    let id: String
    var subject: String
    var activeForm: String?
    var status: TaskItemStatus
    let createdAt: Date

    init(id: String, subject: String, activeForm: String? = nil, status: TaskItemStatus = .pending) {
        self.id = id
        self.subject = subject
        self.activeForm = activeForm
        self.status = status
        self.createdAt = Date()
    }

    var displayText: String {
        activeForm ?? subject
    }
}
