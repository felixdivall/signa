import os

enum Log {
    static let library = Logger(subsystem: "com.felixdivall.signa", category: "library")
    static let system = Logger(subsystem: "com.felixdivall.signa", category: "system")
}
