import SwiftUI

/// A selectable package card: name, level range, summary and, when relevant,
/// the "For Turkish speakers" caption and an access badge.
struct PackageOptionRow: View {
    let option: PackageOption
    let isSelected: Bool
    var accessBadge: String? = nil
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.name).font(.headline).foregroundStyle(Theme.ink)
                    HStack(spacing: 6) {
                        Text("\(option.levelLower)–\(option.levelUpper)")
                        if let accessBadge {
                            Text("·")
                            Text(accessBadge).foregroundStyle(Theme.accent)
                        }
                    }
                    .font(.caption).foregroundStyle(Theme.secondaryInk)
                    if let summary = option.summary, !summary.isEmpty {
                        Text(summary).font(.subheadline).foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if option.isForTurkishSpeakers {
                        Text("For Turkish speakers").font(.caption.weight(.semibold)).foregroundStyle(Theme.primary)
                    }
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.primary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(isSelected ? Theme.primary : Theme.border, lineWidth: isSelected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
