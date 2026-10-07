#if os(iOS)
import SwiftUI

/// Large single-choice option with icon, title and optional detail.
public struct SelectionCard: View {
    let title: String
    let detail: String?
    let systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    public init(title: String, detail: String? = nil, systemImage: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(isSelected ? DS.Colors.onAccent : DS.Colors.accent)
                        .frame(width: 40, height: 40)
                        .background(isSelected ? DS.Colors.accent : DS.Colors.accentSoft,
                                    in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DS.Typography.headline)
                        .foregroundStyle(DS.Colors.textPrimary)
                    if let detail {
                        Text(detail)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: DS.Spacing.xs)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? DS.Colors.accent : DS.Colors.separator)
                    .accessibilityHidden(true)
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .strokeBorder(isSelected ? DS.Colors.accent : DS.Colors.separator, lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.selection, trigger: isSelected)
        .animation(Motion.quick, value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Compact multi-select chip. Wraps in a `FlowLayout`.
public struct SelectableChip: View {
    let title: String
    let systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    public init(title: String, systemImage: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: isSelected ? "checkmark" : systemImage)
                        .font(.footnote.weight(.semibold))
                        .accessibilityHidden(true)
                }
                Text(title).font(DS.Typography.subheadline.weight(.medium))
            }
            .padding(.horizontal, DS.Spacing.sm)
            .frame(minHeight: DS.minimumTapTarget)
            .foregroundStyle(isSelected ? DS.Colors.onAccent : DS.Colors.textPrimary)
            .background(isSelected ? DS.Colors.accent : DS.Colors.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? Color.clear : DS.Colors.separator, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.selection, trigger: isSelected)
        .animation(Motion.quick, value: isSelected)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Multi-select card list (larger targets than chips) for goal-style questions.
public struct MultiSelectCard: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    public init(title: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: systemImage)
                    .foregroundStyle(DS.Colors.accent)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                Text(title)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(isSelected ? DS.Colors.accent : DS.Colors.separator)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DS.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .strokeBorder(isSelected ? DS.Colors.accent : DS.Colors.separator, lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Native segmented control styled by the system (best accessibility and familiarity).
public struct SegmentedChoice<Value: Hashable>: View {
    let label: String
    let options: [Value]
    let title: (Value) -> String
    @Binding var selection: Value

    public init(_ label: String, options: [Value], selection: Binding<Value>, title: @escaping (Value) -> String) {
        self.label = label
        self.options = options
        self._selection = selection
        self.title = title
    }

    public var body: some View {
        Picker(label, selection: $selection) {
            ForEach(options, id: \.self) { option in
                Text(title(option)).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }
}

/// Wrapping layout for chips.
public struct FlowLayout: Layout {
    var spacing: CGFloat

    public init(spacing: CGFloat = DS.Spacing.xs) {
        self.spacing = spacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            // Cap at the available width so long labels wrap instead of overflowing at large text sizes.
            let size = subview.sizeThatFits(ProposedViewSize(width: maxWidth.isFinite ? maxWidth : nil, height: nil))
            if x > 0 && x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
#endif
