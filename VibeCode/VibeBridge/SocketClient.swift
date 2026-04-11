import Foundation
import Shared

/// Client that connects to the VibeCode app's Unix domain socket
class SocketClient {
    private let path: String
    private var socketFd: Int32 = -1

    init(path: String) {
        self.path = path
    }

    func connect() throws {
        socketFd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard socketFd >= 0 else {
            throw SocketError.createFailed(errno)
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = path.utf8CString
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            let raw = UnsafeMutableRawPointer(ptr)
            pathBytes.withUnsafeBufferPointer { buf in
                raw.copyMemory(from: buf.baseAddress!, byteCount: min(buf.count, 104))
            }
        }

        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                Darwin.connect(socketFd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard result == 0 else {
            throw SocketError.connectFailed(errno)
        }
    }

    func sendMessage(_ data: Data) throws {
        // Length-prefixed: 4 bytes big-endian + JSON
        let length = UInt32(data.count)
        var lengthBytes: [UInt8] = [
            UInt8((length >> 24) & 0xFF),
            UInt8((length >> 16) & 0xFF),
            UInt8((length >> 8) & 0xFF),
            UInt8(length & 0xFF)
        ]
        send(socketFd, &lengthBytes, 4, 0)
        data.withUnsafeBytes { ptr in
            _ = send(socketFd, ptr.baseAddress!, data.count, 0)
        }
    }

    func readResponse(timeout: TimeInterval = 86400) throws -> Data {
        // Set socket timeout
        var tv = timeval(tv_sec: Int(timeout), tv_usec: 0)
        setsockopt(socketFd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        // Read 4-byte length header
        var lengthBytes = [UInt8](repeating: 0, count: 4)
        let headerRead = recv(socketFd, &lengthBytes, 4, MSG_WAITALL)
        guard headerRead == 4 else {
            throw SocketError.readFailed(errno)
        }

        let length = Int(lengthBytes[0]) << 24 | Int(lengthBytes[1]) << 16 |
                     Int(lengthBytes[2]) << 8 | Int(lengthBytes[3])
        guard length > 0, length < 1_000_000 else {
            throw SocketError.invalidLength(length)
        }

        var data = Data(count: length)
        let dataRead = data.withUnsafeMutableBytes { ptr in
            recv(socketFd, ptr.baseAddress!, length, MSG_WAITALL)
        }
        guard dataRead == length else {
            throw SocketError.readFailed(errno)
        }

        return data
    }

    func close() {
        if socketFd >= 0 {
            Darwin.close(socketFd)
            socketFd = -1
        }
    }

    deinit { close() }
}

enum SocketError: Error {
    case createFailed(Int32)
    case connectFailed(Int32)
    case readFailed(Int32)
    case invalidLength(Int)
}
