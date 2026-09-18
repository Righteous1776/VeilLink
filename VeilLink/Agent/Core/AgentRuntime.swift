import Foundation

@MainActor
protocol AgentRuntime: AnyObject {
    var state: AgentRuntimeState { get }
    func cancel()
    func trimMemory()
    func unload()
}
