import Foundation

/// 六个 OJ 的比赛抓取：全部使用官网公开接口 / 服务端渲染页面，不需要登录。
enum ContestAPI {

    enum FetchError: LocalizedError {
        case http(Int)
        case decode(String)
        case parse(String)

        var errorDescription: String? {
            switch self {
            case .http(let code): return "HTTP \(code)"
            case .decode(let message): return "解析失败：\(message)"
            case .parse(let message): return "页面结构变化：\(message)"
            }
        }
    }

    // MARK: - 入口

    /// 并行拉全部源；单个源失败不影响其他源。
    static func fetchAll() async -> [OJ: Result<[Contest], Error>] {
        await withTaskGroup(of: (OJ, Result<[Contest], Error>).self) { group in
            for oj in OJ.allCases {
                group.addTask {
                    do {
                        let list = try await fetch(oj)
                        return (oj, .success(list))
                    } catch {
                        return (oj, .failure(error))
                    }
                }
            }
            var out: [OJ: Result<[Contest], Error>] = [:]
            for await pair in group {
                out[pair.0] = pair.1
            }
            return out
        }
    }

    static func fetch(_ oj: OJ) async throws -> [Contest] {
        switch oj {
        case .cf: return try await codeforces()
        case .atcoder: return try await atcoder()
        case .luogu: return try await luogu()
        case .lanqiao: return try await lanqiao()
        case .leetcode: return try await leetcode()
        case .nowcoder: return try await nowcoder()
        }
    }

