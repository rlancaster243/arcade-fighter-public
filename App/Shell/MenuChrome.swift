import SwiftUI

struct MenuBackground<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.08, blue: 0.14), Color(red: 0.02, green: 0.02, blue: 0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.cyan)
                content
            }
            .padding(24)
        }
    }
}

struct MenuListRow: View {
    let label: String
    let selected: Bool

    var body: some View {
        HStack {
            Text(selected ? "▶" : " ")
                .foregroundStyle(.yellow)
            Text(label)
                .font(.system(size: 18, weight: selected ? .bold : .regular, design: .rounded))
                .foregroundStyle(selected ? .white : .gray)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct MenuHintBar: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 8)
    }
}