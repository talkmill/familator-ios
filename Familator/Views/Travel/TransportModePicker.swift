import SwiftUI

struct TransportModePicker: View {
    @Binding var selectedMode: TransportMode
    var onChange: (TransportMode) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TransportMode.allCases, id: \.self) { mode in
                Button {
                    selectedMode = mode
                    onChange(mode)
                } label: {
                    Image(systemName: mode.systemImage)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedMode == mode ? Color.accentColor : Color.clear)
                        .foregroundStyle(selectedMode == mode ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
