import Foundation

enum SaveError: LocalizedError {
    case empty
    case undecodable
    case tooFewSections
    case missingCatalog

    var errorDescription: String? {
        switch self {
        case .empty:
            return "Paste a Cookie Clicker export first."
        case .undecodable:
            return "That text is not a Cookie Clicker export."
        case .tooFewSections:
            return "That export is too short to be a Cookie Clicker save."
        case .missingCatalog:
            return "The upgrade list did not load."
        }
    }
}

struct CatalogItem: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
    let pool: String
}

final class CatalogStore {
    let upgrades: [CatalogItem]
    let achievements: [CatalogItem]
    private let upgradeNames: [String: CatalogItem]
    private let achievementNames: [String: CatalogItem]

    init(upgrades: [CatalogItem], achievements: [CatalogItem]) {
        self.upgrades = upgrades
        self.achievements = achievements
        self.upgradeNames = Dictionary(upgrades.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        self.achievementNames = Dictionary(achievements.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func upgrade(named name: String) -> CatalogItem? {
        upgradeNames[name]
    }

    func achievement(named name: String) -> CatalogItem? {
        achievementNames[name]
    }

    static func load(from url: URL) throws -> CatalogStore {
        let data = try Data(contentsOf: url)
        return try decode(data)
    }

    static func loadBundled() throws -> CatalogStore {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json") else {
            throw SaveError.missingCatalog
        }
        return try load(from: url)
    }

    private static func decode(_ data: Data) throws -> CatalogStore {
        let raw = try JSONDecoder().decode(CatalogFile.self, from: data)
        return CatalogStore(upgrades: raw.upgrades, achievements: raw.achievements)
    }

    private struct CatalogFile: Decodable {
        let upgrades: [CatalogItem]
        let achievements: [CatalogItem]
    }
}

enum JSSave {
    private static let safe: Set<Character> = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789@*_+-./")

    static func unescape(_ source: String) -> String {
        var units: [UInt16] = []
        units.reserveCapacity(source.utf16.count)
        let chars = Array(source.utf16)
        var index = 0
        while index < chars.count {
            if chars[index] == 37 {
                if index + 5 < chars.count, chars[index + 1] == 117, let value = hex(chars[index + 2...index + 5]) {
                    units.append(UInt16(value))
                    index += 6
                    continue
                }
                if index + 2 < chars.count, let value = hex(chars[index + 1...index + 2]) {
                    units.append(UInt16(value))
                    index += 3
                    continue
                }
            }
            units.append(chars[index])
            index += 1
        }
        return String(decoding: units, as: UTF16.self)
    }

    static func escape(_ source: String) -> String {
        var out = ""
        out.reserveCapacity(source.utf16.count)
        for unit in source.utf16 {
            if unit < 128, let scalar = UnicodeScalar(unit), safe.contains(Character(scalar)) {
                out.append(Character(scalar))
            } else if unit < 256 {
                out.append(String(format: "%%%02X", UInt(unit)))
            } else {
                out.append(String(format: "%%u%04X", UInt(unit)))
            }
        }
        return out
    }

    private static func hex(_ units: ArraySlice<UInt16>) -> UInt32? {
        var value: UInt32 = 0
        for unit in units {
            let digit: UInt32
            if unit >= 48 && unit <= 57 {
                digit = UInt32(unit - 48)
            } else if unit >= 65 && unit <= 70 {
                digit = UInt32(unit - 55)
            } else if unit >= 97 && unit <= 102 {
                digit = UInt32(unit - 87)
            } else {
                return nil
            }
            value = value * 16 + digit
        }
        return value
    }

    static func parseNumber(_ token: String) -> Double {
        let trimmed = token.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return 0 }
        return Double(trimmed) ?? 0
    }

    static func parseUserNumber(_ raw: String) -> Double? {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        trimmed = trimmed.replacingOccurrences(of: ",", with: "")
        trimmed = trimmed.replacingOccurrences(of: "_", with: "")
        if trimmed.isEmpty { return nil }
        let lower = trimmed.lowercased()
        // Hex floats such as -0x10 still parse as Double. Scale words such as sextillion also contain x.
        if lower.contains("x") { return scaledWord(lower) }
        if let value = Double(lower), value.isFinite { return value }
        return scaledWord(lower)
    }

    /// "5.3 million" and the other long names the game shows, through novemnonagintillion.
    private static func scaledWord(_ lower: String) -> Double? {
        let parts = lower.split(whereSeparator: \.isWhitespace).map(String.init)
        let numberText: String
        let word: String
        if parts.count == 2 {
            numberText = parts[0]
            word = parts[1]
        } else if parts.count == 1, let split = splitNumberWord(parts[0]) {
            numberText = split.0
            word = split.1
        } else {
            return nil
        }
        var name = word
        if wordScales[name] == nil, name.hasSuffix("s") {
            name.removeLast()
        }
        guard let exponent = wordScales[name] else { return nil }
        return exactScaled(numberText, exponent: exponent)
    }

    private static func splitNumberWord(_ text: String) -> (String, String)? {
        let letters = text.firstIndex { $0.isLetter }
        guard let letters else { return nil }
        let number = String(text[..<letters])
        let word = String(text[letters...])
        guard !number.isEmpty, word.allSatisfy(\.isLetter) else { return nil }
        return (number, word)
    }

    /// Moves the decimal point so "5.3" times a thousand-scale stays exact.
    private static func exactScaled(_ numberText: String, exponent: Int) -> Double? {
        if numberText.contains("e") {
            guard let base = Double(numberText), base.isFinite else { return nil }
            let value = base * pow(10, Double(exponent))
            return value.isFinite ? value : nil
        }
        var text = numberText
        var negative = false
        if text.hasPrefix("-") {
            negative = true
            text.removeFirst()
        } else if text.hasPrefix("+") {
            text.removeFirst()
        }
        let pieces = text.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard pieces.count == 1 || pieces.count == 2 else { return nil }
        let whole = pieces[0].isEmpty ? "0" : pieces[0]
        let fraction = pieces.count == 2 ? pieces[1] : ""
        guard whole.allSatisfy(\.isNumber), fraction.allSatisfy(\.isNumber) else { return nil }
        let digits = whole + fraction
        let point = whole.count + exponent
        let rendered: String
        if point <= 0 {
            rendered = "0." + String(repeating: "0", count: -point) + digits
        } else if point >= digits.count {
            rendered = digits + String(repeating: "0", count: point - digits.count)
        } else {
            let splitAt = digits.index(digits.startIndex, offsetBy: point)
            rendered = String(digits[..<splitAt]) + "." + String(digits[splitAt...])
        }
        let body = negative ? "-" + rendered : rendered
        guard let value = Double(body), value.isFinite else { return nil }
        return value
    }

    private static let wordScales: [String: Int] = {
        var names = [
            "thousand", "million", "billion", "trillion", "quadrillion",
            "quintillion", "sextillion", "septillion", "octillion", "nonillion"
        ]
        let prefixes = ["", "un", "duo", "tre", "quattuor", "quin", "sex", "septen", "octo", "novem"]
        let suffixes = [
            "decillion", "vigintillion", "trigintillion", "quadragintillion", "quinquagintillion",
            "sexagintillion", "septuagintillion", "octogintillion", "nonagintillion"
        ]
        for suffix in suffixes {
            for prefix in prefixes {
                names.append(prefix + suffix)
            }
        }
        var scales: [String: Int] = [:]
        for (index, name) in names.enumerated() {
            scales[name] = (index + 1) * 3
        }
        return scales
    }()

    /// A number `parseFloat` in the game accepts. Unchanged save tokens are not run through this.
    static func numberString(_ value: Double) -> String {
        guard value.isFinite else { return "0" }
        if value == 0 { return "0" }
        let negative = value < 0
        var raw = "\(abs(value))"
        if raw.hasSuffix(".0") { raw.removeLast(2) }
        let body = plainOrScientific(raw)
        return negative ? "-" + body : body
    }

    private static func plainOrScientific(_ raw: String) -> String {
        let lower = raw.replacingOccurrences(of: "E", with: "e")
        guard let marker = lower.firstIndex(of: "e") else { return lower }
        let mantissa = String(lower[..<marker])
        var exponentText = String(lower[lower.index(after: marker)...])
        if exponentText.hasPrefix("+") { exponentText.removeFirst() }
        guard let exponent = Int(exponentText) else { return lower }
        if exponent < -6 || exponent > 20 {
            return mantissa + "e" + (exponent < 0 ? "-" : "+") + String(abs(exponent))
        }
        return expand(mantissa: mantissa, exponent: exponent)
    }

    private static func expand(mantissa: String, exponent: Int) -> String {
        var digits = mantissa
        let negative = digits.hasPrefix("-")
        if negative { digits.removeFirst() }
        let pieces = digits.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let whole = pieces.first ?? "0"
        let fraction = pieces.count > 1 ? pieces[1] : ""
        let all = whole + fraction
        let point = whole.count + exponent
        let rendered: String
        if point <= 0 {
            rendered = "0." + String(repeating: "0", count: -point) + all
        } else if point >= all.count {
            rendered = all + String(repeating: "0", count: point - all.count)
        } else {
            let splitAt = all.index(all.startIndex, offsetBy: point)
            rendered = String(all[..<splitAt]) + "." + String(all[splitAt...])
        }
        return negative ? "-" + rendered : rendered
    }
}

struct SaveFile {
    static let buildingNames = [
        "Cursor", "Grandma", "Farm", "Mine", "Factory", "Bank", "Temple",
        "Wizard tower", "Shipment", "Alchemy lab", "Portal", "Time machine",
        "Antimatter condenser", "Prism", "Chancemaker", "Fractal engine",
        "Javascript console", "Idleverse", "Cortex baker", "You"
    ]

