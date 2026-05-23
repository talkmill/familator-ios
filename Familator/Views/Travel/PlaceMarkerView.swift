import SwiftUI

struct PlaceMarkerView: View {
    let index: Int
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 30, height: 30)
            Circle()
                .strokeBorder(.white, lineWidth: 2)
                .frame(width: 30, height: 30)
            Text("\(index + 1)")
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
        .shadow(radius: 2)
    }
}
