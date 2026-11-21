import SwiftUI

/// 「我的」页里参与成绩统计的站点。比比赛六站多 VJudge、HDU 两个。
enum StatSite: String, CaseIterable, Identifiable, Codable {
    case cf
    case atcoder
    case lc
    case lg
    case nc
    case vj
    case hdu

    var id: String { rawValue }

    var name: String {
        switch self {
        case .cf: return "Codeforces"
        case .atcoder: return "AtCoder"
        case .lc: return "力扣"
        case .lg: return "洛谷"
        case .nc: return "牛客"
        case .vj: return "VJudge"
        case .hdu: return "HDU"
        }
    }

    var hint: String {
        switch self {
        case .cf: return "handle，如 tourist"
        case .atcoder: return "handle，如 tourist"
        case .lc: return "用户名，如 shang-shan-zhao-xing"
        case .lg: return "用户名或 UID"
        case .nc: return "用户 id，如 448522731"
        case .vj: return "用户名"
        case .hdu: return "用户名"
        }
    }

    /// 比赛六站复用同一套 logo；VJudge 用自绘 VJ 徽标，HDU 用其站点图标。
    var logoName: String? {
        switch self {
        case .cf: return "logo_cf"
        case .atcoder: return "logo_atcoder"
        case .lc: return "logo_lc"
        case .lg: return "logo_luogu"
        case .nc: return "logo_nowcoder"
        case .vj: return "logo_vj"
        case .hdu: return "logo_hdu"
        }
    }

    /// ojhunt 聚合接口里各站的路径名（牛客是 nowcoder，不是 nc）。
    var ojhuntCode: String? {
        switch self {
        case .cf: return "cf"
        case .atcoder: return "atcoder"
        case .lc: return "leetcode"
        case .lg: return "luogu"
        case .nc: return "nowcoder"
        case .vj: return "vjudge"
        case .hdu: return "hdu"
        }
    }

    var color: Color {
        switch self {
        case .cf: return Color(hex: 0x1F8ACB)
        case .atcoder: return Color(hex: 0x3A3A46)
        case .lc: return Color(hex: 0xF89F1B)
        case .lg: return Color(hex: 0x00A6A6)
        case .nc: return Color(hex: 0x00B96B)
        case .vj: return Color(hex: 0x6B7280)
        case .hdu: return Color(hex: 0x2563EB)
        }
    }
}