    /// In-game names for a building boost, in building order.
    static let buffNames = [
        "High-five", "Congregation", "Luxuriant harvest", "Ore vein", "Oiled-up",
        "Juicy profits", "Fervent adoration", "Manabloom", "Delicious lifeforms",
        "Breakthrough", "Righteous cataclysm", "Golden ages", "Extra cycles",
        "Solar flare", "Winning streak", "Macrocosm", "Refactoring",
        "Cosmic nursery", "Brainstorm", "Deduplication"
    ]

    /// In-game names for a building rust, in building order.
    static let debuffNames = [
        "Slap to the face", "Senility", "Locusts", "Cave-in", "Jammed machinery",
        "Recession", "Crisis of faith", "Magivores", "Black holes", "Lab disaster",
        "Dimensional calamity", "Time jam", "Predictable tragedy", "Eclipse",
        "Dry spell", "Microcosm", "Antipattern", "Big crunch", "Brain freeze",
        "Clone strike"
    ]

    static let santaLevels = [
        "Festive test tube", "Festive ornament", "Festive wreath", "Festive tree",
        "Festive present", "Festive elf fetus", "Elf toddler", "Elfling",
        "Young elf", "Bulky elf", "Nick", "Santa Claus", "Elder Santa",
        "True Santa", "Final Claus"
    ]

    static let auraNames = [
        "No aura", "Breath of Milk", "Dragon Cursor", "Elder Battalion",
        "Reaper of Fields", "Earth Shatterer", "Master of the Armory",
        "Fierce Hoarder", "Dragon God", "Arcane Aura", "Dragonflight",
        "Ancestral Metamorphosis", "Unholy Dominion", "Epoch Manipulator",
        "Mind Over Matter", "Radiant Appetite", "Dragon's Fortune",
        "Dragon's Curve", "Reality Bending", "Dragon Orbs", "Supreme Intellect",
        "Dragon Guts"
    ]

    static let seasons: [(id: String, label: String, biscuit: String)] = [
        ("", "No season", ""),
        ("christmas", "Christmas", "Festive biscuit"),
        ("halloween", "Halloween", "Ghostly biscuit"),
        ("valentines", "Valentine's", "Lovesick biscuit"),
        ("fools", "Business day", "Fool's biscuit"),
        ("easter", "Easter", "Bunny biscuit")
    ]

    static let heavenlyUpgrades = [
        "Heavenly chip secret", "Heavenly cookie stand", "Heavenly bakery",
        "Heavenly confectionery", "Heavenly key"
    ]

    static let cookiePresets: [(label: String, value: Double)] = [
        ("1 million", 1e6),
        ("1 billion", 1e9),
        ("1 trillion", 1e12),
        ("1 quadrillion", 1e15),
        ("1 quintillion", 1e18),
        ("1 sextillion", 1e21),
        ("1 septillion", 1e24),
        ("1 octillion", 1e27),
        ("1 nonillion", 1e30),
        ("1 decillion", 1e33)
    ]

    static let chipPresets: [(label: String, value: Double)] = [
        ("100", 100),
        ("1 thousand", 1_000),
        ("10 thousand", 10_000),
        ("100 thousand", 100_000),
        ("1 million", 1_000_000),
        ("10 million", 10_000_000),
        ("100 million", 100_000_000),
        ("1 billion", 1_000_000_000)
    ]

    static let lumpPresets: [(label: String, value: Double)] = [
        ("1", 1),
        ("7", 7),
        ("100", 100),
        ("365", 365),
        ("1,000", 1_000)
    ]

    let catalog: CatalogStore
    private let originalSections: [String]
    private var runTokens: [String]
    private var miscTokens: [String]
    private var buildingTokens: [String]
    private var upgradeBits: String
    private var achievementBits: String
    private var runDirty = false
    private var miscDirty = false
    private var buildingsDirty = false
    private var upgradesDirty = false
    private var achievementsDirty = false
    /// Save section 8. Section 9, the mod data, stays in originalSections.
    private var buffSection: String
    private var buffsDirty = false

    var hasEdits: Bool {
        runDirty || miscDirty || buildingsDirty || upgradesDirty || achievementsDirty || buffsDirty
    }

    var version: String { originalSections.first ?? "" }
    var bakeryName: String { token(runTokens, 3) }
    var cookiesToken: String { token(miscTokens, 0) }
    var cookiesEarnedToken: String { token(miscTokens, 1) }
    var cookieClicksToken: String { token(miscTokens, 2) }
    var goldenClicksToken: String { token(miscTokens, 3) }
    var ascensionsToken: String { token(miscTokens, 14) }
    var cookiesResetToken: String { token(miscTokens, 8) }
    var heavenlyChipsToken: String { token(miscTokens, 26) }
    var heavenlySpentToken: String { token(miscTokens, 27) }
    var lumpsToken: String { token(miscTokens, 42) }
    var lumpsTotalToken: String { token(miscTokens, 43) }
    var season: String { token(miscTokens, 22) }
    var seasonTimeToken: String { token(miscTokens, 20) }

    var santaLevel: Int { intToken(token(miscTokens, 18)) }
    var dragonLevel: Int { intToken(token(miscTokens, 35)) }
    var dragonAura: Int { intToken(token(miscTokens, 36)) }
    var dragonAura2: Int { intToken(token(miscTokens, 37)) }

    static func load(pasted: String, catalog: CatalogStore) throws -> SaveFile {
        let compact = String(pasted.unicodeScalars.filter {
            !CharacterSet.whitespacesAndNewlines.contains($0)
        })
        if compact.isEmpty { throw SaveError.empty }
        let unescaped = JSSave.unescape(compact)
        let body: String
        if let range = unescaped.range(of: "!END!") {
            body = String(unescaped[..<range.lowerBound])
        } else {
            body = unescaped
        }
        guard let data = Data(base64Encoded: body),
              let plain = String(data: data, encoding: .utf8),
              !plain.isEmpty
        else { throw SaveError.undecodable }
        let sections = splitKeepEmpty(plain, separator: "|")
        if sections.count < 5 { throw SaveError.tooFewSections }
        return SaveFile(catalog: catalog, sections: sections)
    }

