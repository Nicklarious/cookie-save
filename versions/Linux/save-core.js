/* Cookie Save browser core. Same 2.058 import and edit rules as the Mac app. */
(function (root) {
  "use strict";

  const BUILDINGS = [
    "Cursor", "Grandma", "Farm", "Mine", "Factory", "Bank", "Temple",
    "Wizard tower", "Shipment", "Alchemy lab", "Portal", "Time machine",
    "Antimatter condenser", "Prism", "Chancemaker", "Fractal engine",
    "Javascript console", "Idleverse", "Cortex baker", "You"
  ];
  const BUFF_NAMES = [
    "High-five", "Congregation", "Luxuriant harvest", "Ore vein", "Oiled-up",
    "Juicy profits", "Fervent adoration", "Manabloom", "Delicious lifeforms",
    "Breakthrough", "Righteous cataclysm", "Golden ages", "Extra cycles",
    "Solar flare", "Winning streak", "Macrocosm", "Refactoring",
    "Cosmic nursery", "Brainstorm", "Deduplication"
  ];
  const DEBUFF_NAMES = [
    "Slap to the face", "Senility", "Locusts", "Cave-in", "Jammed machinery",
    "Recession", "Crisis of faith", "Magivores", "Black holes", "Lab disaster",
    "Dimensional calamity", "Time jam", "Predictable tragedy", "Eclipse",
    "Dry spell", "Microcosm", "Antipattern", "Big crunch", "Brain freeze",
    "Clone strike"
  ];
  const SANTA = [
    "Festive test tube", "Festive ornament", "Festive wreath", "Festive tree",
    "Festive present", "Festive elf fetus", "Elf toddler", "Elfling",
    "Young elf", "Bulky elf", "Nick", "Santa Claus", "Elder Santa",
    "True Santa", "Final Claus"
  ];
  const AURAS = [
    "No aura", "Breath of Milk", "Dragon Cursor", "Elder Battalion",
    "Reaper of Fields", "Earth Shatterer", "Master of the Armory",
    "Fierce Hoarder", "Dragon God", "Arcane Aura", "Dragonflight",
    "Ancestral Metamorphosis", "Unholy Dominion", "Epoch Manipulator",
    "Mind Over Matter", "Radiant Appetite", "Dragon's Fortune",
    "Dragon's Curve", "Reality Bending", "Dragon Orbs", "Supreme Intellect",
    "Dragon Guts"
  ];
  const SEASONS = [
    { id: "", label: "No season", biscuit: "" },
    { id: "christmas", label: "Christmas", biscuit: "Festive biscuit" },
    { id: "halloween", label: "Halloween", biscuit: "Ghostly biscuit" },
    { id: "valentines", label: "Valentine's", biscuit: "Lovesick biscuit" },
    { id: "fools", label: "Business day", biscuit: "Fool's biscuit" },
    { id: "easter", label: "Easter", biscuit: "Bunny biscuit" }
  ];
  const HEAVENLY = [
    "Heavenly chip secret", "Heavenly cookie stand", "Heavenly bakery",
    "Heavenly confectionery", "Heavenly key"
  ];
  const EFFECTS = [
    { id: 0, title: "Frenzy", seconds: 77, power: 7, needsBuilding: false, note: "Cookie production is multiplied by the power." },
    { id: 1, title: "Elder frenzy", seconds: 6, power: 666, needsBuilding: false, note: "Cookie production is multiplied by the power." },
    { id: 2, title: "Clot", seconds: 66, power: 0.5, needsBuilding: false, note: "Cookie production is multiplied by the power." },
    { id: 3, title: "Dragon Harvest", seconds: 60, power: 15, needsBuilding: false, note: "If this save owns Dragon fang, the game raises the power by 10% and rounds up on import." },
    { id: 4, title: "Everything must go", seconds: 8, power: 5, needsBuilding: false, note: "Buildings are this percent cheaper." },
    { id: 5, title: "Cursed finger", seconds: 10, power: 1, needsBuilding: false, note: "Cookie production stops. Each click gives this many cookies." },
    { id: 6, title: "Click frenzy", seconds: 13, power: 777, needsBuilding: false, note: "Each click is multiplied by the power." },
    { id: 7, title: "Dragonflight", seconds: 10, power: 1111, needsBuilding: false, note: "If this save owns Dragon fang, the game raises the power by 10% and rounds up on import." },
    { id: 8, title: "Cookie storm", seconds: 7, power: 7, needsBuilding: false, note: "Golden cookies fall while this lasts." },
    { id: 9, title: "Building boost", seconds: 30, power: 2, needsBuilding: true, note: "Leave the power blank to use buildings owned, divided by 10, plus 1." },
    { id: 10, title: "Building rust", seconds: 30, power: 2, needsBuilding: true, note: "Cookie production is divided by the power. Blank power uses buildings owned, divided by 10, plus 1." },
    { id: 11, title: "Sugar blessing", seconds: 86400, power: 1, needsBuilding: false, note: "Golden cookies appear 10% more often. That 10% is fixed in the game." },
    { id: 12, title: "Haggler's luck", seconds: 60, power: 2, needsBuilding: false, note: "Upgrades are this percent cheaper." },
    { id: 13, title: "Haggler's misery", seconds: 3600, power: 2, needsBuilding: false, note: "Upgrades are this percent more expensive." },
    { id: 14, title: "Crafty pixies", seconds: 60, power: 2, needsBuilding: false, note: "Buildings are this percent cheaper." },
    { id: 15, title: "Nasty goblins", seconds: 3600, power: 2, needsBuilding: false, note: "Buildings are this percent more expensive." },
    { id: 16, title: "Magic adept", seconds: 300, power: 10, needsBuilding: false, note: "Spells backfire this many times less." },
    { id: 17, title: "Magic inept", seconds: 600, power: 5, needsBuilding: false, note: "Spells backfire this many times more." },
    { id: 18, title: "Devastation", seconds: 10, power: 2, needsBuilding: false, note: "Each click is multiplied by the power." },
    { id: 19, title: "Sugar frenzy", seconds: 3600, power: 3, needsBuilding: false, note: "Cookie production is multiplied by the power." },
    { id: 20, title: "Loan 1", seconds: 7200, power: 1.5, needsBuilding: false, note: "When this ends in the game, Loan 1 (interest) starts." },
    { id: 21, title: "Loan 1 (interest)", seconds: 14400, power: 0.25, needsBuilding: false, note: "Cookie production is multiplied by the power." },
    { id: 22, title: "Loan 2", seconds: 40.2, power: 2, needsBuilding: false, note: "When this ends in the game, Loan 2 (interest) starts. 40.2 seconds is 1206 frames." },
    { id: 23, title: "Loan 2 (interest)", seconds: 2400, power: 0.1, needsBuilding: false, note: "Cookie production is multiplied by the power." },
    { id: 24, title: "Loan 3", seconds: 172800, power: 1.2, needsBuilding: false, note: "When this ends in the game, Loan 3 (interest) starts." },
    { id: 25, title: "Loan 3 (interest)", seconds: 432000, power: 0.8, needsBuilding: false, note: "Cookie production is multiplied by the power." },
    { id: 26, title: "Gifted out", seconds: 3600, power: 1, needsBuilding: false, note: "Gifts stay closed for this long." }
  ];
  const SAFE = new Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789@*_+-./");
  const SESAME = "saysopensesame";
  const SCALES = wordScales();

  function wordScales() {
    const names = ["thousand", "million", "billion", "trillion", "quadrillion", "quintillion", "sextillion", "septillion", "octillion", "nonillion"];
    const prefixes = ["", "un", "duo", "tre", "quattuor", "quin", "sex", "septen", "octo", "novem"];
    const suffixes = ["decillion", "vigintillion", "trigintillion", "quadragintillion", "quinquagintillion", "sexagintillion", "septuagintillion", "octogintillion", "nonagintillion"];
    suffixes.forEach(function (suffix) {
      prefixes.forEach(function (prefix) { names.push(prefix + suffix); });
    });
    const scales = {};
    names.forEach(function (name, index) { scales[name] = (index + 1) * 3; });
    return scales;
  }

  function splitKeep(text, separator) {
    const parts = [];
    let current = "";
    const source = text == null ? "" : String(text);
    for (let i = 0; i < source.length; i += 1) {
      if (source[i] === separator) {
        parts.push(current);
        current = "";
      } else {
        current += source[i];
      }
    }
    parts.push(current);
    return parts;
  }

  function unescape(source) {
    let out = "";
    let i = 0;
    while (i < source.length) {
      if (source[i] === "%") {
        if (source[i + 1] === "u" && i + 5 < source.length && /^[0-9a-fA-F]{4}$/.test(source.slice(i + 2, i + 6))) {
          out += String.fromCharCode(parseInt(source.slice(i + 2, i + 6), 16));
          i += 6;
          continue;
        }
        if (i + 2 < source.length && /^[0-9a-fA-F]{2}$/.test(source.slice(i + 1, i + 3))) {
          out += String.fromCharCode(parseInt(source.slice(i + 1, i + 3), 16));
          i += 3;
          continue;
        }
      }
      out += source[i];
      i += 1;
    }
    return out;
  }

  function escapeSave(source) {
    let out = "";
    for (let i = 0; i < source.length; i += 1) {
      const code = source.charCodeAt(i);
      const ch = source[i];
      if (code < 128 && SAFE.has(ch)) out += ch;
      else if (code < 256) out += "%" + code.toString(16).toUpperCase().padStart(2, "0");
      else out += "%u" + code.toString(16).toUpperCase().padStart(4, "0");
    }
    return out;
  }

  function bytesToB64(bytes) {
    if (typeof Buffer !== "undefined") return Buffer.from(bytes).toString("base64");
    let bin = "";
    bytes.forEach(function (b) { bin += String.fromCharCode(b); });
    return btoa(bin);
  }

  function b64ToBytes(b64) {
    let text = b64.replace(/-/g, "+").replace(/_/g, "/");
    while (text.length % 4) text += "=";
    if (typeof Buffer !== "undefined") return new Uint8Array(Buffer.from(text, "base64"));
    const bin = atob(text);
    const bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i += 1) bytes[i] = bin.charCodeAt(i);
    return bytes;
  }

  function utf8ToB64(text) {
    const bytes = typeof TextEncoder !== "undefined" ? new TextEncoder().encode(text) : new Uint8Array(Buffer.from(text, "utf8"));
    return bytesToB64(bytes);
  }

  function b64ToUtf8(b64) {
    const bytes = b64ToBytes(b64);
    if (typeof TextDecoder !== "undefined") return new TextDecoder("utf-8", { fatal: false }).decode(bytes);
    return Buffer.from(bytes).toString("utf8");
  }

  function parseNumber(token) {
    const trimmed = String(token || "").trim();
    if (!trimmed) return 0;
    const value = Number(trimmed);
    return Number.isFinite(value) ? value : 0;
  }

  function parseUserNumber(raw) {
    let trimmed = String(raw || "").trim().replace(/,/g, "").replace(/_/g, "");
    if (!trimmed) return null;
    const lower = trimmed.toLowerCase();
    if (lower.indexOf("x") !== -1) return scaledWord(lower);
    const direct = Number(lower);
    if (Number.isFinite(direct)) return direct;
    return scaledWord(lower);
  }

  function scaledWord(lower) {
    const parts = lower.split(/\s+/).filter(Boolean);
    let numberText;
    let word;
    if (parts.length === 2) {
      numberText = parts[0];
      word = parts[1];
    } else if (parts.length === 1) {
      const split = splitNumberWord(parts[0]);
      if (!split) return null;
      numberText = split[0];
      word = split[1];
    } else {
      return null;
    }
    let name = word;
    if (SCALES[name] == null && name.endsWith("s")) name = name.slice(0, -1);
    if (SCALES[name] == null) return null;
    return exactScaled(numberText, SCALES[name]);
  }

  function splitNumberWord(text) {
    const match = /^([^a-zA-Z]+)([a-zA-Z]+)$/.exec(text);
    if (!match) return null;
    return [match[1], match[2]];
  }

  function exactScaled(numberText, exponent) {
    if (numberText.indexOf("e") !== -1) {
      const base = Number(numberText);
      if (!Number.isFinite(base)) return null;
      const value = base * Math.pow(10, exponent);
      return Number.isFinite(value) ? value : null;
    }
    let text = numberText;
    let negative = false;
    if (text[0] === "-") {
      negative = true;
      text = text.slice(1);
    } else if (text[0] === "+") {
      text = text.slice(1);
    }
    const pieces = text.split(".");
    if (pieces.length !== 1 && pieces.length !== 2) return null;
    const whole = pieces[0] === "" ? "0" : pieces[0];
    const fraction = pieces.length === 2 ? pieces[1] : "";
    if (!/^\d+$/.test(whole) || (fraction && !/^\d+$/.test(fraction))) return null;
    const digits = whole + fraction;
    const point = whole.length + exponent;
    let rendered;
    if (point <= 0) rendered = "0." + "0".repeat(-point) + digits;
    else if (point >= digits.length) rendered = digits + "0".repeat(point - digits.length);
    else rendered = digits.slice(0, point) + "." + digits.slice(point);
    const body = negative ? "-" + rendered : rendered;
    const value = Number(body);
    return Number.isFinite(value) ? value : null;
  }

  function numberString(value) {
    if (!Number.isFinite(value)) return "0";
    if (value === 0) return "0";
    const negative = value < 0;
    let raw = String(Math.abs(value));
    if (raw.endsWith(".0")) raw = raw.slice(0, -2);
    const body = plainOrScientific(raw);
    return negative ? "-" + body : body;
  }

  function plainOrScientific(raw) {
    const lower = raw.replace("E", "e");
    const marker = lower.indexOf("e");
    if (marker < 0) return lower;
    const mantissa = lower.slice(0, marker);
    let exponentText = lower.slice(marker + 1);
    if (exponentText[0] === "+") exponentText = exponentText.slice(1);
    const exponent = Number(exponentText);
    if (!Number.isFinite(exponent)) return lower;
    if (exponent < -6 || exponent > 20) {
      return mantissa + "e" + (exponent < 0 ? "-" : "+") + String(Math.abs(exponent));
    }
    return expand(mantissa, exponent);
  }

  function expand(mantissa, exponent) {
    let digits = mantissa;
    const negative = digits[0] === "-";
    if (negative) digits = digits.slice(1);
    const pieces = digits.split(".");
    const whole = pieces[0] || "0";
    const fraction = pieces.length > 1 ? pieces[1] : "";
    const all = whole + fraction;
    const point = whole.length + exponent;
    let rendered;
    if (point <= 0) rendered = "0." + "0".repeat(-point) + all;
    else if (point >= all.length) rendered = all + "0".repeat(point - all.length);
    else rendered = all.slice(0, point) + "." + all.slice(point);
    return negative ? "-" + rendered : rendered;
  }

  function effectFind(id) {
    return EFFECTS.find(function (item) { return item.id === id; }) || null;
  }

  function effectFrames(seconds) {
    if (!Number.isFinite(seconds) || seconds < 0 || seconds > 1e12) return null;
    const product = seconds * 30;
    if (!Number.isFinite(product)) return null;
    const nearest = Math.round(product);
    if (Math.abs(product - nearest) < 0.000001) return nearest;
    return product;
  }

  function effectRecord(typeID, maxFrames, frames, args) {
    const pieces = [String(typeID), numberString(maxFrames), numberString(frames)];
    args.forEach(function (arg) { pieces.push(numberString(arg)); });
    const record = pieces.join(",");
    if (/[;|\n ]/.test(record)) return null;
    return record;
  }

  function whole(token) {
    const value = Number(token);
    if (!Number.isFinite(value)) return null;
    return Math.floor(value);
  }

  function jsInt(text) {
    let digits = String(text || "");
    let sign = 1;
    if (digits[0] === "-") {
      sign = -1;
      digits = digits.slice(1);
    } else if (digits[0] === "+") {
      digits = digits.slice(1);
    }
    const match = /^\d+/.exec(digits);
    if (!match) return null;
    return sign * Number(match[0]);
  }

  function safeBlob(blob) {
    return blob.indexOf(",") < 0 && blob.indexOf(";") < 0 && blob.indexOf("|") < 0 && blob.indexOf("\n") < 0 && blob.indexOf("\r") < 0;
  }

  const MINIS = {
    2: {
      title: "Garden", counter: "Seeds", kept: "garden", already: "Seeds are already",
      note: "Off sets the farm level to 0 and keeps the plants. Seeds unlock the first plants. Baker's wheat stays unlocked.",
      empty: 1,
      clamp: function (value) { return Math.min(Math.max(value, 1), 34); },
      freshAmount: function () { return 1; },
      message: function (clamped, requested) {
        if (requested > 34) return "Seeds set to 34. A garden has 34 plants. Baker's wheat stays unlocked.";
        if (requested < 1) return "Seeds set to 1. Baker's wheat stays unlocked.";
        return "Seeds set to " + clamped + ". That unlocks the first " + clamped + " plants. Baker's wheat stays unlocked.";
      },
      read: function (blob) {
        const fields = splitKeep(blob, " ");
        if (fields.length < 3) return null;
        const bits = fields[1];
        if (![...bits].every(function (ch) { return ch === "0" || ch === "1"; })) return null;
        if (!bits) return 1;
        const window = bits.slice(0, 34);
        let count = [...window].filter(function (ch) { return ch === "1"; }).length;
        if (window[0] !== "1") count += 1;
        return Math.max(count, 1);
      },
      replace: function (blob, amount) {
        const fields = splitKeep(blob, " ");
        if (fields.length < 3) return null;
        const bits = fields[1];
        if (bits && ![...bits].every(function (ch) { return ch === "0" || ch === "1"; })) return null;
        fields[1] = seedBits(amount);
        return fields.join(" ");
      },
      fresh: function (amount) {
        const now = Date.now();
        return now + ":0:" + now + ":0:0:0:1:0:" + now + ": " + seedBits(amount) + " " + "0:0:".repeat(36);
      }
    },
    5: {
      title: "Market", counter: "Brokers", kept: "market", already: "Brokers are already",
      note: "Off sets the bank level to 0 and keeps the stocks. Brokers are the helpers stored in the market.",
      empty: 0,
      clamp: function (value) { return Math.min(Math.max(value, 0), 1000000000); },
      freshAmount: function () { return 0; },
      message: function (clamped) { return "Brokers set to " + clamped + "."; },
      read: function (blob) {
        const fields = splitKeep(blob, " ");
        const header = splitKeep(fields[0] || "", ":");
        if (header.length < 5 || whole(header[1]) == null) return null;
        return Math.max(whole(header[1]), 0);
      },
      replace: function (blob, amount) {
        const fields = splitKeep(blob, " ");
        if (!fields.length) return null;
        const header = splitKeep(fields[0], ":");
        if (header.length < 5 || whole(header[1]) == null) return null;
        header[1] = String(amount);
        fields[0] = header.join(":");
        return fields.join(" ");
      },
      fresh: function (amount, level) {
        const bank = Math.max(level, 1);
        const goods = [];
        for (let id = 0; id < 18; id += 1) {
          const dollars = 10 + 10 * id + (bank - 1);
          goods.push((dollars * 100) + ":0:0:100:0:1:0:0");
        }
        return "0:" + amount + ":1:0:0: " + goods.join("!") + "! 1";
      }
    },
    6: {
      title: "Pantheon", counter: "Worship swaps", kept: "pantheon", already: "Worship swaps are already",
      note: "Off sets the temple level to 0 and keeps the spirits. Worship swaps go from 0 to 3.",
      empty: 3,
      clamp: function (value) { return Math.min(Math.max(value, 0), 3); },
      freshAmount: function () { return 3; },
      message: function (clamped, requested) {
        if (requested !== clamped) return "Worship swaps set to " + clamped + ". The temple holds up to 3.";
        return "Worship swaps set to " + clamped + ".";
      },
      read: function (blob) {
        const fields = splitKeep(blob, " ");
        if (fields.length < 4 || splitKeep(fields[0], "/").length !== 3 || whole(fields[1]) == null) return null;
        return Math.max(whole(fields[1]), 0);
      },
      replace: function (blob, amount) {
        const fields = splitKeep(blob, " ");
        if (fields.length < 4 || splitKeep(fields[0], "/").length !== 3 || whole(fields[1]) == null) return null;
        fields[1] = String(amount);
        return fields.join(" ");
      },
      fresh: function (amount) { return "-1/-1/-1 " + amount + " " + Date.now() + " 1"; }
    },
    7: {
      title: "Grimoire", counter: "Magic", kept: "grimoire", already: "Magic is already",
      note: "Off sets the wizard tower level to 0 and keeps the spells. Magic fills up to this tower's bar.",
      empty: 0,
      clamp: function (value, cap) { return Math.min(Math.max(value, 0), Math.max(cap, 0)); },
      freshAmount: function (cap) { return Math.max(cap, 0); },
      message: function (clamped, requested) {
        if (requested !== clamped) return "Magic set to " + clamped + ". That is this tower's full bar.";
        return "Magic set to " + clamped + ".";
      },
      read: function (blob) {
        const fields = splitKeep(blob, " ");
        if (fields.length < 4 || whole(fields[0]) == null) return null;
        return Math.max(whole(fields[0]), 0);
      },
      replace: function (blob, amount) {
        const fields = splitKeep(blob, " ");
        if (fields.length < 4 || whole(fields[0]) == null) return null;
        fields[0] = String(amount);
        return fields.join(" ");
      },
      fresh: function (amount) { return amount + " 0 0 1"; }
    }
  };

  function seedBits(count) {
    const unlocked = Math.min(Math.max(count, 1), 34);
    return "1".repeat(unlocked) + "0".repeat(34 - unlocked);
  }

  function BakerySave(catalog, sections) {
    this.catalog = catalog;
    this.original = sections.slice();
    this.run = splitKeep(sections[2] || "", ";");
    this.misc = splitKeep(sections.length > 4 ? sections[4] : "", ";");
    this.buildings = splitKeep(sections.length > 5 ? sections[5] : "", ";");
    this.upgrades = sections.length > 6 ? sections[6] : "";
    this.achievements = sections.length > 7 ? sections[7] : "";
    this.buffs = sections.length > 8 ? sections[8] : "";
    this.runDirty = false;
    this.miscDirty = false;
    this.buildingsDirty = false;
    this.upgradesDirty = false;
    this.achievementsDirty = false;
    this.buffsDirty = false;
    this.upgradeByName = {};
    (catalog.upgrades || []).forEach(function (item) {
      if (this.upgradeByName[item.name] == null) this.upgradeByName[item.name] = item;
    }, this);
  }

  BakerySave.load = function (pasted, catalog) {
    const compact = String(pasted || "").replace(/[ \t\r\n\f\v]+/g, "");
    if (!compact) throw new Error("Paste a Cookie Clicker export first.");
    const unescaped = unescape(compact);
    const end = unescaped.indexOf("!END!");
    const body = end >= 0 ? unescaped.slice(0, end) : unescaped;
    let plain = "";
    try { plain = b64ToUtf8(body); } catch (error) { plain = ""; }
    if (!plain) throw new Error("That text is not a Cookie Clicker export.");
    const sections = splitKeep(plain, "|");
    if (sections.length < 5) throw new Error("That export is too short to be a Cookie Clicker save.");
    return new BakerySave(catalog, sections);
  };

  BakerySave.prototype.hasEdits = function () {
    return this.runDirty || this.miscDirty || this.buildingsDirty || this.upgradesDirty || this.achievementsDirty || this.buffsDirty;
  };

  BakerySave.prototype.token = function (list, index) {
    return index < list.length ? list[index] : "";
  };

  BakerySave.prototype.intToken = function (token) {
    if (/^-?\d+$/.test(token)) return Number(token);
    return Math.round(parseNumber(token));
  };

  BakerySave.prototype.version = function () { return this.original[0] || ""; };
  BakerySave.prototype.bakeryName = function () { return this.token(this.run, 3); };
  BakerySave.prototype.cookies = function () { return this.token(this.misc, 0); };
  BakerySave.prototype.chips = function () { return this.token(this.misc, 26); };
  BakerySave.prototype.lumps = function () { return this.token(this.misc, 42); };
  BakerySave.prototype.santa = function () { return this.intToken(this.token(this.misc, 18)); };
  BakerySave.prototype.dragonLevel = function () { return this.intToken(this.token(this.misc, 35)); };
  BakerySave.prototype.dragonAura = function (slot) { return this.intToken(this.token(this.misc, slot === 1 ? 37 : 36)); };
  BakerySave.prototype.season = function () { return this.token(this.misc, 22); };

  BakerySave.prototype.plain = function () {
    const parts = this.original.slice();
    const pad = function (index) { while (parts.length <= index) parts.push(""); };
    if (this.runDirty) { pad(2); parts[2] = this.run.join(";"); }
    if (this.miscDirty) { pad(4); parts[4] = this.misc.join(";"); }
    if (this.buildingsDirty) { pad(5); parts[5] = this.buildings.join(";"); }
    if (this.upgradesDirty) { pad(6); parts[6] = this.upgrades; }
    if (this.achievementsDirty) { pad(7); parts[7] = this.achievements; }
    if (this.buffsDirty) { pad(8); parts[8] = this.buffs; }
    return parts.join("|");
  };

  BakerySave.prototype.export = function () {
    return escapeSave(utf8ToB64(this.plain()) + "!END!");
  };

  BakerySave.prototype.ensureMisc = function (index) {
    const trail = this.misc.length > 0 && this.misc[this.misc.length - 1] === "";
    if (trail) this.misc.pop();
    while (this.misc.length <= index) this.misc.push("0");
    if (trail) this.misc.push("");
  };

  BakerySave.prototype.setMiscNumber = function (index, value) {
    this.ensureMisc(index);
    const current = this.misc[index];
    if (current && parseNumber(current) === value) return;
    const next = numberString(value);
    if (next === current) return;
    this.misc[index] = next;
    this.miscDirty = true;
  };

  BakerySave.prototype.setMiscText = function (index, value) {
    this.ensureMisc(index);
    if (this.misc[index] === value) return;
    this.misc[index] = value;
    this.miscDirty = true;
  };

  BakerySave.prototype.ensureBuilding = function (index) {
    const trail = this.buildings.length > 0 && this.buildings[this.buildings.length - 1] === "";
    if (trail) this.buildings.pop();
    while (this.buildings.length <= index) this.buildings.push("0,0,0,0,,0,0");
    if (trail) this.buildings.push("");
  };

  BakerySave.prototype.buildingParts = function (index) {
    return splitKeep(this.token(this.buildings, index), ",");
  };

  BakerySave.prototype.buildingAmount = function (index) {
    return this.intToken(this.buildingParts(index)[0] || "0");
  };

  BakerySave.prototype.buildingLevel = function (index) {
    const parts = this.buildingParts(index);
    return parts.length > 3 ? this.intToken(parts[3]) : 0;
  };

  BakerySave.prototype.buildingMinigame = function (index) {
    const parts = this.buildingParts(index);
    return parts.length > 4 ? parts[4] : "";
  };

  BakerySave.prototype.buildingHighest = function (index) {
    const parts = this.buildingParts(index);
    if (parts.length > 6) return this.intToken(parts[6]);
    return this.intToken(parts[0] || "0");
  };

  BakerySave.prototype.setBuilding = function (index, amount, level) {
    if (index < 0 || index >= BUILDINGS.length) return;
    this.ensureBuilding(index);
    const parts = splitKeep(this.buildings[index], ",");
    while (parts.length < 7) parts.push(parts.length === 4 ? "" : "0");
    if (amount != null) {
      const count = Math.min(Math.max(amount, 0), 1000000000);
      const bought = Math.max(this.intToken(parts[1]), count);
      const highest = Math.max(this.intToken(parts[6]), count);
      parts[0] = String(count);
      parts[1] = String(bought);
      parts[6] = String(highest);
    }
    if (level != null) parts[3] = String(Math.min(Math.max(level, 0), 10000));
    const next = parts.join(",");
    if (next === this.buildings[index]) return;
    this.buildings[index] = next;
    this.buildingsDirty = true;
  };

  BakerySave.prototype.grimoireCap = function () {
    const towers = Math.max(this.buildingAmount(7), 1);
    const level = Math.max(this.buildingLevel(7), 1);
    const value = 4 + Math.pow(towers, 0.6) + Math.log((towers + (level - 1) * 10) / 15 + 1) * 15;
    if (!Number.isFinite(value)) return 0;
    return Math.max(Math.floor(value), 0);
  };

  BakerySave.prototype.storeMinigame = function (index, blob) {
    if (!safeBlob(blob)) return false;
    this.ensureBuilding(index);
    const parts = splitKeep(this.buildings[index], ",");
    while (parts.length < 7) parts.push(parts.length === 4 ? "" : "0");
    parts[4] = blob;
    const next = parts.join(",");
    if (next === this.buildings[index]) return true;
    this.buildings[index] = next;
    this.buildingsDirty = true;
    return true;
  };

  BakerySave.prototype.minigameAmount = function (index) {
    const kind = MINIS[index];
    if (!kind) return null;
    const blob = this.buildingMinigame(index).trim();
    if (!blob) return null;
    return kind.read(blob);
  };

  BakerySave.prototype.setMinigameEnabled = function (index, on) {
    const kind = MINIS[index];
    if (!kind) return { changed: false, message: "This building has no minigame." };
    const building = BUILDINGS[index];
    const level = this.buildingLevel(index);
    const blob = this.buildingMinigame(index).trim();
    if (on) {
      if (level > 0 && blob) return { changed: false, message: kind.title + " is already on." };
      let wroteFresh = false;
      if (!blob) {
        const amount = kind.freshAmount(this.grimoireCap());
        const fresh = kind.fresh(amount, level);
        if (!this.storeMinigame(index, fresh)) return { changed: false, message: "Could not write a " + kind.title.toLowerCase() + " save." };
        wroteFresh = true;
      }
      if (this.buildingLevel(index) === 0) this.setBuilding(index, null, 1);
      const levelNow = this.buildingLevel(index);
      if (wroteFresh) return { changed: true, message: kind.title + " is on. " + building + " level is " + levelNow + ". A fresh " + kind.kept + " save was written." };
      return { changed: true, message: kind.title + " is on. " + building + " level is " + levelNow + ". The saved " + kind.kept + " stays. Turning it off and on again comes back at level 1." };
    }
    if (level === 0) return { changed: false, message: kind.title + " is already off. The saved " + kind.kept + " stays." };
    this.setBuilding(index, null, 0);
    if (level > 1) return { changed: true, message: kind.title + " is off. " + building + " level is 0. It was level " + level + ". Turning it on sets the level to 1." };
    return { changed: true, message: kind.title + " is off. " + building + " level is 0. Turning it on sets the level to 1." };
  };

  BakerySave.prototype.setMinigameAmount = function (index, value) {
    const kind = MINIS[index];
    if (!kind) return { changed: false, message: "This building has no minigame." };
    const cap = this.grimoireCap();
    const clamped = kind.clamp(value, cap);
    const existing = this.buildingMinigame(index).trim();
    let nextBlob;
    if (!existing) nextBlob = kind.fresh(clamped, this.buildingLevel(index));
    else {
      const replaced = kind.replace(existing, clamped);
      if (replaced == null) return { changed: false, message: "The " + kind.title.toLowerCase() + " save couldn't be read, so " + kind.counter.toLowerCase() + " stayed as it is." };
      nextBlob = replaced;
    }
    if (!safeBlob(nextBlob)) return { changed: false, message: "That " + kind.counter.toLowerCase() + " value can't be stored." };
    const before = this.token(this.buildings, index);
    if (!this.storeMinigame(index, nextBlob)) return { changed: false, message: "That " + kind.counter.toLowerCase() + " value can't be stored." };
    if (this.token(this.buildings, index) === before) return { changed: false, message: kind.already + " " + clamped + "." };
    return { changed: true, message: kind.message(clamped, value) };
  };

  BakerySave.prototype.bit = function (text, index) {
    return index >= 0 && index < text.length && text[index] === "1";
  };

  BakerySave.prototype.upgradeOwned = function (id) { return this.bit(this.upgrades, id * 2 + 1); };
  BakerySave.prototype.achievementWon = function (id) { return this.bit(this.achievements, id); };
  BakerySave.prototype.ownsUpgrade = function (name) {
    const item = this.upgradeByName[name];
    return item ? this.upgradeOwned(item.id) : false;
  };

  BakerySave.prototype.setBits = function (text, pairs) {
    let next = text;
    let limit = 0;
    pairs.forEach(function (pair) { limit = Math.max(limit, pair[0] + 1); });
    if (next.length < limit) next += "0".repeat(limit - next.length);
    const chars = next.split("");
    const before = next;
    pairs.forEach(function (pair) { chars[pair[0]] = pair[1]; });
    next = chars.join("");
    return next === before ? null : next;
  };

  BakerySave.prototype.setUpgrade = function (id, owned) {
    if (id < 0) return;
    const bit = owned ? "1" : "0";
    const next = this.setBits(this.upgrades, [[id * 2, bit], [id * 2 + 1, bit]]);
    if (next == null) return;
    this.upgrades = next;
    this.upgradesDirty = true;
  };

  BakerySave.prototype.setUpgradeNamed = function (name, owned) {
    const item = this.upgradeByName[name];
    if (item) this.setUpgrade(item.id, owned);
  };

  BakerySave.prototype.setUpgradeBought = function (name, bought) {
    const item = this.upgradeByName[name];
    if (!item) return;
    const unlocked = this.bit(this.upgrades, item.id * 2) ? "1" : "0";
    const next = this.setBits(this.upgrades, [[item.id * 2, unlocked], [item.id * 2 + 1, bought ? "1" : "0"]]);
    if (next == null) return;
    this.upgrades = next;
    this.upgradesDirty = true;
  };

  BakerySave.prototype.buyUpgrades = function (include) {
    (this.catalog.upgrades || []).forEach(function (item) {
      if (include(item)) this.setUpgrade(item.id, true);
    }, this);
  };

  BakerySave.prototype.setAchievement = function (id, won) {
    if (id < 0) return;
    const next = this.setBits(this.achievements, [[id, won ? "1" : "0"]]);
    if (next == null) return;
    this.achievements = next;
    this.achievementsDirty = true;
  };

  BakerySave.prototype.awardAll = function () {
    (this.catalog.achievements || []).forEach(function (item) {
      if (item.name !== "Cheated cookies taste awful") this.setAchievement(item.id, true);
    }, this);
  };

  BakerySave.prototype.cookiesForPrestige = function (need) {
    const goal = Math.max(Math.ceil(need), 1);
    let cookies = Math.pow(goal, 3) * 1e12;
    let step = 0;
    while (Number.isFinite(cookies) && Math.floor(Math.pow(cookies / 1e12, 1 / 3)) < need && step < 20) {
      cookies *= 1.0000000000001;
      step += 1;
    }
    return Number.isFinite(cookies) ? cookies : 1e300;
  };

  BakerySave.prototype.raiseReset = function (chips, spent) {
    const need = chips + spent;
    if (need <= 0) return;
    const current = parseNumber(this.token(this.misc, 8));
    if (Math.floor(Math.pow(current / 1e12, 1 / 3)) >= need) return;
    this.setMiscNumber(8, this.cookiesForPrestige(need));
  };

  BakerySave.prototype.setCookies = function (value) {
    const amount = Math.min(Math.max(value, 0), 1e300);
    const earned = parseNumber(this.token(this.misc, 1));
    this.setMiscNumber(0, amount);
    if (amount > earned) this.setMiscNumber(1, amount);
  };

  BakerySave.prototype.setHeavenlyChips = function (value) {
    const chips = Math.min(Math.max(value, 0), 1e15);
    this.setMiscNumber(26, chips);
    this.raiseReset(chips, parseNumber(this.token(this.misc, 27)));
  };

  BakerySave.prototype.setLumps = function (value) {
    const count = Math.min(Math.max(Math.floor(value), 0), 1e15);
    const total = parseNumber(this.token(this.misc, 43));
    this.setMiscNumber(42, count);
    if (total < count) this.setMiscNumber(43, count);
  };

  BakerySave.prototype.setSanta = function (level) {
    const clamped = Math.min(Math.max(level, 0), SANTA.length - 1);
    this.setMiscNumber(18, clamped);
    if (clamped > 0) this.setUpgradeNamed("A festive hat", true);
  };

  BakerySave.prototype.setDragonLevel = function (level) {
    const clamped = Math.min(Math.max(level, 0), 27);
    this.setMiscNumber(35, clamped);
    if (clamped > 0) this.setUpgradeNamed("A crumbly egg", true);
    if (clamped < 27 && this.dragonAura(1) !== 0) this.setMiscNumber(37, 0);
  };

  BakerySave.prototype.setDragonAura = function (slot, id) {
    const aura = Math.min(Math.max(id, 0), AURAS.length - 1);
    this.setMiscNumber(slot === 1 ? 37 : 36, aura);
    if (aura <= 0) return;
    this.setUpgradeNamed("A crumbly egg", true);
    const minimum = slot === 1 ? 27 : aura + 4;
    if (this.dragonLevel() < minimum) this.setMiscNumber(35, minimum);
  };

  BakerySave.prototype.setSeason = function (id) {
    const known = SEASONS.some(function (item) { return item.id === id; });
    const season = known ? id : "";
    this.setMiscText(22, season);
    if (!season) this.setMiscNumber(20, -1);
    else {
      this.setMiscNumber(20, 946080000);
      this.setUpgradeNamed("Season switcher", true);
    }
    SEASONS.forEach(function (option) {
      if (!option.biscuit) return;
      if (option.id === season) this.setUpgradeNamed(option.biscuit, true);
      else this.setUpgradeBought(option.biscuit, false);
    }, this);
  };

  BakerySave.prototype.setBakeryName = function (name) {
    const trimmed = String(name || "").trim();
    if (!trimmed) return "The bakery needs a name.";
    if (trimmed.indexOf(";") >= 0 || trimmed.indexOf("|") >= 0 || trimmed.indexOf("\n") >= 0) return "A bakery name can't include ; or |.";
    while (this.run.length <= 3) this.run.push("");
    if (this.run[3] === trimmed) return "";
    this.run[3] = trimmed;
    this.runDirty = true;
    return "";
  };

  BakerySave.cheatsName = function (current, enabled) {
    let base = String(current || "").trim();
    if (base.toLowerCase().endsWith(SESAME)) base = base.slice(0, -SESAME.length).trim();
    if (!enabled) return base || "Bakery";
    const room = 28 - SESAME.length - 1;
    if (base.length > room) base = base.slice(0, room).trim();
    if (!base) base = "A";
    return base + " " + SESAME;
  };

  BakerySave.cheatsOpen = function (name) {
    const lower = String(name || "").toLowerCase();
    return lower.length > SESAME.length && lower.endsWith(SESAME);
  };

  BakerySave.prototype.buffTokens = function () {
    if (!this.buffs) return [];
    const tokens = splitKeep(this.buffs, ";");
    if (tokens.length && tokens[tokens.length - 1] === "") tokens.pop();
    return tokens;
  };

  BakerySave.prototype.writeBuffs = function (tokens) {
    const body = tokens.filter(function (token) { return token !== ""; });
    const next = body.length ? body.join(";") + ";" : "";
    if (next === this.buffs) return false;
    this.buffs = next;
    this.buffsDirty = true;
    return true;
  };

  function parseEffect(slot, raw) {
    const fields = splitKeep(raw, ",");
    const typeID = Number(fields[0]);
    const maxFrames = Number(fields[1]);
    const frames = Number(fields[2]);
    const kind = effectFind(typeID);
    if (fields.length < 3 || !kind || !Number.isFinite(maxFrames) || !Number.isFinite(frames)) {
      return { slot: slot, raw: raw, typeID: null, maxFrames: null, frames: null, args: [] };
    }
    const args = [];
    for (let i = 3; i < fields.length; i += 1) {
      const value = Number(fields[i]);
      if (!Number.isFinite(value)) return { slot: slot, raw: raw, typeID: null, maxFrames: null, frames: null, args: [] };
      args.push(value);
    }
    return { slot: slot, raw: raw, typeID: typeID, maxFrames: maxFrames, frames: frames, args: args };
  }

  function effectBuilding(effect) {
    const kind = effectFind(effect.typeID);
    if (!kind || !kind.needsBuilding || effect.args.length < 2) return null;
    const index = Math.round(effect.args[1]);
    if (Math.abs(effect.args[1] - index) >= 0.000001 || index < 0 || index >= BUILDINGS.length) return null;
    return index;
  }

  function effectTitle(typeID, building) {
    const kind = effectFind(typeID);
    if (!kind) return "Unrecognized effect";
    if (kind.needsBuilding && building != null && building >= 0 && building < BUILDINGS.length) {
      const names = typeID === 9 ? BUFF_NAMES : DEBUFF_NAMES;
      if (names[building]) return names[building];
    }
    return kind.title;
  }

  function sameEffect(effect, typeID, building) {
    if (effect.typeID !== typeID || !effectFind(typeID)) return false;
    if (effectFind(typeID).needsBuilding) return effectBuilding(effect) === building;
    return true;
  }

  BakerySave.prototype.savedEffects = function () {
    return this.buffTokens().map(function (raw, slot) {
      return raw === "" ? null : parseEffect(slot, raw);
    }).filter(Boolean);
  };

  BakerySave.prototype.addEffect = function (typeID, seconds, power, building) {
    const kind = effectFind(typeID);
    if (!kind) return { changed: false, message: "That effect is not one the game can load." };
    const frames = effectFrames(seconds);
    if (frames == null) return { changed: false, message: "Enter a time in seconds, like 77." };
    if (!Number.isFinite(power)) return { changed: false, message: "Enter a power, like 7." };
    let chosen = null;
    if (kind.needsBuilding) {
      if (building == null || building < 0 || building >= BUILDINGS.length) return { changed: false, message: "Pick a building for this effect." };
      chosen = building;
    }
    const args = [power];
    if (chosen != null) args.push(chosen);
    const rendered = effectRecord(typeID, frames, frames, args);
    if (!rendered) return { changed: false, message: "That number cannot be stored." };
    const kept = [];
    let wrote = false;
    this.buffTokens().forEach(function (token) {
      if (!token) return;
      if (sameEffect(parseEffect(0, token), typeID, chosen)) {
        if (!wrote) {
          kept.push(rendered);
          wrote = true;
        }
      } else kept.push(token);
    });
    if (!wrote) kept.push(rendered);
    const name = effectTitle(typeID, chosen);
    if (!this.writeBuffs(kept)) return { changed: false, message: name + " is already set that way." };
    return { changed: true, message: name + " is on for " + (frames / 30) + " seconds at power " + power + "." };
  };

  BakerySave.prototype.updateEffect = function (slot, seconds, power, building) {
    const tokens = this.buffTokens();
    if (slot < 0 || slot >= tokens.length || !tokens[slot]) return { changed: false, message: "That effect is no longer in this save." };
    const current = parseEffect(slot, tokens[slot]);
    if (current.typeID == null) return { changed: false, message: "That effect could not be read. Remove it if you want it gone." };
    const kind = effectFind(current.typeID);
    let frames = current.frames;
    let maxFrames = current.maxFrames;
    if (seconds != null) {
      const next = effectFrames(seconds);
      if (next == null) return { changed: false, message: "Enter a time in seconds, like 77." };
      frames = next;
      maxFrames = next;
    }
    const args = current.args.slice();
    if (power != null) {
      if (!Number.isFinite(power)) return { changed: false, message: "Enter a power, like 7." };
      if (!args.length) args.push(power);
      else args[0] = power;
    }
    if (kind.needsBuilding) {
      const chosen = building != null ? building : effectBuilding(current);
      if (chosen == null || chosen < 0 || chosen >= BUILDINGS.length) return { changed: false, message: "Pick a building for this effect." };
      const clash = tokens.some(function (raw, offset) {
        return offset !== slot && raw && sameEffect(parseEffect(offset, raw), current.typeID, chosen);
      });
      if (clash) return { changed: false, message: effectTitle(current.typeID, chosen) + " is already in this save." };
      if (!args.length) args.push(kind.power, chosen);
      else if (args.length === 1) args.push(chosen);
      else args[1] = chosen;
    }
    const rendered = effectRecord(current.typeID, maxFrames, frames, args);
    if (!rendered) return { changed: false, message: "That number cannot be stored." };
    if (tokens[slot] === rendered) return { changed: false, message: effectTitle(current.typeID, effectBuilding(current)) + " is already set that way." };
    tokens[slot] = rendered;
    this.writeBuffs(tokens);
    const shown = kind.needsBuilding ? (building != null ? building : effectBuilding(current)) : null;
    return { changed: true, message: effectTitle(current.typeID, shown) + " is on for " + (frames / 30) + " seconds at power " + (args[0] != null ? args[0] : kind.power) + "." };
  };

  BakerySave.prototype.removeEffect = function (slot) {
    const tokens = this.buffTokens();
    if (slot < 0 || slot >= tokens.length || !tokens[slot]) return { changed: false, message: "That effect is already gone." };
    const current = parseEffect(slot, tokens[slot]);
    const name = current.typeID == null ? "Unrecognized effect" : effectTitle(current.typeID, effectBuilding(current));
    tokens.splice(slot, 1);
    this.writeBuffs(tokens);
    return { changed: true, message: "Removed " + name + "." };
  };

  const GOODS = [
    ["Cereals", "CRL"], ["Chocolate", "CHC"], ["Butter", "BTR"], ["Sugar", "SUG"],
    ["Nuts", "NUT"], ["Salt", "SLT"], ["Vanilla", "VNL"], ["Eggs", "EGG"],
    ["Cinnamon", "CNM"], ["Cream", "CRM"], ["Jam", "JAM"], ["White chocolate", "WCH"],
    ["Honey", "HNY"], ["Cookies", "CKI"], ["Recipes", "RCP"], ["Subsidiaries", "SBD"],
    ["Publicists", "PBL"], ["You", "YOU"]
  ];
  const OFFICES = ["Credit garage", "Tiny bank", "Loaning company", "Finance headquarters", "International exchange", "Palace of Greed"];

  function outlook(mode, value, resting) {
    if (mode === 1) return { id: 0, label: "May go up", rise: true };
    if (mode === 3) return { id: 1, label: "May go up fast", rise: true };
    if (mode === 0) return { id: value < resting * 0.9 ? 2 : 3, label: value < resting * 0.9 ? "Cheap and quiet" : "Quiet", rise: false };
    if (mode === 5) return { id: 4, label: "Chaotic", rise: false };
    if (mode === 2) return { id: 5, label: "May go down", rise: false, fall: true };
    if (mode === 4) return { id: 6, label: "May go down fast", rise: false, fall: true };
    return { id: 7, label: "Unknown", rise: false };
  }

  BakerySave.prototype.stockBoard = function () {
    const raw = this.buildingMinigame(5).trim();
    if (!raw) return null;
    const pieces = splitKeep(raw, " ");
    const header = splitKeep(pieces[0] || "", ":");
    const office = jsInt(header[0] || "");
    const brokers = jsInt(header[1] || "");
    if (office == null || brokers == null) return null;
    const bankLevel = this.buildingLevel(5);
    const rows = splitKeep(pieces[1] || "", "!");
    const quotes = [];
    let inactive = 0;
    rows.forEach(function (row, index) {
      if (!row || index >= GOODS.length) return;
      const fields = splitKeep(row, ":");
      if (fields.length < 5) return;
      const valueCents = jsInt(fields[0]);
      const mode = jsInt(fields[1]);
      const minutes = jsInt(fields[3]);
      const owned = jsInt(fields[4]);
      if (valueCents == null || mode == null || minutes == null || owned == null) return;
      if (this.buildingHighest(index + 2) <= 0) {
        inactive += 1;
        return;
      }
      const value = valueCents / 100;
      const resting = 10 + 10 * index + (bankLevel - 1);
      const name = index === GOODS.length - 1 && this.bakeryName().trim() ? this.bakeryName().trim() : GOODS[index][0];
      quotes.push({
        id: index, name: name, symbol: GOODS[index][1], value: value, resting: resting,
        minutes: minutes, owned: Math.max(owned, 0), outlook: outlook(mode, value, resting)
      });
    }, this);
    quotes.sort(function (a, b) {
      if (a.outlook.id !== b.outlook.id) return a.outlook.id - b.outlook.id;
      return (b.resting - b.value) - (a.resting - a.value);
    });
    const officeLevel = Math.min(Math.max(office, 0), OFFICES.length - 1);
    return { office: OFFICES[officeLevel], brokers: Math.max(brokers, 0), bankLevel: bankLevel, quotes: quotes, inactive: inactive };
  };

  root.CookieSaveCore = {
    BUILDINGS: BUILDINGS,
    BUFF_NAMES: BUFF_NAMES,
    DEBUFF_NAMES: DEBUFF_NAMES,
    SANTA: SANTA,
    AURAS: AURAS,
    SEASONS: SEASONS,
    HEAVENLY: HEAVENLY,
    EFFECTS: EFFECTS,
    MINIS: MINIS,
    BakerySave: BakerySave,
    parseUserNumber: parseUserNumber,
    numberString: numberString,
    effectFrames: effectFrames,
    effectBuilding: effectBuilding,
    effectTitle: effectTitle
  };
})(typeof window !== "undefined" ? window : globalThis);
