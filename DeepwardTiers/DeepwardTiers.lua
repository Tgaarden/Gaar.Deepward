--[[
  DeepwardTiers — a progression panel styled after the achievement window.

  Deepward has no achievements (see DeepwardUI). This replaces that "check your
  progress" surface with the real Deepward metric: your current tier, its gear,
  dungeon progress and wipe budget (handover §6.3 / §6.6).

  SHELL (v0.1): the layout + a placeholder data model. The live data source is the
  server-side tier engine (tier / segment / tier_gear / run_log tables) which is
  NOT built yet — so the values shown here are derived/placeholder and will be
  wired to the server (addon message or a hidden tooltip/gossip channel) once the
  engine exists. Search this file for "TODO(server)" for the seams.

  Client-side only (law I). Open with /tier or /deepward, or the draggable button.
]]

local _G = _G

-- ---------------------------------------------------------------------------
-- Data model — TODO(server): replace this static table with values pushed from
-- the tier engine. Shape is intentionally close to the planned tier/segment rows.
-- ---------------------------------------------------------------------------
-- Mirrors the server `tier` / `segment` seed (see Deepward/sql/deepward_tiers.sql).
-- TODO(server): push live tier/segment + progress from the engine instead of this static copy.
local TIERS = {
    -- Per dungeon: art = its loading-screen splash (LoadingScreens.dbc); bosses ordered with the
    -- final/stop-boss last (matches segment.stop_boss_entry); desc = a one-line summary; loc = where.
    {
        id = 1, name = "Ragefire Chasm", level = 16, wipeBudget = 3,
        gear = "Cloth starter set (tier-1 placeholder)",
        dungeons = {
            {
                name = "Ragefire Chasm", cleared = false, map = 389,
                art = "Interface\\Glues\\LoadingScreens\\LoadScreenRagefireChasm",
                loc = "Orgrimmar — Cleft of Shadow", range = "13–18",
                desc = "A volcanic cleft beneath Orgrimmar, overrun by the Searing Blade cult and its elementals.",
                bosses = { {n="Oggleflint",e=11517}, {n="Bazzalan",e=11519}, {n="Jergosh the Invoker",e=11518}, {n="Taragaman the Hungerer",e=11520} },
            },
        },
    },
    {
        id = 2, name = "Deadmines / Wailing Caverns", level = 20, wipeBudget = 3,
        gear = "Tier-2 set (placeholder)",
        dungeons = {
            {
                name = "Deadmines", cleared = false, map = 36,
                art = "Interface\\Glues\\LoadingScreens\\LoadScreenDeadmines",
                loc = "Westfall — Moonbrook", range = "17–24",
                desc = "The Defias Brotherhood's hideout in a flooded Westfall goldmine, ending at their ship.",
                bosses = { {n="Rhahk'Zor",e=644}, {n="Cookie",e=645}, {n="Mr. Smite",e=646}, {n="Captain Greenskin",e=647}, {n="Gilnid",e=1763}, {n="Edwin VanCleef",e=639} },
            },
            {
                name = "Wailing Caverns", cleared = false, map = 43,
                art = "Interface\\Glues\\LoadingScreens\\LoadScreenWailingCaverns",
                loc = "The Barrens", range = "17–24",
                desc = "A living labyrinth in the Barrens where the Wailing Deviates guard the corrupted Fanglords.",
                bosses = { {n="Kresh",e=3653}, {n="Lady Anacondra",e=3671}, {n="Lord Cobrahn",e=3669}, {n="Lord Pythas",e=3670}, {n="Lord Serpentis",e=3673}, {n="Skum",e=3674}, {n="Verdan the Everliving",e=5775}, {n="Mutanus the Devourer",e=3654} },
            },
        },
    },
    {
        id = 3, name = "Shadowfang Keep / Stockade / Blackfathom Deeps", level = 25, wipeBudget = 3,
        gear = "Tier-3 set (placeholder)",
        dungeons = {
            {
                name = "Shadowfang Keep", cleared = false, map = 33,
                art = "Interface\\Glues\\LoadingScreens\\LoadScreenShadowFangKeep",
                loc = "Silverpine Forest", range = "22–30",
                desc = "Arugal's haunted keep above Silverpine, prowled by worgen and the risen dead.",
                bosses = { {n="Rethilgore",e=3914}, {n="Razorclaw the Butcher",e=3886}, {n="Baron Silverlaine",e=3887}, {n="Commander Springvale",e=4278}, {n="Odo the Blindwatcher",e=4279}, {n="Fenrus the Devourer",e=4274}, {n="Wolf Master Nandos",e=3927}, {n="Archmage Arugal",e=4275} },
            },
            {
                name = "The Stockade", cleared = false, map = 34,
                art = "Interface\\Glues\\LoadingScreens\\LoadScreenStormwindStockade",
                loc = "Stormwind City", range = "22–30",
                desc = "Stormwind's prison, seized by the Defias inmates in a bloody riot.",
                bosses = { {n="Targorr the Dread",e=1696}, {n="Kam Deepfury",e=1666}, {n="Hamhock",e=1717}, {n="Dextren Ward",e=1663}, {n="Bazil Thredd",e=1716} },
            },
            {
                name = "Blackfathom Deeps", cleared = false, map = 48,
                art = "Interface\\Glues\\LoadingScreens\\LoadScreenBlackfathomDeeps",
                loc = "Ashenvale", range = "22–30",
                desc = "A drowned Kaldorei temple beneath Ashenvale, claimed by the Twilight's Hammer and the naga.",
                bosses = { {n="Ghamoo-ra",e=4887}, {n="Lady Sarevess",e=4831}, {n="Gelihast",e=6243}, {n="Twilight Lord Kelris",e=4832}, {n="Aku'mai",e=4829} },
            },
        },
    },
    -- Tier 4 — Scarlet Monastery (Graveyard + Library), Gnomeregan, Razorfen Kraul. Clear 2 of 4.
    {
        id = 4, name = "SM Graveyard / SM Library / Gnomeregan / Razorfen Kraul", level = 36, wipeBudget = 3,
        gear = "Earned from drops + Sylvanas caches",
        dungeons = {
            {
                name = "Scarlet Monastery: Graveyard", cleared = false, map = 189,
                art = "Interface\\Glues\\LoadingScreens\\LoadScreenScarletMonastery",
                loc = "Tirisfal Glades", range = "28–38",
                desc = "The Scarlet Crusade's graveyard wing, haunted by Bloodmage Thalnos.",
                bosses = { {n="Interrogator Vishas",e=3983}, {n="Bloodmage Thalnos",e=4543} },
            },
            {
                name = "Scarlet Monastery: Library", cleared = false, map = 189,
                art = "Interface\\Glues\\LoadingScreens\\LoadScreenScarletMonastery",
                loc = "Tirisfal Glades", range = "29–39",
                desc = "The Crusade's library, guarded by Arcanist Doan.",
                bosses = { {n="Houndmaster Loksey",e=3974}, {n="Arcanist Doan",e=6487} },
            },
            {
                name = "Gnomeregan", cleared = false, map = 90,
                art = "Interface\\Glues\\LoadingScreens\\LoadScreenGnomeregan",
                loc = "Dun Morogh", range = "29–38",
                desc = "The irradiated gnome city, seized by troggs and Mekgineer Thermaplugg.",
                bosses = { {n="Electrocutioner 6000",e=6235}, {n="Mekgineer Thermaplugg",e=7800} },
            },
            {
                name = "Razorfen Kraul", cleared = false, map = 47,
                art = "Interface\\Glues\\LoadingScreens\\LoadScreenRazorfenKraul",
                loc = "The Barrens", range = "30–40",
                desc = "The quillboar warren of thorns, ruled by Charlga Razorflank.",
                bosses = { {n="Aggem Thorncurse",e=4424}, {n="Death Speaker Jargba",e=4428}, {n="Overlord Ramtusk",e=4420}, {n="Charlga Razorflank",e=4421} },
            },
        },
    },
    -- Tier 5 — Scarlet Monastery (Armory + Cathedral). Clear 1 of 2.
    {
        id = 5, name = "SM Armory / SM Cathedral", level = 42, wipeBudget = 3,
        gear = "Earned from drops + Sylvanas caches",
        dungeons = {
            {
                name = "Scarlet Monastery: Armory", cleared = false, map = 189,
                art = "Interface\\Glues\\LoadingScreens\\LoadScreenScarletMonastery",
                loc = "Tirisfal Glades", range = "34–44",
                desc = "The Crusade's armory — Herod, the Scarlet Champion, holds the hall.",
                bosses = { {n="Herod",e=3975} },
            },
            {
                name = "Scarlet Monastery: Cathedral", cleared = false, map = 189,
                art = "Interface\\Glues\\LoadingScreens\\LoadScreenScarletMonastery",
                loc = "Tirisfal Glades", range = "35–45",
                desc = "The grand cathedral of Mograine and High Inquisitor Whitemane.",
                bosses = { {n="Scarlet Commander Mograine",e=3976}, {n="High Inquisitor Whitemane",e=3977} },
            },
        },
    },
    -- Tier 6 — Razorfen Downs, Uldaman. Clear 1 of 2.
    {
        id = 6, name = "Razorfen Downs / Uldaman", level = 48, wipeBudget = 3,
        gear = "Earned from drops + Sylvanas caches",
        dungeons = {
            {
                name = "Razorfen Downs", cleared = false, map = 129,
                art = "Interface\\Glues\\LoadingScreens\\LoadScreenRazorfenDowns",
                loc = "Thousand Needles", range = "37–47",
                desc = "The undead quillboar necropolis, raised by Amnennar the Coldbringer.",
                bosses = { {n="Mordresh Fire Eye",e=7357}, {n="Amnennar the Coldbringer",e=7358} },
            },
            {
                name = "Uldaman", cleared = false, map = 70,
                art = "Interface\\Glues\\LoadingScreens\\LoadScreenUldaman",
                loc = "Badlands", range = "41–51",
                desc = "The titan vault beneath the Badlands, sealed by the guardian Archaedas.",
                bosses = { {n="Revelosh",e=6910}, {n="Archaedas",e=2748} },
            },
        },
    },
    -- Tier 7 — Zul'Farrak, Maraudon, Sunken Temple. Clear 2 of 3.
    {
        id = 7, name = "Zul'Farrak / Maraudon / Sunken Temple", level = 54, wipeBudget = 3,
        gear = "Earned from drops + Sylvanas caches",
        dungeons = {
            {
                name = "Zul'Farrak", cleared = false, map = 209,
                art = "Interface\\Glues\\LoadingScreens\\LoadScreenZulFarrak",
                loc = "Tanaris", range = "44–54",
                desc = "The Sandfury troll city in Tanaris, ruled by Chief Ukorz Sandscalp.",
                bosses = { {n="Theka the Martyr",e=7272}, {n="Witch Doctor Zum'rah",e=7271}, {n="Hydromancer Velratha",e=7795}, {n="Chief Ukorz Sandscalp",e=7267} },
            },
            {
                name = "Maraudon", cleared = false, map = 349,
                art = "Interface\\Glues\\LoadingScreens\\LoadScreenMaraudon",
                loc = "Desolace", range = "46–55",
                desc = "The petrified caverns under Desolace, home of Princess Theradras.",
                bosses = { {n="Celebras the Cursed",e=12225}, {n="Landslide",e=12203}, {n="Princess Theradras",e=12201} },
            },
            {
                name = "Sunken Temple", cleared = false, map = 109,
                art = "Interface\\Glues\\LoadingScreens\\LoadScreenSunkenTemple",
                loc = "Swamp of Sorrows", range = "50–60",
                desc = "The Temple of Atal'Hakkar in the Swamp of Sorrows — the Atal'ai and Jammal'an the Prophet.",
                bosses = { {n="Ogom the Wretched",e=5711}, {n="Jammal'an the Prophet",e=5710} },
            },
        },
    },
    -- Tier 8 — the level-58 FARM tier: the six great level-60 dungeons. Clear 4 of 6, repeatable.
    {
        id = 8, name = "BRD / LBRS / UBRS / Scholomance / Stratholme / Dire Maul", level = 58, wipeBudget = 3,
        gear = "Earned from drops + Sylvanas caches",
        dungeons = {
            {
                name = "Blackrock Depths", cleared = false, map = 230,
                art = "Interface\\Glues\\LoadingScreens\\LoadScreenBlackrockDepths",
                loc = "Blackrock Mountain", range = "52–60",
                desc = "The Dark Iron dwarf city deep in Blackrock Mountain — Emperor Dagran Thaurissan's seat.",
                bosses = { {n="High Interrogator Gerstahn",e=9018}, {n="Magmus",e=9938}, {n="Emperor Dagran Thaurissan",e=9019} },
            },
            {
                name = "Lower Blackrock Spire", cleared = false, map = 229,
                art = "Interface\\Glues\\LoadingScreens\\LoadScreenBlackRockSpire",
                loc = "Blackrock Spire", range = "55–60",
                desc = "The orc warrens of the Spinemaw, held by Overlord Wyrmthalak.",
                bosses = { {n="Highlord Omokk",e=9196}, {n="Shadow Hunter Vosh'gajin",e=9236}, {n="War Master Voone",e=9237}, {n="Overlord Wyrmthalak",e=9568} },
            },
            {
                name = "Upper Blackrock Spire", cleared = false, map = 229,
                art = "Interface\\Glues\\LoadingScreens\\LoadScreenBlackRockSpire",
                loc = "Blackrock Spire", range = "55–60",
                desc = "Nefarian's black dragonspawn stronghold atop the Spire — General Drakkisath commands.",
                bosses = { {n="Pyroguard Emberseer",e=9816}, {n="The Beast",e=10430}, {n="General Drakkisath",e=10363} },
            },
            {
                name = "Scholomance", cleared = false, map = 289,
                art = "Interface\\Glues\\LoadingScreens\\LoadScreenScholomance",
                loc = "Western Plaguelands", range = "56–60",
                desc = "The necromantic academy beneath Caer Darrow, run by Darkmaster Gandling.",
                bosses = { {n="Jandice Barov",e=10503}, {n="Ras Frostwhisper",e=10508}, {n="Rattlegore",e=11622}, {n="Darkmaster Gandling",e=1853} },
            },
            {
                name = "Stratholme", cleared = false, map = 329,
                art = "Interface\\Glues\\LoadingScreens\\LoadScreenStratholme",
                loc = "Eastern Plaguelands", range = "56–60",
                desc = "The plagued city — the Scourge's Baron Rivendare holds the undead side.",
                bosses = { {n="Magistrate Barthilas",e=10435}, {n="Nerub'enkan",e=10437}, {n="Maleki the Pallid",e=10438}, {n="Baroness Anastari",e=10436}, {n="Baron Rivendare",e=10440} },
            },
            {
                name = "Dire Maul", cleared = false, map = 429,
                art = "Interface\\Glues\\LoadingScreens\\LoadScreenDireMaul",
                loc = "Feralas", range = "55–60",
                desc = "The ruined Highborne city in Feralas — the ogre King Gordok rules the north.",
                bosses = { {n="Captain Kromcrush",e=14325}, {n="King Gordok",e=11501} },
            },
        },
    },
    -- Tier 9 (Raid) comes later. Tier 66 below is the current Molten Core capstone.
    {
        id = 66, name = "Molten Core", level = 60, wipeBudget = 3,
        gear = "Level 60 raid capstone (proof-of-concept)",
        dungeons = {
            {
                name = "Molten Core", cleared = false, map = 409,
                art = "Interface\\Glues\\LoadingScreens\\LoadScreenMoltenCore",
                loc = "Blackrock Depths — the Molten Core", range = "60 (5-man capstone)",
                desc = "The firelord Ragnaros' domain deep beneath Blackrock Mountain — a 40-man raid, run here as a level-60 5-man capstone (bosses NOT down-tuned yet — brutal).",
                bosses = {
                    {n="Lucifron",e=12118}, {n="Magmadar",e=11982}, {n="Gehennas",e=12259}, {n="Garr",e=12057},
                    {n="Baron Geddon",e=12056}, {n="Shazzrah",e=12264}, {n="Sulfuron Harbinger",e=12098},
                    {n="Golemagg the Incinerator",e=11988}, {n="Majordomo Executus",e=12018}, {n="Ragnaros",e=11502},
                },
            },
        },
    },
}