    private init(catalog: CatalogStore, sections: [String]) {
        self.catalog = catalog
        self.originalSections = sections
        self.runTokens = splitKeepEmpty(sections.count > 2 ? sections[2] : "", separator: ";")
        self.miscTokens = splitKeepEmpty(sections.count > 4 ? sections[4] : "", separator: ";")
        self.buildingTokens = splitKeepEmpty(sections.count > 5 ? sections[5] : "", separator: ";")
        self.upgradeBits = sections.count > 6 ? sections[6] : ""
        self.achievementBits = sections.count > 7 ? sections[7] : ""
        self.buffSection = sections.count > 8 ? sections[8] : ""
    }

    func plain() -> String {
        var parts = originalSections
        if runDirty {
            pad(&parts, through: 2)
            parts[2] = runTokens.joined(separator: ";")
        }
        if miscDirty {
            pad(&parts, through: 4)
            parts[4] = miscTokens.joined(separator: ";")
        }
        if buildingsDirty {
            pad(&parts, through: 5)
            parts[5] = buildingTokens.joined(separator: ";")
        }
        if upgradesDirty {
            pad(&parts, through: 6)
            parts[6] = upgradeBits
        }
        if achievementsDirty {
            pad(&parts, through: 7)
            parts[7] = achievementBits
        }
        if buffsDirty {
            pad(&parts, through: 8)
            parts[8] = buffSection
        }
        return parts.joined(separator: "|")
    }

    func export() -> String {
        let encoded = Data(plain().utf8).base64EncodedString()
        return JSSave.escape(encoded + "!END!")
    }

    func buildingAmount(_ index: Int) -> Int {
        intToken(commaParts(token(buildingTokens, index)).first ?? "0")
    }

    func buildingLevel(_ index: Int) -> Int {
        let parts = commaParts(token(buildingTokens, index))
        return parts.count > 3 ? intToken(parts[3]) : 0
    }

    func buildingBought(_ index: Int) -> Int {
        let parts = commaParts(token(buildingTokens, index))
        return parts.count > 1 ? intToken(parts[1]) : 0
    }

    /// Highest amount ever owned. Older records that omit the field fall back to the current amount.
    func buildingHighest(_ index: Int) -> Int {
        let parts = commaParts(token(buildingTokens, index))
        if parts.count > 6 { return intToken(parts[6]) }
        return intToken(parts.first ?? "0")
    }

    /// Minigame blob, comma field 4. Amount and level edits keep this field.
    /// Farm, Bank, Temple, and Wizard tower can rewrite their own blob.
    func buildingMinigame(_ index: Int) -> String {
        let parts = commaParts(token(buildingTokens, index))
        return parts.count > 4 ? parts[4] : ""
    }

    func ownsUpgrade(_ name: String) -> Bool {
        guard let item = catalog.upgrade(named: name) else { return false }
        return upgradeBought(item.id)
    }

    func upgradeUnlocked(_ id: Int) -> Bool { bit(upgradeBits, id * 2) }
    func upgradeBought(_ id: Int) -> Bool { bit(upgradeBits, id * 2 + 1) }
    func achievementWon(_ id: Int) -> Bool { bit(achievementBits, id) }

    func ownedUpgradeCount() -> Int {
        let bytes = Array(upgradeBits.utf8)
        var count = 0
        var index = 1
        while index < bytes.count {
            if bytes[index] == 49 { count += 1 }
            index += 2
        }
        return count
    }

    func wonAchievementCount() -> Int {
        achievementBits.reduce(0) { $0 + ($1 == "1" ? 1 : 0) }
    }

    static let sesameSuffix = "saysopensesame"

    static func cheatsOpen(in name: String) -> Bool {
        let lower = name.lowercased()
        return lower.count > sesameSuffix.count && lower.hasSuffix(sesameSuffix)
    }

