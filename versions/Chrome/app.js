/* Cookie Save browser editor. Calls CookieSaveCore. Same 2.058 rules as the Mac app. */
(function () {
  "use strict";

  const C = window.CookieSaveCore;
  const catalog = window.CATALOG || { upgrades: [], achievements: [] };
  const PAGES = [
    ["save", "Save"],
    ["cookies", "Cookies"],
    ["buildings", "Buildings"],
    ["upgrades", "Upgrades"],
    ["achievements", "Achievements"],
    ["heaven", "Heaven"],
    ["specials", "Specials"],
    ["cheats", "Cheats"],
    ["effects", "Effects"],
    ["market", "Market"],
    ["how", "How This Works"]
  ];
  const COOKIE_PRESETS = [
    ["1 million", 1e6], ["1 billion", 1e9], ["1 trillion", 1e12],
    ["1 quadrillion", 1e15], ["1 quintillion", 1e18], ["1 sextillion", 1e21],
    ["1 septillion", 1e24], ["1 octillion", 1e27], ["1 nonillion", 1e30],
    ["1 decillion", 1e33]
  ];
  const CHIP_PRESETS = [
    ["100", 100], ["1 thousand", 1000], ["10 thousand", 10000],
    ["100 thousand", 100000], ["1 million", 1000000], ["10 million", 10000000],
    ["100 million", 100000000], ["1 billion", 1000000000]
  ];
  const LUMP_PRESETS = [["1", 1], ["7", 7], ["100", 100], ["365", 365], ["1,000", 1000]];
  const MINI_UI = {
    2: { title: "Garden", counter: "Seeds", note: "Off sets the farm level to 0 and keeps the plants. Seeds unlock the first plants. Baker's wheat stays unlocked." },
    5: { title: "Market", counter: "Brokers", note: "Off sets the bank level to 0 and keeps the stocks. Brokers are the helpers stored in the market." },
    6: { title: "Pantheon", counter: "Worship swaps", note: "Off sets the temple level to 0 and keeps the spirits. Worship swaps go from 0 to 3." },
    7: { title: "Grimoire", counter: "Magic", note: "Off sets the wizard tower level to 0 and keeps the spells. Magic fills up to this tower's bar." }
  };
  const UPGRADE_POOLS = [
    ["all", "All"], ["regular", "Regular"], ["cookie", "Cookies"],
    ["prestige", "Heavenly"], ["toggle", "Toggles"], ["tech", "Tech"], ["debug", "Debug"]
  ];
  const ACHIEVE_POOLS = [
    ["all", "All"], ["normal", "Normal"], ["shadow", "Shadow"], ["dungeon", "Dungeon"]
  ];
  const HOW = [
    ["The pasted text", "A Cookie Clicker export is the save wrapped so a text box can hold it. There is no checksum. Cookie Save unwraps it with the same four steps the game uses on Import, then splits the plain text on vertical bars.", ""],
    ["1. Blank space comes off", "Spaces, tabs, and line breaks are removed first. A save copied across several lines is the same save.", ""],
    ["2. Percent codes become characters", "This is JavaScript unescape. %21 is an exclamation mark. %3D is an equals sign. %25 is a percent sign. %XX is one byte. %uXXXX is one Unicode character. A 2.058 export ends in %21END%21, which is the marker !END!.", "%21END%21   →   !END!"],
    ["3. The marker is cut off", "The importer keeps the text before the first !END!. What remains is base64.", ""],
    ["4. Base64 becomes the save", "Those letters decode to UTF-8 text. The game writes the plain save, encodes that text as base64, adds !END!, then escapes the result. Import runs those steps backwards.", "escape( base64(plain text) + \"!END!\" )"],
    ["Where 2.058 starts", "Every 2.058 export begins with the eight letters Mi4wNTh8. Those letters are the text 2.058 and a vertical bar. The bar opens the section list. The letters after that are the rest of the save, and the export ends with %21END%21. A string in that shape is read by this same path.", "Mi4wNTh8   →   2.058|"],
    ["The sections", "The plain text is split on | and empty sections stay. Fewer than 5 sections is rejected. Section 0 is the version, 2.058. Section 1 is left empty. Section 2 is the run, separated by semicolons: start time, legacy start, last time the game was opened, bakery name, seed, and appearance. Those times are milliseconds. Section 3 is the settings. In 2.058 each setting is the character 1 or 0, in order. Section 4 is the bank and the other numbers, separated by semicolons. Field 0 is cookies in the bank. Field 1 is cookies earned. Field 8 is cookies forfeited. Field 14 is ascensions. Field 18 is Santa's level. Field 20 is season time left, in frames. Field 22 is the season name. Field 26 is unspent heavenly chips. Field 27 is heavenly chips spent. Field 35 is the dragon level. Fields 36 and 37 are the dragon auras. Field 42 is sugar lumps on hand. Field 43 is sugar lumps ever made. Section 5 is the buildings. Section 6 is the upgrades. Section 7 is the achievements. Section 8 is the timed effects. Section 9 is mod data, and Cookie Save leaves that section as it was.", ""],
    ["Buildings", "One building per semicolon, from Cursor through You. Amount edits keep the minigame text. A minigame is open when the level is at least 1. Turning it off sets the level to 0 and keeps the minigame text. Turning it back on from 0 sets the level to 1. Seeds, brokers, worship swaps, and magic live inside that minigame text.", "amount,bought,cookies produced,level,minigame,muted,highest"],
    ["Upgrades and achievements", "Upgrades are two characters each, in catalog order. The first character is unlocked and the second is bought. 1 means yes and 0 means no. Achievements are one character each. 1 means won. Upgrade number 3 uses characters 6 and 7, because the pairs start at character 0.", "characters at 2 × id and 2 × id + 1"],
    ["Effects", "Each saved effect is the type, the full length, the time left, then any extra numbers. Records are separated by semicolons. The game runs at 30 frames a second, so the stored time is the seconds times 30. When that product is within a millionth of a whole frame, it is stored as that whole frame. 40.2 seconds is 1206 frames. Setting the time writes the full length and the time left to the same frame count. The power is the first extra number. A building boost or building rust stores the building number after the power, from 0 for Cursor through 19 for You. Only the 27 effects the game can load are added. Two records with the same display name become one.", "frames = seconds × 30"],
    ["Heavenly chips", "Setting heavenly chips writes field 26. On import the game ignores the stored prestige number and computes prestige from cookies forfeited. If the chips need more prestige than the forfeited cookies would give, Cookie Save raises field 8 until the formula reaches those chips.", "prestige = floor( (forfeited / 1000000000000) ^ (1/3) )"],
    ["Amount words", "A number field accepts 1000, 1e12, or 5.3 million. The word is a long scale name the game shows, and the decimal point moves by 3 places for each step. 5.3 million is 5300000. A trailing s is accepted, and so is sextillion.", ""],
    ["Copy save", "Copy save joins the sections with | again. Sections you did not change stay as they were. The text is encoded as UTF-8 base64, !END! is added, then the string is escaped. Reset restores the export you pasted. Cheats only rewrites the bakery name so the browser game opens its tools when the name ends with saysopensesame and has at least one letter in front. The name is kept to 28 characters.", ""],
    ["A whole example", "This small save is a made-up bakery named Bakery, with 100 cookies and one unlocked upgrade. The escaped line is what you would paste. Unescape turns %21 into !. Cutting !END! leaves the base64. Decoding it returns the plain line, and the vertical bars are the sections above. Field 0 of section 4 is 100.", "2.058||1;1;1;Bakery;seed;0|10|100|0,0,0,0,,0,0|1|1|\nMi4wNTh8fDE7MTsxO0Jha2VyeTtzZWVkOzB8MTB8MTAwfDAsMCwwLDAsLDAsMHwxfDF8%21END%21"]
  ];

  let page = "save";
  let save = null;
  let pasted = "";
  let status = "Paste an export, then press Load.";
  let upgradeQuery = "";
  let upgradePool = "all";
  let achieveQuery = "";
  let achievePool = "all";
  let heavenQuery = "";

  function esc(value) {
    return String(value == null ? "" : value).replace(/[&<>"']/g, function (ch) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[ch];
    });
  }

  function note(message) {
    status = message;
    const el = document.getElementById("status");
    if (el) el.textContent = message;
  }

  function needSave() {
    return '<div class="card"><p>Load a save first.</p><button class="act" data-act="goto" data-page="save" type="button">Go to Save</button></div>';
  }

  function field(id, placeholder, width) {
    return '<input id="' + id + '" placeholder="' + esc(placeholder) + '" style="width:' + width + 'px">';
  }

  function choice(label, on, act, extra) {
    return '<button class="choice' + (on ? " on" : "") + '" type="button" data-act="' + act + '"' + (extra || "") + ">" + esc(label) + "</button>";
  }

  function sameNumber(token, value) {
    const parsed = Number(String(token || "").trim());
    return Number.isFinite(parsed) && parsed === value;
  }

  function wholeCount(raw) {
    const value = C.parseUserNumber(raw);
    if (value == null || value < 0) return null;
    return Math.round(Math.min(value, 1000000000));
  }

  function userNumber(raw) {
    const value = C.parseUserNumber(raw);
    if (value == null || !Number.isFinite(value)) return null;
    return value;
  }

  function paint() {
    const active = document.activeElement;
    const activeId = active && active.id;
    const caret = active && typeof active.selectionStart === "number" ? active.selectionStart : null;
    document.getElementById("nav").innerHTML = PAGES.map(function (item) {
      return '<button type="button" data-act="goto" data-page="' + item[0] + '" class="' + (page === item[0] ? "on" : "") + '">' + esc(item[1]) + "</button>";
    }).join("");
    document.getElementById("status").textContent = status;
    document.getElementById("page").innerHTML = renderPage();
    if (activeId) {
      const next = document.getElementById(activeId);
      if (next) {
        next.focus();
        if (caret != null && next.setSelectionRange) {
          const at = Math.min(caret, next.value.length);
          next.setSelectionRange(at, at);
        }
      }
    }
  }

  function renderPage() {
    if (page === "how") return howPage();
    if (page !== "save" && !save) return needSave();
    if (page === "save") return savePage();
    if (page === "cookies") return cookiesPage();
    if (page === "buildings") return buildingsPage();
    if (page === "upgrades") return upgradesPage();
    if (page === "achievements") return achievementsPage();
    if (page === "heaven") return heavenPage();
    if (page === "specials") return specialsPage();
    if (page === "cheats") return cheatsPage();
    if (page === "effects") return effectsPage();
    if (page === "market") return marketPage();
    return savePage();
  }

  function savePage() {
    const loaded = save
      ? '<p class="muted">Loaded ' + esc(save.version() || "a save") + ' · ' + esc(save.bakeryName() || "unnamed bakery") + "</p>"
      : '<p class="muted">Nothing is loaded yet.</p>';
    const exported = save ? save.export() : "";
    return '<h2>Save</h2><p class="detail">Paste a Cookie Clicker 2.058 export. Buttons on the other pages change only what you press. Copy save writes the export. Reset puts back the text you loaded.</p>'
      + '<div class="card"><textarea id="paste" placeholder="Paste the export here">' + esc(pasted) + "</textarea>"
      + '<div class="row" style="margin-top:8px"><button class="act" type="button" data-act="load">Load</button>'
      + '<label class="file choice">Load a file<input id="file" type="file" accept=".txt,text/plain" hidden></label>'
      + '<button class="choice" type="button" data-act="copy">Copy save</button>'
      + '<button class="choice" type="button" data-act="reset">Reset</button></div>'
      + loaded + "</div>"
      + (save ? '<div class="card"><h3>New export · ' + exported.length + ' characters</h3><textarea id="exportBox" readonly>' + esc(exported) + "</textarea><p class=\"muted\">Copy save puts the full export on the clipboard. You can also select it here.</p></div>" : "")
      + '<p class="muted">Unofficial fan tool for Cookie Clicker 2.058. Not affiliated with Orteil or DashNet.</p>';
  }

  function cookiesPage() {
    const bank = save.cookies();
    const earned = save.token(save.misc, 1);
    const buttons = COOKIE_PRESETS.map(function (preset) {
      return choice(preset[0], sameNumber(bank, preset[1]), "cookies-preset", ' data-value="' + preset[1] + '"');
    }).join("");
    return '<h2>Cookies</h2><p class="detail">Sets the cookies in the bank. If the bank would pass lifetime cookies, lifetime cookies rise with it.</p>'
      + '<div class="card"><p>In the bank</p><p class="mono">' + esc(bank || "0") + "</p><p>Earned</p><p class=\"mono\">" + esc(earned || "0") + "</p>"
      + '<div class="row">' + buttons + "</div>"
      + '<div class="row" style="margin-top:8px">' + field("cookieAmount", "5.3 million", 220)
      + '<button class="act" type="button" data-act="set-cookies">Set cookies</button></div></div>';
  }

  function buildingsPage() {
    const rows = C.BUILDINGS.map(function (name, index) {
      const amount = save.buildingAmount(index);
      const level = save.buildingLevel(index);
      const mini = MINI_UI[index];
      let extra = "";
      if (mini) {
        const readable = save.minigameAmount(index);
        const blob = save.buildingMinigame(index).trim();
        const locked = blob && readable == null;
        extra = '<p class="muted">' + esc(mini.note) + "</p><div class=\"row\">"
          + choice("On", level > 0, "mini-on", ' data-index="' + index + '"')
          + choice("Off", level === 0, "mini-off", ' data-index="' + index + '"')
          + "<span>" + esc(mini.counter) + (readable == null ? "" : " " + readable) + "</span>"
          + (locked ? '<span class="muted">The saved text could not be read, so the amount stays as it is.</span>'
            : field("mini-" + index, String(mini.counter), 140) + '<button class="act" type="button" data-act="mini-set" data-index="' + index + '">Set</button>'
              + '<button class="choice" type="button" data-act="mini-step" data-index="' + index + '" data-delta="-1">-1</button>'
              + '<button class="choice" type="button" data-act="mini-step" data-index="' + index + '" data-delta="1">+1</button>')
          + "</div>";
      }
      return '<div class="building"><strong>' + esc(name) + "</strong>"
        + '<div class="row"><span>' + amount + "</span>"
        + '<button class="choice" type="button" data-act="b-step" data-index="' + index + '" data-delta="1">+1</button>'
        + '<button class="choice" type="button" data-act="b-step" data-index="' + index + '" data-delta="10">+10</button>'
        + '<button class="choice" type="button" data-act="b-step" data-index="' + index + '" data-delta="100">+100</button>'
        + field("amount-" + index, "Amount", 120)
        + '<button class="act" type="button" data-act="b-amount" data-index="' + index + '">Set</button>'
        + "<span>Level " + level + "</span>"
        + '<button class="choice" type="button" data-act="l-step" data-index="' + index + '" data-delta="1">+1</button>'
        + field("level-" + index, "Level", 90)
        + '<button class="act" type="button" data-act="b-level" data-index="' + index + '">Set</button></div>'
        + extra + "</div>";
    }).join("");
    return '<h2>Buildings</h2><p class="detail">Sets how many of each building you own, and its level. Owned count, bought count, and the highest owned stay in step. Farm, Bank, Temple, and Wizard tower can turn their minigame on or off.</p>'
      + '<div class="row">' + field("allAmount", "All amounts", 140)
      + '<button class="act" type="button" data-act="all-amount">Set every amount</button>'
      + field("allLevel", "All levels", 120)
      + '<button class="act" type="button" data-act="all-level">Set every level</button></div>'
      + rows;
  }

  function poolMatch(pool, selected, regular) {
    if (selected === "all") return true;
    if (selected === "regular") return pool === regular;
    return pool === selected;
  }

  function upgradeRows() {
    const query = upgradeQuery.toLowerCase();
    return (catalog.upgrades || []).filter(function (item) {
      if (!poolMatch(item.pool || "", upgradePool, "")) return false;
      return !query || String(item.name).toLowerCase().indexOf(query) >= 0;
    }).map(function (item) {
      const on = save.upgradeOwned(item.id);
      return '<div class="item">' + choice(item.name + " · " + (on ? "Owned" : "Not owned"), on, "up-toggle", ' data-id="' + item.id + '"') + "</div>";
    }).join("");
  }

  function achieveRows() {
    const query = achieveQuery.toLowerCase();
    return (catalog.achievements || []).filter(function (item) {
      const pool = item.pool || "normal";
      if (achievePool !== "all" && pool !== achievePool) return false;
      return !query || String(item.name).toLowerCase().indexOf(query) >= 0;
    }).map(function (item) {
      const on = save.achievementWon(item.id);
      return '<div class="item">' + choice(item.name + " · " + (on ? "Won" : "Not won"), on, "ac-toggle", ' data-id="' + item.id + '"') + "</div>";
    }).join("");
  }

  function upgradesPage() {
    const owned = (catalog.upgrades || []).filter(function (item) { return save.upgradeOwned(item.id); }).length;
    const pools = UPGRADE_POOLS.map(function (item) {
      return choice(item[1], upgradePool === item[0], "up-pool", ' data-pool="' + item[0] + '"');
    }).join("");
    return '<h2>Upgrades</h2><p class="detail">' + owned + ' owned. Buy all skips debug upgrades.</p>'
      + '<div class="row"><button class="act" type="button" data-act="buy-rest">Buy all except debug</button>'
      + '<button class="choice" type="button" data-act="buy-heaven">Buy all heavenly</button></div>'
      + '<div class="row" style="margin-top:8px">' + pools + "</div>"
      + '<div class="row" style="margin-top:8px"><input id="upgradeQuery" placeholder="Search" style="width:240px" value="' + esc(upgradeQuery) + '"></div>'
      + '<div id="upgradeList" style="margin-top:10px">' + upgradeRows() + "</div>";
  }

  function achievementsPage() {
    const won = (catalog.achievements || []).filter(function (item) { return save.achievementWon(item.id); }).length;
    const pools = ACHIEVE_POOLS.map(function (item) {
      return choice(item[1], achievePool === item[0], "ac-pool", ' data-pool="' + item[0] + '"');
    }).join("");
    return '<h2>Achievements</h2><p class="detail">' + won + ' won. Award all leaves Cheated cookies taste awful alone.</p>'
      + '<div class="row"><button class="act" type="button" data-act="award-all">Award all</button></div>'
      + '<div class="row" style="margin-top:8px">' + pools + "</div>"
      + '<div class="row" style="margin-top:8px"><input id="achieveQuery" placeholder="Search" style="width:240px" value="' + esc(achieveQuery) + '"></div>'
      + '<div id="achieveList" style="margin-top:10px">' + achieveRows() + "</div>";
  }

  function ascensionUpgrades() {
    return (catalog.upgrades || []).filter(function (item) { return item.pool === "prestige"; });
  }

  function heavenRows() {
    const query = heavenQuery.toLowerCase();
    return ascensionUpgrades().filter(function (item) {
      return !query || String(item.name).toLowerCase().indexOf(query) >= 0;
    }).map(function (item) {
      const on = save.upgradeOwned(item.id);
      return '<div class="item">' + choice(item.name + " · " + (on ? "Owned" : "Not owned"), on, "asc-toggle", ' data-id="' + item.id + '"') + "</div>";
    }).join("");
  }

  function heavenPage() {
    const chips = save.chips();
    const forfeited = save.token(save.misc, 8);
    const presets = CHIP_PRESETS.map(function (preset) {
      return choice(preset[0], sameNumber(chips, preset[1]), "chip-preset", ' data-value="' + preset[1] + '"');
    }).join("");
    const five = C.HEAVENLY.map(function (name) {
      const on = save.ownsUpgrade(name);
      return '<div class="item">' + choice(name + " · " + (on ? "Owned" : "Not owned"), on, "named-up", ' data-name="' + esc(name) + '"') + "</div>";
    }).join("");
    const ascension = ascensionUpgrades();
    const owned = ascension.filter(function (item) { return save.upgradeOwned(item.id); }).length;
    return '<h2>Heaven</h2><p class="detail">Sets unspent heavenly chips. If those chips need a higher prestige than the forfeited cookies would give, cookies forfeited rise to match.</p>'
      + '<div class="card"><p>Unspent heavenly chips</p><p class="mono">' + esc(chips || "0") + '</p><p>Cookies forfeited</p><p class="mono">' + esc(forfeited || "0") + "</p>"
      + '<div class="row">' + presets + "</div>"
      + '<div class="row" style="margin-top:8px">' + field("chipAmount", "10000", 180)
      + '<button class="act" type="button" data-act="set-chips">Set chips</button></div>'
      + '<p class="muted">These five are separate from the heavenly upgrade pool.</p>' + five
      + '<h3>Ascension upgrades</h3><p class="muted">These are the heavenly upgrades the Ascend screen sells. Press one to add it or remove it.</p>'
      + '<div class="row"><button class="act" type="button" data-act="asc-all" data-on="1">Add all</button>'
      + '<button class="choice" type="button" data-act="asc-all" data-on="0">Remove all</button>'
      + "<span>" + owned + " of " + ascension.length + " owned</span></div>"
      + '<div class="row" style="margin-top:8px"><input id="heavenQuery" placeholder="Search" style="width:240px" value="' + esc(heavenQuery) + '"></div>'
      + '<div id="heavenList" style="margin-top:10px">' + heavenRows() + "</div></div>";
  }

  function specialsPage() {
    const lumps = save.lumps();
    const lumpButtons = LUMP_PRESETS.map(function (preset) {
      return choice(preset[0], sameNumber(lumps, preset[1]), "lump-preset", ' data-value="' + preset[1] + '"');
    }).join("");
    const santa = C.SANTA.map(function (name, level) {
      return '<option value="' + level + '"' + (save.santa() === level ? " selected" : "") + ">" + level + "  " + esc(name) + "</option>";
    }).join("");
    const auras = function (slot) {
      return C.AURAS.map(function (name, id) {
        return '<option value="' + id + '"' + (save.dragonAura(slot) === id ? " selected" : "") + ">" + esc(name) + "</option>";
      }).join("");
    };
    const seasons = C.SEASONS.map(function (option) {
      return choice(option.label, save.season() === option.id, "season", ' data-season="' + esc(option.id) + '"');
    }).join("");
    return '<h2>Specials</h2><p class="detail">Bakery name, sugar lumps, Santa, the dragon, and the season.</p>'
      + '<div class="card"><h3>Bakery</h3><div class="row"><input id="bakeryName" value="' + esc(save.bakeryName()) + '" style="width:240px">'
      + '<button class="act" type="button" data-act="rename">Rename</button></div><p class="muted">Now: ' + esc(save.bakeryName() || "unnamed") + "</p></div>"
      + '<div class="card"><h3>Sugar lumps</h3><p class="mono">' + esc(lumps || "0") + '</p><div class="row">' + lumpButtons + "</div>"
      + '<div class="row" style="margin-top:8px">' + field("lumpAmount", "100", 140)
      + '<button class="act" type="button" data-act="set-lumps">Set lumps</button></div></div>'
      + '<div class="card"><h3>Santa</h3><select id="santa">' + santa + '</select></div>'
      + '<div class="card"><h3>Dragon</h3><p class="muted">Level</p><select id="dragon">'
      + Array.from({ length: 28 }, function (_, level) {
        return '<option value="' + level + '"' + (save.dragonLevel() === level ? " selected" : "") + ">" + level + "</option>";
      }).join("")
      + '</select><p class="muted">Aura</p><select id="aura0">' + auras(0) + '</select><p class="muted">Second aura</p><select id="aura1">' + auras(1) + "</select></div>"
      + '<div class="card"><h3>Season</h3><div class="row">' + seasons + "</div></div>";
  }

  function cheatsPage() {
    const open = C.BakerySave.cheatsOpen(save.bakeryName());
    return '<h2>Cheats</h2><p class="detail">The browser game opens its dev tools when the bakery name ends with saysopensesame. The Steam app leaves those tools closed. The name can be 28 letters, so a long name is shortened to fit the switch. The game grants Cheated cookies taste awful when the tools open. Turning this off takes the switch out of the name and leaves that achievement as it is.</p>'
      + '<div class="card"><p>Bakery name</p><p class="mono">' + esc(save.bakeryName()) + "</p><div class=\"row\">"
      + choice("Enable", open, "cheats", ' data-on="1"')
      + choice("Disable", !open, "cheats", ' data-on="0"')
      + "</div></div>";
  }

  function effectsPage() {
    const options = C.EFFECTS.map(function (kind) {
      return '<option value="' + kind.id + '">' + esc(kind.title) + "</option>";
    }).join("");
    const buildings = C.BUILDINGS.map(function (name, index) {
      return '<option value="' + index + '">' + esc(name) + "</option>";
    }).join("");
    const list = save.savedEffects().map(function (effect) {
      const title = effect.typeID == null ? "Unrecognized effect" : C.effectTitle(effect.typeID, C.effectBuilding(effect));
      if (effect.typeID == null) {
        return '<div class="card"><h3>' + esc(title) + '</h3><p class="mono">' + esc(effect.raw) + '</p><button class="choice" type="button" data-act="fx-remove" data-slot="' + effect.slot + '">Remove</button></div>';
      }
      const seconds = effect.frames / 30;
      const power = effect.args.length ? effect.args[0] : "";
      const building = C.effectBuilding(effect);
      const kind = C.EFFECTS.find(function (item) { return item.id === effect.typeID; });
      const buildingField = kind && kind.needsBuilding
        ? '<select id="fx-b-' + effect.slot + '">' + C.BUILDINGS.map(function (name, index) {
          return '<option value="' + index + '"' + (building === index ? " selected" : "") + ">" + esc(name) + "</option>";
        }).join("") + "</select>"
        : "";
      const fang = (effect.typeID === 3 || effect.typeID === 7) && save.ownsUpgrade("Dragon fang")
        ? '<p class="muted">This save owns Dragon fang, so the game raises this power by 10% and rounds up on import.</p>'
        : "";
      return '<div class="card"><h3>' + esc(title) + "</h3>"
        + '<div class="row">' + field("fx-s-" + effect.slot, String(seconds), 120)
        + field("fx-p-" + effect.slot, String(power), 120)
        + buildingField
        + '<button class="act" type="button" data-act="fx-set" data-slot="' + effect.slot + '">Set</button>'
        + '<button class="choice" type="button" data-act="fx-remove" data-slot="' + effect.slot + '">Remove</button></div>'
        + fang + (kind ? '<p class="muted">' + esc(kind.note) + "</p>" : "") + "</div>";
    }).join("");
    return '<h2>Effects</h2><p class="detail">Adds one of the 27 timed effects the game can load. Time is stored in frames at 30 per second. A building boost or rust can sit on one building at a time.</p>'
      + '<div class="card"><div class="row"><select id="effectKind">' + options + "</select>"
      + field("effectSeconds", "77", 100) + field("effectPower", "7", 100)
      + '<span id="effectBuildingWrap"><select id="effectBuilding">' + buildings + "</select></span>"
      + '<button class="act" type="button" data-act="fx-add">Add</button></div><p class="muted" id="effectNote"></p></div>'
      + (list || '<div class="card"><p>This save has no timed effects.</p></div>');
  }

  function marketPage() {
    const board = save.stockBoard();
    if (!board) {
      return '<h2>Market</h2><p class="detail">Reads the bank minigame. It does not trade.</p><div class="card"><p>This save has no stock market yet. Give the Bank one sugar lump so it reaches level 1, open the market once, then export again.</p></div>';
    }
    const rows = board.quotes.map(function (quote) {
      const tone = quote.outlook.rise ? "rise" : (quote.outlook.fall ? "fall" : "muted");
      return '<div class="card"><strong>' + esc(quote.symbol) + "  " + esc(quote.name) + "</strong>"
        + '<p class="' + tone + '">' + esc(quote.outlook.label) + "</p>"
        + "<p>$" + quote.value + " · resting $" + quote.resting + " · " + quote.minutes + " min · owned " + quote.owned + "</p></div>";
    }).join("");
    return '<h2>Market</h2><p class="detail">' + esc(board.office) + " · " + board.brokers + " brokers · bank level " + board.bankLevel + "</p>"
      + (rows || '<div class="card"><p>No goods are on the board yet. A stock shows up after you have owned its building at least once.</p></div>')
      + (board.inactive ? '<p class="muted">' + board.inactive + " more " + (board.inactive === 1 ? "good is" : "goods are") + " off the board until that building has been owned.</p>" : "");
  }

  function howPage() {
    const cards = HOW.map(function (block) {
      const formula = block[2] ? '<p class="formula">' + esc(block[2]) + "</p>" : "";
      return '<div class="card"><h3>' + esc(block[0]) + '</h3><p class="muted">' + esc(block[1]) + "</p>" + formula + "</div>";
    }).join("");
    return '<h2>How This Works</h2><p class="detail">How a pasted export becomes the save on the other tabs. Written for Cookie Clicker 2.058.</p>' + cards;
  }

  function rememberQueries() {
    const upgrade = document.getElementById("upgradeQuery");
    const achieve = document.getElementById("achieveQuery");
    if (upgrade) upgradeQuery = upgrade.value;
    if (achieve) achieveQuery = achieve.value;
    const heaven = document.getElementById("heavenQuery");
    if (heaven) heavenQuery = heaven.value;
  }

  function afterPaintEffects() {
    const kind = document.getElementById("effectKind");
    if (!kind) return;
    const picked = C.EFFECTS.find(function (item) { return String(item.id) === kind.value; }) || C.EFFECTS[0];
    const wrap = document.getElementById("effectBuildingWrap");
    const noteEl = document.getElementById("effectNote");
    if (wrap) wrap.hidden = !picked.needsBuilding;
    if (noteEl) noteEl.textContent = picked.note;
    const seconds = document.getElementById("effectSeconds");
    const power = document.getElementById("effectPower");
    if (seconds && !seconds.value) seconds.placeholder = String(picked.seconds);
    if (power && !power.value) power.placeholder = String(picked.power);
  }

  function changed(result, fallback) {
    note(result && result.message ? result.message : fallback);
    paint();
    afterPaintEffects();
  }

  function loadText(text) {
    try {
      save = C.BakerySave.load(text, catalog);
      pasted = String(text || "");
      note("Loaded " + (save.bakeryName() || "the bakery") + ".");
    } catch (error) {
      note(error.message || "That text is not a Cookie Clicker export.");
    }
    paint();
  }

  function copyExport() {
    if (!save) {
      note("Load a save first.");
      return;
    }
    const text = save.export();
    const box = document.getElementById("exportBox");
    const done = function () { note("Copied the export."); };
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(done).catch(function () {
        if (box) {
          box.focus();
          box.select();
        }
        note("Select the export and copy it.");
      });
      return;
    }
    if (box) {
      box.focus();
      box.select();
    }
    note("Select the export and copy it.");
  }

  function onClick(event) {
    const button = event.target.closest("button");
    if (!button) return;
    const act = button.getAttribute("data-act");
    if (!act) return;
    if (act === "goto") {
      rememberQueries();
      page = button.getAttribute("data-page");
      paint();
      afterPaintEffects();
      return;
    }
    if (act === "load") {
      loadText(document.getElementById("paste").value);
      return;
    }
    if (act === "copy") {
      copyExport();
      return;
    }
    if (act === "reset") {
      if (!pasted) {
        note("Load a save first.");
        return;
      }
      loadText(pasted);
      note("Restored the loaded export.");
      return;
    }
    if (!save) return;
    if (act === "set-cookies") return setCookiesFrom(document.getElementById("cookieAmount").value);
    if (act === "cookies-preset") return setCookiesFrom(button.getAttribute("data-value"));
    if (act === "all-amount") return setAll(document.getElementById("allAmount").value, true);
    if (act === "all-level") return setAll(document.getElementById("allLevel").value, false);
    if (act === "b-amount" || act === "b-level" || act === "b-step" || act === "l-step") return editBuilding(button, act);
    if (act === "mini-on" || act === "mini-off" || act === "mini-set" || act === "mini-step") return editMini(button, act);
    if (act === "up-pool") {
      upgradePool = button.getAttribute("data-pool");
      rememberQueries();
      paint();
      return;
    }
    if (act === "ac-pool") {
      achievePool = button.getAttribute("data-pool");
      rememberQueries();
      paint();
      return;
    }
    if (act === "up-toggle") {
      const id = Number(button.getAttribute("data-id"));
      save.setUpgrade(id, !save.upgradeOwned(id));
      rememberQueries();
      note("Upgrade updated.");
      paint();
      return;
    }
    if (act === "ac-toggle") {
      const id = Number(button.getAttribute("data-id"));
      save.setAchievement(id, !save.achievementWon(id));
      rememberQueries();
      note("Achievement updated.");
      paint();
      return;
    }
    if (act === "buy-rest") {
      save.buyUpgrades(function (item) { return item.pool !== "debug"; });
      note("Bought every upgrade except debug.");
      paint();
      return;
    }
    if (act === "buy-heaven") {
      C.HEAVENLY.forEach(function (name) { save.setUpgradeNamed(name, true); });
      note("Bought the five heavenly upgrades.");
      paint();
      return;
    }
    if (act === "award-all") {
      save.awardAll();
      note("Awarded the achievements, leaving Cheated cookies taste awful as it was.");
      paint();
      return;
    }
    if (act === "set-chips") return setChips(document.getElementById("chipAmount").value);
    if (act === "chip-preset") return setChips(button.getAttribute("data-value"));
    if (act === "named-up") {
      const name = button.getAttribute("data-name");
      save.setUpgradeNamed(name, !save.ownsUpgrade(name));
      note(name + (save.ownsUpgrade(name) ? " is owned." : " is not owned."));
      paint();
      return;
    }
    if (act === "asc-all") {
      const owned = button.getAttribute("data-on") === "1";
      ascensionUpgrades().forEach(function (item) { save.setUpgrade(item.id, owned); });
      note(owned ? "Added the ascension upgrades." : "Removed the ascension upgrades.");
      paint();
      return;
    }
    if (act === "asc-toggle") {
      const id = Number(button.getAttribute("data-id"));
      const item = ascensionUpgrades().find(function (entry) { return entry.id === id; });
      save.setUpgrade(id, !save.upgradeOwned(id));
      const name = item ? item.name : "That upgrade";
      note(name + (save.upgradeOwned(id) ? " is added." : " is removed."));
      paint();
      return;
    }
    if (act === "set-lumps") return setLumps(document.getElementById("lumpAmount").value);
    if (act === "lump-preset") return setLumps(button.getAttribute("data-value"));
    if (act === "rename") {
      const error = save.setBakeryName(document.getElementById("bakeryName").value);
      note(error || "Bakery renamed.");
      paint();
      return;
    }
    if (act === "season") {
      save.setSeason(button.getAttribute("data-season"));
      note("Season updated.");
      paint();
      return;
    }
    if (act === "cheats") {
      const enabled = button.getAttribute("data-on") === "1";
      const next = C.BakerySave.cheatsName(save.bakeryName(), enabled);
      if (save.bakeryName() === next) {
        note(enabled ? "Cheats are already on for the browser game." : "Cheats are already off.");
        return;
      }
      const error = save.setBakeryName(next);
      note(error || (enabled ? "Cheats are on for the browser game." : "Cheats are off."));
      paint();
      return;
    }
    if (act === "fx-add") return addEffect();
    if (act === "fx-set") return updateEffect(Number(button.getAttribute("data-slot")));
    if (act === "fx-remove") {
      changed(save.removeEffect(Number(button.getAttribute("data-slot"))));
    }
  }

  function onChange(event) {
    const id = event.target.id;
    if (id === "santa") {
      save.setSanta(Number(event.target.value));
      note("Santa is " + C.SANTA[save.santa()] + ".");
      paint();
    } else if (id === "dragon") {
      save.setDragonLevel(Number(event.target.value));
      note("Dragon level is " + save.dragonLevel() + ".");
      paint();
    } else if (id === "aura0" || id === "aura1") {
      save.setDragonAura(id === "aura1" ? 1 : 0, Number(event.target.value));
      note("Dragon aura updated.");
      paint();
    } else if (id === "effectKind") {
      afterPaintEffects();
    } else if (id === "file") {
      const file = event.target.files && event.target.files[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = function () { loadText(String(reader.result || "")); };
      reader.readAsText(file);
    } else if (id === "upgradeQuery") {
      upgradeQuery = event.target.value;
    } else if (id === "achieveQuery") {
      achieveQuery = event.target.value;
    } else if (id === "heavenQuery") {
      heavenQuery = event.target.value;
    }
  }

  function onInput(event) {
    if (event.target.id === "upgradeQuery") {
      upgradeQuery = event.target.value;
      const list = document.getElementById("upgradeList");
      if (list) list.innerHTML = upgradeRows();
    } else if (event.target.id === "achieveQuery") {
      achieveQuery = event.target.value;
      const list = document.getElementById("achieveList");
      if (list) list.innerHTML = achieveRows();
    } else if (event.target.id === "heavenQuery") {
      heavenQuery = event.target.value;
      const list = document.getElementById("heavenList");
      if (list) list.innerHTML = heavenRows();
    }
  }

  function setCookiesFrom(raw) {
    const value = userNumber(raw);
    if (value == null) {
      note("Enter a number, like 1000, 1e12, or 5.3 million.");
      return;
    }
    save.setCookies(value);
    note("Cookies set to " + save.cookies() + ".");
    paint();
  }

  function setChips(raw) {
    const value = userNumber(raw);
    if (value == null) {
      note("Enter a number, like 1000, 1e12, or 5.3 million.");
      return;
    }
    save.setHeavenlyChips(value);
    note("Heavenly chips set to " + save.chips() + ".");
    paint();
  }

  function setLumps(raw) {
    const value = userNumber(raw);
    if (value == null || value < 0) {
      note("Enter a whole number, like 100.");
      return;
    }
    save.setLumps(value);
    note("Sugar lumps set to " + save.lumps() + ".");
    paint();
  }

  function setAll(raw, amounts) {
    const count = wholeCount(raw);
    if (count == null) {
      note("Enter a whole number, like 100.");
      return;
    }
    C.BUILDINGS.forEach(function (_, index) {
      if (amounts) save.setBuilding(index, count, null);
      else save.setBuilding(index, null, count);
    });
    note(amounts ? "Every amount is " + count + "." : "Every level is " + count + ".");
    paint();
  }

  function editBuilding(button, act) {
    const index = Number(button.getAttribute("data-index"));
    if (act === "b-step") {
      save.setBuilding(index, save.buildingAmount(index) + Number(button.getAttribute("data-delta")), null);
      note(C.BUILDINGS[index] + " is " + save.buildingAmount(index) + ".");
      paint();
      return;
    }
    if (act === "l-step") {
      save.setBuilding(index, null, save.buildingLevel(index) + Number(button.getAttribute("data-delta")));
      note(C.BUILDINGS[index] + " level is " + save.buildingLevel(index) + ".");
      paint();
      return;
    }
    const raw = document.getElementById(act === "b-amount" ? "amount-" + index : "level-" + index).value;
    const count = wholeCount(raw);
    if (count == null) {
      note("Enter a whole number, like 100.");
      return;
    }
    if (act === "b-amount") save.setBuilding(index, count, null);
    else save.setBuilding(index, null, count);
    note(C.BUILDINGS[index] + (act === "b-amount" ? " is " + save.buildingAmount(index) : " level is " + save.buildingLevel(index)) + ".");
    paint();
  }

  function editMini(button, act) {
    const index = Number(button.getAttribute("data-index"));
    if (act === "mini-on" || act === "mini-off") {
      changed(save.setMinigameEnabled(index, act === "mini-on"));
      return;
    }
    const current = save.minigameAmount(index);
    let value;
    if (act === "mini-step") {
      if (current == null) {
        note("The saved text could not be read, so the amount stays as it is.");
        return;
      }
      value = current + Number(button.getAttribute("data-delta"));
    } else {
      value = wholeCount(document.getElementById("mini-" + index).value);
      if (value == null) {
        note("Enter a whole number, like 100.");
        return;
      }
    }
    changed(save.setMinigameAmount(index, value));
  }

  function addEffect() {
    const typeID = Number(document.getElementById("effectKind").value);
    const kind = C.EFFECTS.find(function (item) { return item.id === typeID; });
    const secondsRaw = document.getElementById("effectSeconds").value.trim();
    const powerRaw = document.getElementById("effectPower").value.trim();
    const seconds = secondsRaw ? userNumber(secondsRaw) : kind.seconds;
    const power = powerRaw ? userNumber(powerRaw) : kind.power;
    if (seconds == null) {
      note("Enter a time in seconds, like 77.");
      return;
    }
    if (power == null) {
      note("Enter a power, like 7.");
      return;
    }
    const building = kind.needsBuilding ? Number(document.getElementById("effectBuilding").value) : null;
    changed(save.addEffect(typeID, seconds, power, building));
  }

  function updateEffect(slot) {
    const secondsRaw = document.getElementById("fx-s-" + slot).value.trim();
    const powerRaw = document.getElementById("fx-p-" + slot).value.trim();
    const seconds = secondsRaw ? userNumber(secondsRaw) : null;
    const power = powerRaw ? userNumber(powerRaw) : null;
    if (secondsRaw && seconds == null) {
      note("Enter a time in seconds, like 77.");
      return;
    }
    if (powerRaw && power == null) {
      note("Enter a power, like 7.");
      return;
    }
    const buildingPick = document.getElementById("fx-b-" + slot);
    const building = buildingPick ? Number(buildingPick.value) : null;
    changed(save.updateEffect(slot, seconds, power, building));
  }

  function boot() {
    if (!C) {
      note("The editor scripts did not load.");
      return;
    }
    document.getElementById("page").addEventListener("click", onClick);
    document.getElementById("nav").addEventListener("click", onClick);
    document.getElementById("page").addEventListener("change", onChange);
    document.getElementById("page").addEventListener("input", onInput);
    const queryBox = document.getElementById("upgradeQuery");
    if (queryBox) queryBox.value = upgradeQuery;
    paint();
    const upgrade = document.getElementById("upgradeQuery");
    const achieve = document.getElementById("achieveQuery");
    if (upgrade) upgrade.value = upgradeQuery;
    if (achieve) achieve.value = achieveQuery;
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot);
  else boot();
})();
