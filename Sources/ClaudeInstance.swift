import Foundation

struct ClaudeInstance: Identifiable, Hashable {
    let id: Int32  // PID
    let pid: Int32
    let index: Int
    let startTime: Date
    let elapsed: String
    let type: InstanceType
    let folder: String?        // Working directory (cwd)
    let prompt: String?        // First user prompt
    let sessionId: String?
    let sessionTitle: String?  // Chat title from session
    let gitBranch: String?     // Git branch if available
    let cpuPercent: Double
    let memoryKB: Int
    let tty: String?
    let isSSH: Bool
    let parentChain: String?   // Process ancestry chain

    var startTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter.string(from: startTime)
    }

    enum InstanceType: String {
        case happy = "Happy"
        case terminal = "Terminal"
        case node = "Node.js"
        case unknown = "Unknown"

        var icon: String {
            switch self {
            case .happy: return "face.smiling"
            case .terminal: return "terminal"
            case .node: return "circle.hexagongrid"
            case .unknown: return "questionmark.circle"
            }
        }

        var description: String {
            switch self {
            case .happy: return "Spawned by Happy app (Warp terminal)"
            case .terminal: return "Started from shell (zsh/bash)"
            case .node: return "Spawned by Node.js/MCP server"
            case .unknown: return "Unknown parent process"
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

    private var refreshTimer: Timer?
    private var lastPidSet: Set<Int32> = []

    init() {
        startAutoRefresh()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    func startAutoRefresh() {
        // Refresh every 5 seconds
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }

    private func checkForChanges() {
        // Quick check if PIDs changed before doing full refresh
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let pidsOutput = self.shell("ps -xc -o pid,command | grep -E '^\\s*[0-9]+\\s+claude$' | awk '{print $1}'")
            let currentPids = Set(pidsOutput.split(separator: "\n").compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) })

            if currentPids != self.lastPidSet {
                self.lastPidSet = currentPids
                DispatchQueue.main.async {
                    self.refresh()
                }
            }
        }
    }

    func refresh() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let instances = self?.fetchInstances() ?? []
            DispatchQueue.main.async {
                self?.instances = instances
                self?.isLoading = false
                // Update lastPidSet
                self?.lastPidSet = Set(instances.map { $0.pid })
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
            let (type, isSSH, parentChain) = determineTypeAndSSH(ppid: Int32(ppid) ?? 0)

            // Find session info using PID-based lookup for accuracy
            let sessionInfo = findSessionInfo(pid: pid, startTime: startTime)

            return ClaudeInstance(
                id: pid,
                pid: pid,
                index: index + 1,
                startTime: startTime,
                elapsed: elapsed,
                type: type,
                folder: sessionInfo.folder,
                prompt: sessionInfo.prompt,
                sessionId: sessionInfo.sessionId,
                sessionTitle: sessionInfo.sessionTitle,
                gitBranch: sessionInfo.gitBranch,
                cpuPercent: cpu,
                memoryKB: rss,
                tty: tty,
                isSSH: isSSH,
                parentChain: parentChain.isEmpty ? nil : parentChain
            )
        }
    }

    private func determineTypeAndSSH(ppid: Int32) -> (ClaudeInstance.InstanceType, Bool, String) {
        var isSSH = false
        var chain: [String] = []

        // Check ancestry for happy-coder and sshd
        var checkPid = ppid
        var depth = 0
        var foundType: ClaudeInstance.InstanceType = .unknown

        while checkPid > 1 && depth < 10 {
            let cmd = shell("ps -xc -p \(checkPid) -o command= 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)
            if !cmd.isEmpty {
                chain.append(cmd)
            }
            if cmd.contains("happy-coder") {
                foundType = .happy
            }
            if cmd.contains("sshd") {
                isSSH = true
            }
            let nextPpid = shell("ps -xc -p \(checkPid) -o ppid= 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)
            checkPid = Int32(nextPpid) ?? 0
            depth += 1
        }

        if foundType == .happy {
            return (.happy, isSSH, chain.joined(separator: " → "))
        }

        let parentCmd = shell("ps -xc -p \(ppid) -o command= 2>/dev/null")
        if parentCmd.contains("zsh") || parentCmd.contains("bash") {
            return (.terminal, isSSH, chain.joined(separator: " → "))
        } else if parentCmd.contains("node") {
            return (.node, isSSH, chain.joined(separator: " → "))
        }
        return (.unknown, isSSH, chain.joined(separator: " → "))
    }

    struct SessionInfo {
        var folder: String?
        var prompt: String?
        var sessionId: String?
        var sessionTitle: String?
        var gitBranch: String?
    }

    private func findSessionInfo(pid: Int32, startTime: Date) -> SessionInfo {
        // Method 1: Use lsof to find open session files for this specific PID
        // This is the most accurate method - directly links PID to its session file
        let lsofOutput = shell("lsof -p \(pid) 2>/dev/null | grep '\\.jsonl' | grep -v subagents | awk '{print $NF}'")
        let lsofFiles = lsofOutput.split(separator: "\n").map(String.init)

        for file in lsofFiles {
            if FileManager.default.fileExists(atPath: file) {
                let fileURL = URL(fileURLWithPath: file)
                return extractSessionDetails(from: file, fileURL: fileURL)
            }
        }

        // Method 2: Fallback to time-based matching if lsof didn't find anything
        // (e.g., if file was opened and closed, or process is in different state)
        let findOutput = shell("find '\(claudeDir.path)' -name '*.jsonl' -mmin -120 -type f ! -path '*/subagents/*' 2>/dev/null | xargs ls -t 2>/dev/null | head -20")
        let files = findOutput.split(separator: "\n").map(String.init)

        for file in files {
            let fileURL = URL(fileURLWithPath: file)
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: file),
                  let modDate = attrs[.modificationDate] as? Date else { continue }

            let diff = abs(modDate.timeIntervalSince(startTime))
            if diff < 600 {
                return extractSessionDetails(from: file, fileURL: fileURL)
            }
        }

        return SessionInfo()
    }

    private func extractSessionDetails(from file: String, fileURL: URL) -> SessionInfo {
        var info = SessionInfo()
        info.sessionId = fileURL.deletingPathExtension().lastPathComponent

        // Extract folder from path (like cls does: dirname | sed 's|.*/projects/||' | sed 's|-|/|g')
        let dirPath = fileURL.deletingLastPathComponent().path
        if let range = dirPath.range(of: "/projects/") {
            let folderEncoded = String(dirPath[range.upperBound...])
            info.folder = folderEncoded.replacingOccurrences(of: "-", with: "/")
        }

        // Use grep + python3 for reliable JSON parsing (same approach as cls)
        // Read first user message directly with python to avoid shell escaping issues
        let pythonScript = """
        import json
        try:
            with open('\(file.replacingOccurrences(of: "'", with: "'\\''"))', 'r') as f:
                for line in f:
                    try:
                        d = json.loads(line)
                        if d.get('type') == 'user':
                            print(d.get('cwd', ''))
                            print(d.get('gitBranch', ''))
                            content = d.get('message', {}).get('content', '')
                            if isinstance(content, str):
                                print(content[:80].replace('\\n', ' '))
                            else:
                                print('')
                            break
                    except:
                        continue
        except:
            print('')
            print('')
            print('')
        """
        let parseOutput = shell("python3 -c \"\(pythonScript)\" 2>/dev/null")
        if !parseOutput.isEmpty {
            let parts = parseOutput.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

            if parts.count >= 1 && !parts[0].isEmpty {
                info.folder = parts[0]  // Override with cwd from JSON
            }
            if parts.count >= 2 && !parts[1].isEmpty {
                info.gitBranch = parts[1]
            }
            if parts.count >= 3 && !parts[2].isEmpty {
                info.prompt = parts[2].trimmingCharacters(in: .whitespaces)
            }
        }

        // Search for chat title
        let titleOutput = shell("grep -m1 'changed chat title to' '\(file)' 2>/dev/null")
        if let titleMatch = titleOutput.range(of: "\"([^\"]+)\"", options: .regularExpression) {
            let title = String(titleOutput[titleMatch]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            info.sessionTitle = title
        }

        return info
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
