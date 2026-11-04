import AppKit
import SwiftUI

enum EditorPage: String, CaseIterable, Identifiable, Hashable {
    case save
    case cookies
    case buildings
    case upgrades
    case achievements
    case heaven
    case specials
    case cheats
    case effects
    case market
    case farm
    case pantheon
    case spells
    case early
    case goldens
    case ascend
    case later
    case how

    var id: String { rawValue }

    var title: String {
        switch self {
        case .save: return "Save"
        case .cookies: return "Cookies"
        case .buildings: return "Buildings"
        case .upgrades: return "Upgrades"
        case .achievements: return "Achievements"
        case .heaven: return "Heaven"
        case .specials: return "Specials"
        case .cheats: return "Cheats"
        case .effects: return "Effects"
        case .market: return "Market"
        case .farm: return "Farm"
        case .pantheon: return "Pantheon"
        case .spells: return "Spells"
        case .early: return "Early"
        case .goldens: return "Goldens"
        case .ascend: return "Ascend"
        case .later: return "Later"
        case .how: return "How This Works"
        }
    }

    var symbol: String {
        switch self {
        case .save: return "doc.text"
        case .cookies: return "circle.fill"
        case .buildings: return "building.2"
        case .upgrades: return "arrow.up.circle"
        case .achievements: return "star"
        case .heaven: return "sparkles"
        case .specials: return "wand.and.stars"
        case .cheats: return "wrench.and.screwdriver"
        case .effects: return "timer"
        case .market: return "chart.line.uptrend.xyaxis"
        case .farm: return "leaf"
        case .pantheon: return "building.columns"
        case .spells: return "book.closed"
        case .early: return "clock"
        case .goldens: return "sun.max"
        case .ascend: return "arrow.up.square"
        case .later: return "cube"
        case .how: return "questionmark.circle"
        }
    }
}

@MainActor
final class EditorModel: ObservableObject {
    let catalog: CatalogStore
    @Published var paste = ""
    @Published var save: SaveFile?
    @Published var exportText = ""
    @Published var status = "Paste a Cookie Clicker export, then press Load."
    @Published var page: EditorPage? = .save
    @Published var bakeryDraft = ""

    private var loadedPaste = ""

    init() {
        do {
            catalog = try CatalogStore.loadBundled()
        } catch {
            catalog = CatalogStore(upgrades: [], achievements: [])
            status = (error as? LocalizedError)?.errorDescription ?? "The upgrade list did not load."
        }
    }

    var loaded: Bool { save != nil }

    func loadEditor() {
        load(text: paste)
    }

    func loadClipboard() {
        let text = NSPasteboard.general.string(forType: .string) ?? ""
        paste = text
        load(text: text)
    }

    func load(text: String) {
        do {
            let file = try SaveFile.load(pasted: text, catalog: catalog)
            loadedPaste = text
            save = file
            exportText = file.export()
            bakeryDraft = file.bakeryName
            let name = file.bakeryName.isEmpty ? "a bakery" : file.bakeryName
            status = "Loaded \(name), version \(file.version)."
        } catch let error as SaveError {
            status = error.errorDescription ?? "That text is not a Cookie Clicker export."
        } catch {
            status = "That text is not a Cookie Clicker export."
        }
    }

    func reset() {
        guard !loadedPaste.isEmpty else { return }
        load(text: loadedPaste)
        paste = loadedPaste
        status = "Restored the pasted save."
    }

    func copySave() {
        guard let save else {
            status = "Load a save first."
            return
        }
        let text = save.export()
        exportText = text
        let board = NSPasteboard.general
        board.clearContents()
        if board.setString(text, forType: .string) {
            status = "Copied the save. In Cookie Clicker, open Options and choose Import save."
        } else {
            status = "Could not copy the save."
        }
    }

    func edit(_ change: (inout SaveFile) -> Void) {
        guard var file = save else { return }
        change(&file)
        save = file
        exportText = file.export()
    }

    func applyNumber(_ raw: String, _ change: (inout SaveFile, Double) -> Void) {
        guard let value = JSSave.parseUserNumber(raw) else {
            status = "Enter a number, like 1000, 1e12, or 5.3 million."
            return
        }
        edit { change(&$0, value) }
        if status.hasPrefix("Enter a number") { status = "" }
    }

    func applyCount(_ raw: String, _ change: (inout SaveFile, Int) -> Void) {
        guard let value = JSSave.parseUserNumber(raw), value >= 0 else {
            status = "Enter a whole number, like 100."
            return
        }
        let count = Int(min(value, 1_000_000_000).rounded())
        edit { change(&$0, count) }
        if status.hasPrefix("Enter a whole number") { status = "" }
    }

    func setCheats(enabled: Bool) {
        guard var file = save else { return }
        let next = SaveFile.bakeryName(current: file.bakeryName, cheats: enabled)
        if file.bakeryName == next {
            bakeryDraft = next
            status = enabled ? "Cheats are already on for the browser game." : "Cheats are already off."
            return
        }
        let kept = SaveFile.bakeryName(current: file.bakeryName, cheats: false)
        let shortened = enabled && kept.count > 13
        if let error = file.setBakeryName(next) {
            status = error
            return
        }
        save = file
        exportText = file.export()
        bakeryDraft = file.bakeryName
        if enabled {
            status = shortened
                ? "Cheats are on. The bakery name was shortened so the switch fits in 28 letters."
                : "Cheats are on. Import this save in the browser game and the dev tools open."
        } else {
            status = "Cheats are off. The dev tools stay closed on the next import."
        }
    }

    func renameBakery() {
        guard var file = save else { return }
        let before = file.bakeryName
        if let error = file.setBakeryName(bakeryDraft) {
            status = error
            return
        }
        save = file
        exportText = file.export()
        if file.bakeryName != before {
            status = "Renamed the bakery."
        }
    }

    func setMinigame(index: Int, enabled: Bool) {
        guard var file = save else { return }
        commit(file, file.setMinigameEnabled(index: index, on: enabled))
    }

    func setMinigameAmount(index: Int, raw: String) {
        guard var file = save else { return }
        guard let value = JSSave.parseUserNumber(raw), value >= 0 else {
            status = "Enter a whole number, like 100."
            return
        }
        let count = Int(min(value, 1_000_000_000).rounded())
        commit(file, file.setMinigameAmount(index: index, value: count))
    }

    private func commit(_ file: SaveFile, _ result: MinigameWrite) {
        switch result {
        case .unchanged(let message):
            commit(file, changed: false, message)
        case .updated(let message):
            commit(file, changed: true, message)
        }
    }

    func addEffect(typeID: Int, secondsRaw: String, powerRaw: String, building: Int) {
        guard var file = save, let kind = GameEffect.find(typeID) else { return }
        let seconds: Double
        if secondsRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            seconds = kind.seconds
        } else if let value = JSSave.parseUserNumber(secondsRaw) {
            seconds = value
        } else {
            status = "Enter a time in seconds, like 77."
            return
        }
        let fallback = kind.needsBuilding ? Double(file.buildingAmount(building)) / 10 + 1 : kind.power
        let power: Double
        if powerRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            power = fallback
        } else if let value = JSSave.parseUserNumber(powerRaw) {
            power = value
        } else {
            status = "Enter a power, like 7."
            return
        }
        let chosen = kind.needsBuilding ? building : nil
        commit(file, file.addEffect(typeID: typeID, seconds: seconds, power: power, building: chosen))
    }

    func updateEffect(slot: Int, secondsRaw: String, powerRaw: String, building: Int) {
        guard var file = save else { return }
        let seconds = readOptional(secondsRaw, invalid: "Enter a time in seconds, like 77.")
        let power = readOptional(powerRaw, invalid: "Enter a power, like 7.")
        guard let seconds, let power else { return }
        commit(file, file.updateEffect(slot: slot, seconds: seconds, power: power, building: building))
    }

    func removeEffect(slot: Int) {
        guard var file = save else { return }
        commit(file, file.removeEffect(slot: slot))
    }

    /// Empty input stays unset. A bad number sets status and returns nil.
    private func readOptional(_ raw: String, invalid: String) -> Double?? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .some(nil) }
        guard let value = JSSave.parseUserNumber(trimmed) else {
            status = invalid
            return nil
        }
        return .some(value)
    }

    private func commit(_ file: SaveFile, changed: Bool, _ message: String) {
        if changed {
            save = file
            exportText = file.export()
        }
        status = message
    }

    private func commit(_ file: SaveFile, _ result: EffectWrite) {
        switch result {
        case .unchanged(let message):
            commit(file, changed: false, message)
        case .updated(let message):
            commit(file, changed: true, message)
        }
    }

    func upgradeTitle(_ id: Int) -> String {
        guard let save else { return "Not owned" }
        if save.upgradeBought(id) { return "Owned" }
        if save.upgradeUnlocked(id) { return "Unlocked" }
        return "Not owned"
    }

    func upgradeOn(_ id: Int) -> Bool {
        save?.upgradeBought(id) == true
    }
}

