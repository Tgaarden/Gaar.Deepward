--[[
  Deepward Meter — a compact, Details!-inspired combat meter for 3.3.5a.

  Client-side only (law I): everything is derived from COMBAT_LOG_EVENT_UNFILTERED. No server data.

  Features
    * Modes (attributes): Damage (DPS), Healing (HPS, effective), Damage taken, Interrupts, Dispels, Deaths.
    * Segments: Current fight, Overall (whole instance), and a history of the last fights.
    * Click a bar -> per-spell breakdown for that actor + mode (Details!'s signature). "< Back" to return.
    * Bars: rank, class icon, class-coloured bar, white text "total (per-sec, %)".
    * Header: [segment ▾] on the left, [mode ▾] on the right — click for a dropdown.
    * Right-click the window: menu with Reset, Report to chat, and the mode/segment pickers.
    * Resizable (drag the bottom-right corner), movable (drag the body). Position/size/mode persist.
    * Hover a bar for a tooltip of that actor's top spells. Auto-shows when you enter an instance.

  Slash: /dwmeter (toggle) · /dwmeter reset · /dwmeter report · /dwmeter mode · /dwmeter config
]]

local _G = _G
local ADDON = "Deepward Meter"

-- ---------------------------------------------------------------------------
-- Modes
-- ---------------------------------------------------------------------------
-- key -> { label, short, perSec (bool: show a per-second figure), rate (label for the per-second stat) }
local MODES = {
    { key = "damage",     label = "Damage done",  short = "DPS",   perSec = true,  rate = "DPS" },
    { key = "healing",    label = "Healing done", short = "HPS",   perSec = true,  rate = "HPS" },
    { key = "taken",      label = "Damage taken", short = "DTPS",  perSec = true,  rate = "DTPS" },
    { key = "interrupts", label = "Interrupts",   short = "Int",   perSec = false },
    { key = "dispels",    label = "Dispels",      short = "Disp",  perSec = false },
    { key = "deaths",     label = "Deaths",       short = "Death", perSec = false },
}
local MODE_BY_KEY = {}
for i, m in ipairs(MODES) do MODE_BY_KEY[m.key] = m end

-- ---------------------------------------------------------------------------
-- SavedVariables / settings
-- ---------------------------------------------------------------------------
local DB
DB = function()
    if type(DeepwardMeterDB) ~= "table" then DeepwardMeterDB = {} end
    local d = DeepwardMeterDB
    if d.mode == nil then d.mode = "damage" end
    if d.width == nil then d.width = 240 end
    if d.height == nil then d.height = 190 end
    if d.reportChannel == nil then d.reportChannel = "PARTY" end
    if d.shown == nil then d.shown = false end   -- persistent visibility (stays put across zoning/reload)
    return d
end

-- ---------------------------------------------------------------------------
-- Data model: segments. Each segment = { name, start, endt, actors = { [name] = actor } }.
--   actor = { name, class, amount = {mode=n}, spells = {mode = {[spell]={amt,hits}}}, }
-- overall accumulates for the whole instance; `cur` is the in-combat fight; `fights` is the closed history.
-- ---------------------------------------------------------------------------
local MAX_FIGHTS = 20
local overall = { name = "Overall", start = GetTime(), actors = {} }
local fights = {}          -- most-recent-first
local cur = nil            -- open fight (in combat) or nil
local wasInside = nil

local function NewSeg(name) return { name = name, start = GetTime(), actors = {} } end

local function NewActor(name)
    return { name = name, class = nil,
             amount = { damage = 0, healing = 0, taken = 0, interrupts = 0, dispels = 0, deaths = 0 },
             spells = { damage = {}, healing = {}, taken = {}, interrupts = {}, dispels = {} } }
end

local function GetActor(seg, name)
    local a = seg.actors[name]
    if not a then a = NewActor(name); seg.actors[name] = a end
    return a
end

-- class cache (bots included — they report a real class)
local classByName = {}
local function RefreshClassCache()
    local pn = UnitName("player"); local _, pc = UnitClass("player")
    if pn then classByName[pn] = pc end
    local nr = (GetNumRaidMembers and GetNumRaidMembers()) or 0
    if nr > 0 then
        for i = 1, nr do
            local nm = UnitName("raid" .. i); local _, cl = UnitClass("raid" .. i)
            if nm then classByName[nm] = cl end
        end
    else
        local np = (GetNumPartyMembers and GetNumPartyMembers()) or 0
        for i = 1, np do
            local nm = UnitName("party" .. i); local _, cl = UnitClass("party" .. i)
            if nm then classByName[nm] = cl end
        end
    end
end

local function ClassColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 0.4, 0.55, 0.85
end

-- ---------------------------------------------------------------------------
-- Recording
-- ---------------------------------------------------------------------------
local AFF_GROUP = 0x7   -- COMBATLOG_OBJECT_AFFILIATION_MINE|PARTY|RAID

-- add one event's value to a segment's actor (both amount and per-spell breakdown)
local function AddToSeg(seg, name, mode, spell, amount)
    local a = GetActor(seg, name)
    if not a.class then a.class = classByName[name] end
    a.amount[mode] = (a.amount[mode] or 0) + amount
    if spell and a.spells[mode] then
        local s = a.spells[mode][spell]
        if not s then s = { amt = 0, hits = 0 }; a.spells[mode][spell] = s end
        s.amt = s.amt + amount
        s.hits = s.hits + 1
    end
end

-- record into BOTH the current fight (created lazily) and overall
local function Record(name, mode, spell, amount)
    if not name or not amount or amount <= 0 then return end
    if not cur then cur = NewSeg("Current fight") end
    AddToSeg(cur, name, mode, spell, amount)
    AddToSeg(overall, name, mode, spell, amount)
end

local function InGroup(flags) return bit.band(flags or 0, AFF_GROUP) ~= 0 end

local MELEE = "Melee"

local function OnCombatLog(...)
    local sub      = select(2, ...)
    local srcName  = select(4, ...)
    local srcFlags = select(5, ...)
    local dstName  = select(7, ...)
    local dstFlags = select(8, ...)

    if sub == "SWING_DAMAGE" then
        local amount = select(9, ...)
        if InGroup(srcFlags) then Record(srcName, "damage", MELEE, amount) end
        if InGroup(dstFlags) then Record(dstName, "taken", MELEE, amount) end

    elseif sub == "SPELL_DAMAGE" or sub == "SPELL_PERIODIC_DAMAGE" or sub == "RANGE_DAMAGE"
        or sub == "DAMAGE_SHIELD" or sub == "DAMAGE_SPLIT" then
        local spell  = select(10, ...)
        local amount = select(12, ...)
        if InGroup(srcFlags) then Record(srcName, "damage", spell, amount) end
        if InGroup(dstFlags) then Record(dstName, "taken", spell, amount) end

    elseif sub == "SPELL_HEAL" or sub == "SPELL_PERIODIC_HEAL" then
        local spell   = select(10, ...)
        local amount  = select(12, ...)
        local overheal = select(13, ...) or 0
        local eff = (amount or 0) - overheal          -- effective healing (Details! default)
        if eff > 0 and InGroup(srcFlags) then Record(srcName, "healing", spell, eff) end

    elseif sub == "SPELL_INTERRUPT" then
        if InGroup(srcFlags) then Record(srcName, "interrupts", select(13, ...) or "Interrupt", 1) end

    elseif sub == "SPELL_DISPEL" then
        if InGroup(srcFlags) then Record(srcName, "dispels", select(13, ...) or "Dispel", 1) end

    elseif sub == "UNIT_DIED" then
        if InGroup(dstFlags) then Record(dstName, "deaths", nil, 1) end
    end
end

-- ---------------------------------------------------------------------------
-- Segment selection for display
-- ---------------------------------------------------------------------------
-- viewSeg: "current" | "overall" | <index into fights>
local viewSeg = "current"
local detailActor = nil    -- when set, show this actor's per-spell breakdown

local function SelectedSeg()
    if viewSeg == "overall" then return overall end
    if viewSeg == "current" then return cur or fights[1] end
    return fights[viewSeg]
end

local function SegDuration(seg)
    if not seg or not seg.start then return 1 end
    local endt = seg.endt or GetTime()
    local d = endt - seg.start
    return d < 1 and 1 or d
end

local function SegName(seg)
    if not seg then return "—" end
    if seg == overall then return "Overall" end
    if seg == cur then return "Current" end
    return seg.name or "Fight"
end

-- ---------------------------------------------------------------------------
-- UI
-- ---------------------------------------------------------------------------
local Redraw
local frame = CreateFrame("Frame", "DeepwardMeterFrame", UIParent)
local db0 = DB()
frame:SetSize(db0.width, db0.height)
if db0.point then frame:SetPoint(db0.point, UIParent, db0.point, db0.x or 0, db0.y or 0)
else frame:SetPoint("CENTER", 300, 0) end
frame:SetMovable(true); frame:SetResizable(true); frame:EnableMouse(true)
frame:SetClampedToScreen(true)
frame:SetMinResize(170, 90); frame:SetMaxResize(560, 760)
frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
frame:SetBackdropColor(0.05, 0.07, 0.12, 0.92)
frame:SetBackdropBorderColor(0.35, 0.55, 0.9, 1)
frame:Hide()
table.insert(UISpecialFrames, "DeepwardMeterFrame")

local function SavePos()
    local d = DB()
    local p, _, _, x, y = frame:GetPoint()
    d.point, d.x, d.y = p, x, y
    d.width, d.height = math.floor(frame:GetWidth() + 0.5), math.floor(frame:GetHeight() + 0.5)
end

-- Header (title) bar — draggable, holds the two dropdown buttons.
local header = CreateFrame("Button", nil, frame)
header:SetPoint("TOPLEFT", 4, -4); header:SetPoint("TOPRIGHT", -4, -4); header:SetHeight(18)
header:RegisterForDrag("LeftButton")
header:SetScript("OnDragStart", function() frame:StartMoving() end)
header:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); SavePos() end)
header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
local htex = header:CreateTexture(nil, "BACKGROUND"); htex:SetAllPoints(); htex:SetTexture(0.12, 0.16, 0.28, 0.9)

