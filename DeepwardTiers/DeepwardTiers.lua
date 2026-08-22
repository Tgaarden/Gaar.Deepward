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
    -- Tiers 4–29 (Ascension) are appended as they're specified. Locked until reached.
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

-- A tier is cleared (qualified to advance) when every one of its dungeons is cleared. Needs live
-- data; without it we return false so the Advance button stays hidden until we actually know.
local function IsTierClearedLive(t)
    if not (DeepwardLive and DeepwardLive.cleared) or not t or not t.dungeons or #t.dungeons == 0 then
        return false
    end
    for _, d in ipairs(t.dungeons) do
        if not DeepwardLive.cleared[d.map] then return false end
    end
    return true
end

-- ---------------------------------------------------------------------------
-- UI (built lazily on first open)
-- ---------------------------------------------------------------------------
local frame
local tierButtons = {}
local selectedId = 1
local selectedDungeonIdx = 1   -- which dungeon of the selected tier is shown (bg + info + Enter target)

-- Bot-comp editor + live roster (idea #6). Forward-declared so CreateUI's button closures can call them.
local RenderComp, RenderRoster, UpdateBadge

-- Header badge (achievement-frame style): total bosses slain, from the live "B=" set.
UpdateBadge = function()
    if not frame or not frame.badge then return end
    local n = 0
    if DeepwardLive and DeepwardLive.killed then for _ in pairs(DeepwardLive.killed) do n = n + 1 end end
    frame.badge:SetText(("%d"):format(n))
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
        tag = " |cff40ff40(current)|r"
    elseif b.tierId < cur then
        tag = "  |TInterface\\RaidFrame\\ReadyCheck-Ready:18:18:0:0|t"   -- completed
    else
        tag = ""
    end
    b.label:SetText(("Tier %d%s"):format(b.tierId, tag))
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
        frame.enterBtn:SetText("Enter Dungeon")
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
    local roleBtnY   = twoRows and 78 or 44
    local roleLabelY = roleBtnY + 26
    local selectorY  = roleBtnY + 56

    frame.detailTitle:SetText(sel and ("Tier %d — %s"):format(tier.id, sel.name) or ("Tier %d — %s"):format(tier.id, tier.name))

    -- The panel now shows ONE dungeon at a time (the selected one) — background + info both follow
    -- the selection, and the Enter button targets it.
    local lines = {}
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
                    table.insert(lines, ("   |cff40ff40v %s|r"):format(b.n))       -- slain
                else
                    table.insert(lines, ("   |cffb0b0b0- %s|r"):format(b.n))       -- still up
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
    local n = showSelectors and math.min(#dgs, #frame.dungeonBtns) or 0
    for i, db in ipairs(frame.dungeonBtns) do
        local d = dgs[i]
        if d and i <= n then
            db:SetText(d.name)
            db:ClearAllPoints()
            db:SetPoint("BOTTOM", frame.rightPanel, "BOTTOM", (i - (n + 1) / 2) * 216, selectorY)
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
        local rbw = 124
        for i, rb in ipairs(frame.roleButtons) do
            rb:ClearAllPoints()
            rb:SetPoint("BOTTOM", frame.rightPanel, "BOTTOM", (i - 2) * (rbw + 10), roleBtnY)
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

    -- Advance is a standalone TOP-RIGHT button (anchored at creation); just toggle it here.
    if advanceVisible then frame.advanceBtn:Show() else frame.advanceBtn:Hide() end

    -- Resolve the single bottom-band secondary (Travel only now; Advance moved to the top-right).
    local secondary = nil
    if travelVisible then
        frame.travelTier = tier.id
        frame.travelBtn:SetText(("Travel to Tier %d"):format(tier.id))
        secondary = frame.travelBtn
    end

    -- Hide Enter/Travel, then place whatever is visible: Enter centred (upper if a secondary follows),
    -- secondary centred on the line below.
    frame.enterBtn:Hide()
    frame.travelBtn:Hide()

    local PRIMARY_Y, LOWER_Y = 52, 12
    local function place(btn, y)
        btn:ClearAllPoints()
        btn:SetPoint("BOTTOM", frame.rightPanel, "BOTTOM", 0, y)
        btn:Show()
    end
    if enterVisible and secondary then
        place(frame.enterBtn, PRIMARY_Y)
        place(secondary, LOWER_Y)
    elseif enterVisible then
        place(frame.enterBtn, LOWER_Y)
    elseif secondary then
        place(secondary, LOWER_Y)
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

local TIER_BTN_H = 46   -- per-row height (incl. the 4px gap) — drives the scroll-child height
local function BuildTierList(parent)
    local cur = CurrentTierId()
    local prev
    -- Highest tier ALWAYS on top: walk TIERS in reverse so Tier N sits above Tier N-1.
    for i = #TIERS, 1, -1 do
        local t = TIERS[i]
        local b = CreateFrame("Button", nil, parent)
        b:SetSize(196, TIER_BTN_H - 4)
        if prev then
            b:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -4)
        else
            b:SetPoint("TOPLEFT", 0, 0)
        end
        b.tierId = t.id

        -- selection highlight
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetTexture(0.6, 0.5, 0.2, 0.45)
        b.bg:Hide()

        local label = b:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        label:SetPoint("LEFT", 10, 0)
        b.label = label
        SetTierLabel(b)   -- "(current)" or a completed checkmark, per live tier

        b:SetScript("OnClick", function() SelectTier(t.id) end)
        b:SetScript("OnEnter", function() b.bg:Show() end)
        b:SetScript("OnLeave", function() if b.tierId ~= selectedId then b.bg:Hide() end end)

        table.insert(tierButtons, b)
        prev = b
    end
    -- Size the scroll child to hold every row so the scrollbar engages when the list runs long.
    parent:SetHeight(#TIERS * TIER_BTN_H + 8)
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
        local roles = { "Tank", "DPS", "Healer" }
        for i, r in ipairs(roles) do
            local rb = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            rb:SetSize(80, 28)
            rb:SetPoint("TOP", f, "TOP", (i - 2) * 86, -48)
            rb:SetText(r)
            rb.role = string.lower(r)
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

local function CreateUI()
    if frame then
        return
    end

    frame = CreateFrame("Frame", "DeepwardTiersFrame", UIParent)
    frame:SetSize(880, 680)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
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
    frame.bgParch:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")   -- achievements look
    frame.bgParch:SetTexCoord(0, 1, 0, 1)

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOP", 0, -20)
    title:SetText("Deepward — Progression")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    frame.summary = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    frame.summary:SetPoint("TOP", title, "BOTTOM", 0, -8)

    -- Header badge (achievement-frame style): a shield with the count of bosses slain, top-right of the title.
    frame.badgeIcon = frame:CreateTexture(nil, "ARTWORK")
    frame.badgeIcon:SetSize(30, 30)
    frame.badgeIcon:SetPoint("RIGHT", title, "LEFT", -14, 0)
    frame.badgeIcon:SetTexture("Interface\\Icons\\Achievement_Dungeon_UtgardePinnacle_75")
    frame.badge = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.badge:SetPoint("RIGHT", frame.badgeIcon, "LEFT", -4, 0)
    frame.badge:SetText("0")
    frame.badgeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.badgeLabel:SetPoint("TOP", frame.badgeIcon, "BOTTOM", 0, -1)
    frame.badgeLabel:SetText("slain")

    -- Gold divider under the header (achievements-frame banner separation).
    local hdiv = frame:CreateTexture(nil, "ARTWORK")
    hdiv:SetHeight(2)
    hdiv:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -92)
    hdiv:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -92)
    hdiv:SetTexture(0.72, 0.56, 0.22, 0.85)

    -- Left: tier ("category") list. It has no art, so it gets the quest-log parchment as its
    -- background (+ a border) so the whole column reads as a solid beige field. The rows live in a
    -- scroll frame so a long tier list (up to 29) scrolls instead of overflowing.
    local left = CreateFrame("Frame", nil, frame)
    left:SetPoint("TOPLEFT", 24, -100)
    left:SetSize(236, 548)
    left:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
    })
    -- Opaque parchment fill for the menu column (the backdrop bgFile rendered see-through).
    left.parch = left:CreateTexture(nil, "BACKGROUND", nil, -7)
    left.parch:SetPoint("TOPLEFT", 5, -5)
    left.parch:SetPoint("BOTTOMRIGHT", -5, 5)
    left.parch:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
    left.parch:SetTexCoord(0, 0.5, 0, 1)   -- left slice of the parchment for the narrow column

    local tierScroll = CreateFrame("ScrollFrame", "DeepwardTiersTierScroll", left, "UIPanelScrollFrameTemplate")
    tierScroll:SetPoint("TOPLEFT", 10, -10)
    tierScroll:SetPoint("BOTTOMRIGHT", -28, 208)   -- leave the lower part of the column for group/comp
    local tierChild = CreateFrame("Frame", nil, tierScroll)
    tierChild:SetSize(196, 10)
    tierScroll:SetScrollChild(tierChild)
    BuildTierList(tierChild)

    -- Bottom of the left column: live group roster + bot-comp editor (idea #6). A thin divider on top.
    local gdiv = left:CreateTexture(nil, "ARTWORK")
    gdiv:SetHeight(2)
    gdiv:SetPoint("TOPLEFT", tierScroll, "BOTTOMLEFT", 0, -2)
    gdiv:SetPoint("TOPRIGHT", tierScroll, "BOTTOMRIGHT", 18, -2)
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
    frame.rosterText:SetWidth(196)
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
    local sdefs = { { key = "t", lbl = "|cff4080ffT|r" }, { key = "h", lbl = "|cff40ff40H|r" }, { key = "d", lbl = "|cffff8040D|r" } }
    for i, def in ipairs(sdefs) do
        local rowY = -4 - (i - 1) * 24
        local lbl = left:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        lbl:SetPoint("TOPLEFT", frame.autoBtn, "BOTTOMLEFT", 2, rowY)
        lbl:SetText(def.lbl)
        local minus = CreateFrame("Button", nil, left, "UIPanelButtonTemplate")
        minus:SetSize(20, 20)
        minus:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
        minus:SetText("-")
        local cnt = left:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
        cnt:SetPoint("LEFT", minus, "RIGHT", 6, 0)
        cnt:SetWidth(22)
        cnt:SetJustifyH("CENTER")
        cnt:SetText("0")
        local plus = CreateFrame("Button", nil, left, "UIPanelButtonTemplate")
        plus:SetSize(20, 20)
        plus:SetPoint("LEFT", cnt, "RIGHT", 6, 0)
        plus:SetText("+")
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
    right:SetSize(572, 548)

    frame.artBg = right:CreateTexture(nil, "BACKGROUND")
    frame.artBg:SetAllPoints()
    frame.artBg:SetTexCoord(0.10, 0.90, 0.05, 0.95)   -- crop the splash toward the panel's aspect

    -- Parchment fallback, shown when a tier/dungeon has no art (keeps the panel from going black).
    frame.artFallback = right:CreateTexture(nil, "BACKGROUND")
    frame.artFallback:SetAllPoints()
    frame.artFallback:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
    frame.artFallback:SetVertexColor(1, 1, 1, 0.9)

    local dark = right:CreateTexture(nil, "ARTWORK")
    dark:SetAllPoints()
    dark:SetTexture(0, 0, 0, 0.62)                     -- dim busy art for readable text

    frame.rightPanel = right

    -- Title sits below a top margin so it clears the splash's own banner/logo instead of jamming
    -- against the top edge.
    frame.detailTitle = right:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    frame.detailTitle:SetPoint("TOPLEFT", 18, -110)   -- sits just under the splash's WARCRAFT logo

    -- Body lives in a scroll frame spanning from below the title down to just above the button row,
    -- so long descriptions scroll within the beige field instead of spilling over the buttons.
    local bodyScroll = CreateFrame("ScrollFrame", "DeepwardTiersBodyScroll", right, "UIPanelScrollFrameTemplate")
    bodyScroll:SetPoint("TOPLEFT", 18, -145)           -- top sits just under the title (taller scroll = more text visible)
    bodyScroll:SetPoint("BOTTOMRIGHT", -30, 138)       -- extends lower now the buttons sit lower (taller text area)
    local bodyChild = CreateFrame("Frame", nil, bodyScroll)
    bodyChild:SetSize(516, 10)
    bodyScroll:SetScrollChild(bodyChild)
    frame.bodyChild = bodyChild

    frame.detailBody = bodyChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightLeft")
    frame.detailBody:SetPoint("TOPLEFT", 0, 0)
    frame.detailBody:SetWidth(516)                      -- fixed width → wraps; height drives the scroll range
    frame.detailBody:SetFont("Fonts\\FRIZQT__.TTF", 18) -- larger, easier to read
    frame.detailBody:SetSpacing(3)
    frame.detailBody:SetJustifyH("LEFT")
    frame.detailBody:SetJustifyV("TOP")

    -- Per-dungeon "enter this løype" buttons (max 2 in tiers 1-3). Configured per selected tier in
    -- RenderDetail; each sends ".enter <role> <map>" so you can pick a specific dungeon (incl. one
    -- you've already cleared, e.g. to run it again with a friend).
    frame.dungeonBtns = {}
    for i = 1, 2 do
        local db = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
        db:SetSize(210, 28)
        db:Hide()
        frame.dungeonBtns[i] = db
    end

    -- Role selector (Tank / DPS / Healer): your slot in the auto-formed 5-man
    -- (Tank + 3 DPS + Healer). Persisted; the server-side party fill uses it.
    frame.roleLabel = right:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.roleLabel:SetPoint("BOTTOM", right, "BOTTOM", 0, 126)   -- repositioned per-render
    frame.roleLabel:SetText("Your role:")

    frame.roleButtons = {}
    local roles = { "Tank", "DPS", "Healer" }
    local rbw = 124
    for i, r in ipairs(roles) do
        local rb = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
        rb:SetSize(rbw, 26)
        rb:SetPoint("BOTTOM", right, "BOTTOM", (i - 2) * (rbw + 10), 96)
        rb:SetText(r)
        rb.role = string.lower(r)
        rb:SetScript("OnClick", function()
            DeepwardTiersDB.role = rb.role
            UpdateRoleButtons()
            SendCmd(".dwrole " .. rb.role)   -- update the live group roster for everyone
        end)
        frame.roleButtons[i] = rb
    end

    -- Enter button: fires the server-side ".enter" to teleport into the current tier's dungeon
    -- (or ".leave" when already inside). The server decides where + enforces the rules.
    frame.enterBtn = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
    frame.enterBtn:SetSize(232, 34)
    frame.enterBtn:SetPoint("BOTTOM", right, "BOTTOM", 0, 54)   -- centred; repositioned in RenderDetail
    frame.enterBtn:SetText("Enter Dungeon")
    frame.enterBtn:SetScript("OnClick", function()
        if IsInInstance() then
            print("|cff33ff99Deepward:|r Use your Hearthstone to leave — it is your only way out.")
            return
        end
        EnterDungeon(frame.selectedMap)   -- the currently selected dungeon (nil -> server auto-routes)
        frame:Hide()
    end)

    -- Advance button: the explicit "rykke opp" choice. Sends ".advance"; the SERVER gates it on
    -- having cleared every dungeon of the current tier (rejects with a message if not qualified),
    -- so it's safe to always offer. Hidden while inside an instance (you advance from the hub).
    frame.advanceBtn = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
    frame.advanceBtn:SetSize(150, 30)
    frame.advanceBtn:SetPoint("TOPRIGHT", right, "TOPRIGHT", -10, -12)   -- standalone top-right button (toggled in RenderDetail)
    frame.advanceBtn:SetFrameLevel(right:GetFrameLevel() + 10)          -- sit above the splash art
    frame.advanceBtn:SetText("Advance Tier")
    frame.advanceBtn:SetScript("OnClick", function()
        SendCmd(".advance")
        frame:Hide()
        -- Give the server a beat to apply .advance, then reload the UI so the panel (current-tier
        -- marker, granted quests, gating) reflects the new tier. 3.3.5 has no C_Timer, so poll OnUpdate.
        local t, waiter = 0, CreateFrame("Frame")
        waiter:SetScript("OnUpdate", function(self, elapsed)
            t = t + elapsed
            if t >= 1.5 then self:SetScript("OnUpdate", nil); ReloadUI() end
        end)
    end)

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
        if ParseRoster(message) then       -- roster-only message ("G=...") -> just refresh the roster
            if RenderRoster then RenderRoster() end
            return
        end
        ParseLive(message)
        if UpdateBadge then UpdateBadge() end
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
