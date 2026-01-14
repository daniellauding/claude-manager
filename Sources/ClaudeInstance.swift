import Foundation

struct ClaudeInstance: Identifiable, Hashable {
    let id: Int32  // PID
    let pid: Int32
    let index: Int
    let startTime: Date
    let elapsed: String
    let type: InstanceType
    let folder: String?
    let prompt: String?
    let sessionId: String?
    let cpuPercent: Double
    let memoryKB: Int
    let tty: String?
    let isSSH: Bool

    var startTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter.string(from: startTime)
    }

    enum InstanceType: String {
        case happy = "happy"
        case terminal = "terminal"
        case node = "node"
        case unknown = "unknown"

        var icon: String {
            switch self {
            case .happy: return "face.smiling"
            case .terminal: return "terminal"
            case .node: return "circle.hexagongrid"
            case .unknown: return "questionmark.circle"
            }
        }

        var color: String {
            switch self {
            case .happy: return "green"
            case .terminal: return "blue"
            case .node: return "orange"
            case .unknown: return "gray"
            }
        }
    }

    var launchCommand: String {
        switch type {
        case .happy:
            return "happy open"
        default:
            if let folder = folder {
                return "cd \(folder) && claude"
            }
            return "claude"
        }
    }

    static func == (lhs: ClaudeInstance, rhs: ClaudeInstance) -> Bool {
        lhs.pid == rhs.pid
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(pid)
    }
}

class ClaudeProcessManager: ObservableObject {
    @Published var instances: [ClaudeInstance] = []
    @Published var isLoading = false

    private let claudeDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude")
        .appendingPathComponent("projects")

    func refresh() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let instances = self?.fetchInstances() ?? []
            DispatchQueue.main.async {
                self?.instances = instances
                self?.isLoading = false
            }
        }
    }

    private func fetchInstances() -> [ClaudeInstance] {
        // Get Claude PIDs using ps
        let pidsOutput = shell("ps -xc -o pid,command | grep -E '^\\s*[0-9]+\\s+claude$' | awk '{print $1}'")
        let pids = pidsOutput.split(separator: "\n").compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }

        return pids.enumerated().compactMap { (index, pid) -> ClaudeInstance? in
            // Get process info with CPU/MEM
            let psInfo = shell("ps -xc -p \(pid) -o lstart=,etime=,%cpu=,rss=,tty= 2>/dev/null")
            let parts = psInfo.split(separator: " ").map(String.init)
            guard parts.count >= 6 else { return nil }

            let startTimeStr = parts[0...3].joined(separator: " ")
            let elapsed = parts[4]
            let cpu = Double(parts[5]) ?? 0.0
            let rss = Int(parts[6]) ?? 0
            let tty = parts.count > 7 ? parts[7] : nil

            // Parse start time
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEE MMM d HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            let startTime = dateFormatter.date(from: startTimeStr) ?? Date()

            // Determine type and SSH status
            let ppid = shell("ps -xc -p \(pid) -o ppid= 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)
            let (type, isSSH) = determineTypeAndSSH(ppid: Int32(ppid) ?? 0)

            // Find session info
            let (folder, prompt, sessionId) = findSessionInfo(startTime: startTime)

            return ClaudeInstance(
                id: pid,
                pid: pid,
                index: index + 1,
                startTime: startTime,
                elapsed: elapsed,
                type: type,
                folder: folder,
                prompt: prompt,
                sessionId: sessionId,
                cpuPercent: cpu,
                memoryKB: rss,
                tty: tty,
                isSSH: isSSH
            )
        }
    }

    private func determineTypeAndSSH(ppid: Int32) -> (ClaudeInstance.InstanceType, Bool) {
        var isSSH = false

        // Check ancestry for happy-coder and sshd
        var checkPid = ppid
        var depth = 0
        while checkPid > 1 && depth < 10 {
            let cmd = shell("ps -xc -p \(checkPid) -o command= 2>/dev/null")
            if cmd.contains("happy-coder") {
                return (.happy, isSSH)
            }
            if cmd.contains("sshd") {
                isSSH = true
            }
            let nextPpid = shell("ps -xc -p \(checkPid) -o ppid= 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)
            checkPid = Int32(nextPpid) ?? 0
            depth += 1
        }

        let parentCmd = shell("ps -xc -p \(ppid) -o command= 2>/dev/null")
        if parentCmd.contains("zsh") || parentCmd.contains("bash") {
            return (.terminal, isSSH)
        } else if parentCmd.contains("node") {
            return (.node, isSSH)
        }
        return (.unknown, isSSH)
    }

    private func findSessionInfo(startTime: Date) -> (folder: String?, prompt: String?, sessionId: String?) {
        // Find recently modified JSONL files
        let findOutput = shell("find '\(claudeDir.path)' -name '*.jsonl' -mmin -120 -type f 2>/dev/null | xargs ls -t 2>/dev/null | head -10")
        let files = findOutput.split(separator: "\n").map(String.init)

        for file in files {
            let fileURL = URL(fileURLWithPath: file)
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: file),
                  let modDate = attrs[.modificationDate] as? Date else { continue }

            let diff = abs(modDate.timeIntervalSince(startTime))
            if diff < 600 {
                // Extract folder from path
                let folder = fileURL.deletingLastPathComponent().path
                    .replacingOccurrences(of: claudeDir.path + "/", with: "")
                    .replacingOccurrences(of: "-", with: "/")

                // Extract first prompt
                let prompt = extractFirstPrompt(from: file)
                let sessionId = fileURL.deletingPathExtension().lastPathComponent

                return (folder, prompt, sessionId)
            }
        }

        return (nil, nil, nil)
    }

    private func extractFirstPrompt(from file: String) -> String? {
        let grepOutput = shell("grep '\"type\":\"user\"' '\(file)' 2>/dev/null | head -1")
        guard !grepOutput.isEmpty else { return nil }

        // Parse JSON to extract content
        if let data = grepOutput.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = json["message"] as? [String: Any],
           let content = message["content"] as? String {
            return String(content.prefix(50)).replacingOccurrences(of: "\n", with: " ")
        }
        return nil
    }

    func killInstance(_ instance: ClaudeInstance, force: Bool = false) {
        let signal = force ? "-9" : "-15"
        _ = shell("kill \(signal) \(instance.pid) 2>/dev/null")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refresh()
        }
    }

    func killAll(force: Bool = false) {
        let signal = force ? "-9" : "-15"
        for instance in instances {
            _ = shell("kill \(signal) \(instance.pid) 2>/dev/null")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refresh()
        }
    }

    private func shell(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        task.standardInput = nil

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
