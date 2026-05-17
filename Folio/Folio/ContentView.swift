import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack(alignment: .top) {
            Self.paper.ignoresSafeArea()

            Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide).year())
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(Self.ink)
                .padding(.top, 8)
        }
    }

    /// Cream off-white, slightly warm. Per design.md §8.1.
    /// Temporary as a flat colour — the paper texture comes later.
    static let paper = Color(red: 0.98, green: 0.96, blue: 0.92)

    /// Deep warm near-black. Never pure #000. Per design.md §8.1.
    static let ink = Color(red: 0.18, green: 0.16, blue: 0.14)
}

#Preview {
    ContentView()
}
