import SwiftUI

/// OJ 站点 logo（资源来自 Android 版的 xxxhdpi 图）。
struct LogoView: View {
    let oj: OJ
    var size: CGFloat = 22

    var body: some View {
        Image(oj.logoName)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .accessibilityLabel(oj.name)
    }
}