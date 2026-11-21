import Foundation

struct StatsSnapshot {
    var solved: Int = -1
    var rating: Double?
    var extra: String?
}

struct StatsError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum StatsService {
    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 20
        cfg.timeoutIntervalForResource = 40
        cfg.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) OjHelper/1.0",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8"
        ]
        return URLSession(configuration: cfg)
    }()

    static func fetch(_ site: StatSite, handle raw: String) async throws -> StatsSnapshot {
        let handle = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !handle.isEmpty else { throw StatsError(message: "请先填写用户名") }
        switch site {
        case .cf: return try await codeforces(handle)
        case .atcoder: return try await atcoder(handle)
        case .lc: return try await leetcode(handle)
        case .lg: return try await luogu(handle)
        case .nc: return try await nowcoder(handle)
        case .vj: return try await vjudge(handle)
        case .hdu: return try await hdu(handle)
        }
    }

    // MARK: - 站点实现

    private static func codeforces(_ h: String) async throws -> StatsSnapshot {
        let esc = h.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? h
        let info = try await getJSON("https://codeforces.com/api/user.info?handles=\(esc)")
        guard (info["status"] as? String) == "OK",
              let list = info["result"] as? [[String: Any]],
              let user = list.first else {
            throw StatsError(message: "用户不存在或接口返回异常")
        }
        var snap = StatsSnapshot()
        snap.rating = number(user["rating"])
        if let rank = user["rank"] as? String { snap.extra = rank }
        var solved = try await ojhunt("cf", h)
        if solved < 0 { solved = try await codeforcesSolved(h) }
        snap.solved = solved
        return snap
    }

    private static func codeforcesSolved(_ h: String) async throws -> Int {
        var solved = Set<String>()
        var from = 1
        let esc = h.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? h
        while true {
            let json = try await getJSON("https://codeforces.com/api/user.status?handle=\(esc)&from=\(from)&count=10000")
            guard (json["status"] as? String) == "OK",
                  let rows = json["result"] as? [[String: Any]] else { break }
            for row in rows {
                guard (row["verdict"] as? String) == "OK",
                      let problem = row["problem"] as? [String: Any] else { continue }
                let cid = problem["contestId"].map { "\($0)" } ?? ""
                let idx = problem["index"] as? String ?? ""
                solved.insert("\(cid)-\(idx)")
            }
            if rows.count < 10000 { break }
            from += 10000
            try? await Task.sleep(nanoseconds: 2_100_000_000)
        }
        return solved.count
    }

    private static func atcoder(_ h: String) async throws -> StatsSnapshot {
        let enc = h.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? h
        var snap = StatsSnapshot()
        if let history = try? await getJSONArray("https://atcoder.jp/users/\(enc)/history/json"),
           let last = history.last as? [String: Any] {
            snap.rating = number(last["NewRating"])
        }
        var solved = try await ojhunt("atcoder", h)
        if solved < 0,
           let ac = try? await getJSON("https://kenkoooo.com/atcoder/atcoder-api/v3/user/ac_rank?user=\(enc)") {
            solved = (ac["count"] as? Int) ?? -1
            if let rank = ac["rank"] as? Int { snap.extra = "AC 排名 \(rank)" }
        }
        snap.solved = solved
        return snap
    }

    private static func leetcode(_ h: String) async throws -> StatsSnapshot {
        let enc = h.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? h
        let headers = ["Referer": "https://leetcode.cn/u/\(enc)/", "Origin": "https://leetcode.cn"]
        let progressQuery = """
        query userProfileUserQuestionProgress($userSlug: String!) {
          userProfileUserQuestionProgress(userSlug: $userSlug) {
            numAcceptedQuestions { difficulty count }
          }
        }
        """
        let progress = try await postJSON("https://leetcode.cn/graphql/",
                                          body: ["query": progressQuery, "variables": ["userSlug": h]],
                                          headers: headers)
        guard let data = progress["data"] as? [String: Any],
              let prog = data["userProfileUserQuestionProgress"] as? [String: Any],
              let rows = prog["numAcceptedQuestions"] as? [[String: Any]] else {
            throw StatsError(message: "用户不存在或接口返回异常")
        }
        var snap = StatsSnapshot()
        snap.solved = rows.reduce(0) { $0 + ((($1["count"]) as? Int) ?? 0) }

        let contestQuery = """
        query userContestRanking($userSlug: String!) {
          userContestRanking(userSlug: $userSlug) { rating globalRanking localRanking topPercentage }
        }
        """
        if let contest = try? await postJSON("https://leetcode.cn/graphql/noj-go/",
                                             body: ["query": contestQuery, "variables": ["userSlug": h]],
                                             headers: headers),
           let cdata = contest["data"] as? [String: Any],
           let ranking = cdata["userContestRanking"] as? [String: Any] {
            snap.rating = number(ranking["rating"])
            if let g = ranking["globalRanking"] as? Int {
                snap.extra = "全球排名 \(g)"
            }
        }
        return snap
    }

    private static func luogu(_ h: String) async throws -> StatsSnapshot {
        var uid = h
        if Int(h) == nil {
            let esc = h.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? h
            let search = try await getJSON("https://www.luogu.com.cn/api/user/search?keyword=\(esc)")
            guard let users = search["users"] as? [[String: Any]],
                  let hit = users.first(where: { (($0["name"] as? String) ?? "").lowercased() == h.lowercased() })
                    ?? users.first,
                  let id = hit["uid"] as? Int else {
                throw StatsError(message: "没有找到该用户")
            }
            uid = "\(id)"
        }
        let info = try await getJSON("https://www.luogu.com.cn/api/user/info/\(uid)")
        guard let user = info["user"] as? [String: Any] else {
            throw StatsError(message: "用户不存在或接口返回异常")
        }
        var snap = StatsSnapshot()
        snap.solved = (user["passedProblemCount"] as? Int) ?? -1
        snap.rating = number(user["elo"])
        if let ranking = user["ranking"] as? Int {
            snap.extra = "排名 \(ranking)"
        }
        return snap
    }

    private static func nowcoder(_ h: String) async throws -> StatsSnapshot {
        let enc = h.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? h
        let html = try await getString("https://ac.nowcoder.com/acm/contest/profile/\(enc)")
        var snap = StatsSnapshot()
        if let text = firstMatch(#"class="state-num rate-score4">(\d+)<"#, in: html) {
            snap.rating = Double(text)
        }
        if let text = firstMatch(#"Rating排名</span>\s*<[^>]*>\s*(\d+)"#, in: html)
            ?? firstMatch(#"Rating排名[^0-9]{0,120}?(\d+)"#, in: html) {
            snap.extra = "Rating 排名 \(text)"
        }
        var solved = try await ojhunt("nc", h)
        if solved < 0 { solved = -1 }
        snap.solved = solved
        return snap
    }

    private static func vjudge(_ h: String) async throws -> StatsSnapshot {
        let enc = h.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? h
        let html = try await getString("https://vjudge.net/user/\(enc)")
        guard let jsonText = firstMatch(#"<script id="profile-header-data"[^>]*>([\s\S]*?)</script>"#, in: html),
              let data = jsonText.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw StatsError(message: "用户不存在或页面结构已变化")
        }
        var snap = StatsSnapshot()
        if let counts = json["counts"] as? [String: Any] {
            snap.solved = (counts["acAll"] as? Int) ?? -1
        }
        if let ranks = json["ranks"] as? [String: Any], let rank = ranks["all"] as? Int {
            snap.extra = "排名 \(rank)"
        }
        return snap
    }

    private static func hdu(_ h: String) async throws -> StatsSnapshot {
        let esc = h.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? h
        let html = try await getString("https://acm.hdu.edu.cn/userstatus.php?user=\(esc)", gb18030: true)
        var snap = StatsSnapshot()
        if let text = firstMatch(#"Problems Solved</td>\s*<td[^>]*>\s*<[^>]*>\s*(\d+)"#, in: html)
            ?? firstMatch(#"Problems Solved[^0-9]{0,120}?(\d+)"#, in: html) {
            snap.solved = Int(text) ?? -1
        }
        if let text = firstMatch(#"Rank</td>\s*<td[^>]*>\s*(\d+)"#, in: html)
            ?? firstMatch(#"Rank[^0-9]{0,120}?(\d+)"#, in: html) {
            snap.extra = "排名 \(text)"
        }
        if snap.solved < 0 { throw StatsError(message: "用户不存在或页面结构已变化") }
        return snap
    }

    // MARK: - 公共数据源与工具

    /// ojhunt 统一抓解题数；失败返回 -1。
    private static func ojhunt(_ code: String, _ handle: String) async throws -> Int {
        let esc = handle.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? handle
        guard let json = try? await getJSON("https://ojhunt.com/api/crawlers/\(code)/\(esc)"),
              let data = json["data"] as? [String: Any] else { return -1 }
        if let solved = data["solved"] as? Int, solved >= 0 { return solved }
        return -1
    }

    static func getJSON(_ url: String) async throws -> [String: Any] {
        let data = try await getData(url)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw StatsError(message: "返回内容不是 JSON")
        }
        return json
    }

    static func getJSONArray(_ url: String) async throws -> [Any] {
        let data = try await getData(url)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
            throw StatsError(message: "返回内容不是 JSON")
        }
        return json
    }

    static func postJSON(_ url: String, body: [String: Any], headers: [String: String] = [:]) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://leetcode.cn/", forHTTPHeaderField: "Origin")
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        try check(response)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw StatsError(message: "返回内容不是 JSON")
        }
        return json
    }

    static func getString(_ url: String, gb18030: Bool = false) async throws -> String {
        let data = try await getData(url)
        if gb18030, let text = String(data: data, encoding: .init(rawValue: 0x8000_0632)) {
            return text
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func getData(_ url: String) async throws -> Data {
        guard let u = URL(string: url) else { throw StatsError(message: "地址无效") }
        let (data, response) = try await session.data(from: u)
        try check(response)
        return data
    }

    private static func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode == 404 { throw StatsError(message: "用户不存在") }
        if !(200..<300).contains(http.statusCode) {
            throw StatsError(message: "HTTP \(http.statusCode)")
        }
    }

    private static func number(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let s = value as? String { return Double(s) }
        return nil
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }
}