@main
struct CookieSaveApp: App {
    var body: some Scene {
        WindowGroup {
            EditorRoot()
        }
        .defaultSize(width: 980, height: 680)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

struct EditorRoot: View {
    @StateObject private var model = EditorModel()

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 188)
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
            VStack(spacing: 0) {
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .clipped()
                statusBar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Oven.background)
        }
        .tint(Oven.accent)
        .preferredColorScheme(.dark)
        .frame(minWidth: 860, minHeight: 560)
        .background(Oven.background)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Cookie Save")
                .font(.headline)
                .padding(.horizontal, 10)
                .padding(.top, 12)
                .padding(.bottom, 8)
            GeometryReader { geo in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(EditorPage.allCases) { page in
                            let selected = (model.page ?? .save) == page
                            Button {
                                model.page = page
                            } label: {
                                Label(page.title, systemImage: page.symbol)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 7)
                                    .padding(.horizontal, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(selected ? Oven.accent : Color.white.opacity(0.04))
                                    )
                                    .foregroundStyle(selected ? Color.black : Color.primary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(page.title)
                        }
                    }
                    .frame(width: max(geo.size.width, 1), alignment: .topLeading)
                    .padding(.bottom, 12)
                }
                .frame(width: max(geo.size.width, 1), height: max(geo.size.height, 1), alignment: .topLeading)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Oven.background)
    }

    @ViewBuilder
    private var detail: some View {
        switch model.page ?? .save {
        case .save:
            SavePage(model: model)
        case .cookies:
            CookiesPage(model: model)
        case .buildings:
            BuildingsPage(model: model)
        case .upgrades:
            UpgradesPage(model: model)
        case .achievements:
            AchievementsPage(model: model)
        case .heaven:
            HeavenPage(model: model)
        case .specials:
            SpecialsPage(model: model)
        case .cheats:
            CheatsPage(model: model)
        case .effects:
            EffectsPage(model: model)
        case .market:
            MarketPage(model: model)
        case .farm:
            GuidePage(title: "Farm", detail: Guide.farmDetail, blocks: Guide.farm)
        case .pantheon:
            GuidePage(title: "Pantheon", detail: Guide.pantheonDetail, blocks: Guide.pantheon)
        case .spells:
            GuidePage(title: "Spells", detail: Guide.spellsDetail, blocks: Guide.spells)
        case .early:
            GuidePage(title: "Early game", detail: Guide.earlyDetail, blocks: Guide.early)
        case .goldens:
            GuidePage(title: "Golden cookies", detail: Guide.goldensDetail, blocks: Guide.goldens)
        case .ascend:
            GuidePage(title: "Ascension", detail: Guide.ascendDetail, blocks: Guide.ascend)
        case .later:
            GuidePage(title: "Later game", detail: Guide.laterDetail, blocks: Guide.later)
        case .how:
            HowPage()
        }
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            Text(model.status)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 8)
            Button("Reset") { model.reset() }
                .disabled(model.save?.hasEdits != true)
            Button("Copy save") { model.copySave() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(model.save == nil)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.28))
    }
}

private enum Oven {
    static let background = Color(red: 0.11, green: 0.07, blue: 0.04)
    static let card = Color(red: 0.18, green: 0.12, blue: 0.08)
    static let accent = Color(red: 0.92, green: 0.58, blue: 0.22)
}

private struct PageIntro: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.weight(.semibold))
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct NeedSave: View {
    @ObservedObject var model: EditorModel

    var body: some View {
        VStack(spacing: 12) {
            Text("Load a save first.")
                .font(.title3)
            Button("Go to Save") { model.page = .save }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FillingScroll<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geo in
            fitted(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func fitted(width: CGFloat, height: CGFloat) -> some View {
        let w = max(width, 1)
        let h = max(height, 1)
        if #available(macOS 14.0, *) {
            ScrollView {
                row(width: w)
            }
            .contentMargins(.bottom, 16, for: .scrollContent)
            .frame(width: w, height: h, alignment: .topLeading)
        } else {
            ScrollView {
                row(width: w)
            }
            .frame(width: w, height: h, alignment: .topLeading)
        }
    }

    private func row(width: CGFloat) -> some View {
        content()
            .frame(width: width, alignment: .topLeading)
            .padding(.bottom, 24)
    }
}

private struct ChoiceButton: View {
    let title: String
    var on: Bool = false
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.borderedProminent)
            .tint(on ? Oven.accent : Color(white: 0.28))
    }
}

private struct SavePage: View {
    @ObservedObject var model: EditorModel

    var body: some View {
        FillingScroll {
            VStack(alignment: .leading, spacing: 16) {
                PageIntro(
                    title: "Save",
                    detail: "Paste an export, then press Load. Only the buttons you press after that are written into the new save."
                )
                TextEditor(text: $model.paste)
                    .font(.system(size: 12, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 160, maxHeight: 220)
                    .background(Oven.card)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                HStack(spacing: 8) {
                    Button("Load") { model.loadEditor() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.return, modifiers: .command)
                    Button("Load from clipboard") { model.loadClipboard() }
                    Spacer()
                }
                if let save = model.save {
                    summary(save)
                    exportPreview
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Oven.background)
    }

    private func summary(_ save: SaveFile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            labeled("Bakery", save.bakeryName.isEmpty ? "—" : save.bakeryName)
            labeled("Version", save.version)
            labeled("Cookies", "\(friendlyCookies(save.cookiesToken))  (\(save.cookiesToken))")
            labeled("Upgrades owned", "\(save.ownedUpgradeCount()) of \(model.catalog.upgrades.count)")
            labeled("Achievements", "\(save.wonAchievementCount()) of \(model.catalog.achievements.count)")
            labeled("Changes", save.hasEdits ? "Edited" : "None yet")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Oven.card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func labeled(_ name: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name)
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
        }
        .font(.body)
    }

    private var exportPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("New export  ·  \(model.exportText.count) characters")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(model.exportText)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(4)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Copy save puts the full export on the clipboard.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CookiesPage: View {
    @ObservedObject var model: EditorModel
    @State private var custom = ""

    var body: some View {
        if let save = model.save {
            FillingScroll {
                VStack(alignment: .leading, spacing: 16) {
                    PageIntro(
                        title: "Cookies",
                        detail: "Sets the cookies in the bank. If the bank would pass lifetime cookies, lifetime cookies rise with it."
                    )
                    stat("In the bank", "\(friendlyCookies(save.cookiesToken))  (\(save.cookiesToken))")
                    stat("Earned", "\(friendlyCookies(save.cookiesEarnedToken))  (\(save.cookiesEarnedToken))")
                    presetGrid(SaveFile.cookiePresets) { preset in
                        ChoiceButton(title: preset.label, on: matches(save.cookiesToken, preset.value)) {
                            model.edit { $0.setCookies(preset.value) }
                        }
                    }
                    HStack {
                        TextField("5.3 million", text: $custom)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 280)
                        Button("Set cookies") { model.applyNumber(custom) { $0.setCookies($1) } }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Oven.background)
        } else {
            NeedSave(model: model)
        }
    }

    private func matches(_ token: String, _ value: Double) -> Bool {
        JSSave.parseNumber(token) == value
    }
}

private struct BuildingsPage: View {
    @ObservedObject var model: EditorModel
    @State private var allAmount = ""
    @State private var allLevel = ""

    var body: some View {
        if model.save != nil {
            FillingScroll {
                VStack(alignment: .leading, spacing: 14) {
                    PageIntro(
                        title: "Buildings",
                        detail: "Sets how many of each building you own, and its level. Owned count, bought count, and the highest owned stay in step. Farm, Bank, Temple, and Wizard tower can turn their minigame on or off."
                    )
                    HStack(spacing: 8) {
                        TextField("All amounts", text: $allAmount)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                        Button("Set every amount") {
                            model.applyCount(allAmount) { $0.setAllBuildings(amount: $1) }
                        }
                        TextField("All levels", text: $allLevel)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Button("Set every level") {
                            model.applyCount(allLevel) { $0.setAllBuildingLevels($1) }
                        }
                    }
                    ForEach(SaveFile.buildingNames.indices, id: \.self) { index in
                        BuildingRow(model: model, index: index)
                        Divider().opacity(0.35)
                    }
                }
                .padding(20)
            }
            .background(Oven.background)
        } else {
            NeedSave(model: model)
        }
    }
}

private struct BuildingRow: View {
    @ObservedObject var model: EditorModel
    let index: Int
    @State private var amountText = ""
    @State private var levelText = ""
    @State private var miniText = ""

    var body: some View {
        let amount = model.save?.buildingAmount(index) ?? 0
        let level = model.save?.buildingLevel(index) ?? 0
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(SaveFile.buildingNames[index])
                    .frame(width: 168, alignment: .leading)
                Text("\(amount)")
                    .monospacedDigit()
                    .frame(width: 72, alignment: .trailing)
                stepButton("+1") { model.edit { $0.setBuilding(index: index, amount: amount + 1) } }
                stepButton("+10") { model.edit { $0.setBuilding(index: index, amount: amount + 10) } }
                stepButton("+100") { model.edit { $0.setBuilding(index: index, amount: amount + 100) } }
                TextField("amount", text: $amountText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 88)
                Button("Set") { model.applyCount(amountText) { $0.setBuilding(index: index, amount: $1) } }
            }
            HStack(spacing: 8) {
                Text("Level \(level)")
                    .monospacedDigit()
                    .frame(width: 248, alignment: .leading)
                stepButton("+1") { model.edit { $0.setBuilding(index: index, level: level + 1) } }
                TextField("level", text: $levelText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 72)
                Button("Set") { model.applyCount(levelText) { $0.setBuilding(index: index, level: $1) } }
            }
            if let kind = BuildingMinigame(rawValue: index) {
                minigameControls(kind, level: level)
            }
        }
        .padding(.vertical, 4)
    }

    private func minigameControls(_ kind: BuildingMinigame, level: Int) -> some View {
        let stored = model.save?.minigameAmount(index)
        let blob = model.save?.buildingMinigame(index) ?? ""
        let locked = stored == nil && !blob.isEmpty
        let current = stored ?? kind.emptyAmount
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(kind.title)
                    .frame(width: 168, alignment: .leading)
                ChoiceButton(title: "On", on: level > 0) {
                    model.setMinigame(index: index, enabled: true)
                }
                ChoiceButton(title: "Off", on: level == 0) {
                    model.setMinigame(index: index, enabled: false)
                }
            }
            HStack(spacing: 8) {
                Text(kind.counterName)
                    .frame(width: 168, alignment: .leading)
                Text(stored.map(String.init) ?? "—")
                    .monospacedDigit()
                    .frame(width: 72, alignment: .trailing)
                stepButton("-1") {
                    model.setMinigameAmount(index: index, raw: String(max(current - 1, 0)))
                }
                .disabled(locked)
                stepButton("+1") {
                    model.setMinigameAmount(index: index, raw: String(current + 1))
                }
                .disabled(locked)
                TextField(kind.counterName, text: $miniText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 88)
                    .disabled(locked)
                Button("Set") { model.setMinigameAmount(index: index, raw: miniText) }
                    .disabled(locked)
            }
            Text(kind.note)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func stepButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
    }
}

private struct UpgradesPage: View {
    @ObservedObject var model: EditorModel
    @State private var query = ""
    @State private var pool = "all"