local segBtn = CreateFrame("Button", nil, header)
segBtn:SetPoint("LEFT", 2, 0); segBtn:SetHeight(16); segBtn:SetWidth(90)
segBtn.text = segBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
segBtn.text:SetPoint("LEFT", 2, 0); segBtn.text:SetJustifyH("LEFT"); segBtn.text:SetWidth(88)
segBtn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

local modeBtn = CreateFrame("Button", nil, header)
modeBtn:SetPoint("RIGHT", -2, 0); modeBtn:SetHeight(16); modeBtn:SetWidth(96)
modeBtn.text = modeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
modeBtn.text:SetPoint("RIGHT", -2, 0); modeBtn.text:SetJustifyH("RIGHT"); modeBtn.text:SetWidth(94)
modeBtn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

-- Rows container starts under the header.
local ROW_H = 16
local rows = {}
local function AcquireRow(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, frame)
    r:SetHeight(ROW_H)
    r.bar = r:CreateTexture(nil, "ARTWORK")
    r.bar:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    r.bar:SetPoint("TOPLEFT"); r.bar:SetPoint("BOTTOMLEFT"); r.bar:SetWidth(1)
    r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(); r.bg:SetTexture(0, 0, 0, 0.35)
    r.icon = r:CreateTexture(nil, "OVERLAY"); r.icon:SetSize(14, 14); r.icon:SetPoint("LEFT", 2, 0)
    r.left = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.left:SetPoint("LEFT", r.icon, "RIGHT", 3, 0); r.left:SetJustifyH("LEFT")
    r.right = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.right:SetPoint("RIGHT", -3, 0); r.right:SetJustifyH("RIGHT")
    r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    rows[i] = r
    return r
