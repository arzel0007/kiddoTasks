import SwiftUI

/// Curated SF Symbol catalog for tasks, chores, and rewards.
/// One family (filled), grouped so pickers feel designed — not a raw dump.
enum KiddoIconCatalog {

    struct Category: Identifiable, Hashable {
        let id: String
        let title: String
        let symbols: [String]
    }

    static let taskCategories: [Category] = [
        Category(id: "home", title: "Home", symbols: [
            "bed.double.fill", "sparkles", "trash.fill", "washer.fill",
            "shower.fill", "sofa.fill", "house.fill", "window.awning.fill",
            "lightbulb.fill", "fanblades.fill", "bubbles.and.sparkles.fill",
            "refrigerator.fill", "oven.fill", "sink.fill", "toilet.fill"
        ]),
        Category(id: "kitchen", title: "Kitchen", symbols: [
            "fork.knife", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill",
            "carrot.fill", "birthday.cake.fill", "refrigerator.fill", "wineglass.fill",
            "mug.fill", "frying.pan.fill", "carrot"
        ]),
        Category(id: "school", title: "School", symbols: [
            "book.fill", "pencil.and.outline", "backpack.fill", "graduationcap.fill",
            "ruler.fill", "paperclip", "doc.text.fill", "calculator.fill",
            "pencil.tip", "highlighter", "paperplane.fill", "globe"
        ]),
        Category(id: "health", title: "Health", symbols: [
            "mouth.fill", "figure.run", "heart.fill", "cross.case.fill",
            "bed.double.circle.fill", "leaf.fill", "drop.fill", "bandage.fill",
            "stethoscope", "eye.fill", "hand.raised.fill", "figure.walk"
        ]),
        Category(id: "play", title: "Play", symbols: [
            "gamecontroller.fill", "music.note", "sportscourt.fill", "figure.play",
            "paintpalette.fill", "theatermasks.fill", "party.popper.fill", "dice.fill",
            "guitars.fill", "camera.fill", "puzzlepiece.fill", "basketball.fill"
        ]),
        Category(id: "pets", title: "Pets", symbols: [
            "pawprint.fill", "tortoise.fill", "fish.fill", "bird.fill",
            "cat.fill", "dog.fill", "ladybug.fill", "ant.fill"
        ]),
        Category(id: "chores", title: "Chores", symbols: [
            "cart.fill", "hammer.fill", "wrench.and.screwdriver.fill",
            "shippingbox.fill", "leaf.arrow.triangle.circlepath", "sparkles",
            "broom.fill", "paintbrush.fill", "folder.fill", "archivebox.fill",
            "car.fill", "key.fill"
        ]),
    ]

    static let rewardCategories: [Category] = [
        Category(id: "treats", title: "Treats", symbols: [
            "gift.fill", "birthday.cake.fill", "cup.and.saucer.fill",
            "carrot.fill", "takeoutbag.and.cup.and.straw.fill", "fork.knife"
        ]),
        Category(id: "play", title: "Play", symbols: [
            "gamecontroller.fill", "tv.fill", "play.tv.fill", "film.fill",
            "music.note", "headphones.fill", "dice.fill", "puzzlepiece.fill"
        ]),
        Category(id: "outings", title: "Outings", symbols: [
            "figure.walk", "beach.umbrella.fill", "airplane", "car.fill",
            "movieclapper.fill", "ticket.fill", "storefront.fill", "parkingsign.circle.fill"
        ]),
        Category(id: "family", title: "Family", symbols: [
            "heart.fill", "star.fill", "sparkles", "house.fill",
            "photo.on.rectangle.angled", "hands.clap.fill", "party.popper.fill"
        ]),
        Category(id: "privileges", title: "Perks", symbols: [
            "crown.fill", "moon.stars.fill", "clock.fill", "iphone",
            "bed.double.fill", "paintpalette.fill", "book.fill"
        ]),
    ]

    static func allSymbols(from categories: [Category]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for category in categories {
            for symbol in category.symbols where !seen.contains(symbol) {
                seen.insert(symbol)
                ordered.append(symbol)
            }
        }
        return ordered
    }

