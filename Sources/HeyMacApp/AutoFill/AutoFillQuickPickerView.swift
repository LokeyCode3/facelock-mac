import AppKit
import Foundation
import HeyMacEngine
import Observation
import SwiftUI

/// Generates a pleasant domain avatar badge with the initial letter and harmonious accent tint.
struct DomainAvatarView: View {
    let title: String
    let domain: String
    var size: CGFloat = 32

    private var initial: String {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = name.first { return String(first).uppercased() }
        return "•"
    }

    private var tint: Color {
        let text = domain.isEmpty ? title : domain
        let hash = abs(text.lowercased().hashValue)
        let colors: [Color] = [
            Color(hex: 0x0071E3), // Apple Blue
            Color(hex: 0x34C759), // Green
            Color(hex: 0xFF9500), // Orange (Amazon)
            Color(hex: 0xAF52DE), // Purple
            Color(hex: 0xFF2D55), // Coral Pink
            Color(hex: 0x5856D6), // Indigo
            Color(hex: 0x00C7BE), // Cyan Teal
        ]
        return colors[hash % colors.count]
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(tint.opacity(0.18))
            Text(initial)
                .font(.system(size: size * 0.44, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .stroke(tint.opacity(0.28), lineWidth: 1)
        )
    }
}

@MainActor @Observable
final class AutoFillPickerState {
    static let shared = AutoFillPickerState()
    var search = ""
    var credentials: [Credential] = []
    var hoveredID: UUID?
    var onSelect: ((Credential) -> Void)?
    var onCancel: (() -> Void)?

    var filtered: [Credential] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return credentials }
        return credentials.filter { $0.matches(target: q) }
    }
}

/// Floating spotlight-style AutoFill Quick Picker with frosted glass and fluid animations.
struct AutoFillQuickPickerView: View {
    let state: AutoFillPickerState

    var body: some View {
        VStack(spacing: 0) {
            // Search Input Header
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.accent)

                TextField("Search saved logins (e.g. Amazon, Google)…", text: Binding(
                    get: { state.search },
                    set: { state.search = $0 }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .onSubmit {
                    if let first = state.filtered.first {
                        state.onSelect?(first)
                    }
                }

                if !state.search.isEmpty {
                    Button(action: { state.search = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                }

                // Keyboard escape hint
                HStack(spacing: 3) {
                    Text("esc")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 14)
            .background(Surface.card)

            Divider()

            // Credential results list
            ScrollView {
                LazyVStack(spacing: 2) {
                    if state.filtered.isEmpty {
                        VStack(spacing: Spacing.sm) {
                            Image(systemName: "key.slash")
                                .font(.system(size: 26))
                                .foregroundStyle(.secondary)
                            Text("No matching logins found")
                                .font(.system(size: 13, weight: .medium))
                            Text("Try searching by site name, username, or domain.")
                                .font(Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    } else {
                        ForEach(state.filtered) { cred in
                            let isHovered = state.hoveredID == cred.id
                            Button(action: { state.onSelect?(cred) }) {
                                HStack(spacing: Spacing.md) {
                                    DomainAvatarView(title: cred.title, domain: cred.displayHost)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(cred.title)
                                            .font(.system(size: 13.5, weight: .semibold))
                                            .foregroundStyle(Color.primary)
                                            .lineLimit(1)

                                        HStack(spacing: 5) {
                                            if !cred.username.isEmpty {
                                                Text(cred.username)
                                                    .font(Typography.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                            if !cred.url.isEmpty {
                                                Text("•")
                                                    .font(Typography.caption)
                                                    .foregroundStyle(.tertiary)
                                                Text(cred.displayHost)
                                                    .font(Typography.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                    }

                                    Spacer(minLength: 0)

                                    // Action badge
                                    HStack(spacing: 5) {
                                        Image(systemName: "faceid")
                                            .font(.system(size: 14))
                                        Text("AutoFill")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(isHovered ? Theme.accent : Theme.accent.opacity(0.12))
                                    .foregroundStyle(isHovered ? Theme.accentInk : Theme.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                .padding(.horizontal, Spacing.md)
                                .padding(.vertical, 8)
                                .background(isHovered ? Theme.accent.opacity(0.08) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                if hovering { state.hoveredID = cred.id }
                                else if state.hoveredID == cred.id { state.hoveredID = nil }
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
            }
            .frame(maxHeight: 280)

            // Footer
            Divider()
            HStack {
                HStack(spacing: 4) {
                    Circle().fill(Theme.good).frame(width: 6, height: 6)
                    Text("Hey Mac Face ID Protection")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Select to verify face and autofill")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 9)
            .background(Surface.subtle.opacity(0.5))
        }
        .frame(width: 440)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Surface.hairline, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.24), radius: 24, x: 0, y: 12)
    }
}