    // MARK: - 网络

    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        cfg.timeoutIntervalForResource = 40
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
        ]
        return URLSession(configuration: cfg)
    }()

    private static func load(
        _ url: URL,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = body
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw FetchError.http(http.statusCode)
        }
        return data
    }

    // MARK: - Codeforces

    private struct CFEnvelope: Decodable {
        let status: String
        let result: [CFItem]?
    }

    private struct CFItem: Decodable {
        let id: Int
        let name: String
        let phase: String?
        let startTimeSeconds: Int?
        let durationSeconds: Int?
    }

    private static func codeforces() async throws -> [Contest] {
        let url = URL(string: "https://codeforces.com/api/contest.list?gym=false")!
        let data = try await load(url)
        let envelope = try JSONDecoder().decode(CFEnvelope.self, from: data)
        guard envelope.status == "OK" else {
            throw FetchError.parse("status=\(envelope.status)")
        }
        var out: [Contest] = []
        for item in envelope.result ?? [] {
            guard item.phase == "BEFORE" || item.phase == "CODING" else { continue }
            guard let seconds = item.startTimeSeconds, seconds > 0 else { continue }
            let start = Date(timeIntervalSince1970: TimeInterval(seconds))
            let end = start.addingTimeInterval(TimeInterval(item.durationSeconds ?? 7200))
            guard Contest.inWindow(start, end) else { continue }
            out.append(
                Contest(
                    oj: .cf,
                    sid: String(item.id),
                    title: item.name,
                    start: start,
                    end: end,
                    url: URL(string: "https://codeforces.com/contest/\(item.id)")
                )
            )
        }
        return out
    }

    // MARK: - 力扣

    private struct LCEnvelope: Decodable {
        let data: LCData?
    }

    private struct LCData: Decodable {
        let contestUpcomingContests: [LCItem]?
    }

    private struct LCItem: Decodable {
        let title: String
        let startTime: Int
        let duration: Int
        let titleSlug: String?
    }

    private static func leetcode() async throws -> [Contest] {
        let url = URL(string: "https://leetcode.cn/graphql")!
        let query = "{\"query\":\"{ contestUpcomingContests { title startTime duration titleSlug } }\"}"
        let data = try await load(
            url,
            method: "POST",
            headers: ["Content-Type": "application/json", "Referer": "https://leetcode.cn/contest/"],
            body: query.data(using: .utf8)
        )
        let envelope = try JSONDecoder().decode(LCEnvelope.self, from: data)
        guard let items = envelope.data?.contestUpcomingContests else {
            throw FetchError.parse("缺少 contestUpcomingContests")
        }
        var out: [Contest] = []
        for item in items {
            guard item.startTime > 0, !item.title.isEmpty else { continue }
            let start = Date(timeIntervalSince1970: TimeInterval(item.startTime))
            let duration = item.duration > 0 ? item.duration : 5400
            let end = start.addingTimeInterval(TimeInterval(duration))
            guard Contest.inWindow(start, end) else { continue }
            let slug = (item.titleSlug ?? "").isEmpty ? String(item.startTime) : (item.titleSlug ?? "")
            out.append(
                Contest(
                    oj: .leetcode,
                    sid: slug,
                    title: item.title,
                    start: start,
                    end: end,
                    url: URL(string: "https://leetcode.cn/contest/\(slug)/")
                )
            )
        }
        return out
    }

    // MARK: - 洛谷

    private static func luogu() async throws -> [Contest] {
        let url = URL(string: "https://www.luogu.com.cn/contest/list?_contentOnly=1")!
        let data = try await load(
            url,
            headers: [
                "x-lentille-request": "content-only",
                "x-requested-with": "XMLHttpRequest",
                "Referer": "https://www.luogu.com.cn/contest/list",
            ]
        )
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FetchError.parse("返回不是 JSON")
        }
        guard let items = firstResultArray(in: root) else {
            throw FetchError.parse("未找到 result")
        }
        var out: [Contest] = []
        for item in items {
            guard let name = item["name"] as? String, !name.isEmpty else { continue }
            guard let startSeconds = intValue(item["startTime"]), startSeconds > 0 else { continue }
            let start = Date(timeIntervalSince1970: TimeInterval(startSeconds))
            var end = start.addingTimeInterval(2 * 3600)
            if let endSeconds = intValue(item["endTime"]), endSeconds > startSeconds {
                end = Date(timeIntervalSince1970: TimeInterval(endSeconds))
            }
            guard Contest.inWindow(start, end) else { continue }
            let sid = String(intValue(item["id"]) ?? startSeconds)
            out.append(
                Contest(
                    oj: .luogu,
                    sid: sid,
                    title: name,
                    start: start,
                    end: end,
                    url: URL(string: "https://www.luogu.com.cn/contest/\(sid)")
                )
            )
        }
        return out
    }

    /// 递归找第一个非空的 result 数组（洛谷把列表藏在 currentData.contests 里）。
    private static func firstResultArray(in value: Any) -> [[String: Any]]? {
        if let dict = value as? [String: Any] {
            if let array = dict["result"] as? [Any] {
                let items = array.compactMap { $0 as? [String: Any] }
                if !items.isEmpty { return items }
            }
            for (_, child) in dict {
                if let found = firstResultArray(in: child) { return found }
            }
        }
        return nil
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string) }
        return nil
    }

    // MARK: - 蓝桥云课

    private struct LQItem: Decodable {
        let id: Int
        let name: String
        let openAt: String?
        let endAt: String?
        let htmlURL: String?

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case openAt = "open_at"
            case endAt = "end_at"
            case htmlURL = "html_url"
        }
    }

    private static func lanqiao() async throws -> [Contest] {
        let url = URL(string: "https://www.lanqiao.cn/api/v2/contests/?sort=opentime&paginate=0&status=not_finished&game_type_code=2")!
        let data = try await load(url, headers: ["Referer": "https://www.lanqiao.cn/contests/"])
        let items = try JSONDecoder().decode([LQItem].self, from: data)
        var out: [Contest] = []
        for item in items {
            guard !item.name.isEmpty else { continue }
            guard let start = isoDate(item.openAt), start.timeIntervalSince1970 > 0 else { continue }
            var end = start.addingTimeInterval(2 * 3600)
            if let parsed = isoDate(item.endAt), parsed > start {
                end = parsed
            }
            guard Contest.inWindow(start, end) else { continue }
            let href = item.htmlURL ?? ""
            let page = href.hasPrefix("http") ? href : "https://www.lanqiao.cn\(href)"
            out.append(
                Contest(
                    oj: .lanqiao,
                    sid: String(item.id),
                    title: item.name,
                    start: start,
                    end: end,
                    url: URL(string: page)
                )
            )
        }
        return out
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static func isoDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        return isoFormatter.date(from: raw)
    }

    // MARK: - AtCoder（官网 SSR HTML 里的 Upcoming Contests 表）

    private static func atcoder() async throws -> [Contest] {
        let url = URL(string: "https://atcoder.jp/contests/")!
        let data = try await load(url, headers: ["Referer": "https://atcoder.jp/"])
        guard let html = String(data: data, encoding: .utf8), !html.isEmpty else {
            throw FetchError.parse("空响应")
        }
        let pattern = #"<tr>\s*<td[^>]*>\s*<a href=['"][^>]*['"]>\s*<time class=['"]fixtime fixtime-full['"]>([^<]+)</time>.*?<a href="/contests/([^"]+)">([^<]+)</a>.*?<td class="text-center">(\d{1,3}):(\d{2})</td>"#
        let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let ns = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else {
            throw FetchError.parse("未匹配到表格行")
        }
        var seen = Set<String>()
        var out: [Contest] = []
        for match in matches {
            guard match.numberOfRanges >= 6 else { continue }
            let sid = ns.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
            let rawTime = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            let rawTitle = ns.substring(with: match.range(at: 3))
            guard let start = atcoderDate(rawTime) else { continue }
            let hours = Int(ns.substring(with: match.range(at: 4))) ?? 0
            let minutes = Int(ns.substring(with: match.range(at: 5))) ?? 0
            let duration = Double(hours * 60 + minutes) * 60
            guard duration > 0, !sid.isEmpty, seen.insert(sid).inserted else { continue }
            let end = start.addingTimeInterval(duration)
            guard Contest.inWindow(start, end) else { continue }
            let title = unescape(stripTags(rawTitle)).trimmingCharacters(in: .whitespacesAndNewlines)
            out.append(
                Contest(
                    oj: .atcoder,
                    sid: sid,
                    title: title.isEmpty ? sid : title,
                    start: start,
                    end: end,
                    url: URL(string: "https://atcoder.jp/contests/\(sid)")
                )
            )
        }
        return out
    }

    /// AtCoder 时间形如 `2026-11-21 21:00:00+0900`，自带时区。
    private static let atcoderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ssZ"
        return formatter
    }()

    private static func atcoderDate(_ raw: String) -> Date? {
        atcoderFormatter.date(from: raw)
    }

    // MARK: - 牛客（服务端 HTML）

    private static func nowcoder() async throws -> [Contest] {
        let url = URL(string: "https://ac.nowcoder.com/acm/contest/vip-index")!
        let data = try await load(url, headers: ["Referer": "https://ac.nowcoder.com/acm/contest/vip-index"])
        let html = decodeText(data)
        guard !html.isEmpty else { throw FetchError.parse("空响应") }
        let blocks = html.components(separatedBy: "<div class=\"platform-item-main\">")
        let timePattern = "比赛时间：\\s*(\\d{4}-\\d{1,2}-\\d{1,2}\\s+\\d{1,2}:\\d{2})\\s*至\\s*(\\d{4}-\\d{1,2}-\\d{1,2}\\s+\\d{1,2}:\\d{2})"
        let linkPattern = "<a href=\"/acm/contest/(\\d+)\"[^>]*>(.*?)</a>"
        let timeRegex = try NSRegularExpression(pattern: timePattern)
        let linkRegex = try NSRegularExpression(pattern: linkPattern, options: [.dotMatchesLineSeparators])
        var out: [Contest] = []
        for block in blocks.dropFirst() {
            let ns = block as NSString
            let range = NSRange(location: 0, length: ns.length)
            guard let timeMatch = timeRegex.firstMatch(in: block, range: range), timeMatch.numberOfRanges >= 3 else {
                continue
            }
            guard let linkMatch = linkRegex.firstMatch(in: block, range: range), linkMatch.numberOfRanges >= 3 else {
                continue
            }
            let startRaw = ns.substring(with: timeMatch.range(at: 1))
            let endRaw = ns.substring(with: timeMatch.range(at: 2))
            guard let start = nowcoderDate(startRaw), let end = nowcoderDate(endRaw), end > start else {
                continue
            }
            guard Contest.inWindow(start, end) else { continue }
            let sid = ns.substring(with: linkMatch.range(at: 1))
            let title = unescape(stripTags(ns.substring(with: linkMatch.range(at: 2))))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            out.append(
                Contest(
                    oj: .nowcoder,
                    sid: sid,
                    title: title.isEmpty ? "牛客练习赛 \(sid)" : title,
                    start: start,
                    end: end,
                    url: URL(string: "https://ac.nowcoder.com/acm/contest/\(sid)")
                )
            )
        }
        return out
    }

    private static let nowcoderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    private static func nowcoderDate(_ raw: String) -> Date? {
        let cleaned = raw.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        return nowcoderFormatter.date(from: cleaned)
    }

    // MARK: - 文本工具

    private static func decodeText(_ data: Data) -> String {
        if let text = String(data: data, encoding: .utf8) { return text }
        let gb = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        return String(data: data, encoding: String.Encoding(rawValue: gb)) ?? ""
    }

    private static func stripTags(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }

    private static func unescape(_ text: String) -> String {
        let map = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
            "&#39;": "'", "&apos;": "'", "&nbsp;": " ",
        ]
        var out = text
        for (key, value) in map {
            out = out.replacingOccurrences(of: key, with: value)
        }
        return out
    }
}