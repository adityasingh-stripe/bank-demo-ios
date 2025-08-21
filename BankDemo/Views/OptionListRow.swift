import SwiftUI

struct OptionListRow: View {
    let title: String
    private(set) var subtitle: String?
    var selected: Bool = false
    var onSelected: () -> Void
    var body: some View {
        Button {
            onSelected()
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)
                    subtitle.map(Text.init)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
                    .opacity(selected ? 1.0 : 0.0)
            }
        }
    }
}