    private let pools = ["all", "regular", "cookie", "prestige", "toggle", "tech", "debug"]

    var body: some View {
        if let save = model.save {
            let rows = filtered
            VStack(alignment: .leading, spacing: 12) {
                PageIntro(
                    title: "Upgrades",
                    detail: "Press a row to own it or remove it. Buy all skips the debug upgrades."
                )
                .padding(.horizontal, 20)
                .padding(.top, 20)
                HStack(spacing: 8) {
                    Text("\(save.ownedUpgradeCount()) owned")
                        .foregroundStyle(.secondary)
                    Button("Buy all except debug") {
                        model.edit { file in
                            file.buyUpgrades { $0.pool != "debug" }
                        }
                    }
                    Button("Buy all heavenly") {
                        model.edit { file in
                            file.buyUpgrades { $0.pool == "prestige" }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                TextField("Search upgrades", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 20)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(pools, id: \.self) { name in
                        ChoiceButton(title: poolTitle(name), on: pool == name) { pool = name }
                    }
                }
                .padding(.horizontal, 20)
                Text("\(rows.count) shown")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                FillingScroll {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(rows) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                    Text(poolTitle(item.pool.isEmpty ? "regular" : item.pool))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                ChoiceButton(title: model.upgradeTitle(item.id), on: model.upgradeOn(item.id)) {
                                    let owned = model.upgradeOn(item.id)
                                    model.edit { $0.setUpgrade(id: item.id, owned: !owned) }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Oven.background)
        } else {
            NeedSave(model: model)
        }
    }

    private var filtered: [CatalogItem] {
        model.catalog.upgrades.filter { item in
            if pool != "all" {
                let name = item.pool.isEmpty ? "regular" : item.pool
                if name != pool { return false }
            }
            if query.isEmpty { return true }
            return item.name.localizedCaseInsensitiveContains(query)
        }
    }

    private func poolTitle(_ pool: String) -> String {
        switch pool {
        case "all": return "All"
        case "regular": return "Regular"
        case "cookie": return "Cookies"
        case "prestige": return "Heavenly"
        case "toggle": return "Toggles"
        case "tech": return "Tech"
        case "debug": return "Debug"
        default: return pool
        }
    }
}

private struct AchievementsPage: View {
    @ObservedObject var model: EditorModel
    @State private var query = ""

    var body: some View {
        if let save = model.save {
            let rows = filtered
            VStack(alignment: .leading, spacing: 12) {
                PageIntro(
                    title: "Achievements",
                    detail: "Press a row to give it or take it away. Award all leaves out Cheated cookies taste awful."
                )
                .padding(.horizontal, 20)
                .padding(.top, 20)
                HStack {
                    Text("\(save.wonAchievementCount()) won")
                        .foregroundStyle(.secondary)
                    Button("Award all") { model.edit { $0.awardAllAchievements() } }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                    TextField("Search achievements", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 280)
                }
                .padding(.horizontal, 20)
                Text("\(rows.count) shown")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                FillingScroll {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(rows) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                    Text(poolTitle(item.pool))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                let won = save.achievementWon(item.id)
                                ChoiceButton(title: won ? "Won" : "Not won", on: won) {
                                    model.edit { $0.setAchievement(id: item.id, won: !won) }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Oven.background)
        } else {
            NeedSave(model: model)
        }
    }

    private var filtered: [CatalogItem] {
        model.catalog.achievements.filter { item in
            query.isEmpty || item.name.localizedCaseInsensitiveContains(query)
        }
    }

    private func poolTitle(_ pool: String) -> String {
        switch pool {
        case "shadow": return "Shadow"
        case "dungeon": return "Dungeon"
        case "", "normal": return "Normal"
        default: return pool.isEmpty ? "Normal" : pool.capitalized
        }
    }
}

private struct HeavenPage: View {
    @ObservedObject var model: EditorModel
    @State private var custom = ""
    @State private var query = ""

    private var ascensionUpgrades: [CatalogItem] {
        model.catalog.upgrades.filter { $0.pool == "prestige" }
    }

    private var shownAscension: [CatalogItem] {
        guard !query.isEmpty else { return ascensionUpgrades }
        return ascensionUpgrades.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        if let save = model.save {
            let ascension = shownAscension
            FillingScroll {
                VStack(alignment: .leading, spacing: 16) {
                    PageIntro(
                        title: "Heaven",
                        detail: "Sets unspent heavenly chips. Cookies forfeited rise when they must, so the chips are still there after import."
                    )
                    stat("Unspent chips", save.heavenlyChipsToken.isEmpty ? "0" : save.heavenlyChipsToken)
                    stat("Spent chips", save.heavenlySpentToken.isEmpty ? "0" : save.heavenlySpentToken)
                    stat("Cookies forfeited", save.cookiesResetToken.isEmpty ? "0" : save.cookiesResetToken)
                    presetGrid(SaveFile.chipPresets) { preset in
                        ChoiceButton(title: preset.label, on: matches(save.heavenlyChipsToken, preset.value)) {
                            model.edit { $0.setHeavenlyChips(preset.value) }
                        }
                    }
                    HStack {
                        TextField("Custom chips", text: $custom)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 280)
                        Button("Set chips") { model.applyNumber(custom) { $0.setHeavenlyChips($1) } }
                            .buttonStyle(.borderedProminent)
                    }
                    Text("These five are separate from the heavenly upgrade pool.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(SaveFile.heavenlyUpgrades, id: \.self) { name in
                            if let item = model.catalog.upgrade(named: name) {
                                ChoiceButton(title: "\(name) · \(model.upgradeTitle(item.id))", on: model.upgradeOn(item.id)) {
                                    let owned = model.upgradeOn(item.id)
                                    model.edit { $0.setUpgrade(id: item.id, owned: !owned) }
                                }
                            }
                        }
                    }
                    Text("Ascension upgrades")
                        .font(.headline)
                    Text("These are the heavenly upgrades the Ascend screen sells. Press one to add it or remove it.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Text("\(ascensionOwned) of \(ascensionUpgrades.count) owned")
                            .foregroundStyle(.secondary)
                        Button("Add all") { setAscension(owned: true) }
                            .buttonStyle(.borderedProminent)
                        Button("Remove all") { setAscension(owned: false) }
                        Spacer()
                    }
                    TextField("Search ascension upgrades", text: $query)
                        .textFieldStyle(.roundedBorder)
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(ascension) { item in
                            HStack {
                                Text(item.name)
                                Spacer()
                                ChoiceButton(title: model.upgradeTitle(item.id), on: model.upgradeOn(item.id)) {
                                    let owned = model.upgradeOn(item.id)
                                    model.edit { $0.setUpgrade(id: item.id, owned: !owned) }
                                    model.status = owned ? "\(item.name) is removed." : "\(item.name) is added."
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Oven.background)
        } else {
            NeedSave(model: model)
        }
    }

    private var ascensionOwned: Int {
        ascensionUpgrades.filter { model.upgradeOn($0.id) }.count
    }

    private func setAscension(owned: Bool) {
        let ids = ascensionUpgrades.map(\.id)
        model.edit { file in
            for id in ids {
                file.setUpgrade(id: id, owned: owned)
            }
        }
        model.status = owned ? "Added the ascension upgrades." : "Removed the ascension upgrades."
    }

    private func matches(_ token: String, _ value: Double) -> Bool {
        JSSave.parseNumber(token) == value
    }
}

private struct EffectsPage: View {
    @ObservedObject var model: EditorModel
    @State private var kindID = 0
    @State private var buildingID = 0
    @State private var secondsText = ""
    @State private var powerText = ""
    @State private var rowSeconds: [Int: String] = [:]
    @State private var rowPowers: [Int: String] = [:]
    @State private var rowBuildings: [Int: Int] = [:]

    var body: some View {
        if let save = model.save {
            let kind = GameEffect.find(kindID) ?? GameEffect.all[0]
            let effects = save.savedEffects()
            let blankPower = kind.needsBuilding ? Double(save.buildingAmount(buildingID)) / 10 + 1 : kind.power
            FillingScroll {
                VStack(alignment: .leading, spacing: 16) {
                    PageIntro(
                        title: "Effects",
                        detail: "Pick one of the 27 effects this game can save. Set the seconds and the power, then add it. Adding one that is already on replaces it. A building boost can be on for two different buildings at once. Setting the time refills that timer."
                    )
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Effect", selection: $kindID) {
                            ForEach(GameEffect.all) { effect in
                                Text(effect.title).tag(effect.id)
                            }
                        }
                        .pickerStyle(.menu)
                        if kind.needsBuilding {
                            Picker("Building", selection: $buildingID) {
                                ForEach(Array(SaveFile.buildingNames.enumerated()), id: \.offset) { index, name in
                                    Text(name).tag(index)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        HStack(spacing: 8) {
                            TextField("Seconds", text: $secondsText, prompt: Text(JSSave.numberString(kind.seconds)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)
                            TextField("Power", text: $powerText, prompt: Text(JSSave.numberString(blankPower)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)
                            Button("Add") {
                                model.addEffect(typeID: kind.id, secondsRaw: secondsText, powerRaw: powerText, building: buildingID)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        Text("Blank time uses \(JSSave.numberString(kind.seconds)) seconds. Blank power uses \(JSSave.numberString(blankPower)).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(kind.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Oven.card)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    if effects.isEmpty {
                        Text("This save has no timed effects.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(effects) { effect in
                        effectRow(effect, save: save)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Oven.background)
        } else {
            NeedSave(model: model)
        }
    }

    private func effectRow(_ effect: SavedEffect, save: SaveFile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(effect.displayName)
                .font(.headline)
            Text(detailLine(effect))
                .font(.caption)
                .foregroundStyle(.secondary)
            if effect.typeID == nil {
                Text(effect.raw)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Button("Remove") { model.removeEffect(slot: effect.slot) }
            } else if let kind = effect.typeID.flatMap(GameEffect.find) {
                if save.ownsUpgrade("Dragon fang"), effect.typeID == 3 || effect.typeID == 7 {
                    Text("This save owns Dragon fang, so the game raises this power by 10% and rounds up on import.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 8) {
                    TextField("Seconds", text: secondsBinding(effect.slot), prompt: Text(effect.frames.map { JSSave.numberString($0 / 30) } ?? ""))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                    TextField("Power", text: powerBinding(effect.slot), prompt: Text(effect.power.map(JSSave.numberString) ?? ""))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                    if kind.needsBuilding {
                        Picker("Building", selection: buildingBinding(effect)) {
                            ForEach(Array(SaveFile.buildingNames.enumerated()), id: \.offset) { index, name in
                                Text(name).tag(index)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 180)
                    }
                    Button("Set") {
                        model.updateEffect(
                            slot: effect.slot,
                            secondsRaw: rowSeconds[effect.slot] ?? "",
                            powerRaw: rowPowers[effect.slot] ?? "",
                            building: rowBuildings[effect.slot] ?? effect.building ?? 0
                        )
                    }
                    Button("Remove") { model.removeEffect(slot: effect.slot) }
                }
                Text(kind.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Oven.card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func detailLine(_ effect: SavedEffect) -> String {
        var parts: [String] = []
        if let frames = effect.frames {
            parts.append(SaveFile.secondLabel(frames))
        }
        if let power = effect.power {
            parts.append("power \(JSSave.numberString(power))")
        }
        if let building = effect.building {
            parts.append(SaveFile.buildingNames[building])
        }
        if parts.isEmpty { return "This effect could not be read." }
        return parts.joined(separator: " · ")
    }

    private func secondsBinding(_ slot: Int) -> Binding<String> {
        Binding(
            get: { rowSeconds[slot] ?? "" },
            set: { rowSeconds[slot] = $0 }
        )
    }

    private func powerBinding(_ slot: Int) -> Binding<String> {
        Binding(
            get: { rowPowers[slot] ?? "" },
            set: { rowPowers[slot] = $0 }
        )
    }

    private func buildingBinding(_ effect: SavedEffect) -> Binding<Int> {
        Binding(
            get: { rowBuildings[effect.slot] ?? effect.building ?? 0 },
            set: { rowBuildings[effect.slot] = $0 }
        )
    }
}

private struct CheatsPage: View {
    @ObservedObject var model: EditorModel

    var body: some View {
        if let save = model.save {
            let open = SaveFile.cheatsOpen(in: save.bakeryName)
            FillingScroll {
                VStack(alignment: .leading, spacing: 16) {
                    PageIntro(
                        title: "Cheats",
                        detail: "The browser game opens its dev tools when the bakery name ends with saysopensesame. The Steam app leaves those tools closed. The name can be 28 letters, so a long name is shortened to fit the switch. The game grants Cheated cookies taste awful when the tools open. Turning this off takes the switch out of the name and leaves that achievement as it is."
                    )
                    VStack(alignment: .leading, spacing: 10) {
                        Text(open ? "Dev tools are set to open." : "Dev tools stay closed.")
                            .font(.headline)
                        Text(save.bakeryName)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        HStack(spacing: 8) {
                            ChoiceButton(title: "Enable", on: open) {
                                model.setCheats(enabled: true)
                            }
                            ChoiceButton(title: "Disable", on: !open) {
                                model.setCheats(enabled: false)
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Oven.card)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Oven.background)
        } else {
            NeedSave(model: model)
        }
    }
}

private struct SpecialsPage: View {
    @ObservedObject var model: EditorModel
    @State private var lumpsText = ""

    var body: some View {
        if let save = model.save {
            FillingScroll {
                VStack(alignment: .leading, spacing: 18) {
                    PageIntro(
                        title: "Specials",
                        detail: "Bakery name, sugar lumps, Santa, the dragon, and the season. A season stays on for a year and buys its biscuit."
                    )
                    bakery(save)
                    lumps(save)
                    santa(save)
                    dragon(save)
                    seasons(save)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Oven.background)
        } else {
            NeedSave(model: model)
        }
    }

    private func bakery(_ save: SaveFile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bakery").font(.headline)
            HStack {
                TextField("Bakery name", text: $model.bakeryDraft)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)
                Button("Rename") { model.renameBakery() }
                    .buttonStyle(.borderedProminent)
                Text(save.bakeryName)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func lumps(_ save: SaveFile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sugar lumps").font(.headline)
            stat("In hand", lumpLabel(save.lumpsToken))
            stat("Total grown", lumpLabel(save.lumpsTotalToken))
            presetGrid(SaveFile.lumpPresets) { preset in
                ChoiceButton(title: preset.label, on: matches(save.lumpsToken, preset.value)) {
                    model.edit { $0.setLumps(preset.value) }
                }
            }
            HStack {
                TextField("Custom lumps", text: $lumpsText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                Button("Set lumps") { model.applyNumber(lumpsText) { $0.setLumps($1) } }
            }
        }
    }

    private func santa(_ save: SaveFile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Santa").font(.headline)
            Picker("Santa", selection: Binding(
                get: { save.santaLevel },
                set: { level in model.edit { $0.setSanta(level) } }
            )) {
                ForEach(SaveFile.santaLevels.indices, id: \.self) { level in
                    Text("\(level)  \(SaveFile.santaLevels[level])").tag(level)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 360)
            Text(save.santaLevel > 0 ? "A festive hat is owned." : "Level 0 leaves the hat as it was.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func dragon(_ save: SaveFile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dragon").font(.headline)
            Text(dragonLevelName(save.dragonLevel))
                .foregroundStyle(.secondary)
            labeledPicker("Level", value: save.dragonLevel, range: 0...27, label: { "\($0)  \(dragonLevelName($0))" }) { level in
                model.edit { $0.setDragonLevel(level) }
            }
            labeledPicker("Aura", value: save.dragonAura, range: 0...21, label: { SaveFile.auraNames[$0] }) { aura in
                model.edit { $0.setDragonAura(slot: 0, id: aura) }
            }
            labeledPicker("Second aura", value: save.dragonAura2, range: 0...21, label: { SaveFile.auraNames[$0] }) { aura in
                model.edit { $0.setDragonAura(slot: 1, id: aura) }
            }
        }
    }

    private func seasons(_ save: SaveFile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Season").font(.headline)
            Text(save.season.isEmpty ? "No season is running." : "Running \(save.season), timer \(save.seasonTimeToken).")
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(SaveFile.seasons, id: \.id) { option in
                    ChoiceButton(title: option.label, on: save.season == option.id) {
                        model.edit { $0.setSeason(option.id) }
                    }
                }
            }
        }
    }

    private func lumpLabel(_ token: String) -> String {
        if token.isEmpty || token == "-1" { return "Not started" }
        return token
    }

    private func matches(_ token: String, _ value: Double) -> Bool {
        JSSave.parseNumber(token) == value
    }

    private func labeledPicker(_ title: String, value: Int, range: ClosedRange<Int>, label: @escaping (Int) -> String, set: @escaping (Int) -> Void) -> some View {
        Picker(title, selection: Binding(get: { value }, set: set)) {
            ForEach(range, id: \.self) { item in
                Text(label(item)).tag(item)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: 420, alignment: .leading)
    }
}

private func stat(_ name: String, _ value: String) -> some View {
    HStack(alignment: .firstTextBaseline) {
        Text(name)
            .foregroundStyle(.secondary)
            .frame(width: 150, alignment: .leading)
        Text(value)
            .textSelection(.enabled)
    }
}

private func presetGrid(_ presets: [(label: String, value: Double)], button: @escaping ((label: String, value: Double)) -> ChoiceButton) -> some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], alignment: .leading, spacing: 8) {
        ForEach(Array(presets.enumerated()), id: \.offset) { _, preset in
            button(preset)
        }
    }
}

private struct HowBlock: Identifiable {
    let heading: String
    let body: String
    var formula: String = ""
    var id: String { heading }
}

private struct HowPage: View {
    private let blocks: [HowBlock] = [
        HowBlock(
            heading: "The pasted text",
            body: "A Cookie Clicker export is the save wrapped so a text box can hold it. There is no checksum. Cookie Save unwraps it with the same four steps the game uses on Import, then splits the plain text on vertical bars."
        ),
        HowBlock(
            heading: "1. Blank space comes off",
            body: "Spaces, tabs, and line breaks are removed first. A save copied across several lines is the same save."
        ),
        HowBlock(
            heading: "2. Percent codes become characters",
            body: "This is JavaScript unescape. %21 is an exclamation mark. %3D is an equals sign. %25 is a percent sign. %XX is one byte. %uXXXX is one Unicode character. A 2.058 export ends in %21END%21, which is the marker !END!.",
            formula: "%21END%21   →   !END!"
        ),
        HowBlock(
            heading: "3. The marker is cut off",
            body: "The importer keeps the text before the first !END!. What remains is base64."
        ),
        HowBlock(
            heading: "4. Base64 becomes the save",
            body: "Those letters decode to UTF-8 text. The game writes the plain save, encodes that text as base64, adds !END!, then escapes the result. Import runs those steps backwards.",
            formula: "escape( base64(plain text) + \"!END!\" )"
        ),
        HowBlock(
            heading: "Where 2.058 starts",
            body: "Every 2.058 export begins with the eight letters Mi4wNTh8. Those letters are the text 2.058 and a vertical bar. The bar opens the section list. The letters after that are the rest of the save, and the export ends with %21END%21. A string in that shape is read by this same path.",
            formula: "Mi4wNTh8   →   2.058|"
        ),
        HowBlock(
            heading: "The sections",
            body: "The plain text is split on | and empty sections stay. Fewer than 5 sections is rejected. Section 0 is the version, 2.058. Section 1 is left empty. Section 2 is the run, separated by semicolons: start time, legacy start, last time the game was opened, bakery name, seed, and appearance. Those times are milliseconds. Section 3 is the settings. In 2.058 each setting is the character 1 or 0, in order. Section 4 is the bank and the other numbers, separated by semicolons. Field 0 is cookies in the bank. Field 1 is cookies earned. Field 8 is cookies forfeited. Field 14 is ascensions. Field 18 is Santa's level. Field 20 is season time left, in frames. Field 22 is the season name. Field 26 is unspent heavenly chips. Field 27 is heavenly chips spent. Field 35 is the dragon level. Fields 36 and 37 are the dragon auras. Field 42 is sugar lumps on hand. Field 43 is sugar lumps ever made. Section 5 is the buildings. Section 6 is the upgrades. Section 7 is the achievements. Section 8 is the timed effects. Section 9 is mod data, and Cookie Save leaves that section as it was."
        ),
        HowBlock(
            heading: "Buildings",
            body: "One building per semicolon, from Cursor through You. Amount edits keep the minigame text. A minigame is open when the level is at least 1. Turning it off sets the level to 0 and keeps the minigame text. Turning it back on from 0 sets the level to 1. Seeds, brokers, worship swaps, and magic live inside that minigame text.",
            formula: "amount,bought,cookies produced,level,minigame,muted,highest"
        ),
        HowBlock(
            heading: "Upgrades and achievements",
            body: "Upgrades are two characters each, in catalog order. The first character is unlocked and the second is bought. 1 means yes and 0 means no. Achievements are one character each. 1 means won. Upgrade number 3 uses characters 6 and 7, because the pairs start at character 0.",
            formula: "characters at 2 × id and 2 × id + 1"
        ),
        HowBlock(
            heading: "Effects",
            body: "Each saved effect is the type, the full length, the time left, then any extra numbers. Records are separated by semicolons. The game runs at 30 frames a second, so the stored time is the seconds times 30. When that product is within a millionth of a whole frame, it is stored as that whole frame. 40.2 seconds is 1206 frames. Setting the time writes the full length and the time left to the same frame count. The power is the first extra number. A building boost or building rust stores the building number after the power, from 0 for Cursor through 19 for You. Only the 27 effects the game can load are added. Two records with the same display name become one.",
            formula: "frames = seconds × 30"
        ),
        HowBlock(
            heading: "Heavenly chips",
            body: "Setting heavenly chips writes field 26. On import the game ignores the stored prestige number and computes prestige from cookies forfeited. If the chips need more prestige than the forfeited cookies would give, Cookie Save raises field 8 until the formula reaches those chips.",
            formula: "prestige = floor( (forfeited / 1000000000000) ^ (1/3) )"
        ),
        HowBlock(
            heading: "Amount words",
            body: "A number field accepts 1000, 1e12, or 5.3 million. The word is a long scale name the game shows, and the decimal point moves by 3 places for each step. 5.3 million is 5300000. A trailing s is accepted, and so is sextillion."
        ),
        HowBlock(
            heading: "Copy save",
            body: "Copy save joins the sections with | again. Sections you did not change stay as they were. The text is encoded as UTF-8 base64, !END! is added, then the string is escaped. Reset restores the export you pasted. Cheats only rewrites the bakery name so the browser game opens its tools when the name ends with saysopensesame and has at least one letter in front. The name is kept to 28 characters."
        ),
        HowBlock(
            heading: "A whole example",
            body: "This small save is a made-up bakery named Bakery, with 100 cookies and one unlocked upgrade. The escaped line is what you would paste. Unescape turns %21 into !. Cutting !END! leaves the base64. Decoding it returns the plain line, and the vertical bars are the sections above. Field 0 of section 4 is 100.",
            formula: "2.058||1;1;1;Bakery;seed;0|10|100|0,0,0,0,,0,0|1|1|\nMi4wNTh8fDE7MTsxO0Jha2VyeTtzZWVkOzB8MTB8MTAwfDAsMCwwLDAsLDAsMHwxfDF8%21END%21"
        )
    ]

    var body: some View {
        FillingScroll {
            VStack(alignment: .leading, spacing: 16) {
                PageIntro(
                    title: "How This Works",
                    detail: "How a pasted export becomes the save on the other tabs. Written for Cookie Clicker 2.058."
                )
                ForEach(blocks) { block in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(block.heading)
                            .font(.headline)
                        Text(block.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if !block.formula.isEmpty {
                            Text(block.formula)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Oven.card)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Oven.background)
    }
}

private struct GuideBlock: Identifiable {
    let heading: String
    let body: String
    var id: String { heading }
}

private enum Guide {
    static let earlyDetail = "Where the cookies go before the first few ascensions. Written for Cookie Clicker 2.058."
    static let goldensDetail = "How the cookies that fall from the sky pay. Written for Cookie Clicker 2.058."
    static let ascendDetail = "The permanent bonuses, and the first chips to spend. Written for Cookie Clicker 2.058."
    static let laterDetail = "Grandmas, wrinklers, and sugar lumps. Written for Cookie Clicker 2.058."
    static let farmDetail = "Every garden mutation, the soils, and the sugar lumps the Farm spends. A listed chance is one roll on an empty open plot. Written for Cookie Clicker 2.058."
    static let pantheonDetail = "The three temple slots, and the sugar lump that refills worship swaps. The three numbers on each spirit are Diamond, then Ruby, then Jade. Written for Cookie Clicker 2.058."
    static let spellsDetail = "The grimoire spells, and the sugar lump that refills magic. Written for Cookie Clicker 2.058."

    static let early: [GuideBlock] = [
        GuideBlock(
            heading: "Where the cookies go",
            body: "Buy the building or upgrade that adds the most cookies per second for its price. A cheap building that barely adds anything can wait. Keep clicking the big cookie while the buildings are still weak. Cursor upgrades matter in that part of the run."
        ),
        GuideBlock(
            heading: "Hold some for Lucky",
            body: "Once golden cookies show up, keep a bank for a Lucky payout. The Goldens tab has the amount. Spending the whole bank on a building in the minute before a golden cookie shows up leaves that Lucky small."
        ),
        GuideBlock(
            heading: "First ascension",
            body: "The first heavenly chip takes 1 trillion cookies baked in total. Five chips is enough for Legacy, Twin Gates, and Heavenly cookies. The Ascend tab says what each one does. One chip on its own is a very small bonus, so those five are the early target."
        ),
        GuideBlock(
            heading: "One mind",
            body: "One mind adds 0.02 base CpS per grandma, for every grandma, and it starts the grandmapocalypse. Wrath cookies and wrinklers come with it. The Later tab covers when that trade is worth it."
        )
    ]

    static let goldens: [GuideBlock] = [
        GuideBlock(
            heading: "Frenzy",
            body: "Frenzy multiplies cookie production by 7 for 77 seconds. Click a golden cookie whenever it appears. The heavenly upgrades Get lucky and Lasting fortune make buffs last longer."
        ),
        GuideBlock(
            heading: "Lucky",
            body: "Lucky pays the smaller of 15% of the cookies you are holding, or 15 minutes of your cookies per second at the moment you click, plus 13. During a Frenzy your production is already ×7, so the full payout wants about 42,000 seconds of your normal production in the bank. That is about 11 hours and 40 minutes of CpS."
        ),
        GuideBlock(
            heading: "Click frenzy",
            body: "Click frenzy multiplies each click by 777 for about 13 seconds. It stacks with Frenzy. Click the big cookie the whole time both are up."
        ),
        GuideBlock(
            heading: "Building special",
            body: "A building special picks one building you own at least 10 of. It multiplies all cookie production by that count divided by 10, plus 1, for about 30 seconds. Two hundred of that building is a ×21 buff on everything."
        ),
        GuideBlock(
            heading: "Wrath cookies",
            body: "After One mind, some of these cookies are wrath cookies. Ruin takes cookies away. Elder Frenzy multiplies production by 666 for a few seconds. A building special can come out as a debuff about 30% of the time while wrath is up. Stay in that phase when you are ready to click through it."
        )
    ]

    static let ascend: [GuideBlock] = [
        GuideBlock(
            heading: "The chip",
            body: "Ascend from the Legacy button. Cookies baked all-time become heavenly chips. The first chip is at 1 trillion. Prestige level is the cube root of cookies forfeited divided by 1 trillion. Level 5 needs 125 trillion. Level 100 needs 1 quintillion. Each level is +1% cookies per second after Legacy is bought."
        ),
        GuideBlock(
            heading: "First three buys",
            body: "Legacy costs 1 chip and opens the tree. Heavenly cookies costs 3 chips, requires Legacy, and adds 10% CpS permanently. Twin Gates of Transcendence costs 1 chip. With the game closed you keep 5% of your CpS for the first hour, then 0.5%."
        ),
        GuideBlock(
            heading: "After those",
            body: "Heavenly luck costs 77 chips and makes golden cookies appear 5% more often. A permanent upgrade slot costs 100 chips and keeps one normal upgrade bought across ascensions. How to bake your dragon costs 9 chips and lets you buy the crumbly egg once the next run earns 1 million cookies."
        ),
        GuideBlock(
            heading: "When to press it",
            body: "Ascend while no Frenzy or click frenzy is running. Those buffs end with the run."
        )
    ]

    static let later: [GuideBlock] = [
        GuideBlock(
            heading: "Bingo center",
            body: "The Elder achievement is owning 7 grandma types. With that achievement, and at least 6 grandmas, Bingo center can be bought. It makes grandmas 4 times as efficient and starts the research upgrades."
        ),
        GuideBlock(
            heading: "Wrinklers",
            body: "One mind sets elder wrath to 1. Communal brainsweep adds another 0.02 base CpS per grandma and sets wrath to 2. Wrinklers then swallow part of your production and pay it back with a 10% bonus when you pop them. A shiny wrinkler pays triple that."
        ),
        GuideBlock(
            heading: "Sugar lumps",
            body: "Sugar lumps start after you have baked 1 billion cookies in total. A lump matures at 20 hours, and clicking it then is a 50% chance. It ripens at 23 hours, and that click is a sure harvest. It falls at 24 hours, and the game still collects it. Lumps keep growing while the game is closed. Open the game to harvest."
        ),
        GuideBlock(
            heading: "First lumps",
            body: "The first lump on a building opens its minigame. The Farm opens the garden, the Bank opens the stock market, the Temple opens the pantheon, and the Wizard tower opens the grimoire. The Farm, Pantheon, Spells, and Market tabs cover what those lumps do."
        )
    ]

    static let farm: [GuideBlock] = [
        GuideBlock(
            heading: "How a cross works",
            body: "A new seed can appear on an empty open plot. The game looks at all 8 tiles around that plot. The chance on each line is one roll when those plants are neighbors. If more than one roll succeeds, the game picks one of them. A plant counts as mature only where the line says mature. Wood chips runs that check 3 times. Supreme Intellect makes plants age and mutate 5% faster for each rank."
        ),
        GuideBlock(
            heading: "Soils",
            body: "Dirt ticks every 5 minutes. Fertilizer ticks every 3 minutes, plant effects are 25% weaker, weeds grow 20% more, and it unlocks after 50 harvests. Clay ticks every 15 minutes, plant effects are 25% stronger, and it unlocks after 100 harvests. Pebbles ticks every 5 minutes, plant effects are 75% weaker, weeds grow 90% less, a plant that dies of old age has a 35% chance to drop its seed, and it unlocks after 200 harvests. Wood chips ticks every 5 minutes, plant effects are 75% weaker, weeds grow 90% less, plants spread and mutate 3 times more, and it unlocks after 300 harvests. Wood chips is the soil for crossing."
        ),
        GuideBlock(
            heading: "Garden lump",
            body: "One sugar lump refills the soil timer and runs one growth tick at 3 times the spread and mutation. That button shares a 15-minute timer with the pantheon and the grimoire. The timer stays put while the game is closed. Level 1 is the lump that opens the garden. Each further Farm level costs one more lump than the current level and adds that level as a percent of Farm CpS."
        ),
        GuideBlock(
            heading: "Plot size",
            body: "The garden is 6 by 6. Farm level 1 opens 4 tiles. The next levels open 6, 9, 12, 16, 20, 25, 30, and 36 tiles at level 9. Reaching level 9 from level 0 costs 45 lumps."
        ),
        GuideBlock(
            heading: "Lumps from plants",
            body: "Baker's wheat is the seed you start with. Harvest a mature plant to unlock its seed. Juicy queenbeet cannot be planted from the seed bar. While it grows, CpS is 10% lower and the 3 by 3 around it is 20% less efficient. The Juicy queenbeet card has its cross and the lump a mature harvest pays. With every seed unlocked, Sacrifice garden clears the plot and every seed except Baker's wheat, and pays 10 sugar lumps."
        ),
        GuideBlock(
            heading: "Baker's wheat",
            body: "2 mature Baker's wheat: Baker's wheat 20%, Thumbcorn 5%, Bakeberry 0.1%."
        ),
        GuideBlock(
            heading: "Thumbcorn",
            body: "2 mature Thumbcorn: Thumbcorn 10%, Baker's wheat 5%. 2 mature Cronerice: Thumbcorn 2%."
        ),
        GuideBlock(
            heading: "Cronerice",
            body: "1 mature Baker's wheat and 1 mature Thumbcorn: 1%."
        ),
        GuideBlock(
            heading: "Gildmillet",
            body: "1 mature Cronerice and 1 mature Thumbcorn: 3%."
        ),
        GuideBlock(
            heading: "Clovers",
            body: "1 mature Baker's wheat and 1 mature Gildmillet: Ordinary clover 3%, Golden clover 0.07%. 2 or more mature Ordinary clover, while fewer than 5 Ordinary clover of any age are neighbors: Ordinary clover 0.7%, Golden clover 0.01%. 4 or more mature Ordinary clover: Golden clover 0.07%."
        ),
        GuideBlock(
            heading: "Shimmerlily",
            body: "1 mature Ordinary clover and 1 mature Gildmillet: 2%."
        ),
        GuideBlock(
            heading: "Elderwort",
            body: "1 mature Shimmerlily and 1 mature Cronerice: 1%. 1 mature Wrinklegill and 1 mature Cronerice: 0.2%."
        ),
        GuideBlock(
            heading: "Chocoroot",
            body: "1 mature Baker's wheat and 1 Brown mold of any age: 10%."
        ),
        GuideBlock(
            heading: "White chocoroot",
            body: "1 mature Chocoroot and 1 White mildew of any age: 10%."
        ),
        GuideBlock(
            heading: "Brown mold",
            body: "1 mature White mildew, while Brown mold of any age is 1 or fewer: 50%."
        ),
        GuideBlock(
            heading: "White mildew",
            body: "1 mature Brown mold, while White mildew of any age is 1 or fewer: 50%."
        ),
        GuideBlock(
            heading: "Meddleweed",
            body: "1 mature Meddleweed, while Meddleweed of any age is 3 or fewer: 15%."
        ),
        GuideBlock(
            heading: "Whiskerbloom",
            body: "1 mature Shimmerlily and 1 mature White chocoroot: 1%."
        ),
        GuideBlock(
            heading: "Chimerose",
            body: "1 mature Shimmerlily and 1 mature Whiskerbloom: 5%. 2 mature Chimerose: 0.5%."
        ),
        GuideBlock(
            heading: "Nursetulip",
            body: "2 mature Whiskerbloom: 5%."
        ),
        GuideBlock(
            heading: "Drowsyfern",
            body: "1 mature Chocoroot and 1 mature Keenmoss: 0.5%."
        ),
        GuideBlock(
            heading: "Wardlichen",
            body: "1 mature Cronerice with 1 mature Keenmoss, or 1 mature Cronerice with 1 mature White mildew: 0.5%. 1 mature Wardlichen, while fewer than 2 Wardlichen of any age are neighbors: 5%."
        ),
        GuideBlock(
            heading: "Keenmoss",
            body: "1 mature Green rot and 1 mature Brown mold: 10%. 1 mature Keenmoss, while fewer than 2 Keenmoss of any age are neighbors: 5%."
        ),
        GuideBlock(
            heading: "Queenbeet",
            body: "1 mature Chocoroot and 1 mature Bakeberry: 1%."
        ),
        GuideBlock(
            heading: "Juicy queenbeet",
            body: "8 mature Queenbeets: 0.1%. Harvest it once mature for exactly 1 sugar lump."
        ),
        GuideBlock(
            heading: "Duketater",
            body: "2 mature Queenbeets: 0.1%."
        ),
        GuideBlock(
            heading: "Crumbspore",
            body: "1 mature Crumbspore, and it is the only Crumbspore of any age: 7%. 2 mature Doughshroom: Crumbspore 0.5%."
        ),
        GuideBlock(
            heading: "Glovemorel",
            body: "1 mature Crumbspore and 1 mature Thumbcorn: 2%."
        ),
        GuideBlock(
            heading: "Cheapcap",
            body: "1 mature Crumbspore and 1 mature Shimmerlily: 4%."
        ),
        GuideBlock(
            heading: "Fool's bolete",
            body: "1 mature Doughshroom and 1 mature Green rot: 4%."
        ),
        GuideBlock(
            heading: "Doughshroom",
            body: "2 mature Crumbspore: 0.5%. 1 mature Doughshroom, and it is the only Doughshroom of any age: 7%."
        ),
        GuideBlock(
            heading: "Wrinklegill",
            body: "1 mature Crumbspore and 1 mature Brown mold: 6%."
        ),
        GuideBlock(
            heading: "Green rot",
            body: "1 mature White mildew and 1 mature Ordinary clover: 5%."
        ),
        GuideBlock(
            heading: "Shriekbulb",
            body: "1 mature Wrinklegill and 1 mature Elderwort: 0.1%. 5 mature Elderwort: 0.1%. 3 Duketater of any age: 0.5%. 4 Doughshroom of any age: 0.2%. 5 mature Queenbeet: 0.1%. 1 Shriekbulb of any age, while fewer than 2 are neighbors: 0.5%."
        ),
        GuideBlock(
            heading: "Tidygrass",
            body: "1 mature Baker's wheat and 1 mature White chocoroot: 0.2%."
        ),
        GuideBlock(
            heading: "Everdaisy",
            body: "3 mature Tidygrass and 3 mature Elderwort: 0.2%."
        ),
        GuideBlock(
            heading: "Ichorpuff",
            body: "1 mature Elderwort and 1 mature Crumbspore: 0.2%."
        )
    ]

    static let pantheon: [GuideBlock] = [
        GuideBlock(
            heading: "Slots and swaps",
            body: "Diamond is the strongest slot, then Ruby, then Jade. The slot count stays at three at every temple level. Putting a spirit in spends 1 worship swap. Taking one out is free. You start with 3 swaps. The next swap returns in 1 hour when 2 are left, in 4 hours when 1 is left, and in 16 hours when none are left. One sugar lump fills all 3 swaps. It shares the 15-minute lump timer. With Supreme Intellect, Jade acts as Ruby and Ruby acts as Diamond. Each temple level adds that level as a percent of Temple CpS. Level 1 is the lump that opens the pantheon."
        ),
        GuideBlock(
            heading: "Holobore",
            body: "Base CpS +15%, +10%, +5%. Clicking a golden cookie unslots Holobore and spends every worship swap."
        ),
        GuideBlock(
            heading: "Vomitrax",
            body: "Golden and wrath cookie effects last 7%, 5%, or 2% longer. Buildings grant 7%, 5%, or 2% less CpS."
        ),
        GuideBlock(
            heading: "Godzamok",
            body: "Selling buildings buffs clicks by 1%, 0.5%, or 0.25% for each building sold, for 10 seconds."
        ),
        GuideBlock(
            heading: "Cyclius",
            body: "CpS swings between +15% and −15%. The swing takes 3 hours, 12 hours, or 24 hours."
        ),
        GuideBlock(
            heading: "Selebrak",
            body: "Seasonal effects get a large, medium, or small boost. Switching seasons costs 100%, 50%, or 25% more."
        ),
        GuideBlock(
            heading: "Dotjeiess",
            body: "All buildings are 7%, 5%, or 2% cheaper. Heavenly chips are 30%, 20%, or 10% less effective."
        ),
        GuideBlock(
            heading: "Muridal",
            body: "Clicks are 15%, 10%, or 5% stronger. Buildings produce 3%, 2%, or 1% less."
        ),
        GuideBlock(
            heading: "Jeremy",
            body: "Buildings produce 10%, 6%, or 3% more. Golden and wrath cookies appear 10%, 6%, or 3% less often."
        ),
        GuideBlock(
            heading: "Mokalsium",
            body: "Milk is 10%, 5%, or 3% more powerful. Golden and wrath cookies appear 15%, 10%, or 5% less often."
        ),
        GuideBlock(
            heading: "Skruuia",
            body: "Golden cookies become wrath cookies, and a negative effect is more likely. Wrinklers appear 150%, 100%, or 50% faster and digest 15%, 10%, or 5% more cookies."
        ),
        GuideBlock(
            heading: "Rigidel",
            body: "Sugar lumps ripen 1 hour, 40 minutes, or 20 minutes sooner. This works when the number of buildings you own ends in 0."
        )
    ]

    static let spells: [GuideBlock] = [
        GuideBlock(
            heading: "Magic",
            body: "The most magic you can hold grows with how many wizard towers you own and with the tower's level. A spell costs its minimum plus a percent of that maximum. The base chance to backfire is 15%. One sugar lump refills 100 magic and shares the 15-minute lump timer. Magic also comes back on its own, slower while the meter is low. Supreme Intellect makes spells 10% cheaper and 10% more likely to fail. Level 1 on the Wizard tower is the lump that opens the grimoire. Each further level costs one more lump than the current level and adds that level as a percent of tower CpS."
        ),
        GuideBlock(
            heading: "Conjure Baked Goods",
            body: "Costs 2 magic plus 40% of your maximum. Success pays the smaller of 15% of the cookies you hold or 30 minutes of CpS, and at least 7 cookies. A backfire starts a 15-minute clot at half production and takes the smaller of 15% of your cookies or 15 minutes of CpS, plus 13. It cannot take more cookies than you hold."
        ),
        GuideBlock(
            heading: "Force the Hand of Fate",
            body: "Costs 10 magic plus 60% of your maximum. Success summons a golden cookie. A backfire summons a wrath cookie. Each golden cookie already on screen adds 15% to the backfire chance."
        ),
        GuideBlock(
            heading: "Stretch Time",
            body: "Costs 8 magic plus 20% of your maximum. Success adds 10% of each buff's full length, up to 5 extra minutes. A backfire cuts 20% off the time left on each buff, up to 10 minutes. With no buffs running, nothing changes."
        ),
        GuideBlock(
            heading: "Spontaneous Edifice",
            body: "Costs 20 magic plus 75% of your maximum. Success gives a free building you could buy with twice your cookies, as long as you own fewer than 400 of it, and it is not your most-built building unless that is your only building. A backfire removes one random building you own. With no valid building, nothing happens."
        ),
        GuideBlock(
            heading: "Haggler's Charm",
            body: "Costs 10 magic plus 10% of your maximum. Success makes upgrades 2% cheaper for 1 minute. A backfire makes upgrades 2% more expensive for 1 hour."
        ),
        GuideBlock(
            heading: "Summon Crafty Pixies",
            body: "Costs 10 magic plus 20% of your maximum. Success makes buildings 2% cheaper for 1 minute. A backfire makes buildings 2% more expensive for 1 hour."
        ),
        GuideBlock(
            heading: "Gambler's Fever Dream",
            body: "Costs 3 magic plus 5% of your maximum. It casts another spell you can still afford, at half that spell's magic cost, and that cast backfires at least half the time. If the other spell cannot be cast, this magic is returned."
        ),
        GuideBlock(
            heading: "Resurrect Abomination",
            body: "Costs 20 magic plus 10% of your maximum. Success summons a wrinkler when the game allows one. A backfire pops a random wrinkler. If there is nothing to summon or pop, nothing else happens."
        ),
        GuideBlock(
            heading: "Diminish Ineptitude",
            body: "Costs 5 magic plus 20% of your maximum. Success makes spells backfire 10 times less for 5 minutes. A backfire makes spells backfire 5 times more for 10 minutes."
        )
    ]
}

private struct GuidePage: View {
    let title: String
    let detail: String
    let blocks: [GuideBlock]

    var body: some View {
        FillingScroll {
            VStack(alignment: .leading, spacing: 16) {
                PageIntro(title: title, detail: detail)
                ForEach(blocks) { block in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(block.heading)
                            .font(.headline)
                        Text(block.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Oven.card)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Oven.background)
    }
}

private struct MarketPage: View {
    @ObservedObject var model: EditorModel

    var body: some View {
        FillingScroll {
            VStack(alignment: .leading, spacing: 16) {
                PageIntro(
                    title: "Market",
                    detail: "Read from this save. Each pattern lasts until its timer ends, and a market shock can end one early. A fast rise can flip into a fast fall. Prices are seconds of your highest raw cookies per second."
                )
                if let save = model.save {
                    if let board = StockBoard.read(from: save) {
                        boardHeader(board)
                        quoteList(board)
                    } else {
                        Text("This save has no stock market yet. Give the Bank one sugar lump so it reaches level 1, open the market once, then export again.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Load a save first.")
                            .font(.title3)
                        Button("Go to Save") { model.page = .save }
                    }
                }
                lumpCard
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Oven.background)
    }

    private var lumpCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "cube")
                    .foregroundStyle(Oven.accent)
                Text("Sugar lumps on the bank")
                    .font(.headline)
            }
            Text("One sugar lump takes the Bank from level 0 to level 1. Open the market once after that, then export, and this page can read it. Each further level costs one more lump than the current level. The Bank gains that level as a percent of CpS, and every stock's usual price rises by $1 for each bank level above 1. Offices, brokers, and loans are bought with cookies.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Oven.card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func quoteList(_ board: StockBoard) -> some View {
        if board.quotes.isEmpty {
            Text("No goods are on the board yet. A stock shows up after you have owned its building at least once.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            let rising = board.quotes.filter { $0.outlook.mayRise }
            let rest = board.quotes.filter { !$0.outlook.mayRise }
            Text(rising.isEmpty ? "Nothing in this save is in a rising pattern right now." : "May go up")
                .font(.headline)
                .foregroundStyle(rising.isEmpty ? Color.secondary : riseColor)
            if rising.isEmpty {
                Text("Look again after the next market minute. The timer on each row is how long the current pattern still has.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(rising) { quote in
                    stockCard(quote)
                }
            }
            if !rest.isEmpty {
                Text("The rest")
                    .font(.headline)
                    .padding(.top, 4)
                ForEach(rest) { quote in
                    stockCard(quote)
                }
            }
        }
        if board.inactiveCount > 0 {
            Text("\(board.inactiveCount) more \(board.inactiveCount == 1 ? "good is" : "goods are") off the board until that building has been owned.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func boardHeader(_ board: StockBoard) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            stat("Office", "\(board.officeName)  ·  level \(board.officeLevel + 1)")
            stat("Brokers", "\(board.brokers)")
            stat("Bank level", "\(board.bankLevel)")
            if board.supremeIntellect {
                Text("Supreme Intellect is on, so patterns end sooner and jump harder.")
                    .font(.callout)
                    .foregroundStyle(Oven.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Oven.card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func stockCard(_ quote: StockQuote) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(quote.symbol)  \(quote.name)")
                    .font(.headline)
                Spacer(minLength: 8)
                Text(marketMoney(quote.value))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(tone(quote.outlook))
            }
            Text(verdict(quote))
                .foregroundStyle(tone(quote.outlook))
            Text(note(quote))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(meta(quote))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Oven.card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func verdict(_ quote: StockQuote) -> String {
        switch quote.outlook {
        case .slowRise: return "May go up"
        case .fastRise: return "May go up fast"
        case .cheapStable: return "Under its usual price"
        case .stable: return "Mostly flat"
        case .chaotic: return "Skip"
        case .slowFall: return "Likely down"
        case .fastFall: return "Likely down fast"
        case .unknown: return "Unknown pattern"
        }
    }

    private func note(_ quote: StockQuote) -> String {
        switch quote.outlook {
        case .slowRise:
            return "This is the calmer rise. It still wobbles each minute."
        case .fastRise:
            return "Each market minute has about a 3% chance to flip this into a fast fall."
        case .cheapStable:
            return "The price sits under the usual value, so it has a small pull upward. The pattern itself is flat."
        case .stable:
            return "The pattern is flat. The minute-to-minute noise can still move it a little."
        case .chaotic:
            return "This one jumps both ways. Treat a guess here as a coin flip."
        case .slowFall:
            return "The pattern is a slow fall."
        case .fastFall:
            return "The pattern is a fast fall."
        case .unknown:
            return "This row uses a mode the reader does not know."
        }
    }

    private func meta(_ quote: StockQuote) -> String {
        var parts = [
            "Usual \(marketMoney(quote.resting))",
            stepText(quote),
            clock(quote.minutesLeft)
        ]
        if quote.owned > 0 {
            var holding = "Holding \(quote.owned)"
            if quote.lastBuy > 0 {
                holding += " · last buy \(marketMoney(quote.lastBuy))"
                if quote.value > quote.lastBuy {
                    holding += " · above that buy"
                } else if quote.value < quote.lastBuy {
                    holding += " · under that buy"
                }
            }
            parts.append(holding)
        }
        if quote.hidden {
            parts.append("Hidden in the market list")
        }
        return parts.joined(separator: "  ·  ")
    }

    private func clock(_ minutes: Int) -> String {
        if minutes <= 0 { return "Changes on the next market minute" }
        if minutes == 1 { return "About 1 minute left" }
        return "About \(minutes) minutes left"
    }

    private func stepText(_ quote: StockQuote) -> String {
        let previous = quote.value - quote.step
        guard previous > 0.01 else {
            if quote.step > 0 { return "Last step up" }
            if quote.step < 0 { return "Last step down" }
            return "Last step flat"
        }
        let shown = floor((quote.value / previous - 1) * 10000) / 100
        if shown > 0 { return String(format: "Last step +%.2f%%", shown) }
        if shown < 0 { return String(format: "Last step %.2f%%", shown) }
        return "Last step flat"
    }

    private var riseColor: Color {
        Color(red: 0.40, green: 0.82, blue: 0.48)
    }

    private func tone(_ outlook: StockOutlook) -> Color {
        switch outlook {
        case .slowRise, .fastRise:
            return riseColor
        case .slowFall, .fastFall:
            return Color(red: 0.86, green: 0.42, blue: 0.32)
        default:
            return Color.secondary
        }
    }

    private func marketMoney(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }
}