-- Fire a "." command in chat. The player-accessible ".enter" command (custom RBAC perm,
-- no GM needed) teleports into the current tier's dungeon server-side — replaces the
-- in-world Ascension Portal NPC, and the SERVER owns the destination + rules.
local function SendCmd(cmd)
    local ch = "SAY"
    if GetNumRaidMembers() > 0 then ch = "RAID"
    elseif GetNumPartyMembers() > 0 then ch = "PARTY" end
    SendChatMessage(cmd, ch)
end

-- ---------------------------------------------------------------------------
-- Live data from the server (addon message, "DEEPWARD" prefix). Payload:
--   "T=<current_tier>;M=<max_tier>;C=<clearedMap1,clearedMap2,...>"
-- Pushed on login / clear / tier change, and on ".dwsync" (fired when the panel opens).
-- Until the first push, the panel falls back to level-derived values.
-- ---------------------------------------------------------------------------
local DeepwardLive   -- { tier = N, max = N, cleared = { [mapId] = true } } once received

local function ParseLive(message)
    local t = tonumber(message:match("T=(%d+)"))
    if not t then return end
    local cleared = {}
    local c = message:match("C=([%d,]*)")
    if c then for id in c:gmatch("%d+") do cleared[tonumber(id)] = true end end
    local killed = {}                                  -- boss entries slain (per-boss panel marks)
    local b = message:match("B=([%d,]*)")
    if b then for id in b:gmatch("%d+") do killed[tonumber(id)] = true end end
    local admin = (tonumber(message:match("A=(%d+)")) == 1)   -- owner account may force-advance
    DeepwardLive = { tier = t, max = tonumber(message:match("M=(%d+)")) or t, cleared = cleared, killed = killed, admin = admin }
end

-- Live group roster, sent by the server as its own short "DEEPWARD\tG=name:role,name:role,..." message
-- (separate from the progress payload so it never hits the 255-char addon limit).
local DeepwardRoster   -- { {name=, role=}, ... }
local function ParseRoster(message)
    local g = message:match("G=([^;]*)")
    if not g then return false end
    local r = {}
    for entry in g:gmatch("[^,]+") do
        local name, role = entry:match("([^:]+):([^:]+)")
        if name then table.insert(r, { name = name, role = role }) end
    end
    DeepwardRoster = r
    return true
end

-- Account-wide journey stats, sent as "AS=chars:kills:cleared:highTier:goldCopper:playedSec".
local DeepwardAccount   -- { chars, kills, cleared, highTier, gold(copper), played(sec) }
local function ParseAccount(message)
    local a = message:match("AS=([%d:]+)")
    if not a then return false end
    local c, k, cl, ht, g, p = a:match("^(%d+):(%d+):(%d+):(%d+):(%d+):(%d+)")
    if not c then return false end
    DeepwardAccount = {
        chars = tonumber(c), kills = tonumber(k), cleared = tonumber(cl),
        highTier = tonumber(ht), gold = tonumber(g), played = tonumber(p),
    }
    return true
end

local function RequestSync()
    SendCmd(".dwrole " .. (DeepwardTiersDB and DeepwardTiersDB.role or "dps"))   -- register my role for the roster
    SendCmd(".dwsync")
end

-- Bot slots = 5 minus the real players in your group (party/raid size; solo = 1 -> 4 bot slots).
local function BotSlotCount()
    local humans = (GetNumPartyMembers() or 0) + 1
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then humans = GetNumRaidMembers() end
    local slots = 5 - humans
    if slots < 0 then slots = 0 end
    return slots
end

-- Ensure our SavedVariables fields exist AT RUNTIME. A DeepwardTiersDB saved before these fields existed
-- (e.g. only had `role`) replaces the file-scope defaults when SavedVariables load -> botComp would be
-- nil. Every function that reads the DB calls this first so the panel never indexes a nil comp.
local function EnsureDB()
    DeepwardTiersDB = DeepwardTiersDB or {}
    if DeepwardTiersDB.role == nil then DeepwardTiersDB.role = "dps" end
    if DeepwardTiersDB.botAuto == nil then DeepwardTiersDB.botAuto = true end
    if DeepwardTiersDB.fillBots == nil then DeepwardTiersDB.fillBots = true end
    if type(DeepwardTiersDB.botComp) ~= "table" then DeepwardTiersDB.botComp = { t = 1, h = 1, d = 2 } end
end