end

local CLASS_ICON = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local function SetClassIcon(tex, class)
    local c = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if c then tex:SetTexture(CLASS_ICON); tex:SetTexCoord(c[1], c[2], c[3], c[4]); tex:Show()
    else tex:Hide() end
end

local function ShortNum(n)
    n = n or 0
    if n >= 1e6 then return ("%.1fM"):format(n / 1e6) end
    if n >= 1e3 then return ("%.1fk"):format(n / 1e3) end
    return tostring(math.floor(n + 0.5))
end

-- Build a sorted {name, amount} list for a segment + mode.
local function BuildList(seg, modeKey)
    local out, total = {}, 0
    if seg then
        for name, a in pairs(seg.actors) do
            local v = a.amount[modeKey] or 0
            if v > 0 then out[#out + 1] = { name = name, amount = v, class = a.class }; total = total + v end
        end
    end
    table.sort(out, function(a, b) return a.amount > b.amount end)
    return out, total
end

-- Build a sorted spell breakdown {spell, amt, hits} for an actor + mode.
local function BuildSpells(seg, actorName, modeKey)
    local out, total = {}, 0
    local a = seg and seg.actors[actorName]
    local sp = a and a.spells[modeKey]
    if sp then
        for spell, s in pairs(sp) do out[#out + 1] = { spell = spell, amt = s.amt, hits = s.hits }; total = total + s.amt end
    end
    table.sort(out, function(a, b) return a.amt > b.amt end)
    return out, total
end

local function VisibleRowCount()
    local h = frame:GetHeight() - 26   -- header + padding
    return math.max(1, math.floor(h / ROW_H))
end

Redraw = function()
    if not frame:IsShown() then return end
    RefreshClassCache()
    local mode = MODE_BY_KEY[DB().mode] or MODES[1]
    local seg = SelectedSeg()
    local dur = SegDuration(seg)

    segBtn.text:SetText("|cffffd100" .. SegName(seg) .. "|r ▾")
    modeBtn.text:SetText("▾ |cffffd100" .. mode.label .. "|r")

    local shown = VisibleRowCount()
    local top = -26

    if detailActor then
        -- per-spell breakdown for one actor; row 1 = back button, rest = spells
        local list, total = BuildSpells(seg, detailActor, mode.key)
        for idx = 1, shown do
            local r = AcquireRow(idx)
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 4, top - (idx - 1) * ROW_H); r:SetPoint("TOPRIGHT", -4, top - (idx - 1) * ROW_H)
            if idx == 1 then
                r.icon:Hide()
                r.bar:SetWidth(1)
                r.left:SetText("|cff66ccff< Back|r  |cffffffff" .. detailActor .. "|r")
                r.left:SetTextColor(1, 1, 1)
                r.right:SetText("|cffaaaaaa" .. mode.short .. "|r")
                r.data = "__back__"
                r:Show()
            else
                local e = list[idx - 1]
                if e then
                    local pct = total > 0 and (e.amt / total * 100) or 0
                    local cr, cgc, cb = 0.35, 0.5, 0.8
                    r.icon:Hide()
                    r.bar:SetWidth((frame:GetWidth() - 8) * (list[1] and (e.amt / list[1].amt) or 0))
                    r.bar:SetVertexColor(cr, cgc, cb, 0.55)
                    r.left:SetText(e.spell); r.left:SetTextColor(1, 1, 1)
                    r.right:SetText(("%s  %.0f%% (%d)"):format(ShortNum(e.amt), pct, e.hits))
                    r.right:SetTextColor(1, 1, 1)
                    r.data = nil
                    r:Show()
                else
                    r:Hide()
                end
            end
        end
        for idx = shown + 1, #rows do rows[idx]:Hide() end
        return
    end

    local list, total = BuildList(seg, mode.key)
    local topAmt = list[1] and list[1].amount or 1
    for idx = 1, shown do
        local r = AcquireRow(idx)
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", 4, top - (idx - 1) * ROW_H); r:SetPoint("TOPRIGHT", -4, top - (idx - 1) * ROW_H)
        local e = list[idx]
        if e then
            local cr, cg, cb = ClassColor(e.class)
            local pct = total > 0 and (e.amount / total * 100) or 0
            r.bar:SetWidth((frame:GetWidth() - 8) * (e.amount / topAmt))
            r.bar:SetVertexColor(cr, cg, cb, 0.85)
            SetClassIcon(r.icon, e.class)
            r.left:SetText(("%d. %s"):format(idx, e.name)); r.left:SetTextColor(1, 1, 1)
            if mode.perSec then
                r.right:SetText(("%s  %s  %.0f%%"):format(ShortNum(e.amount), ShortNum(e.amount / dur), pct))
            else
                r.right:SetText(("%d  %.0f%%"):format(e.amount, pct))
            end
            r.right:SetTextColor(1, 1, 1)
            r.data = e.name
            r:Show()
        else
            r:Hide()
        end
    end
    for idx = shown + 1, #rows do rows[idx]:Hide() end
end

-- Row click: open/close the breakdown.
local function OnRowClick(self, button)
    if self.data == "__back__" then detailActor = nil; Redraw(); return end
    if button == "RightButton" then detailActor = nil; Redraw(); return end
    if self.data then detailActor = (detailActor == self.data) and nil or self.data; Redraw() end
end
-- Row tooltip: top spells for the actor.
local function OnRowEnter(self)
    if not self.data or self.data == "__back__" then return end
    local seg = SelectedSeg(); local mode = MODE_BY_KEY[DB().mode] or MODES[1]
    local list, total = BuildSpells(seg, self.data, mode.key)
    if #list == 0 then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.data .. " — " .. mode.label)
    for i = 1, math.min(8, #list) do
        local e = list[i]
        local pct = total > 0 and (e.amt / total * 100) or 0
        GameTooltip:AddDoubleLine(e.spell, ("%s  %.0f%%"):format(ShortNum(e.amt), pct), 1, 1, 1, 1, 0.82, 0)
    end
    GameTooltip:Show()
end
-- Patch row scripts once created (AcquireRow doesn't set them, do it lazily here via hook on first Redraw).
local function WireRow(r)
    if r._wired then return end
    r._wired = true
    r:SetScript("OnClick", OnRowClick)
    r:SetScript("OnEnter", OnRowEnter)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
-- wrap AcquireRow to wire scripts
local _AcquireRow = AcquireRow
AcquireRow = function(i) local r = _AcquireRow(i); WireRow(r); return r end

-- ---------------------------------------------------------------------------
-- Menus (mode / segment / config) via EasyMenu
-- ---------------------------------------------------------------------------
local menuFrame = CreateFrame("Frame", "DeepwardMeterMenu", UIParent, "UIDropDownMenuTemplate")

local function Reset()
    overall = { name = "Overall", start = GetTime(), actors = {} }
    fights = {}; cur = nil; detailActor = nil
    Redraw()
end

local function ModeMenu()
    local t = { { text = "Mode", isTitle = true, notCheckable = true } }
    for _, m in ipairs(MODES) do
        t[#t + 1] = { text = m.label, checked = (DB().mode == m.key), func = function()
            DB().mode = m.key; detailActor = nil; Redraw()
        end }
    end
    return t
end

local function SegMenu()
    local t = { { text = "Segment", isTitle = true, notCheckable = true },
        { text = "Current fight", checked = (viewSeg == "current"), func = function() viewSeg = "current"; detailActor = nil; Redraw() end },
        { text = "Overall (instance)", checked = (viewSeg == "overall"), func = function() viewSeg = "overall"; detailActor = nil; Redraw() end },
    }
    for i, f in ipairs(fights) do
        if i > 10 then break end
        t[#t + 1] = { text = (f.name or ("Fight " .. i)) .. ("  (%ds)"):format(math.floor(SegDuration(f))),
            checked = (viewSeg == i), func = function() viewSeg = i; detailActor = nil; Redraw() end }
    end
    return t
end

-- Report the current view to chat.
local function Report()
    local mode = MODE_BY_KEY[DB().mode] or MODES[1]
    local seg = SelectedSeg(); local dur = SegDuration(seg)
    local list, total = BuildList(seg, mode.key)
    local ch = DB().reportChannel
    if ch == "PARTY" and GetNumRaidMembers() > 0 then ch = "RAID" end
    if ch == "PARTY" and GetNumPartyMembers() == 0 then ch = "SAY" end
    SendChatMessage(("Deepward Meter — %s (%s):"):format(mode.label, SegName(seg)), ch)
    for i = 1, math.min(5, #list) do
        local e = list[i]
        local pct = total > 0 and (e.amount / total * 100) or 0
        if mode.perSec then
            SendChatMessage(("%d. %s  %s (%s, %.0f%%)"):format(i, e.name, ShortNum(e.amount), ShortNum(e.amount / dur), pct), ch)
        else
            SendChatMessage(("%d. %s  %d (%.0f%%)"):format(i, e.name, e.amount, pct), ch)
        end
    end
end

local function ConfigMenu()
    return {
        { text = ADDON, isTitle = true, notCheckable = true },
        { text = "Reset data", notCheckable = true, func = Reset },
        { text = "Report to chat", notCheckable = true, func = Report },
        { text = "Mode", notCheckable = true, hasArrow = true, menuList = ModeMenu() },
        { text = "Segment", notCheckable = true, hasArrow = true, menuList = SegMenu() },
        { text = "Report channel", notCheckable = true, hasArrow = true, menuList = {
            { text = "Party/Raid", checked = (DB().reportChannel == "PARTY"), func = function() DB().reportChannel = "PARTY" end },
            { text = "Say",        checked = (DB().reportChannel == "SAY"),   func = function() DB().reportChannel = "SAY" end },
            { text = "Guild",      checked = (DB().reportChannel == "GUILD"), func = function() DB().reportChannel = "GUILD" end },
        } },
        { text = "Close", notCheckable = true, func = function() end },
    }
end

segBtn:SetScript("OnClick", function() EasyMenu(SegMenu(), menuFrame, segBtn, 0, 0, "MENU") end)
modeBtn:SetScript("OnClick", function() EasyMenu(ModeMenu(), menuFrame, modeBtn, 0, 0, "MENU") end)
header:SetScript("OnClick", function(_, button)
    if button == "RightButton" then EasyMenu(ConfigMenu(), menuFrame, "cursor", 0, 0, "MENU") end
end)
frame:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then EasyMenu(ConfigMenu(), menuFrame, "cursor", 0, 0, "MENU") end
end)

-- Resize handle (bottom-right).
local grip = CreateFrame("Button", nil, frame)
grip:SetSize(16, 16); grip:SetPoint("BOTTOMRIGHT", -2, 2)
grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
grip:SetScript("OnMouseUp", function() frame:StopMovingOrSizing(); SavePos(); Redraw() end)

-- ---------------------------------------------------------------------------
-- Throttled live redraw
-- ---------------------------------------------------------------------------
local acc = 0
frame:SetScript("OnUpdate", function(self, elapsed)
    acc = acc + elapsed
    if acc >= 0.3 then acc = 0; Redraw() end
end)

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLog(...)
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- new pull: start a fresh current fight (unless one is already open from lingering combat)
        if not cur then cur = NewSeg("Current fight") end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- fight ended: close it + push to history
        if cur then
            cur.endt = GetTime()
            cur.name = date("%H:%M:%S")
            table.insert(fights, 1, cur)
            while #fights > MAX_FIGHTS do table.remove(fights) end
            if type(viewSeg) == "number" then viewSeg = viewSeg + 1 end   -- keep pointing at the same fight
            cur = nil
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        RefreshClassCache()
        local inside = IsInInstance()
        if inside and not wasInside then Reset() end   -- reset data once, on first entry into the instance
        wasInside = inside
        if inside then DB().shown = true end           -- always show the meter while in an instance
        if DB().shown then frame:Show(); Redraw() end
    end
end)

-- ---------------------------------------------------------------------------
-- Slash
-- ---------------------------------------------------------------------------
SLASH_DEEPWARDMETER1 = "/dwmeter"
SLASH_DEEPWARDMETER2 = "/meter"
SlashCmdList["DEEPWARDMETER"] = function(msg)
    msg = (msg or ""):lower():gsub("%s+", "")
    if msg == "reset" then
        Reset(); print("|cff5599ff" .. ADDON .. ":|r reset.")
    elseif msg == "report" then
        Report()
    elseif msg == "mode" then
        -- cycle modes
        local keys = {}; for _, m in ipairs(MODES) do keys[#keys + 1] = m.key end
        local i = 1; for k, key in ipairs(keys) do if key == DB().mode then i = k end end
        DB().mode = keys[(i % #keys) + 1]; detailActor = nil; Redraw()
        print("|cff5599ff" .. ADDON .. ":|r mode = " .. (MODE_BY_KEY[DB().mode].label))
    elseif msg == "config" then
        EasyMenu(ConfigMenu(), menuFrame, "cursor", 0, 0, "MENU")
    else
        if frame:IsShown() then frame:Hide(); DB().shown = false
        else frame:Show(); DB().shown = true; Redraw() end
    end
end

-- Restore persistent visibility at load (ADDON's SavedVariables are ready by PLAYER_LOGIN).
local loginF = CreateFrame("Frame")
loginF:RegisterEvent("PLAYER_LOGIN")
loginF:SetScript("OnEvent", function() if DB().shown then frame:Show(); Redraw() end end)
