--[[
  Deepward Meter — a minimal group damage/DPS meter for 3.3.5a.

  Why: existing meters weren't working on this setup. This one is tiny, self-contained, and
  AUTO-RESETS every time you zone into an instance (the entrance = a fresh pull), which is exactly
  what a boss-rush run wants. Client-side only (law I) — it just reads the combat log.

  Toggle: /dwmeter  (or /meter).   Manual reset: /dwmeter reset.   Drag the title to move it.
]]

local _G = _G
local MAXROWS = 8
local BARCOL  = { 0.20, 0.45, 0.85 }   -- Deepward blue
local SELFCOL = { 0.30, 0.70, 1.00 }   -- your own bar, brighter

-- ---------------------------------------------------------------------------
-- Data
-- ---------------------------------------------------------------------------
local data = {}          -- [name] = totalDamage
local names = {}         -- list of names (for sorting)
local total = 0
local combatStart = nil  -- GetTime() of first damage since reset
local lastActivity = nil
local wasInside = nil

local function Reset()
    wipe(data); wipe(names); total = 0; combatStart = nil; lastActivity = nil
end

-- name -> englishClass, so each line can be class-coloured. Rebuilt from the group (bots included — they
-- report a real class). Cheap enough to refresh on each redraw.
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

local function ClassColor(name)
    local cl = classByName[name]
    local c = cl and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cl]
    if c then return c.r, c.g, c.b end
    return BARCOL[1], BARCOL[2], BARCOL[3]
end

-- Only count sources in YOUR group (mine / party / raid), so mobs don't clutter the list.
local AFF_GROUP = 0x7   -- COMBATLOG_OBJECT_AFFILIATION_MINE|PARTY|RAID

local function AddDamage(srcName, srcFlags, amount)
    if not srcName or not amount or amount <= 0 then return end
    if bit.band(srcFlags or 0, AFF_GROUP) == 0 then return end
    local now = GetTime()
    if not combatStart then combatStart = now end
    lastActivity = now
    if not data[srcName] then data[srcName] = 0; names[#names + 1] = srcName end
    data[srcName] = data[srcName] + amount
    total = total + amount
end

-- 3.3.5 combat-log: timestamp, subevent, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...
local function OnCombatLog(...)
    local sub, srcName, srcFlags = select(2, ...), select(4, ...), select(5, ...)
    if sub == "SWING_DAMAGE" then
        AddDamage(srcName, srcFlags, select(9, ...))
    elseif sub == "SPELL_DAMAGE" or sub == "SPELL_PERIODIC_DAMAGE" or sub == "RANGE_DAMAGE"
        or sub == "DAMAGE_SHIELD" or sub == "DAMAGE_SPLIT" then
        AddDamage(srcName, srcFlags, select(12, ...))
    end
end

-- ---------------------------------------------------------------------------
-- Display
-- ---------------------------------------------------------------------------
local frame = CreateFrame("Frame", "DeepwardMeterFrame", UIParent)
frame:SetSize(220, 20 + MAXROWS * 16 + 8)
frame:SetPoint("CENTER", 300, 0)
frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then Reset(); if frame:IsShown() then Redraw() end
        print("|cff5599ffDeepward Meter:|r reset.") end
end)
frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
frame:SetBackdropColor(0.05, 0.07, 0.12, 0.92)
frame:SetBackdropBorderColor(0.35, 0.55, 0.9, 1)
frame:Hide()

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.title:SetPoint("TOPLEFT", 8, -6)
frame.title:SetText("|cff5599ffDeepward Meter|r")

frame.dur = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
frame.dur:SetPoint("TOPRIGHT", -8, -7)

local rows = {}
for i = 1, MAXROWS do
    local r = CreateFrame("StatusBar", nil, frame)
    r:SetSize(204, 15)
    r:SetPoint("TOPLEFT", 6, -22 - (i - 1) * 16)
    r:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    r:SetMinMaxValues(0, 1); r:SetValue(0)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints(); r.bg:SetTexture(0, 0, 0, 0.4)
    r.left = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.left:SetPoint("LEFT", 4, 0)
    r.right = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.right:SetPoint("RIGHT", -4, 0)
    r:Hide()
    rows[i] = r
end

local function ShortNum(n)
    if n >= 1e6 then return ("%.1fM"):format(n / 1e6) end
    if n >= 1e3 then return ("%.1fk"):format(n / 1e3) end
    return tostring(math.floor(n))
end

local function Redraw()
    RefreshClassCache()
    table.sort(names, function(a, b) return (data[a] or 0) > (data[b] or 0) end)
    local dur = 0
    if combatStart then
        local endt = UnitAffectingCombat("player") and GetTime() or (lastActivity or GetTime())
        dur = endt - combatStart
    end
    if dur < 1 then dur = 1 end
    frame.dur:SetText(("%ds"):format(math.floor(dur)))
    local topDmg = names[1] and data[names[1]] or 1
    local me = UnitName("player")
    for i = 1, MAXROWS do
        local r, nm = rows[i], names[i]
        if nm then
            local dmg = data[nm] or 0
            local dps = dmg / dur
            r:SetValue(topDmg > 0 and (dmg / topDmg) or 0)
            local cr, cg, cb = ClassColor(nm)
            r:SetStatusBarColor(cr, cg, cb)
            r.left:SetText(("%d. %s"):format(i, nm))
            r.left:SetTextColor(cr, cg, cb)
            r.right:SetText(("%s (%s)"):format(ShortNum(dps), ShortNum(dmg)))
            r:Show()
        else
            r:Hide()
        end
    end
end

-- throttle redraw to ~3/s
local acc = 0
frame:SetScript("OnUpdate", function(self, elapsed)
    acc = acc + elapsed
    if acc >= 0.34 then acc = 0; if self:IsShown() then Redraw() end end
end)

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
-- Settings (SavedVariables): perEncounter = reset on each pull; otherwise accumulate over the whole instance.
local function DB()
    if type(DeepwardMeterDB) ~= "table" then DeepwardMeterDB = {} end
    if DeepwardMeterDB.perEncounter == nil then DeepwardMeterDB.perEncounter = false end
    return DeepwardMeterDB
end

frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")   -- entering combat = a new pull
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLog(...)
    elseif event == "PLAYER_REGEN_DISABLED" then
        if DB().perEncounter then Reset() end       -- per-encounter mode: fresh numbers each pull
    elseif event == "PLAYER_ENTERING_WORLD" then
        RefreshClassCache()
        local inside = IsInInstance()
        if inside and not wasInside then Reset() end   -- whole-instance mode: reset at the entrance
        wasInside = inside
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
        Reset(); Redraw()
        print("|cff5599ffDeepward Meter:|r reset.")
    elseif msg == "encounter" or msg == "mode" then
        DB().perEncounter = not DB().perEncounter
        Reset(); if frame:IsShown() then Redraw() end
        print("|cff5599ffDeepward Meter:|r " .. (DB().perEncounter
            and "per-encounter (resets each pull)." or "whole-instance (resets at the entrance)."))
    else
        if frame:IsShown() then frame:Hide() else frame:Show(); Redraw() end
    end
end