-- Enter a specific løype by map id (explicit choice — e.g. replay Wailing Caverns with a friend).
-- The server validates the map belongs to your current tier; an omitted map auto-routes to the
-- first løype you haven't cleared. When a CUSTOM bot comp is set (not Auto) and it fills the free
-- slots exactly, it's appended as "<t>-<h>-<d>"; otherwise the server auto-fills the roles.
local function EnterDungeon(map)
    EnsureDB()
    local role = DeepwardTiersDB.role or "dps"
    local cmd = ".enter " .. role
    local slots = BotSlotCount()
    local c = DeepwardTiersDB.botComp
    if (not DeepwardTiersDB.botAuto) and c and slots > 0 and (c.t + c.h + c.d == slots) then
        cmd = cmd .. " " .. (map or 0) .. " " .. c.t .. "-" .. c.h .. "-" .. c.d
    elseif map then
        cmd = cmd .. " " .. map
    end
    SendCmd(cmd)
end

-- Your current tier. TODO(server): the authoritative value is the character's `current_tier`,
-- pushed from the engine (AIO/phase 2). Until that channel exists, derive it from level: each tier
-- grants a fixed level (TIERS[].level = 16/20/25), so the highest tier whose level you meet is the
-- one you're on. Level is restored per tier by the snapshot, so this stays correct going up OR down.
local function CurrentTierId()
    if DeepwardLive and DeepwardLive.tier then return DeepwardLive.tier end   -- authoritative
    local lvl = (UnitLevel and UnitLevel("player")) or 0                       -- fallback
    local cur = 1
    for _, t in ipairs(TIERS) do
        if lvl >= t.level then cur = t.id end
    end
    return cur
end

-- A dungeon is cleared when the server has reported its map as cleared for this char.
local function IsDungeonCleared(d)
    return DeepwardLive and DeepwardLive.cleared and d and DeepwardLive.cleared[d.map] or false
end

-- A boss (a {n=name, e=entry} entry) is slain when the server reported its entry as killed.
local function IsBossKilled(b)
    return DeepwardLive and DeepwardLive.killed and b and DeepwardLive.killed[b.e] or false
end