    /// Browser Cookie Clicker opens its dev tools when the bakery name ends with
    /// `saysopensesame` and has at least one letter in front. The game keeps 28 letters.
    static func bakeryName(current: String, cheats enabled: Bool) -> String {
        let suffix = sesameSuffix
        var base = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.lowercased().hasSuffix(suffix) {
            base = String(base.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !enabled {
            return base.isEmpty ? "Bakery" : base
        }
        let room = 28 - suffix.count - 1
        if base.count > room {
            let end = base.index(base.startIndex, offsetBy: room)
            base = String(base[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if base.isEmpty { base = "A" }
        return base + " " + suffix
    }

    mutating func setBakeryName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "The bakery needs a name." }
        if trimmed.contains(";") || trimmed.contains("|") || trimmed.contains("\n") {
            return "A bakery name can't include ; or |."
        }
        while runTokens.count <= 3 { runTokens.append("") }
        guard runTokens[3] != trimmed else { return nil }
        runTokens[3] = trimmed
        runDirty = true
        return nil
    }

    mutating func setCookies(_ value: Double) {
        let amount = min(max(value, 0), 1e300)
        let earned = JSSave.parseNumber(token(miscTokens, 1))
        setMiscNumber(0, amount)
        // The game flags the save when cookies in the bank exceed cookies earned.
        if amount > earned {
            setMiscNumber(1, amount)
        }
    }

    mutating func setHeavenlyChips(_ value: Double) {
        let chips = min(max(value, 0), 1e15)
        setMiscNumber(26, chips)
        raiseCookiesResetIfNeeded(chips: chips, spent: JSSave.parseNumber(token(miscTokens, 27)))
    }

    mutating func setHeavenlySpent(_ value: Double) {
        let spent = min(max(value, 0), 1e15)
        setMiscNumber(27, spent)
        raiseCookiesResetIfNeeded(chips: JSSave.parseNumber(token(miscTokens, 26)), spent: spent)
    }

    mutating func setLumps(_ value: Double) {
        let count = min(max(floor(value), 0), 1e15)
        let total = JSSave.parseNumber(token(miscTokens, 43))
        setMiscNumber(42, count)
        if total < count {
            setMiscNumber(43, count)
        }
    }

    mutating func setSanta(_ level: Int) {
        let clamped = min(max(level, 0), SaveFile.santaLevels.count - 1)
        setMiscNumber(18, Double(clamped))
        if clamped > 0 {
            setUpgrade(named: "A festive hat", owned: true)
        }
    }

    mutating func setDragonLevel(_ level: Int) {
        let clamped = min(max(level, 0), 27)
        setMiscNumber(35, Double(clamped))
        if clamped > 0 {
            setUpgrade(named: "A crumbly egg", owned: true)
        }
        if clamped < 27, dragonAura2 != 0 {
            setMiscNumber(37, 0)
        }
    }

    mutating func setDragonAura(slot: Int, id: Int) {
        let aura = min(max(id, 0), SaveFile.auraNames.count - 1)
        if slot == 0 {
            setMiscNumber(36, Double(aura))
        } else {
            setMiscNumber(37, Double(aura))
        }
        guard aura > 0 else { return }
        setUpgrade(named: "A crumbly egg", owned: true)
        let minimum = slot == 1 ? 27 : aura + 4
        if dragonLevel < minimum {
            setMiscNumber(35, Double(minimum))
        }
    }

    mutating func setSeason(_ id: String) {
        let known = SaveFile.seasons.contains { $0.id == id }
        let season = known ? id : ""
        setMiscText(22, season)
        if season.isEmpty {
            setMiscNumber(20, -1)
        } else {
            // One year of frames at 30 fps. Offline import keeps a season that still has time left.
            setMiscNumber(20, 946_080_000)
            setUpgrade(named: "Season switcher", owned: true)
        }
        for option in SaveFile.seasons where !option.biscuit.isEmpty {
            if option.id == season {
                setUpgrade(named: option.biscuit, owned: true)
            } else {
                setUpgradeBought(named: option.biscuit, bought: false)
            }
        }
    }

    mutating func setBuilding(index: Int, amount: Int? = nil, level: Int? = nil) {
        guard index >= 0, index < SaveFile.buildingNames.count else { return }
        ensureBuilding(index)
        var parts = commaParts(buildingTokens[index])
        while parts.count < 7 {
            parts.append(parts.count == 4 ? "" : "0")
        }
        if let amount {
            let count = min(max(amount, 0), 1_000_000_000)
            let bought = max(intToken(parts[1]), count)
            let highest = max(intToken(parts[6]), count)
            parts[0] = String(count)
            parts[1] = String(bought)
            parts[6] = String(highest)
        }
        if let level {
            parts[3] = String(min(max(level, 0), 10_000))
        }
        let next = parts.joined(separator: ",")
        guard next != buildingTokens[index] else { return }
        buildingTokens[index] = next
        buildingsDirty = true
    }

    mutating func setAllBuildings(amount: Int) {
        for index in SaveFile.buildingNames.indices {
            setBuilding(index: index, amount: amount)
        }
    }

    mutating func setAllBuildingLevels(_ level: Int) {
        for index in SaveFile.buildingNames.indices {
            setBuilding(index: index, level: level)
        }
    }

    /// Parsed seeds, brokers, worship swaps, or magic. Nil when this building has no minigame or the blob is empty or unreadable.
    func minigameAmount(_ index: Int) -> Int? {
        guard let kind = BuildingMinigame(rawValue: index) else { return nil }
        let blob = buildingMinigame(index).trimmingCharacters(in: .whitespacesAndNewlines)
        if blob.isEmpty { return nil }
        return kind.readAmount(blob)
    }

    /// Live grimoire cap: floor(4 + towers^0.6 + ln((towers + (level-1)*10) / 15 + 1) * 15).
    /// Level 0 uses 1, matching a minigame that is turned back on.
    func grimoireCap() -> Int {
        let towers = Double(max(buildingAmount(7), 1))
        let level = Double(max(buildingLevel(7), 1))
        let value = 4 + pow(towers, 0.6) + log((towers + (level - 1) * 10) / 15 + 1) * 15
        guard value.isFinite else { return 0 }
        return max(Int(value.rounded(.down)), 0)
    }

    /// On means level is at least 1. Off sets level to 0 and keeps the minigame string.
    mutating func setMinigameEnabled(index: Int, on: Bool) -> MinigameWrite {
        guard let kind = BuildingMinigame(rawValue: index) else {
            return .unchanged("This building has no minigame.")
        }
        let building = SaveFile.buildingNames[index]
        let level = buildingLevel(index)
        let blob = buildingMinigame(index).trimmingCharacters(in: .whitespacesAndNewlines)
        if on {
            if level > 0 && !blob.isEmpty {
                return .unchanged("\(kind.title) is already on.")
            }
            var wroteFresh = false
            if blob.isEmpty {
                let amount = kind.defaultAmount(cap: grimoireCap())
                let fresh = kind.freshBlob(amount: amount, buildingLevel: level)
                guard storeMinigame(index, fresh) else {
                    return .unchanged("Could not write a \(kind.title.lowercased()) save.")
                }
                wroteFresh = true
            }
            if buildingLevel(index) == 0 {
                setBuilding(index: index, level: 1)
            }
            let levelNow = buildingLevel(index)
            if wroteFresh {
                return .updated("\(kind.title) is on. \(building) level is \(levelNow). A fresh \(kind.kept) save was written.")
            }
            return .updated("\(kind.title) is on. \(building) level is \(levelNow). The saved \(kind.kept) stays. Turning it off and on again comes back at level 1.")
        }
        if level == 0 {
            return .unchanged("\(kind.title) is already off. The saved \(kind.kept) stays.")
        }
        setBuilding(index: index, level: 0)
        if level > 1 {
            return .updated("\(kind.title) is off. \(building) level is 0, so it stays closed. The saved \(kind.kept) stays. It was level \(level). Turning it on sets the level to 1.")
        }
        return .updated("\(kind.title) is off. \(building) level is 0, so it stays closed. The saved \(kind.kept) stays. Turning it on sets the level to 1.")
    }

    /// Writes seeds, brokers, worship swaps, or magic. A blob that cannot be read is left alone.
    mutating func setMinigameAmount(index: Int, value: Int) -> MinigameWrite {
        guard let kind = BuildingMinigame(rawValue: index) else {
            return .unchanged("This building has no minigame.")
        }
        let cap = grimoireCap()
        let clamped = kind.clamp(value, cap: cap)
        let existing = buildingMinigame(index).trimmingCharacters(in: .whitespacesAndNewlines)
        let nextBlob: String
        if existing.isEmpty {
            nextBlob = kind.freshBlob(amount: clamped, buildingLevel: buildingLevel(index))
        } else if let replaced = kind.replacing(existing, amount: clamped) {
            nextBlob = replaced
        } else {
            return .unchanged("The \(kind.title.lowercased()) save couldn't be read, so \(kind.counterName.lowercased()) stayed as it is.")
        }
        let before = token(buildingTokens, index)
        guard storeMinigame(index, nextBlob) else {
            return .unchanged("That \(kind.counterName.lowercased()) value can't be stored.")
        }
        if token(buildingTokens, index) == before {
            return .unchanged("\(kind.already) \(clamped).")
        }
        return .updated(kind.amountMessage(clamped, requested: value))
    }

    private mutating func storeMinigame(_ index: Int, _ blob: String) -> Bool {
        guard BuildingMinigame.safe(blob) else { return false }
        ensureBuilding(index)
        var parts = commaParts(buildingTokens[index])
        while parts.count < 7 {
            parts.append(parts.count == 4 ? "" : "0")
        }
        parts[4] = blob
        let next = parts.joined(separator: ",")
        guard next != buildingTokens[index] else { return true }
        buildingTokens[index] = next
        buildingsDirty = true
        return true
    }

    mutating func setUpgrade(id: Int, owned: Bool) {
        guard id >= 0 else { return }
        let bit: Character = owned ? "1" : "0"
        setBits(id * 2, bit, id * 2 + 1, bit, inUpgrades: true)
    }

    mutating func setUpgrade(named name: String, owned: Bool) {
        guard let item = catalog.upgrade(named: name) else { return }
        setUpgrade(id: item.id, owned: owned)
    }

    mutating func buyUpgrades(where include: (CatalogItem) -> Bool) {
        for item in catalog.upgrades where include(item) {
            setUpgrade(id: item.id, owned: true)
        }
    }

    mutating func setAchievement(id: Int, won: Bool) {
        guard id >= 0 else { return }
        setBits(id, won ? "1" : "0", nil, nil, inUpgrades: false)
    }

    mutating func awardAllAchievements() {
        for item in catalog.achievements where item.name != "Cheated cookies taste awful" {
            setAchievement(id: item.id, won: true)
        }
    }

    private mutating func setUpgradeBought(named name: String, bought: Bool) {
        guard let item = catalog.upgrade(named: name) else { return }
        let unlocked: Character = upgradeUnlocked(item.id) ? "1" : "0"
        setBits(item.id * 2, unlocked, item.id * 2 + 1, bought ? "1" : "0", inUpgrades: true)
    }

    private mutating func raiseCookiesResetIfNeeded(chips: Double, spent: Double) {
        let need = chips + spent
        guard need > 0 else { return }
        let current = JSSave.parseNumber(token(miscTokens, 8))
        if floor(pow(current / 1e12, 1.0 / 3.0)) >= need { return }
        // On import the game sets prestige from cookies forfeited, and ignores the stored prestige field.
        setMiscNumber(8, cookiesForPrestige(atLeast: need))
    }

    private func cookiesForPrestige(atLeast need: Double) -> Double {
        let goal = max(ceil(need), 1)
        var cookies = pow(goal, 3) * 1e12
        var step = 0
        while cookies.isFinite && floor(pow(cookies / 1e12, 1.0 / 3.0)) < need && step < 20 {
            cookies *= 1.0000000000001
            step += 1
        }
        if !cookies.isFinite { return 1e300 }
        return cookies
    }

    private mutating func setMiscNumber(_ index: Int, _ value: Double) {
        ensureMisc(index)
        let current = miscTokens[index]
        if !current.isEmpty && JSSave.parseNumber(current) == value { return }
        let next = JSSave.numberString(value)
        guard next != current else { return }
        miscTokens[index] = next
        miscDirty = true
    }

    private mutating func setMiscText(_ index: Int, _ value: String) {
        ensureMisc(index)
        guard miscTokens[index] != value else { return }
        miscTokens[index] = value
        miscDirty = true
    }

    private mutating func ensureMisc(_ index: Int) {
        let trail = miscTokens.last == ""
        if trail { miscTokens.removeLast() }
        while miscTokens.count <= index { miscTokens.append("0") }
        if trail { miscTokens.append("") }
    }

    private mutating func ensureBuilding(_ index: Int) {
        let trail = buildingTokens.last == ""
        if trail { buildingTokens.removeLast() }
        while buildingTokens.count <= index {
            buildingTokens.append("0,0,0,0,,0,0")
        }
        if trail { buildingTokens.append("") }
    }

    private mutating func setBits(_ first: Int, _ firstValue: Character, _ second: Int?, _ secondValue: Character?, inUpgrades: Bool) {
        var text = inUpgrades ? upgradeBits : achievementBits
        let limit = max(first, second ?? first) + 1
        if text.count < limit {
            text.append(contentsOf: String(repeating: "0", count: limit - text.count))
        }
        var chars = Array(text)
        let before = chars
        chars[first] = firstValue
        if let second, let secondValue {
            chars[second] = secondValue
        }
        guard chars != before else { return }
        let next = String(chars)
        if inUpgrades {
            upgradeBits = next
            upgradesDirty = true
        } else {
            achievementBits = next
            achievementsDirty = true
        }
    }

    private func token(_ tokens: [String], _ index: Int) -> String {
        index < tokens.count ? tokens[index] : ""
    }

    private func intToken(_ token: String) -> Int {
        if let value = Int(token) { return value }
        return Int(JSSave.parseNumber(token).rounded())
    }

    private func commaParts(_ record: String) -> [String] {
        record.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
    }

    private func bit(_ text: String, _ index: Int) -> Bool {
        let bytes = Array(text.utf8)
        guard index >= 0, index < bytes.count else { return false }
        return bytes[index] == 49
    }

    private func pad(_ parts: inout [String], through index: Int) {
        while parts.count <= index { parts.append("") }
    }

    func savedEffects() -> [SavedEffect] {
        buffTokens().enumerated().compactMap { slot, raw in
            raw.isEmpty ? nil : SavedEffect.parse(slot: slot, raw: raw)
        }
    }

    mutating func addEffect(typeID: Int, seconds: Double, power: Double, building: Int?) -> EffectWrite {
        guard let kind = GameEffect.find(typeID) else {
            return .unchanged("That effect is not one the game can load.")
        }
        guard let frames = Self.effectFrames(seconds) else {
            return .unchanged("Enter a time in seconds, like 77.")
        }
        guard power.isFinite else {
            return .unchanged("Enter a power, like 7.")
        }
        let chosen: Int?
        if kind.needsBuilding {
            guard let building, Self.buildingNames.indices.contains(building) else {
                return .unchanged("Pick a building for this effect.")
            }
            chosen = building
        } else {
            chosen = nil
        }
        var args = [power]
        if let chosen { args.append(Double(chosen)) }
        guard let rendered = Self.effectRecord(typeID: typeID, maxFrames: frames, frames: frames, args: args) else {
            return .unchanged("That number cannot be stored.")
        }
        var kept: [String] = []
        var wrote = false
        for token in buffTokens() where !token.isEmpty {
            let effect = SavedEffect.parse(slot: 0, raw: token)
            if Self.sameEffect(effect, typeID: typeID, building: chosen) {
                if !wrote {
                    kept.append(rendered)
                    wrote = true
                }
            } else {
                kept.append(token)
            }
        }
        if !wrote { kept.append(rendered) }
        let name = Self.effectTitle(typeID: typeID, building: chosen)
        guard writeBuffSection(kept) else {
            return .unchanged("\(name) is already set that way.")
        }
        return .updated("\(name) is on for \(Self.secondLabel(frames)) at power \(JSSave.numberString(power)).")
    }

    mutating func updateEffect(slot: Int, seconds: Double?, power: Double?, building: Int?) -> EffectWrite {
        var tokens = buffTokens()
        guard tokens.indices.contains(slot), !tokens[slot].isEmpty else {
            return .unchanged("That effect is no longer in this save.")
        }
        let current = SavedEffect.parse(slot: slot, raw: tokens[slot])
        guard let typeID = current.typeID, let kind = GameEffect.find(typeID), let oldFrames = current.frames else {
            return .unchanged("That effect could not be read. Remove it if you want it gone.")
        }
        let frames: Double
        let maxFrames: Double
        if let seconds {
            guard let converted = Self.effectFrames(seconds) else {
                return .unchanged("Enter a time in seconds, like 77.")
            }
            frames = converted
            maxFrames = converted
        } else {
            frames = oldFrames
            maxFrames = current.maxFrames ?? oldFrames
        }
        guard power == nil || power?.isFinite == true else {
            return .unchanged("Enter a power, like 7.")
        }
        var args = current.args
        if let power {
            if args.isEmpty { args = [power] } else { args[0] = power }
        }
        let chosen: Int?
        if kind.needsBuilding {
            chosen = building ?? current.building
            guard let chosen, Self.buildingNames.indices.contains(chosen) else {
                return .unchanged("Pick a building for this effect.")
            }
            let clash = tokens.enumerated().contains { offset, raw in
                offset != slot && !raw.isEmpty && Self.sameEffect(
                    SavedEffect.parse(slot: offset, raw: raw),
                    typeID: typeID,
                    building: chosen
                )
            }
            if clash {
                return .unchanged("\(Self.effectTitle(typeID: typeID, building: chosen)) is already in this save.")
            }
            if args.isEmpty { args = [kind.power, Double(chosen)] }
            else if args.count == 1 { args.append(Double(chosen)) }
            else { args[1] = Double(chosen) }
        } else {
            chosen = nil
        }
        guard let rendered = Self.effectRecord(typeID: typeID, maxFrames: maxFrames, frames: frames, args: args) else {
            return .unchanged("That number cannot be stored.")
        }
        let name = Self.effectTitle(typeID: typeID, building: kind.needsBuilding ? chosen : nil)
        guard tokens[slot] != rendered else {
            return .unchanged("\(name) is already set that way.")
        }
        tokens[slot] = rendered
        _ = writeBuffSection(tokens)
        return .updated("\(name) is on for \(Self.secondLabel(frames)) at power \(JSSave.numberString(args.first ?? kind.power)).")
    }

    mutating func removeEffect(slot: Int) -> EffectWrite {
        var tokens = buffTokens()
        guard tokens.indices.contains(slot), !tokens[slot].isEmpty else {
            return .unchanged("That effect is no longer in this save.")
        }
        let current = SavedEffect.parse(slot: slot, raw: tokens[slot])
        let name = current.displayName
        tokens.remove(at: slot)
        _ = writeBuffSection(tokens)
        return .updated("Removed \(name).")
    }

    private func buffTokens() -> [String] {
        if buffSection.isEmpty { return [] }
        var tokens = splitKeepEmpty(buffSection, separator: ";")
        if tokens.last?.isEmpty == true { tokens.removeLast() }
        return tokens
    }

    private mutating func writeBuffSection(_ tokens: [String]) -> Bool {
        let body = tokens.filter { !$0.isEmpty }
        let next = body.isEmpty ? "" : body.joined(separator: ";") + ";"
        guard next != buffSection else { return false }
        buffSection = next
        buffsDirty = true
        return true
    }

    static func effectTitle(typeID: Int, building: Int?) -> String {
        guard let kind = GameEffect.find(typeID) else { return "Unrecognized effect" }
        if kind.needsBuilding, let building, buildingNames.indices.contains(building) {
            let names = typeID == 9 ? buffNames : debuffNames
            if names.indices.contains(building) { return names[building] }
        }
        return kind.title
    }

    static func secondLabel(_ frames: Double) -> String {
        let text = JSSave.numberString(frames / 30)
        return text == "1" ? "1 second" : "\(text) seconds"
    }

    private static func sameEffect(_ effect: SavedEffect, typeID: Int, building: Int?) -> Bool {
        guard effect.typeID == typeID, let kind = GameEffect.find(typeID) else { return false }
        if kind.needsBuilding { return effect.building == building }
        return true
    }

    private static func effectFrames(_ seconds: Double) -> Double? {
        guard seconds.isFinite, seconds >= 0, seconds <= 1_000_000_000_000 else { return nil }
        let product = seconds * 30
        guard product.isFinite else { return nil }
        let nearest = product.rounded()
        if abs(product - nearest) < 0.000_001 { return nearest }
        return product
    }

    private static func effectRecord(typeID: Int, maxFrames: Double, frames: Double, args: [Double]) -> String? {
        var pieces = [String(typeID), JSSave.numberString(maxFrames), JSSave.numberString(frames)]
        for arg in args {
            pieces.append(JSSave.numberString(arg))
        }
        let record = pieces.joined(separator: ",")
        if record.contains(";") || record.contains("|") || record.contains("\n") || record.contains(" ") {
            return nil
        }
        return record
    }
}

enum EffectWrite {
    case unchanged(String)
    case updated(String)
}

/// One timed effect the 2.058 game can save. The id is the buff type id.
struct GameEffect: Identifiable, Equatable {
    let id: Int
    let title: String
    let seconds: Double
    let power: Double
    let needsBuilding: Bool
    let note: String

    static func find(_ id: Int) -> GameEffect? {
        all.first { $0.id == id }
    }

    static let all: [GameEffect] = [
        GameEffect(id: 0, title: "Frenzy", seconds: 77, power: 7, needsBuilding: false, note: "Cookie production is multiplied by the power."),
        GameEffect(id: 1, title: "Elder frenzy", seconds: 6, power: 666, needsBuilding: false, note: "Cookie production is multiplied by the power."),
        GameEffect(id: 2, title: "Clot", seconds: 66, power: 0.5, needsBuilding: false, note: "Cookie production is multiplied by the power. A wrath cookie uses 0.5."),
        GameEffect(id: 3, title: "Dragon Harvest", seconds: 60, power: 15, needsBuilding: false, note: "Cookie production is multiplied by the power. If this save owns Dragon fang, the game raises the power by 10% and rounds up on import."),
        GameEffect(id: 4, title: "Everything must go", seconds: 8, power: 5, needsBuilding: false, note: "Buildings are this percent cheaper."),
        GameEffect(id: 5, title: "Cursed finger", seconds: 10, power: 1, needsBuilding: false, note: "Cookie production stops. Each click gives this many cookies. A wrath cookie sets that from your cookies per second."),
        GameEffect(id: 6, title: "Click frenzy", seconds: 13, power: 777, needsBuilding: false, note: "Each click is multiplied by the power."),
        GameEffect(id: 7, title: "Dragonflight", seconds: 10, power: 1111, needsBuilding: false, note: "Each click is multiplied by the power. If this save owns Dragon fang, the game raises the power by 10% and rounds up on import."),
        GameEffect(id: 8, title: "Cookie storm", seconds: 7, power: 7, needsBuilding: false, note: "Golden cookies fall while this lasts. A golden cookie stores power 7 with it."),
        GameEffect(id: 9, title: "Building boost", seconds: 30, power: 2, needsBuilding: true, note: "Cookie production is multiplied by the power. Leave the power blank to use buildings owned, divided by 10, plus 1."),
        GameEffect(id: 10, title: "Building rust", seconds: 30, power: 2, needsBuilding: true, note: "Cookie production is divided by the power. Leave the power blank to use buildings owned, divided by 10, plus 1."),
        GameEffect(id: 11, title: "Sugar blessing", seconds: 86400, power: 1, needsBuilding: false, note: "Golden cookies appear 10% more often. That 10% is fixed in the game. A lump blessing stores power 1."),
        GameEffect(id: 12, title: "Haggler's luck", seconds: 60, power: 2, needsBuilding: false, note: "Upgrades are this percent cheaper."),
        GameEffect(id: 13, title: "Haggler's misery", seconds: 3600, power: 2, needsBuilding: false, note: "Upgrades are this percent more expensive."),
        GameEffect(id: 14, title: "Crafty pixies", seconds: 60, power: 2, needsBuilding: false, note: "Buildings are this percent cheaper."),
        GameEffect(id: 15, title: "Nasty goblins", seconds: 3600, power: 2, needsBuilding: false, note: "Buildings are this percent more expensive."),
        GameEffect(id: 16, title: "Magic adept", seconds: 300, power: 10, needsBuilding: false, note: "Spells backfire this many times less."),
        GameEffect(id: 17, title: "Magic inept", seconds: 600, power: 5, needsBuilding: false, note: "Spells backfire this many times more."),
        GameEffect(id: 18, title: "Devastation", seconds: 10, power: 2, needsBuilding: false, note: "Each click is multiplied by the power. The temple sets the power from buildings you sell."),
        GameEffect(id: 19, title: "Sugar frenzy", seconds: 3600, power: 3, needsBuilding: false, note: "Cookie production is multiplied by the power."),
        GameEffect(id: 20, title: "Loan 1", seconds: 7200, power: 1.5, needsBuilding: false, note: "Cookie production is multiplied by the power. When this ends in the game, Loan 1 (interest) starts."),
        GameEffect(id: 21, title: "Loan 1 (interest)", seconds: 14400, power: 0.25, needsBuilding: false, note: "Cookie production is multiplied by the power."),
        GameEffect(id: 22, title: "Loan 2", seconds: 40.2, power: 2, needsBuilding: false, note: "Cookie production is multiplied by the power. When this ends in the game, Loan 2 (interest) starts."),
        GameEffect(id: 23, title: "Loan 2 (interest)", seconds: 2400, power: 0.1, needsBuilding: false, note: "Cookie production is multiplied by the power."),
        GameEffect(id: 24, title: "Loan 3", seconds: 172800, power: 1.2, needsBuilding: false, note: "Cookie production is multiplied by the power. When this ends in the game, Loan 3 (interest) starts."),
        GameEffect(id: 25, title: "Loan 3 (interest)", seconds: 432000, power: 0.8, needsBuilding: false, note: "Cookie production is multiplied by the power."),
        GameEffect(id: 26, title: "Gifted out", seconds: 3600, power: 1, needsBuilding: false, note: "Gifts stay closed for this long.")
    ]
}

struct SavedEffect: Identifiable, Equatable {
    let slot: Int
    let raw: String
    let typeID: Int?
    let maxFrames: Double?
    let frames: Double?
    let args: [Double]

    var id: Int { slot }
    var power: Double? { args.first }
    var building: Int? {
        guard let typeID, GameEffect.find(typeID)?.needsBuilding == true, args.count > 1 else { return nil }
        let index = Int(args[1].rounded())
        guard abs(args[1] - Double(index)) < 0.000_001, SaveFile.buildingNames.indices.contains(index) else { return nil }
        return index
    }
    var displayName: String {
        guard let typeID else { return "Unrecognized effect" }
        return SaveFile.effectTitle(typeID: typeID, building: building)
    }

    static func parse(slot: Int, raw: String) -> SavedEffect {
        let fields = raw.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        guard fields.count >= 3,
              let typeID = Int(fields[0]),
              GameEffect.find(typeID) != nil,
              let maxFrames = Double(fields[1]), maxFrames.isFinite,
              let frames = Double(fields[2]), frames.isFinite
        else {
            return SavedEffect(slot: slot, raw: raw, typeID: nil, maxFrames: nil, frames: nil, args: [])
        }
        var args: [Double] = []
        for field in fields.dropFirst(3) {
            guard let value = Double(field), value.isFinite else {
                return SavedEffect(slot: slot, raw: raw, typeID: nil, maxFrames: nil, frames: nil, args: [])
            }
            args.append(value)
        }
        return SavedEffect(slot: slot, raw: raw, typeID: typeID, maxFrames: maxFrames, frames: frames, args: args)
    }
}

enum MinigameWrite {
    case unchanged(String)
    case updated(String)
}

/// Farm garden, bank market, temple pantheon, and wizard grimoire. Raw value is the building index.
enum BuildingMinigame: Int {
    case garden = 2
    case market = 5
    case pantheon = 6
    case grimoire = 7

    var title: String {
        switch self {
        case .garden: return "Garden"
        case .market: return "Market"
        case .pantheon: return "Pantheon"
        case .grimoire: return "Grimoire"
        }
    }

    var counterName: String {
        switch self {
        case .garden: return "Seeds"
        case .market: return "Brokers"
        case .pantheon: return "Worship swaps"
        case .grimoire: return "Magic"
        }
    }

    /// Noun used when telling Nick the saved minigame was kept.
    var kept: String {
        switch self {
        case .garden: return "garden"
        case .market: return "market"
        case .pantheon: return "pantheon"
        case .grimoire: return "grimoire"
        }
    }

    var already: String {
        switch self {
        case .garden: return "Seeds are already"
        case .market: return "Brokers are already"
        case .pantheon: return "Worship swaps are already"
        case .grimoire: return "Magic is already"
        }
    }

    var note: String {
        switch self {
        case .garden:
            return "Off sets the farm level to 0 and keeps the plants. Seeds unlock the first plants. Baker's wheat stays unlocked."
        case .market:
            return "Off sets the bank level to 0 and keeps the stocks. Brokers are the helpers stored in the market."
        case .pantheon:
            return "Off sets the temple level to 0 and keeps the spirits. Worship swaps go from 0 to 3."
        case .grimoire:
            return "Off sets the wizard tower level to 0 and keeps the spells. Magic fills up to this tower's bar."
        }
    }

    /// Shown when the save has no blob yet, so +1 and -1 have a starting count.
    var emptyAmount: Int {
        switch self {
        case .garden: return 1
        case .market: return 0
        case .pantheon: return 3
        case .grimoire: return 0
        }
    }

    func clamp(_ value: Int, cap: Int) -> Int {
        switch self {
        case .garden: return min(max(value, 1), 34)
        case .market: return min(max(value, 0), 1_000_000_000)
        case .pantheon: return min(max(value, 0), 3)
        case .grimoire: return min(max(value, 0), max(cap, 0))
        }
    }

    func defaultAmount(cap: Int) -> Int {
        switch self {
        case .garden: return 1
        case .market: return 0
        case .pantheon: return 3
        case .grimoire: return max(cap, 0)
        }
    }

    func amountMessage(_ clamped: Int, requested: Int) -> String {
        switch self {
        case .garden:
            if requested > 34 {
                return "Seeds set to 34. A garden has 34 plants. Baker's wheat stays unlocked."
            }
            if requested < 1 {
                return "Seeds set to 1. Baker's wheat stays unlocked."
            }
            return "Seeds set to \(clamped). That unlocks the first \(clamped) plants. Baker's wheat stays unlocked."
        case .market:
            return "Brokers set to \(clamped)."
        case .pantheon:
            if requested != clamped {
                return "Worship swaps set to \(clamped). The temple holds up to 3."
            }
            return "Worship swaps set to \(clamped)."
        case .grimoire:
            if requested != clamped {
                return "Magic set to \(clamped). That is this tower's full bar."
            }
            return "Magic set to \(clamped)."
        }
    }

    static func safe(_ blob: String) -> Bool {
        !blob.contains(",") && !blob.contains(";") && !blob.contains("|")
            && !blob.contains("\n") && !blob.contains("\r")
    }

    func readAmount(_ blob: String) -> Int? {
        let fields = splitKeepEmpty(blob, separator: " ")
        switch self {
        case .garden:
            guard fields.count >= 3 else { return nil }
            let bits = fields[1]
            guard bits.allSatisfy({ $0 == "0" || $0 == "1" }) else { return nil }
            if bits.isEmpty { return 1 }
            let window = bits.prefix(34)
            var count = window.filter { $0 == "1" }.count
            if window.first != "1" { count += 1 }
            return max(count, 1)
        case .market:
            guard let header = fields.first, !header.isEmpty else { return nil }
            let headerFields = splitKeepEmpty(header, separator: ":")
            guard headerFields.count >= 5, let brokers = Self.whole(headerFields[1]) else { return nil }
            return max(brokers, 0)
        case .pantheon:
            guard fields.count >= 4 else { return nil }
            guard splitKeepEmpty(fields[0], separator: "/").count == 3 else { return nil }
            guard let swaps = Self.whole(fields[1]) else { return nil }
            return max(swaps, 0)
        case .grimoire:
            guard fields.count >= 4, let magic = Self.whole(fields[0]) else { return nil }
            return max(magic, 0)
        }
    }

    func replacing(_ blob: String, amount: Int) -> String? {
        var fields = splitKeepEmpty(blob, separator: " ")
        switch self {
        case .garden:
            guard fields.count >= 3 else { return nil }
            let bits = fields[1]
            guard bits.isEmpty || bits.allSatisfy({ $0 == "0" || $0 == "1" }) else { return nil }
            fields[1] = Self.seedBits(amount)
        case .market:
            guard !fields.isEmpty else { return nil }
            var header = splitKeepEmpty(fields[0], separator: ":")
            guard header.count >= 5, Self.whole(header[1]) != nil else { return nil }
            header[1] = String(amount)
            fields[0] = header.joined(separator: ":")
        case .pantheon:
            guard fields.count >= 4 else { return nil }
            guard splitKeepEmpty(fields[0], separator: "/").count == 3 else { return nil }
            guard Self.whole(fields[1]) != nil else { return nil }
            fields[1] = String(amount)
        case .grimoire:
            guard fields.count >= 4, Self.whole(fields[0]) != nil else { return nil }
            fields[0] = String(amount)
        }
        let next = fields.joined(separator: " ")
        return Self.safe(next) ? next : nil
    }

    func freshBlob(amount: Int, buildingLevel: Int) -> String {
        let now = Int(Date().timeIntervalSince1970 * 1000)
        switch self {
        case .garden:
            let plot = String(repeating: "0:0:", count: 36)
            return "\(now):0:\(now):0:0:0:1:0:\(now): \(Self.seedBits(amount)) \(plot)"
        case .market:
            let level = max(buildingLevel, 1)
            let goods = (0..<18).map { id -> String in
                let dollars = 10 + 10 * id + (level - 1)
                return "\(dollars * 100):0:0:100:0:1:0:0"
            }.joined(separator: "!") + "!"
            return "0:\(amount):1:0:0: \(goods) 1"
        case .pantheon:
            return "-1/-1/-1 \(amount) \(now) 1"
        case .grimoire:
            return "\(amount) 0 0 1"
        }
    }

    private static func seedBits(_ count: Int) -> String {
        let unlocked = min(max(count, 1), 34)
        return String(repeating: "1", count: unlocked) + String(repeating: "0", count: 34 - unlocked)
    }

    private static func whole(_ token: String) -> Int? {
        guard let value = Double(token), value.isFinite else { return nil }
        return Int(value.rounded(.down))
    }
}

enum StockOutlook: Int, Equatable {
    case slowRise = 0
    case fastRise = 1
    case cheapStable = 2
    case stable = 3
    case chaotic = 4
    case slowFall = 5
    case fastFall = 6
    case unknown = 7

    var mayRise: Bool { self == .slowRise || self == .fastRise }
}

struct StockQuote: Identifiable, Equatable {
    let id: Int
    let name: String
    let symbol: String
    let value: Double
    let resting: Double
    let mode: Int
    let step: Double
    let minutesLeft: Int
    let owned: Int
    let hidden: Bool
    let lastBuy: Double
    let outlook: StockOutlook
}

struct StockBoard: Equatable {
    let officeName: String
    let officeLevel: Int
    let brokers: Int
    let bankLevel: Int
    let quotes: [StockQuote]
    let inactiveCount: Int
    let supremeIntellect: Bool

    static let bankIndex = 5
    static let supremeIntellectAura = 20

    private static let offices = [
        "Credit garage", "Tiny bank", "Loaning company", "Finance headquarters",
        "International exchange", "Palace of Greed"
    ]

    /// Goods follow the market script, Farm through You. Building index is good id + 2.
    private static let goods: [(name: String, symbol: String)] = [
        ("Cereals", "CRL"), ("Chocolate", "CHC"), ("Butter", "BTR"), ("Sugar", "SUG"),
        ("Nuts", "NUT"), ("Salt", "SLT"), ("Vanilla", "VNL"), ("Eggs", "EGG"),
        ("Cinnamon", "CNM"), ("Cream", "CRM"), ("Jam", "JAM"), ("White chocolate", "WCH"),
        ("Honey", "HNY"), ("Cookies", "CKI"), ("Recipes", "RCP"), ("Subsidiaries", "SBD"),
        ("Publicists", "PBL"), ("You", "YOU")
    ]

    /// Reads the bank minigame. Returns nil when this save has no market string yet.
    static func read(from save: SaveFile) -> StockBoard? {
        let raw = save.buildingMinigame(bankIndex).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let pieces = splitKeepEmpty(raw, separator: " ")
        guard let header = pieces.first, !header.isEmpty else { return nil }
        let headerFields = splitKeepEmpty(header, separator: ":")
        guard let office = jsInt(headerFields.first ?? ""),
              let brokers = jsInt(headerFields.count > 1 ? headerFields[1] : "")
        else { return nil }

        let bankLevel = save.buildingLevel(bankIndex)
        let goodsBlob = pieces.count > 1 ? pieces[1] : ""
        var quotes: [StockQuote] = []
        var inactive = 0
        if !goodsBlob.isEmpty {
            let rows = splitKeepEmpty(goodsBlob, separator: "!")
            for (index, row) in rows.enumerated() {
                if row.isEmpty || index >= goods.count { continue }
                guard let quote = quote(index: index, row: row, save: save, bankLevel: bankLevel) else { continue }
                if save.buildingHighest(index + 2) > 0 {
                    quotes.append(quote)
                } else {
                    inactive += 1
                }
            }
        }
        quotes.sort { lhs, rhs in
            if lhs.outlook.rawValue != rhs.outlook.rawValue {
                return lhs.outlook.rawValue < rhs.outlook.rawValue
            }
            return (lhs.resting - lhs.value) > (rhs.resting - rhs.value)
        }
        let officeLevel = min(max(office, 0), offices.count - 1)
        let intellect = save.dragonAura == supremeIntellectAura || save.dragonAura2 == supremeIntellectAura
        return StockBoard(
            officeName: offices[officeLevel],
            officeLevel: officeLevel,
            brokers: max(brokers, 0),
            bankLevel: bankLevel,
            quotes: quotes,
            inactiveCount: inactive,
            supremeIntellect: intellect
        )
    }

    private static func quote(index: Int, row: String, save: SaveFile, bankLevel: Int) -> StockQuote? {
        let fields = splitKeepEmpty(row, separator: ":")
        guard fields.count >= 5,
              let valueCents = jsInt(fields[0]),
              let mode = jsInt(fields[1]),
              let stepCents = jsInt(fields[2]),
              let minutes = jsInt(fields[3]),
              let owned = jsInt(fields[4])
        else { return nil }
        let value = Double(valueCents) / 100
        let resting = Double(10 + 10 * index + (bankLevel - 1))
        let good = goods[index]
        let name: String
        if index == goods.count - 1 {
            let bakery = save.bakeryName.trimmingCharacters(in: .whitespacesAndNewlines)
            name = bakery.isEmpty ? good.name : bakery
        } else {
            name = good.name
        }
        return StockQuote(
            id: index,
            name: name,
            symbol: good.symbol,
            value: value,
            resting: resting,
            mode: mode,
            step: Double(stepCents) / 100,
            minutesLeft: minutes,
            owned: max(owned, 0),
            hidden: (jsInt(fields.count > 5 ? fields[5] : "") ?? 0) != 0,
            lastBuy: Double(jsInt(fields.count > 7 ? fields[7] : "") ?? 0) / 100,
            outlook: outlook(mode: mode, value: value, resting: resting)
        )
    }

    private static func outlook(mode: Int, value: Double, resting: Double) -> StockOutlook {
        switch mode {
        case 1: return .slowRise
        case 3: return .fastRise
        case 0: return value < resting * 0.9 ? .cheapStable : .stable
        case 5: return .chaotic
        case 2: return .slowFall
        case 4: return .fastFall
        default: return .unknown
        }
    }

    /// Cookie Clicker's parseInt: optional sign, then digits, stopping at the first non-digit.
    private static func jsInt(_ text: String) -> Int? {
        var digits = text
        var sign = 1
        if digits.hasPrefix("-") {
            sign = -1
            digits.removeFirst()
        } else if digits.hasPrefix("+") {
            digits.removeFirst()
        }
        let number = digits.prefix { $0.isNumber }
        guard !number.isEmpty, let value = Int(number) else { return nil }
        return sign * value
    }
}

private func splitKeepEmpty(_ text: String, separator: Character) -> [String] {
    var parts: [String] = []
    var current = ""
    for character in text {
        if character == separator {
            parts.append(current)
            current = ""
        } else {
            current.append(character)
        }
    }
    parts.append(current)
    return parts
}

func friendlyCookies(_ token: String) -> String {
    guard let value = Double(token), value.isFinite else { return token.isEmpty ? "0" : token }
    if value == 0 { return "0" }
    let units: [(Double, String)] = [
        (1e33, "decillion"), (1e30, "nonillion"), (1e27, "octillion"),
        (1e24, "septillion"), (1e21, "sextillion"), (1e18, "quintillion"),
        (1e15, "quadrillion"), (1e12, "trillion"), (1e9, "billion"),
        (1e6, "million"), (1e3, "thousand")
    ]
    let sign = value < 0 ? "-" : ""
    let magnitude = abs(value)
    for (scale, name) in units where magnitude >= scale {
        let scaled = magnitude / scale
        let rounded = (scaled * 100).rounded() / 100
        let text = rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), rounded)
        return "\(sign)\(text) \(name)"
    }
    return token
}

func dragonLevelName(_ level: Int) -> String {
    switch level {
    case 0, 1, 2: return "Dragon egg"
    case 3: return "Shivering egg"
    case 4: return "Hatchling"
    case 5...25:
        let aura = level - 4
        if aura < SaveFile.auraNames.count {
            return "Trained \(SaveFile.auraNames[aura])"
        }
        return "Level \(level)"
    case 26: return "Ready to bake a dragon cookie"
    case 27: return "Fully trained"
    default: return "Level \(level)"
    }
}