    /// Keyword → icon for auto-suggest when typing a task name.
    static func suggestedTaskIcon(for name: String) -> String {
        let lower = name.lowercased()
        let mapping: [(keywords: [String], icon: String)] = [
            (["bed", "sleep", "tidy room", "make bed"], "bed.double.fill"),
            (["dish", "kitchen", "plate", "food", "cook", "meal", "table", "sink"], "fork.knife"),
            (["trash", "garbage", "bin"], "trash.fill"),
            (["read", "book", "study", "homework", "school", "homework"], "book.fill"),
            (["run", "exercise", "sport", "walk", "bike", "gym"], "figure.run"),
            (["teeth", "brush", "shower", "bath", "wash", "hair"], "mouth.fill"),
            (["laundry", "clothes", "fold", "dress", "washer"], "washer.fill"),
            (["pet", "dog", "cat", "feed", "puppy", "kitten"], "pawprint.fill"),
            (["garden", "plant", "water", "leaf", "flower", "yard"], "leaf.fill"),
            (["vacuum", "sweep", "mop", "dust", "clean", "tidy", "broom"], "sparkles"),
            (["shop", "grocery", "buy", "store", "cart"], "cart.fill"),
            (["write", "draw", "art", "craft", "paint"], "pencil.and.outline"),
            (["music", "piano", "practice", "guitar", "sing"], "music.note"),
            (["fix", "repair", "tool", "hammer", "build"], "hammer.fill"),
            (["love", "help", "care", "kind"], "heart.fill"),
            (["lunch", "breakfast", "dinner", "cook", "bake"], "frying.pan.fill"),
            (["car", "drive", "wash car"], "car.fill"),
            (["email", "mail", "letter"], "paperplane.fill"),
            (["screen", "phone", "ipad", "device"], "iphone"),
            (["plan", "calendar", "schedule"], "calendar"),
            (["folder", "desk", "organize"], "folder.fill"),
            (["key", "lock", "door"], "key.fill"),
        ]
        for (keywords, icon) in mapping {
            for keyword in keywords where lower.contains(keyword) {
                return icon
            }
        }
        return "checkmark.circle.fill"
    }

    static func suggestedRewardIcon(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("screen") || lower.contains("tv") || lower.contains("movie") { return "tv.fill" }
        if lower.contains("game") { return "gamecontroller.fill" }
        if lower.contains("dessert") || lower.contains("cake") || lower.contains("treat") { return "birthday.cake.fill" }
        if lower.contains("ice") || lower.contains("sweet") { return "popcorn.fill" }
        if lower.contains("trip") || lower.contains("park") || lower.contains("outing") { return "figure.walk" }
        if lower.contains("movie") { return "film.fill" }
        if lower.contains("stay up") || lower.contains("late") { return "moon.stars.fill" }
        if lower.contains("crown") || lower.contains("special") { return "crown.fill" }
        return "gift.fill"
    }
}

// MARK: - Picker UI

struct KiddoIconPicker: View {
    let title: String
    let categories: [KiddoIconCatalog.Category]
    @Binding var selection: String
    var onPick: (() -> Void)?

    @State private var selectedCategoryID: String
    @State private var search = ""

    private var category: KiddoIconCatalog.Category {
        categories.first { $0.id == selectedCategoryID } ?? categories[0]
    }

    private var symbols: [String] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return category.symbols }
        return KiddoIconCatalog.allSymbols(from: categories).filter { $0.localizedCaseInsensitiveContains(query) }
    }

    init(
        title: String = "Icon",
        categories: [KiddoIconCatalog.Category],
        selection: Binding<String>,
        onPick: (() -> Void)? = nil
    ) {
        self.title = title
        self.categories = categories
        self._selection = selection
        self.onPick = onPick
        _selectedCategoryID = State(initialValue: categories.first?.id ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KiddoTasksDesignTokens.Spacing.small) {
            HStack {
                Text(title)
                    .font(KiddoTasksDesignTokens.Typography.titleSmall)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                Spacer()
                Image(systemName: selection)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(KiddoTasksDesignTokens.Colors.primary)
                    )
            }

            KiddoTextField(label: "Search", placeholder: "Search icons…", text: $search)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories) { cat in
                        Button {
                            withAnimation(KiddoTasksDesignTokens.Animation.quick) {
                                selectedCategoryID = cat.id
                            }
                        } label: {
                            Text(cat.title)
                                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                                .fontWeight(.semibold)
                                .foregroundStyle(
                                    selectedCategoryID == cat.id
                                        ? .white
                                        : KiddoTasksDesignTokens.Colors.textSecondary
                                )
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(
                                        selectedCategoryID == cat.id
                                            ? KiddoTasksDesignTokens.Colors.primary
                                            : KiddoTasksDesignTokens.Colors.surfaceElevated
                                    )
                                )
                        }
                        .buttonStyle(KiddoPressStyle())
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 10)], spacing: 10) {
                ForEach(symbols, id: \.self) { symbol in
                    Button {
                        withAnimation(KiddoTasksDesignTokens.KidsAnimations.quick) {
                            selection = symbol
                        }
                        Haptic.light()
                        onPick?()
                    } label: {
                        Image(systemName: symbol)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(selection == symbol ? .white : KiddoTasksDesignTokens.Colors.textSecondary)
                            .frame(width: 48, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(
                                        selection == symbol
                                            ? KiddoTasksDesignTokens.Colors.primary
                                            : KiddoTasksDesignTokens.Colors.surfaceElevated
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(
                                        selection == symbol ? Color.clear : KiddoTasksDesignTokens.Colors.borderSubtle,
                                        lineWidth: 1
                                    )
                            )
                            .scaleEffect(selection == symbol ? 1.04 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(symbol)
                }
            }
            .padding(.top, 2)
        }
    }
}