-- Required clears per tier (N of M instances). Mirrors the server's tier.required_clears.
local TIER_REQ = { [1]=1, [2]=1, [3]=1, [4]=2, [5]=1, [6]=1, [7]=2, [8]=4, [66]=1 }
local function TierReq(t) return (t and TIER_REQ[t.id]) or (t and t.dungeons and #t.dungeons) or 1 end

-- How many of a tier's dungeons this char has cleared (live data).
local function CountClearedDungeons(t)
    if not (DeepwardLive and DeepwardLive.cleared) or not t or not t.dungeons then return 0 end
    local n = 0
    for _, d in ipairs(t.dungeons) do
        if DeepwardLive.cleared[d.map] then n = n + 1 end
    end
    return n
end

-- A tier is cleared (qualified to advance) when the char has cleared at least the REQUIRED number of
-- its dungeons (N of M). Needs live data; without it we return false so Advance stays hidden.
local function IsTierClearedLive(t)
    if not (DeepwardLive and DeepwardLive.cleared) or not t or not t.dungeons or #t.dungeons == 0 then
        return false
    end
    return CountClearedDungeons(t) >= TierReq(t)
end

-- ---------------------------------------------------------------------------
-- UI (built lazily on first open)
-- ---------------------------------------------------------------------------
local frame
local tierButtons = {}
local selectedId = 1
local selectedDungeonIdx = 1   -- which dungeon of the selected tier is shown (bg + info + Enter target)

-- Bot-comp editor + live roster (idea #6). Forward-declared so CreateUI's button closures can call them.
-- Custom Deepward role medallions: three separate icons shipped with the addon (pre-cropped by Thomas,
-- converted to power-of-two 32-bit TGA). One texture per role — no atlas / TexCoord carving. Shared by
-- the panel role selector, the bot-comp steppers, and the role-check popup.
local ROLE_TEX = {
    dps    = "Interface\\AddOns\\DeepwardTiers\\DPS-role",
    healer = "Interface\\AddOns\\DeepwardTiers\\Healer-role",
    tank   = "Interface\\AddOns\\DeepwardTiers\\Tank-role",
}
local ROLE_LABEL = { tank = "Tank", healer = "Healer", dps = "DPS" }
-- Boss-status inline icons for the detail list (killed = green check, still up = skull).
local BOSS_KILLED_ICON = "|TInterface\\RaidFrame\\ReadyCheck-Ready:15:15:0:-2|t"
local BOSS_ALIVE_ICON  = "|TInterface\\TargetingFrame\\UI-TargetingFrame-Skull:15:15:0:-2|t"
-- Inline (|T…|t) role icons for embedding in FontStrings (the group roster). 18px glyph, 64x64 source.
local ROLE_INLINE = {
    tank   = "|TInterface\\LFGFrame\\UI-LFG-ICON-ROLES:18:18:0:0:64:64:0:19:22:41|t",
    healer = "|TInterface\\LFGFrame\\UI-LFG-ICON-ROLES:18:18:0:0:64:64:20:39:1:20|t",
    dps    = "|TInterface\\LFGFrame\\UI-LFG-ICON-ROLES:18:18:0:0:64:64:20:39:22:41|t",
}

-- A clickable role-icon button. The icon is the normal texture; a square glow (SetHighlightTexture)
-- shows on hover and, via LockHighlight()/UnlockHighlight(), marks the selected role.
local function MakeRoleIcon(parent, role, size)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(size, size)
    btn:SetNormalTexture(ROLE_TEX[role])
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    btn:GetHighlightTexture():SetBlendMode("ADD")
    btn.role = role
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(ROLE_LABEL[role])
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return btn
end

local RenderComp, RenderRoster, UpdateBadge, UpdateJourney

-- Header badge (achievement-frame style): total bosses slain, from the live "B=" set.
UpdateBadge = function()
    if not frame or not frame.badge then return end
    local n = 0
    if DeepwardLive and DeepwardLive.killed then for _ in pairs(DeepwardLive.killed) do n = n + 1 end end
    frame.badge:SetText(("%d"):format(n))
end

-- Left-column "Din reise" summary: this character's running totals, refreshed with every live push.
UpdateJourney = function()
    if not frame or not frame.journeyText then return end
    local kills, insts = 0, 0
    local curT = CurrentTierId()
    if DeepwardLive then
        if DeepwardLive.killed  then for _ in pairs(DeepwardLive.killed)  do kills = kills + 1 end end
        if DeepwardLive.cleared then for _ in pairs(DeepwardLive.cleared) do insts = insts + 1 end end
    end
    -- tier label: the capstone raid tier (66) reads as "9 (Raid)"
    local function tlabel(n) if n == 66 then return "9 (Raid)" else return tostring(n) end end

    -- This character (compact: two stats per line to fit the fixed left-column band).
    local s = ("|cffffd100Denne karakteren|r\n|cffffd100Tier:|r %d   |cffffd100Level:|r %d\n|cffffd100Bosser:|r %d   |cffffd100Instanser:|r %d")
              :format(curT, UnitLevel("player"), kills, insts)

    local acc = DeepwardAccount
    if acc then
        local goldG   = math.floor((acc.gold or 0) / 10000)
        local playedH = (acc.played or 0) / 3600
        s = s .. ("\n\n|cffffd100Kontoen|r\n|cffffd100Høyeste tier nådd:|r %s\n|cffffd100Karakterer:|r %d   |cffffd100Bosser:|r %d\n|cffffd100Instanser:|r %d   |cffffd100Gull:|r %dg\n|cffffd100Spilletid:|r %.1ft")
                 :format(tlabel(acc.highTier), acc.chars, acc.kills, acc.cleared, goldG, playedH)
    else
        -- account stats not arrived yet: fall back to this char's own highest reached
        local maxT = (DeepwardLive and DeepwardLive.max) or curT
        s = s .. ("\n\n|cffffd100Høyeste tier nådd:|r %s"):format(tlabel(maxT))
    end
    frame.journeyText:SetText(s)
end

-- Bump a role count in the chosen bot comp, clamped to [0, free slots] (total can't exceed the slots
-- bots will fill). Any manual change switches OFF Auto.
local function AdjustComp(key, delta)
    EnsureDB()
    local c = DeepwardTiersDB.botComp
    DeepwardTiersDB.botAuto = false
    local slots = BotSlotCount()
    local others = (c.t + c.h + c.d) - (c[key] or 0)
    local newv = (c[key] or 0) + delta
    if newv < 0 then newv = 0 end
    if others + newv > slots then newv = slots - others end
    if newv < 0 then newv = 0 end
    c[key] = newv
    if RenderComp then RenderComp() end
end

RenderComp = function()
    if not frame or not frame.compHeader then return end
    EnsureDB()
    local slots = BotSlotCount()
    frame.compHeader:SetText(("Bot comp — %d slot%s"):format(slots, slots == 1 and "" or "s"))
    if DeepwardTiersDB.botAuto then frame.autoBtn:LockHighlight() else frame.autoBtn:UnlockHighlight() end
    local c = DeepwardTiersDB.botComp
    for _, s in ipairs(frame.steppers or {}) do
        s.cnt:SetText(tostring(c[s.key] or 0))
        if DeepwardTiersDB.botAuto then s.cnt:SetTextColor(0.5, 0.5, 0.5) else s.cnt:SetTextColor(1, 1, 1) end
    end
    if frame.compRemain then
        local rem = slots - (c.t + c.h + c.d)
        if DeepwardTiersDB.botAuto then
            frame.compRemain:SetText("|cff909090server fills the slots|r")
        elseif rem == 0 then
            frame.compRemain:SetText("|cff40ff40comp ready|r")
        else
            frame.compRemain:SetText(("|cffff8040%d unassigned|r"):format(rem))
        end
    end
end

RenderRoster = function()
    if not frame or not frame.rosterText then return end
    if not DeepwardRoster or #DeepwardRoster == 0 then
        frame.rosterText:SetText("|cffa0a0a0(just you)|r")
        return
    end
    local abbr = { tank = "|cff4080ffTank|r", healer = "|cff40ff40Heal|r", dps = "|cffff8040DPS|r" }
    local parts = {}
    for _, m in ipairs(DeepwardRoster) do
        table.insert(parts, (m.name or "?") .. "  " .. (abbr[m.role] or "|cff909090?|r"))
    end
    frame.rosterText:SetText(table.concat(parts, "\n"))
end

-- Left-menu row label: mark the current tier "(current)" and every tier you've moved past with a
-- green checkmark. Recomputed on open + on every live sync so the marker follows a tier-up without a
-- reload. (Completed = below your current tier — you can only go up by clearing, so past == cleared.)
local function SetTierLabel(b)
    if not b or not b.label then return end
    local cur = CurrentTierId()
    local tag
    if b.tierId == cur then
        -- current tier: a bright yellow raid-target star marker (no "(current)" text per request)
        tag = "  |TInterface\\TargetingFrame\\UI-RaidTargetingIcons:20:20:0:0:256:256:0:64:0:64|t"
    elseif b.tierId < cur then
        tag = "  |TInterface\\RaidFrame\\ReadyCheck-Ready:18:18:0:0|t"   -- completed
    else
        tag = ""
    end
    b.label:SetText(("Tier %d%s"):format((b.tierId == 66) and 9 or b.tierId, tag))   -- 66 = the raid capstone, shown as Tier 9
end

local function RefreshTierLabels()
    for _, b in ipairs(tierButtons) do SetTierLabel(b) end
end

-- Top summary line ("Current tier: N • Level L"). Refreshed with the labels so a tier-up shows here
-- immediately too (it was previously set once at build time and went stale on advance).
local function UpdateSummary()
    if not frame or not frame.summary then return end
    local lvl = (UnitLevel and UnitLevel("player")) or 0
    frame.summary:SetText(("Current tier: %d   •   Level %d"):format(CurrentTierId(), lvl))
end

-- Persisted role choice (Tank / DPS / Healer). The server-side party fill (next build)
-- composes Tank + 3 DPS + Healer around this role.
DeepwardTiersDB = DeepwardTiersDB or {}
DeepwardTiersDB.role = DeepwardTiersDB.role or "dps"
if DeepwardTiersDB.fillBots == nil then DeepwardTiersDB.fillBots = true end
-- Bot composition (for the slots bots fill). Auto = server decides (1T/1H/rest DPS around the humans).
if DeepwardTiersDB.botAuto == nil then DeepwardTiersDB.botAuto = true end
DeepwardTiersDB.botComp = DeepwardTiersDB.botComp or { t = 1, h = 1, d = 2 }

local function UpdateRoleButtons()
    if not frame or not frame.roleButtons then return end
    for _, rb in ipairs(frame.roleButtons) do
        if rb.role == DeepwardTiersDB.role then rb:LockHighlight() else rb:UnlockHighlight() end
    end
end

-- Enter is the way IN. Hearthstone is the only way OUT (CHANGE-NOTES 2026-08-18), so inside an
-- instance the button is disabled with a hint instead of offering Leave.
local function UpdateEnterButton()
    if not frame or not frame.enterBtn then return end
    if IsInInstance() then
        frame.enterBtn:SetText("Hearthstone to Exit")
        frame.enterBtn:Disable()
    else
        frame.enterBtn:SetText("Play with bots")
        frame.enterBtn:Enable()
    end
end

-- Set the detail panel's background to a dungeon's loading-screen splash (or the parchment
-- fallback when nil / a tier has no art yet).
local function SetPanelArt(path)
    if not frame or not frame.artBg then return end
    if path then
        frame.artBg:SetTexture(path)
        frame.artBg:SetTexCoord(0.10, 0.90, 0.05, 0.95)   -- SetTexture resets TexCoord — re-apply the crop
        frame.artBg:Show()
        frame.artFallback:Hide()
    else
        frame.artBg:Hide()
        frame.artFallback:Show()
    end
end

local function RenderDetail(tier)
    if not tier then
        return
    end

    local dgs = tier.dungeons or {}
    if selectedDungeonIdx < 1 or selectedDungeonIdx > #dgs then selectedDungeonIdx = 1 end
    local sel = dgs[selectedDungeonIdx]
    local onCurrent = (tier.id == CurrentTierId())

    -- Bottom-band vertical plan. Enter/Leave is the primary; Advance/Travel is an optional secondary
    -- that stacks a row below it. When both show, the role cluster must sit higher to clear the
    -- two-button stack; when only Enter shows, the role cluster drops down close to it (what the
    -- screenshot asked for). These Y values (from the panel bottom) drive selectors + roles + actions.
    local enterVisible   = IsInInstance() or onCurrent
    local maxReached     = (DeepwardLive and DeepwardLive.max) or CurrentTierId()
    -- Advance shows at your cleared frontier — OR always for the owner account (force-advance without
    -- clearing/quests; the server .advance mirrors the same admin bypass).
    local canAdvanceGate = IsTierClearedLive(tier) or (DeepwardLive and DeepwardLive.admin)
    local advanceVisible = onCurrent and not IsInInstance()
        and (CurrentTierId() == maxReached) and (CurrentTierId() < #TIERS) and canAdvanceGate
    -- Travel (.movetier snapshot swap) is DISABLED (2026-08-17): it wiped gear + crashed on load.
    -- Hidden until a safe in-game item-move rework exists. (GM .settier still works for testing.)
    local travelVisible  = false
    local twoRows    = enterVisible and travelVisible   -- Advance is now a standalone top-right button, not a bottom-band row
    -- Bottom-band sits LOW in the beige strip under the splash: role cluster just below the art, Enter
    -- at the very bottom. (Lower Y = closer to the panel bottom.)
    local roleBtnY   = twoRows and 78 or 48   -- role cluster sits low (instance selectors moved to the top now)
    local roleLabelY = roleBtnY + 46   -- "Your role:" sits clear ABOVE the role icons (they're ~40px tall)

    local dispId = (tier.id == 66) and 9 or tier.id   -- 66 = the raid capstone, shown as Tier 9
    frame.detailTitle:SetText(sel and ("Tier %d — %s"):format(dispId, sel.name) or ("Tier %d — %s"):format(dispId, tier.name))

    -- Clear-status badge (prominent, under the title).
    if frame.statusBadge then
        if sel then
            local tot, kn = (sel.bosses and #sel.bosses) or 0, 0
            if sel.bosses then for _, b in ipairs(sel.bosses) do if IsBossKilled(b) then kn = kn + 1 end end end
            if IsDungeonCleared(sel) then
                frame.statusBadge:SetText("|cff40ff40STATUS: Cleared|r")
            else
                frame.statusBadge:SetText(("|cffff6060STATUS: Not Cleared (%d/%d)|r"):format(kn, tot))
            end
            frame.statusBadge:Show()
        else
            frame.statusBadge:Hide()
        end
    end

    -- The panel now shows ONE dungeon at a time (the selected one) — background + info both follow
    -- the selection, and the Enter button targets it.
    local lines = {}
    -- Overall tier progress: how many of this tier's instances are cleared vs the requirement to ascend.
    do
        local clearedN, reqN = CountClearedDungeons(tier), TierReq(tier)
        local col = (clearedN >= reqN) and "cff40ff40" or "cffffd100"
        table.insert(lines, ("|cffffd100Instanser klart:|r |%s%d / %d|r  |cff808080(krav %d for opprykk)|r"):format(col, clearedN, #tier.dungeons, reqN))
    end
    table.insert(lines, ("|cffffd100Level:|r %d"):format(tier.level))   -- wipe budget removed (no wipe penalty in the living-instance model)
    table.insert(lines, ("|cffffd100Gear:|r %s"):format(tier.gear))
    table.insert(lines, " ")
    if sel then
        local mark = IsDungeonCleared(sel) and "|cff40ff40cleared|r" or "|cffff8040not cleared|r"
        table.insert(lines, ("|cffffffff%s|r  — %s"):format(sel.name, mark))
        local subp = {}
        if sel.loc then table.insert(subp, sel.loc) end
        if sel.range then table.insert(subp, "lvl " .. sel.range) end
        if #subp > 0 then
            table.insert(lines, ("|cffa0a0a0%s|r"):format(table.concat(subp, "  ·  ")))
        end
        if sel.bosses and #sel.bosses > 0 then
            local killedN = 0
            for _, b in ipairs(sel.bosses) do if IsBossKilled(b) then killedN = killedN + 1 end end
            table.insert(lines, ("|cffffd100Bosses (%d/%d):|r  |cff808080(all required to clear)|r"):format(killedN, #sel.bosses))
            for _, b in ipairs(sel.bosses) do
                if IsBossKilled(b) then
                    table.insert(lines, ("   %s |cff40ff40%s|r"):format(BOSS_KILLED_ICON, b.n))   -- slain
                else
                    table.insert(lines, ("   %s |cffc8c8c8%s|r"):format(BOSS_ALIVE_ICON, b.n))    -- still up
                end
            end
        end
        if sel.desc then
            table.insert(lines, " ")
            table.insert(lines, ("|cffc8c8c8%s|r"):format(sel.desc))
        end
    end
    frame.detailBody:SetText(table.concat(lines, "\n"))
    -- Resize the scroll child to the text's wrapped height so the scrollbar knows its range
    -- (UIPanelScrollFrameTemplate fires OnScrollRangeChanged when the child rect changes).
    if frame.bodyChild then
        frame.bodyChild:SetHeight((frame.detailBody:GetStringHeight() or 0) + 8)
    end

    SetPanelArt(sel and sel.art or nil)
    frame.selectedMap = sel and sel.map or nil

    -- Dungeon selector buttons — shown for ANY tier with more than one løype, whatever tier you're
    -- on (browse/preview is always allowed; entering is still gated to your current tier via the
    -- Enter button). Clicking one swaps the background + info to that dungeon; on your current tier
    -- the Enter button then targets whatever is selected. Sit right above the role row.
    local showSelectors = (#dgs > 1)
    -- Instance selectors flow as a wrapping row across the TOP of the info panel, right under the
    -- header's blue line (2 per row, left->right). Browse/preview any dungeon; entering is still gated
    -- to your current tier via the Enter button.
    local BTN_W, BTN_H, GAP, PER_ROW = 292, 24, 6, 2
    local n = showSelectors and math.min(#dgs, #frame.dungeonBtns) or 0
    for i, db in ipairs(frame.dungeonBtns) do
        local d = dgs[i]
        if d and i <= n then
            local col = (i - 1) % PER_ROW
            local row = math.floor((i - 1) / PER_ROW)
            db:SetText(d.name)
            db:SetSize(BTN_W, BTN_H)
            db:ClearAllPoints()
            db:SetPoint("TOPLEFT", frame.rightPanel, "TOPLEFT", 14 + col * (BTN_W + GAP), -6 - row * (BTN_H + GAP))
            if i == selectedDungeonIdx then db:LockHighlight() else db:UnlockHighlight() end
            db:SetScript("OnClick", function()
                selectedDungeonIdx = i
                RenderDetail(tier)                     -- swap background + info to the picked dungeon
            end)
            db:SetScript("OnEnter", nil)
            db:SetScript("OnLeave", nil)
            db:Show()
        else
            db:Hide()
        end
    end

    -- Role cluster: shown ONLY on your current tier — that's the only tier you can Enter, so picking a
    -- role anywhere else is meaningless. On other tiers the panel is pure browse/preview, so hide it.
    if onCurrent then
        frame.roleLabel:Show()
        frame.roleLabel:ClearAllPoints()
        frame.roleLabel:SetPoint("BOTTOM", frame.rightPanel, "BOTTOM", 0, roleLabelY)
        for i, rb in ipairs(frame.roleButtons) do
            rb:ClearAllPoints()
            rb:SetPoint("BOTTOM", frame.rightPanel, "BOTTOM", (i - 2) * 68, roleBtnY)   -- wider gap between icons
            rb:Show()
        end
    else
        frame.roleLabel:Hide()
        for _, rb in ipairs(frame.roleButtons) do rb:Hide() end
    end

    -- Bottom action buttons. Enter/Leave is the PRIMARY and is always centred under the role row.
    -- A secondary (Advance on your cleared frontier, or Travel to another reached tier) drops to a
    -- centred line directly BELOW Enter/Leave. Enter and Travel can't co-occur (Enter needs the
    -- current tier / in-instance; Travel needs a different reached tier), and Advance is current-tier
    -- only — so at most two buttons ever stack. (Visibility booleans computed at the top of RenderDetail.)

    -- Only a solo player or the party/raid LEADER drives the run (queues + starts a bot run). A non-leader
    -- doesn't get "Play with bots" or "Find player group" — they get "Go to group leader" instead.
    local grouped  = (GetNumPartyMembers() or 0) > 0 or (GetNumRaidMembers() or 0) > 0
    local canQueue = (not grouped) or IsPartyLeader() or IsRaidLeader()

    -- Left-column action stack, horizontally CENTERED on the left panel and stacked BOTTOM-UP (top->bottom:
    -- Play with bots -> Ascend at the Herald). Bottom-anchored, so a hidden button leaves no gap.
    -- "Go to group leader" is NOT here — for a non-leader it takes the center "Find player group" slot.
    do
        local prev = nil   -- lowest visible button so far (nil = anchor to panel bottom)
        local function stackUp(btn, shown)
            if not btn then return end
            if not shown then btn:Hide(); return end
            btn:ClearAllPoints()
            if prev then
                btn:SetPoint("BOTTOM", prev, "TOP", 0, 6)
            else
                btn:SetPoint("BOTTOM", frame.leftPanel, "BOTTOM", 0, 14)
            end
            btn:Show()
            prev = btn
        end
        stackUp(frame.advanceBtn, advanceVisible)
        -- "Hearthstone to Exit" shows for everyone inside an instance; "Play with bots" only for solo/leader.
        stackUp(frame.enterBtn, IsInInstance() or (onCurrent and canQueue))
    end

    -- Resolve the single bottom-band secondary (Travel only now; Advance moved to the top-right).
    local secondary = nil
    if travelVisible then
        frame.travelTier = tier.id
        frame.travelBtn:SetText(("Travel to Tier %d"):format(tier.id))
        secondary = frame.travelBtn
    end

    frame.travelBtn:Hide()
    frame.playersBtn:Hide()
    frame.toLeaderBtn:Hide()
    if frame.fillBotsChk then frame.fillBotsChk:Hide() end

    local PRIMARY_Y, LOWER_Y = 52, 12
    local function placeAt(btn, x, y)
        btn:ClearAllPoints()
        btn:SetPoint("BOTTOM", frame.rightPanel, "BOTTOM", x, y)
        btn:Show()
    end
    if canQueue then
        -- Find player group: centred in the right panel (current tier, outside an instance).
        if onCurrent and not IsInInstance() then
            placeAt(frame.playersBtn, 0, LOWER_Y)
            if frame.fillBotsChk then   -- Fill-with-bots checkbox on the same row, far-right edge
                frame.fillBotsChk:ClearAllPoints()
                frame.fillBotsChk:SetPoint("RIGHT", frame.rightPanel, "BOTTOMRIGHT", -14, LOWER_Y + 15)
                frame.fillBotsChk:SetChecked(DeepwardTiersDB and DeepwardTiersDB.fillBots)
                frame.fillBotsChk:Show()
            end
        end
    elseif grouped then
        -- Non-leader: can't queue — offer "Go to group leader" in the center slot instead.
        placeAt(frame.toLeaderBtn, 0, LOWER_Y)
    end
    if secondary then
        placeAt(secondary, 0, PRIMARY_Y)
    end
end

local function SelectTier(id)
    selectedId = id
    selectedDungeonIdx = 1   -- start each tier on its first dungeon
    RefreshTierLabels()      -- keep (current)/checkmarks in sync with live tier
    UpdateSummary()          -- keep the top "Current tier: N" line in sync too
    for _, b in ipairs(tierButtons) do
        if b.tierId == id then
            b.bg:Show()
        else
            b.bg:Hide()
        end
    end
    for _, t in ipairs(TIERS) do
        if t.id == id then
            RenderDetail(t)
            break
        end
    end
end

local TIER_BTN_W, TIER_BTN_H = 84, 30   -- horizontal tier bar: one pill per tier, flowing left->right
local function BuildTierList(parent)
    local prev
    -- Horizontal bar: Tier 1 leftmost, ascending to the right (like the website's tier selector).
    for i = 1, #TIERS do
        local t = TIERS[i]
        local b = CreateFrame("Button", nil, parent)
        b:SetSize(TIER_BTN_W, TIER_BTN_H)
        if prev then
            b:SetPoint("LEFT", prev, "RIGHT", 4, 0)
        else
            b:SetPoint("LEFT", 0, 0)
        end
        b.tierId = t.id

        -- selection highlight
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetTexture(0.6, 0.5, 0.2, 0.45)
        b.bg:Hide()

        local label = b:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("CENTER", 0, 0)
        b.label = label
        SetTierLabel(b)   -- "Tier N" + current-star / cleared-check, per live tier

        b:SetScript("OnClick", function() SelectTier(t.id) end)
        b:SetScript("OnEnter", function() b.bg:Show() end)
        b:SetScript("OnLeave", function() if b.tierId ~= selectedId then b.bg:Hide() end end)

        table.insert(tierButtons, b)
        prev = b
    end
end

-- Custom role-check popup (idea #6, safe variant). The leader fires .dwrolecheck -> the server relays an
-- "RC=" message to every member -> this pops up a Tank/DPS/Healer picker. Accept sends .dwrole, which
-- updates the live roster. Not the native LFG popup -> no LFG state-machine risk.
local roleCheckFrame
local function ShowRoleCheckPopup(leaderName)
    EnsureDB()
    if not roleCheckFrame then
        local f = CreateFrame("Frame", "DeepwardRoleCheckPopup", UIParent)
        f:SetSize(290, 156)
        f:SetPoint("CENTER", 0, 140)
        f:SetFrameStrata("DIALOG")
        f:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        f:EnableMouse(true)
        table.insert(UISpecialFrames, "DeepwardRoleCheckPopup")   -- ESC closes
        f.title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        f.title:SetPoint("TOP", 0, -16)
        f.sel = nil
        f.roleBtns = {}
        local roleOrder = { "tank", "dps", "healer" }
        for i, r in ipairs(roleOrder) do
            local rb = MakeRoleIcon(f, r, 44)
            rb:SetPoint("TOP", f, "TOP", (i - 2) * 58, -46)
            rb:SetScript("OnClick", function()
                f.sel = rb.role
                for _, b in ipairs(f.roleBtns) do
                    if b == rb then b:LockHighlight() else b:UnlockHighlight() end
                end
            end)
            f.roleBtns[i] = rb
        end
        local accept = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        accept:SetSize(116, 26)
        accept:SetPoint("BOTTOM", f, "BOTTOM", -62, 16)
        accept:SetText("Accept")
        accept:SetScript("OnClick", function()
            local role = f.sel or DeepwardTiersDB.role or "dps"
            DeepwardTiersDB.role = role
            SendCmd(".dwrole " .. role)
            if UpdateRoleButtons then UpdateRoleButtons() end
            f:Hide()
        end)
        local cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        cancel:SetSize(92, 26)
        cancel:SetPoint("BOTTOM", f, "BOTTOM", 62, 16)
        cancel:SetText("Cancel")
        cancel:SetScript("OnClick", function() f:Hide() end)
        roleCheckFrame = f
    end
    roleCheckFrame.sel = DeepwardTiersDB.role or "dps"
    for _, b in ipairs(roleCheckFrame.roleBtns) do
        if b.role == roleCheckFrame.sel then b:LockHighlight() else b:UnlockHighlight() end
    end
    roleCheckFrame.title:SetText((leaderName and leaderName ~= "" and (leaderName .. "'s role check")) or "Role check")
    roleCheckFrame:Show()
end

-- Match-found accept dialog: the server proposes a full group ("P=<secs>") and gives you 30s to accept.
-- Accept -> ".dwqueue accept" then wait for the others; Decline -> ".dwqueue decline" and it dissolves;
-- run out the clock -> the server drops you. "P=waiting" = you accepted, "P=cancel" = the proposal ended.
local matchPopup
local function HideMatchPopup()
    if matchPopup then matchPopup.deadline = nil; matchPopup:Hide() end
end
local function SetMatchWaiting()
    if matchPopup and matchPopup:IsShown() then
        matchPopup.accepted = true
        matchPopup.accept:Disable()
        matchPopup.msg:SetText("Akseptert \226\128\148 venter p\195\165 de andre spillerne...")
    end
end
local function ShowMatchPopup(secs, isBots)
    EnsureDB()
    if not matchPopup then
        local f = CreateFrame("Frame", "DeepwardMatchPopup", UIParent)
        f:SetSize(330, 158)
        f:SetPoint("CENTER", 0, 160)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        f:EnableMouse(true)
        table.insert(UISpecialFrames, "DeepwardMatchPopup")   -- ESC closes (does not decline; server times out)
        f.title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        f.title:SetPoint("TOP", 0, -16)
        f.title:SetText("Gruppe funnet!")
        f.msg = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        f.msg:SetPoint("TOP", 0, -46)
        f.msg:SetWidth(290)
        f.timer = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        f.timer:SetPoint("TOP", 0, -80)
        f.accept = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.accept:SetSize(122, 26)
        f.accept:SetPoint("BOTTOM", f, "BOTTOM", -66, 16)
        f.accept:SetText("Accept")
        f.accept:SetScript("OnClick", function()
            SendCmd(".dwqueue accept")
            SetMatchWaiting()
        end)
        f.decline = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.decline:SetSize(122, 26)
        f.decline:SetPoint("BOTTOM", f, "BOTTOM", 66, 16)
        f.decline:SetText("Decline")
        f.decline:SetScript("OnClick", function()
            SendCmd(".dwqueue decline")
            HideMatchPopup()
        end)
        f:SetScript("OnUpdate", function(self)
            if not self.deadline then return end
            local left = self.deadline - GetTime()
            if left < 0 then left = 0 end
            self.timer:SetText(("%ds"):format(math.ceil(left)))
            if left <= 0 then
                self.deadline = nil
                self:Hide()   -- server enforces its own 30s deadline and drops non-accepters
            end
        end)
        matchPopup = f
    end
    local f = matchPopup
    f.accepted = false
    f.accept:Enable()
    if isBots then
        f.msg:SetText("En gruppe er klar (fylles med bots). Aksepter for \195\165 bli med.")
    else
        f.msg:SetText("En gruppe er klar. Aksepter for \195\165 bli med.")
    end
    f.deadline = GetTime() + (tonumber(secs) or 30)
    if PlaySound then pcall(PlaySound, "ReadyCheck") end   -- audible alert, like a ready check
    f:Show()
end

local function CreateUI()
    if frame then
        return
    end

    frame = CreateFrame("Frame", "DeepwardTiersFrame", UIParent)
    frame:SetSize(880, 680)
    frame:SetScale(1.12)   -- scale the whole panel up a touch for more breathing room
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:SetBackdropBorderColor(0.55, 0.72, 1.0)      -- blue-steel frame (titan theme)
    frame:SetBackdropColor(0.14, 0.19, 0.30, 1)        -- dark blue behind the stone fill
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    table.insert(UISpecialFrames, "DeepwardTiersFrame")   -- ESC closes it

    -- Opaque quest-log parchment behind the WHOLE window so nothing shows the game world through it
    -- (the dialog backdrop alone rendered see-through). The right-hand art panel is a child frame, so
    -- it still draws on top of this. Plain stretched texture — more reliable than a tiled backdrop bg.
    frame.bgParch = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame.bgParch:SetPoint("TOPLEFT", 6, -6)
    frame.bgParch:SetPoint("BOTTOMRIGHT", -6, 6)
    frame.bgParch:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble")   -- stone, tinted blue (titan/Ulduar theme)
    frame.bgParch:SetTexCoord(0, 1, 0, 1)
    frame.bgParch:SetVertexColor(0.42, 0.55, 0.78)   -- blue stone
    -- Solid OPAQUE fill UNDER the marble so nothing shows through the window (less see-through per request).
    frame.bgSolid = frame:CreateTexture(nil, "BACKGROUND", nil, -9)
    frame.bgSolid:SetPoint("TOPLEFT", 6, -6)
    frame.bgSolid:SetPoint("BOTTOMRIGHT", -6, 6)
    frame.bgSolid:SetTexture(0.05, 0.07, 0.13, 1)   -- 3.3.5 solid-colour SetTexture(r,g,b,a): opaque dark blue

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOP", 0, -20)
    title:SetText("Deepward — Progression")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    frame.summary = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    frame.summary:SetPoint("TOP", title, "BOTTOM", 0, -8)

    -- (Removed the "N slain" header badge per request — the bosses-slain count now lives in the
    -- left-column "Din reise" summary instead. UpdateBadge() is a guarded no-op without frame.badge.)

    -- Gold divider under the header (achievements-frame banner separation).
    local hdiv = frame:CreateTexture(nil, "ARTWORK")
    hdiv:SetHeight(2)
    hdiv:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -92)
    hdiv:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -92)
    hdiv:SetTexture(0.35, 0.62, 0.95, 0.9)   -- blue divider (titan theme)

    -- Horizontal tier bar across the top (like the website's tier selector): Tier 1..N left->right,
    -- just under the header's blue divider. Replaces the old vertical tier list in the left column.
    local tierBar = CreateFrame("Frame", nil, frame)
    tierBar:SetPoint("TOPLEFT", 24, -98)
    tierBar:SetSize(832, TIER_BTN_H)
    BuildTierList(tierBar)

    -- Left column: this character's JOURNEY summary on top, Group + bot settings below (kept in place).
    -- Sits under the tier bar. Parchment/stone fill + border so it reads as a solid field.
    local left = CreateFrame("Frame", nil, frame)
    frame.leftPanel = left   -- referenced by RenderDetail to horizontally center the action-button stack
    left:SetPoint("TOPLEFT", 24, -138)
    left:SetSize(210, 510)
    left:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
    })
    left:SetBackdropBorderColor(0.55, 0.72, 1.0)   -- blue-steel column border
    -- Opaque parchment fill for the menu column (the backdrop bgFile rendered see-through).
    left.parch = left:CreateTexture(nil, "BACKGROUND", nil, -7)
    left.parch:SetPoint("TOPLEFT", 5, -5)
    left.parch:SetPoint("BOTTOMRIGHT", -5, 5)
    left.parch:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble")
    left.parch:SetTexCoord(0, 1, 0, 1)
    left.parch:SetVertexColor(0.42, 0.55, 0.78)   -- blue stone, matches the main background

    -- Char journey summary (top of the left column). Filled live by UpdateJourney().
    local jHeader = left:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    jHeader:SetPoint("TOPLEFT", 12, -12)
    jHeader:SetText("|cffffd100Din reise|r")
    frame.journeyText = left:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.journeyText:SetPoint("TOPLEFT", jHeader, "BOTTOMLEFT", 0, -10)
    frame.journeyText:SetWidth(184)
    frame.journeyText:SetJustifyH("LEFT")
    frame.journeyText:SetJustifyV("TOP")
    frame.journeyText:SetText("")

    -- Bottom of the left column: live group roster + bot-comp editor (idea #6). A thin divider on top.
    local gdiv = left:CreateTexture(nil, "ARTWORK")
    gdiv:SetHeight(2)
    gdiv:SetPoint("TOPLEFT", left, "TOPLEFT", 10, -200)     -- fixed spot: Group + bot block stays low-left
    gdiv:SetPoint("TOPRIGHT", left, "TOPRIGHT", -10, -200)
    gdiv:SetTexture(0.5, 0.4, 0.15, 0.7)

    local gHeader = left:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    gHeader:SetPoint("TOPLEFT", gdiv, "BOTTOMLEFT", 4, -6)
    gHeader:SetText("|cffffd100Group|r")

    -- Role Check: the leader starts one; every member gets the role popup (server checks leader).
    frame.roleCheckBtn = CreateFrame("Button", nil, left, "UIPanelButtonTemplate")
    frame.roleCheckBtn:SetSize(86, 18)
    frame.roleCheckBtn:SetPoint("LEFT", gHeader, "RIGHT", 10, 0)
    frame.roleCheckBtn:SetText("Role Check")
    frame.roleCheckBtn:SetScript("OnClick", function() SendCmd(".dwrolecheck") end)

    frame.rosterText = left:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.rosterText:SetPoint("TOPLEFT", gHeader, "BOTTOMLEFT", 2, -4)
    frame.rosterText:SetWidth(172)
    frame.rosterText:SetJustifyH("LEFT")
    frame.rosterText:SetJustifyV("TOP")
    frame.rosterText:SetText("|cffa0a0a0(just you)|r")

    frame.compHeader = left:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.compHeader:SetPoint("TOPLEFT", frame.rosterText, "BOTTOMLEFT", -2, -12)
    frame.compHeader:SetText("|cffffd100Bot comp|r")

    frame.autoBtn = CreateFrame("Button", nil, left, "UIPanelButtonTemplate")
    frame.autoBtn:SetSize(58, 20)
    frame.autoBtn:SetPoint("TOPLEFT", frame.compHeader, "BOTTOMLEFT", 2, -4)
    frame.autoBtn:SetText("Auto")
    frame.autoBtn:SetScript("OnClick", function()
        DeepwardTiersDB.botAuto = true
        RenderComp()
    end)

    -- Three steppers: T / H / D (each "-  n  +"), laid out to the right of the Auto button.
    frame.steppers = {}
    local sdefs = { { key = "t", role = "tank" }, { key = "h", role = "healer" }, { key = "d", role = "dps" } }
    for i, def in ipairs(sdefs) do
        local rowY = -4 - (i - 1) * 24
        local lbl = left:CreateTexture(nil, "ARTWORK")
        lbl:SetSize(18, 18)
        lbl:SetPoint("TOPLEFT", frame.autoBtn, "BOTTOMLEFT", 2, rowY)
        lbl:SetTexture(ROLE_TEX[def.role])
        local minus = CreateFrame("Button", nil, left)
        minus:SetSize(24, 24)
        minus:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
        minus:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
        minus:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-Down")
        minus:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
        local cnt = left:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
        cnt:SetPoint("LEFT", minus, "RIGHT", 6, 0)
        cnt:SetWidth(22)
        cnt:SetJustifyH("CENTER")
        cnt:SetText("0")
        local plus = CreateFrame("Button", nil, left)
        plus:SetSize(24, 24)
        plus:SetPoint("LEFT", cnt, "RIGHT", 6, 0)
        plus:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
        plus:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-Down")
        plus:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
        minus:SetScript("OnClick", function() AdjustComp(def.key, -1) end)
        plus:SetScript("OnClick", function() AdjustComp(def.key, 1) end)
        frame.steppers[i] = { key = def.key, lbl = lbl, minus = minus, cnt = cnt, plus = plus }
    end

    frame.compRemain = left:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.compRemain:SetPoint("TOPLEFT", frame.steppers[3].lbl, "BOTTOMLEFT", 0, -6)
    frame.compRemain:SetText("")

    -- Right: detail area. Background is the selected dungeon's loading-screen splash, dimmed so the
    -- text stays readable. (Art paths come from the client's LoadingScreens.dbc; the BLPs ship with
    -- the client.) Layers: art (BACKGROUND) < dark overlay (ARTWORK) < text (OVERLAY).
    local right = CreateFrame("Frame", nil, frame)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 12, 0)
    right:SetSize(612, 510)   -- matches the left column height (both sit under the top tier bar now)

    frame.artBg = right:CreateTexture(nil, "BACKGROUND")
    frame.artBg:SetAllPoints()
    frame.artBg:SetTexCoord(0.10, 0.90, 0.05, 0.95)   -- crop the splash toward the panel's aspect

    -- Parchment fallback, shown when a tier/dungeon has no art (keeps the panel from going black).
    frame.artFallback = right:CreateTexture(nil, "BACKGROUND")
    frame.artFallback:SetAllPoints()
    frame.artFallback:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble")
    frame.artFallback:SetVertexColor(0.42, 0.55, 0.78, 1)   -- blue stone fallback (matches the theme)

    local dark = right:CreateTexture(nil, "ARTWORK")
    dark:SetAllPoints()
    dark:SetTexture(0, 0, 0, 0.62)                     -- dim busy art for readable text

    frame.rightPanel = right

    -- Refresh (icon only, no label) bottom-left of the instance view: forces a full server-side reconcile
    -- (.dwrefresh) so a boss kill the panel missed (far group-mate / older run) is recovered on demand.
    frame.refreshBtn = CreateFrame("Button", nil, right)
    frame.refreshBtn:SetSize(30, 30)
    frame.refreshBtn:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 12, 12)
    frame.refreshBtn:SetFrameLevel(right:GetFrameLevel() + 20)
    -- Custom refresh icon (orange circular arrows) shipped with the addon as a 128px TGA.
    frame.refreshBtn:SetNormalTexture("Interface\\AddOns\\DeepwardTiers\\refresh")
    frame.refreshBtn:SetPushedTexture("Interface\\AddOns\\DeepwardTiers\\refresh")
    frame.refreshBtn:SetHighlightTexture("Interface\\AddOns\\DeepwardTiers\\refresh", "ADD")
    frame.refreshBtn:SetScript("OnClick", function()
        SendCmd(".dwrefresh")
        RequestSync()
    end)
    frame.refreshBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Synk fremgang")
        GameTooltip:AddLine("Henter tapte boss-kill fra quest-loggen.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    frame.refreshBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Title sits below a top margin so it clears the splash's own banner/logo instead of jamming
    -- against the top edge.
    frame.detailTitle = right:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    frame.detailTitle:SetPoint("TOPLEFT", 18, -110)   -- sits just under the splash's WARCRAFT logo

    -- Prominent clear-status badge under the title (mockup: "STATUS: Not Cleared (x/y)").
    frame.statusBadge = right:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.statusBadge:SetPoint("TOPLEFT", frame.detailTitle, "BOTTOMLEFT", 2, -6)

    -- Body lives in a scroll frame spanning from below the title down to just above the button row,
    -- so long descriptions scroll within the beige field instead of spilling over the buttons.
    local bodyScroll = CreateFrame("ScrollFrame", "DeepwardTiersBodyScroll", right, "UIPanelScrollFrameTemplate")
    bodyScroll:SetPoint("TOPLEFT", 18, -170)           -- top sits below the title + STATUS badge (avoids overlapping Level)
    bodyScroll:SetPoint("BOTTOMRIGHT", -30, 112)       -- extends down to just above "Your role:" (instance selectors moved to the top now)
    local bodyChild = CreateFrame("Frame", nil, bodyScroll)
    bodyChild:SetSize(556, 10)
    bodyScroll:SetScrollChild(bodyChild)
    frame.bodyChild = bodyChild

    frame.detailBody = bodyChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightLeft")
    frame.detailBody:SetPoint("TOPLEFT", 0, 0)
    frame.detailBody:SetWidth(556)                      -- fixed width → wraps; height drives the scroll range
    frame.detailBody:SetFont("Fonts\\FRIZQT__.TTF", 18) -- larger, easier to read
    frame.detailBody:SetSpacing(3)
    frame.detailBody:SetJustifyH("LEFT")
    frame.detailBody:SetJustifyV("TOP")

    -- Per-dungeon "enter this løype" buttons (max 2 in tiers 1-3). Configured per selected tier in
    -- RenderDetail; each sends ".enter <role> <map>" so you can pick a specific dungeon (incl. one
    -- you've already cleared, e.g. to run it again with a friend).
    frame.dungeonBtns = {}
    for i = 1, 6 do   -- up to 6 instances in a tier (tier 8); RenderDetail sizes + flows them at the top
        local db = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
        db:SetSize(292, 24)
        db:Hide()
        frame.dungeonBtns[i] = db
    end

    -- Role selector (Tank / DPS / Healer): your slot in the auto-formed 5-man
    -- (Tank + 3 DPS + Healer). Persisted; the server-side party fill uses it.
    frame.roleLabel = right:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.roleLabel:SetPoint("BOTTOM", right, "BOTTOM", 0, 126)   -- repositioned per-render
    frame.roleLabel:SetText("Your role:")

    frame.roleButtons = {}
    local roleOrder = { "tank", "dps", "healer" }
    local isz = 40
    for i, r in ipairs(roleOrder) do
        local rb = MakeRoleIcon(right, r, isz)
        rb:SetPoint("BOTTOM", right, "BOTTOM", (i - 2) * 68, 92)   -- placeholder; RenderDetail repositions
        rb:SetScript("OnClick", function()
            DeepwardTiersDB.role = rb.role
            UpdateRoleButtons()
            SendCmd(".dwrole " .. rb.role)   -- update the live group roster for everyone
        end)
        frame.roleButtons[i] = rb
    end

    -- Enter button: fires the server-side ".enter" to teleport into the current tier's dungeon
    -- (or ".leave" when already inside). The server decides where + enforces the rules.
    frame.enterBtn = CreateFrame("Button", nil, left, "UIPanelButtonTemplate")
    frame.enterBtn:SetSize(190, 28)
    frame.enterBtn:SetPoint("TOPLEFT", frame.compRemain, "BOTTOMLEFT", -2, -10)   -- LEFT column, right under the bot comp
    frame.enterBtn:SetFrameLevel(left:GetFrameLevel() + 10)
    frame.enterBtn:SetText("Play with bots")
    frame.enterBtn:SetScript("OnClick", function()
        if IsInInstance() then
            print("|cff33ff99Deepward:|r Use your Hearthstone to leave — it is your only way out.")
            return
        end
        EnterDungeon(frame.selectedMap)   -- the currently selected dungeon (nil -> server auto-routes)
        frame:Hide()
    end)

    -- Play players: matchmaker. Queues you (solo) for the tier; matches 5 real players or bot-fills after
    -- 60s. While queued the button becomes "Leave Queue" and shows the countdown. Fires .dwqueue.
    frame.playersBtn = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
    frame.playersBtn:SetSize(180, 30)   -- same size as Play bot group; placed beside it in RenderDetail
    frame.playersBtn:SetText("Find player group")
    frame.playersQueued = false
    frame.playersBtn:SetScript("OnClick", function()
        if IsInInstance() then return end
        if frame.playersQueued then
            SendCmd(".dwqueue leave")
        else
            -- pass the Fill-with-bots choice: 1 = bot-fill at 60s, 0 = players-only (60s + 120s, no bots)
            local fill = (DeepwardTiersDB and DeepwardTiersDB.fillBots) and 1 or 0
            SendCmd(".dwqueue random " .. fill)
        end
    end)

    -- "Fill with bots" checkbox: sits on the SAME row as Find player group, pushed as far right as the
    -- panel allows. Checked (default) -> empty slots fill with bots at the 60s timeout. Unchecked ->
    -- a players-only search: chat says no group yet, keeps looking 120s more, then gives up (no bots).
    frame.fillBotsChk = CreateFrame("CheckButton", nil, right, "UICheckButtonTemplate")
    frame.fillBotsChk:SetSize(22, 22)
    frame.fillBotsChk.text = frame.fillBotsChk:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.fillBotsChk.text:SetPoint("RIGHT", frame.fillBotsChk, "LEFT", -4, 0)
    frame.fillBotsChk.text:SetText("Fill with bots")
    frame.fillBotsChk:SetScript("OnClick", function(self)
        DeepwardTiersDB.fillBots = self:GetChecked() and true or false
    end)
    frame.fillBotsChk:SetScript("OnShow", function(self)
        self:SetChecked(DeepwardTiersDB and DeepwardTiersDB.fillBots)
    end)

    -- Ascend reminder: advancement is a PERMANENT, confirmed choice made at the Deepward Herald in
    -- Dalaran (native point-of-no-return popup + Gaar-Token carry-cap warning) — NOT from the panel.
    -- This button no longer advances; it just points you to the Herald. Shown when you're eligible.
    frame.advanceBtn = CreateFrame("Button", nil, left, "UIPanelButtonTemplate")
    frame.advanceBtn:SetSize(190, 28)
    frame.advanceBtn:SetPoint("BOTTOM", left, "BOTTOM", 0, 12)   -- bottom of the LEFT column, under the bot comp
    frame.advanceBtn:SetFrameLevel(left:GetFrameLevel() + 10)
    frame.advanceBtn:SetText("Ascend at the Herald")
    frame.advanceBtn:SetScript("OnClick", function()
        print("|cff33ff99Deepward:|r Rykk opp hos the Deepward Herald i Dalaran — opprykk er permanent, so det bekreftes der (og GT over taket mistes, bruk dem forst).")
    end)

    -- Go to leader: safety net for a missed auto-pull — teleports you to the group leader (their instance
    -- or Dalaran). Sits just above Ascend in the left column; shown only while you're in a group.
    frame.toLeaderBtn = CreateFrame("Button", nil, left, "UIPanelButtonTemplate")
    frame.toLeaderBtn:SetSize(190, 28)
    frame.toLeaderBtn:SetPoint("BOTTOM", frame.advanceBtn, "TOP", 0, 6)
    frame.toLeaderBtn:SetFrameLevel(left:GetFrameLevel() + 10)
    frame.toLeaderBtn:SetText("Go to group leader")
    frame.toLeaderBtn:SetScript("OnClick", function() SendCmd(".dwtoleader") end)

    -- Travel button: move (up or down) to another tier you've already reached. Sends ".movetier N";
    -- the server swaps your per-tier loadout + gear and logs you out (log back in on that tier).
    -- Shown only when a DIFFERENT, already-reached tier is selected (see RenderDetail).
    frame.travelBtn = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
    frame.travelBtn:SetSize(232, 34)
    frame.travelBtn:SetPoint("BOTTOM", right, "BOTTOM", 0, 16)   -- centred; positioned in RenderDetail
    frame.travelBtn:Hide()
    frame.travelBtn:SetScript("OnClick", function()
        if frame.travelTier then SendCmd(".movetier " .. frame.travelTier) end
        frame:Hide()
    end)

    UpdateRoleButtons()

    -- TODO(server): update this string from the pushed current_tier / level.
    local lvl = UnitLevel and UnitLevel("player") or 0
    frame.summary:SetText(("Current tier: %d   •   Level %d"):format(CurrentTierId(), lvl))

    RenderComp()
    RenderRoster()
    UpdateBadge()
    UpdateJourney()
end

local function Toggle()
    EnsureDB()
    CreateUI()
    if frame:IsShown() then
        frame:Hide()
    else
        RequestSync()                       -- ask the server for fresh tier/clear state + roster
        SelectTier(CurrentTierId())
        UpdateEnterButton()
        RenderComp()                        -- slot count reflects current party size
        RenderRoster()
        frame:Show()
    end
end

-- Matchmaker status from the server ("Q=..."). Toggles the Play players button into a live "Leave Queue"
-- countdown, and resets it when the match forms / is cancelled. Global so the addon-message handler finds it.
-- ---------------------------------------------------------------------------
-- DeepwardAlert — reusable top-of-screen HUD. One alert per `key`; alerts stack
-- downward from the top and work whether or not the progression panel is open.
-- Feed it from any server message: queue search, dungeon progress, boss kills, etc.
--   DeepwardAlert(key, { label=string, deadline=GetTime()+secs?, button={text,cmd,onClick}?, color? })
--   DeepwardAlertHide(key)
-- If `deadline` is set the alert shows a live countdown ("label — 12s"); when it hits 0 it stays at 0
-- (the server owns the actual timeout). Calling DeepwardAlert again with the same key updates in place.
-- ---------------------------------------------------------------------------
local dwAlerts = {}       -- key -> frame
local dwAlertOrder = {}   -- ordered list of keys (top-to-bottom)

local function DwLayoutAlerts()
    local y = -8
    for _, k in ipairs(dwAlertOrder) do
        local a = dwAlerts[k]
        if a and a:IsShown() then
            a:ClearAllPoints()
            a:SetPoint("TOP", UIParent, "TOP", 0, y)
            y = y - (a:GetHeight() + 6)
        end
    end
end

function DeepwardAlertHide(key)
    local a = dwAlerts[key]
    if a then a.deadline = nil; a:Hide() end
    for i, k in ipairs(dwAlertOrder) do
        if k == key then table.remove(dwAlertOrder, i); break end
    end
    DwLayoutAlerts()
end

local function DwMakeAlert()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(320, 40)
    f:SetFrameStrata("HIGH")
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0, 0, 0, 0.85)
    f.text = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    f.text:SetPoint("LEFT", 12, 0)
    f.btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.btn:SetSize(64, 22)
    f.btn:SetPoint("RIGHT", -8, 0)
    f:SetScript("OnUpdate", function(self)
        if not self.deadline then return end
        local left = self.deadline - GetTime()
        if left < 0 then left = 0 end
        self.text:SetText(self.label .. (" \226\128\148 %ds"):format(math.ceil(left)))
    end)
    return f
end

function DeepwardAlert(key, opts)
    local a = dwAlerts[key]
    if not a then
        a = DwMakeAlert()
        dwAlerts[key] = a
        table.insert(dwAlertOrder, key)
    end
    a.label = opts.label or ""
    a.deadline = opts.deadline
    if opts.button then
        a.btn:SetText(opts.button.text or "OK")
        local cmd, fn = opts.button.cmd, opts.button.onClick
        a.btn:SetScript("OnClick", function()
            if cmd then SendCmd(cmd) end
            if fn then fn() end
        end)
        a.btn:Show()
        a.text:SetWidth(320 - 64 - 30)   -- leave room for the button
    else
        a.btn:Hide()
        a.text:SetWidth(320 - 24)
    end
    if not a.deadline then a.text:SetText(a.label) end   -- static text (OnUpdate handles the timed case)
    a:Show()
    DwLayoutAlerts()
end

-- Queue search banner = one caller of the generic alert (key "queue").
local function HideQueueBanner()
    DeepwardAlertHide("queue")
end
local function ShowQueueBanner(left, have, full)
    local label
    if have and full then
        label = ("|cffffd200Deepward:|r s\195\184ker gruppe  (%s/%s)"):format(have, full)
    else
        label = "|cffffd200Deepward:|r s\195\184ker gruppe"
    end
    DeepwardAlert("queue", {
        label = label,
        deadline = GetTime() + (tonumber(left) or 0),
        button = { text = "Leave", cmd = ".dwqueue leave" },
    })
end

function UpdateQueueUI(state)
    -- Drive the top-of-screen banner FIRST — it must work even if the panel frame isn't built/open.
    local left, have, full = state:match("^searching:(%d+):(%d+):(%d+)")
    if not left then left = state:match("^searching:(%d+)") end
    if left then
        ShowQueueBanner(left, have, full)
    else
        HideQueueBanner()
    end

    if not frame or not frame.playersBtn then return end
    if left then
        frame.playersQueued = true
        -- Show only the countdown, not the raw queue count: with role caps the number in the queue isn't
        -- the number that fits one group (e.g. 5 tanks -> only 1 fits), so a "5/5" would be misleading.
        frame.playersBtn:SetText(("Leave (%ss)"):format(left))
        frame.playersBtn:Show()
    else
        frame.playersQueued = false
        frame.playersBtn:SetText("Find player group")
        if HideMatchPopup then HideMatchPopup() end   -- close the accept dialog on form / cancel / fail
        if state == "matched" then
            print("|cff33ff99Deepward:|r Match funnet — gruppa dannes, du sendes inn!")
        elseif state == "failed" then
            print("|cff33ff99Deepward:|r Fant ikke nok ekte spillere — ingen bot-gruppe ble laget. Prov igjen, eller huk av 'Fill with bots'.")
        end
    end
end

-- Live updates from the server: re-parse and, if the panel is open, re-render the current view.
local liveFrame = CreateFrame("Frame")
liveFrame:RegisterEvent("CHAT_MSG_ADDON")
liveFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
liveFrame:RegisterEvent("RAID_ROSTER_UPDATE")
liveFrame:SetScript("OnEvent", function(_, event, prefix, message)
    if event == "CHAT_MSG_ADDON" then
        if prefix ~= "DEEPWARD" then return end
        local rc = message:match("RC=(.*)")
        if rc then                          -- leader started a role check -> pop the role picker
            ShowRoleCheckPopup(rc)
            return
        end
        local pm = message:match("P=(.*)")
        if pm then                          -- match-found accept dialog
            if pm == "cancel" then
                HideMatchPopup()
            elseif pm == "waiting" then
                SetMatchWaiting()
            else
                local secs, mode = pm:match("^(%d+):?(%a*)")
                secs = tonumber(secs)
                if secs then
                    HideQueueBanner()       -- the accept dialog takes over from the search banner
                    ShowMatchPopup(secs, mode == "bots")
                end
            end
            return
        end
        local q = message:match("Q=(.*)")
        if q then                           -- matchmaker status ("Play players")
            if UpdateQueueUI then UpdateQueueUI(q) end
            return
        end
        if ParseRoster(message) then       -- roster-only message ("G=...") -> just refresh the roster
            if RenderRoster then RenderRoster() end
            return
        end
        if ParseAccount(message) then      -- account-wide stats ("AS=...") -> refresh the journey summary
            if UpdateJourney then UpdateJourney() end
            return
        end
        ParseLive(message)
        if UpdateBadge then UpdateBadge() end
        if UpdateJourney then UpdateJourney() end
        if frame and frame:IsShown() then
            SelectTier(selectedId or CurrentTierId())
        end
    else
        -- party/raid changed -> bot-slot count changed: refresh the comp, and re-pull the roster
        if RenderComp then RenderComp() end
        if frame and frame:IsShown() then RequestSync() end
    end
end)

-- ---------------------------------------------------------------------------
-- Entry points: slash commands + a small draggable button near the minimap
-- ---------------------------------------------------------------------------
SLASH_DEEPWARDTIERS1 = "/tier"
SLASH_DEEPWARDTIERS2 = "/deepward"
SlashCmdList["DEEPWARDTIERS"] = Toggle

-- Keybinding: exposed globally for Bindings.xml, labelled in the Key Bindings UI,
-- and defaulted to "Y" on first login (only if the action isn't already bound).
_G.DeepwardTiers_Toggle = Toggle
_G.BINDING_HEADER_DEEPWARD = "Deepward"
_G.BINDING_NAME_DEEPWARDTIERS_TOGGLE = "Toggle Progression panel"

-- Mount anywhere (grunnlov I): the client greys/blocks the normal mount button indoors (instances,
-- Dalaran), so we route mounting through the server-side ".dwmount" command — a chat message, not a
-- spell cast, so the client's location check never fires. Bind a key in Key Bindings (category
-- "Deepward"), or use /dwmount (/mnt). Toggles: dismounts if you're already mounted. The server picks
-- one of YOUR OWN mounts at random.
local function MountAnywhere() SendCmd(".dwmount") end
SLASH_DEEPWARDMOUNT1 = "/dwmount"
SLASH_DEEPWARDMOUNT2 = "/mnt"
SlashCmdList["DEEPWARDMOUNT"] = MountAnywhere

SLASH_DEEPWARDROLECHECK1 = "/rolecheck"
SlashCmdList["DEEPWARDROLECHECK"] = function() SendCmd(".dwrolecheck") end   -- leader starts a role check
_G.DeepwardTiers_Mount = MountAnywhere
_G.BINDING_NAME_DEEPWARDTIERS_MOUNT = "Mount anywhere"

local binder = CreateFrame("Frame")
binder:RegisterEvent("PLAYER_LOGIN")
binder:SetScript("OnEvent", function()
    if not GetBindingKey("DEEPWARDTIERS_TOGGLE") then
        SetBinding("Y", "DEEPWARDTIERS_TOGGLE")
        SaveBindings(GetCurrentBindingSet() or 1)
    end
end)

local opener = CreateFrame("Button", "DeepwardTiersButton", Minimap)
opener:SetSize(31, 31)
opener:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -8, -8)
opener:SetFrameStrata("MEDIUM")
opener:SetMovable(true)
opener:RegisterForDrag("LeftButton")
opener:SetScript("OnDragStart", opener.StartMoving)
opener:SetScript("OnDragStop", opener.StopMovingOrSizing)

local icon = opener:CreateTexture(nil, "ARTWORK")
icon:SetSize(20, 20)
icon:SetPoint("CENTER")
icon:SetTexture("Interface\\Icons\\Achievement_Dungeon_UtgardePinnacle_75")

local ring = opener:CreateTexture(nil, "OVERLAY")
ring:SetSize(53, 53)
ring:SetPoint("TOPLEFT")
ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

opener:SetScript("OnClick", Toggle)
opener:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Deepward — Progression")
    GameTooltip:AddLine("Click to open your tier panel", 1, 1, 1)
    GameTooltip:Show()
end)
opener:SetScript("OnLeave", function() GameTooltip:Hide() end)
