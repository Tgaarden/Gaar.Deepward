--[[
  Deepward Threat — a real-time group threat meter, inspired by ClassicThreatMeter.

  Unlike 1.12 (no threat API, everything estimated from the combat log), WotLK 3.3.5a exposes the real
  threat API — so this reads actual server threat via UnitDetailedThreatSituation(unit, "target"):
    * One class-coloured bar per group member with any threat on your current target.
    * Bars scaled to the highest threat; each shows threat value + "aggro %" (percent of the pull threshold).
    * The aggro holder is flagged; your own row is outlined.
    * Pull warning: when YOU cross ~90% of the tank's threat (and aren't tanking), the window flashes + warns.

  Client-side only (law I). Toggle: /dwthreat. Right-click the window for options. Drag to move, grab the
  corner to resize. Auto-shows when you're in combat with a target that has a threat list.
]]

local _G = _G
local ADDON = "Deepward Threat"

local function DB()
    if type(DeepwardThreatDB) ~= "table" then DeepwardThreatDB = {} end
    local d = DeepwardThreatDB
    if d.width  == nil then d.width  = 220 end
    if d.height == nil then d.height = 150 end
    if d.autoShow == nil then d.autoShow = false end  -- optionally SHOW in combat (never auto-hides)
    if d.warn == nil then d.warn = true end           -- pull-aggro warning flash
    if d.sound == nil then d.sound = true end
    if d.shown == nil then d.shown = false end        -- persistent visibility (stays put; no popping)
    return d
end

local function ClassColor(unit)
    if unit and UnitIsPlayer(unit) then
        local _, cls = UnitClass(unit)
        local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
        if c then return c.r, c.g, c.b end
    end
    return 0.55, 0.55, 0.6
end

local function ShortNum(n)
    n = n or 0
    if n >= 1e6 then return ("%.1fM"):format(n / 1e6) end
    if n >= 1e3 then return ("%.1fk"):format(n / 1e3) end
    return tostring(math.floor(n + 0.5))
end

-- group member unit tokens (player + party/raid)
local function GroupUnits()
    local u = {}
    local nr = (GetNumRaidMembers and GetNumRaidMembers()) or 0
    if nr > 0 then
        for i = 1, nr do u[#u + 1] = "raid" .. i end
    else
        u[#u + 1] = "player"
        local np = (GetNumPartyMembers and GetNumPartyMembers()) or 0
        for i = 1, np do u[#u + 1] = "party" .. i end
    end
    return u
end

-- ---------------------------------------------------------------------------
-- UI
-- ---------------------------------------------------------------------------
local Redraw
local frame = CreateFrame("Frame", "DeepwardThreatFrame", UIParent)
local d0 = DB()
frame:SetSize(d0.width, d0.height)
if d0.point then frame:SetPoint(d0.point, UIParent, d0.point, d0.x or 0, d0.y or 0)
else frame:SetPoint("CENTER", -300, 0) end
frame:SetMovable(true); frame:SetResizable(true); frame:EnableMouse(true); frame:SetClampedToScreen(true)
frame:SetMinResize(160, 80); frame:SetMaxResize(500, 640)
frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
frame:SetBackdropColor(0.05, 0.07, 0.12, 0.92)
frame:SetBackdropBorderColor(0.35, 0.55, 0.9, 1)
frame:Hide()
table.insert(UISpecialFrames, "DeepwardThreatFrame")

local function SavePos()
    local d = DB()
    local p, _, _, x, y = frame:GetPoint()
    d.point, d.x, d.y = p, x, y
    d.width, d.height = math.floor(frame:GetWidth() + 0.5), math.floor(frame:GetHeight() + 0.5)
end

local header = CreateFrame("Frame", nil, frame)
header:SetPoint("TOPLEFT", 4, -4); header:SetPoint("TOPRIGHT", -4, -4); header:SetHeight(16)
local htex = header:CreateTexture(nil, "BACKGROUND"); htex:SetAllPoints(); htex:SetTexture(0.12, 0.16, 0.28, 0.9)
frame.title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
frame.title:SetPoint("LEFT", 4, 0); frame.title:SetText("|cffffd100Threat|r")

frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function() frame:StartMoving() end)
frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); SavePos() end)

local ROW_H = 16
local rows = {}
local function Row(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, frame)
    r:SetHeight(ROW_H)
    r.bar = r:CreateTexture(nil, "ARTWORK")
    r.bar:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    r.bar:SetPoint("TOPLEFT"); r.bar:SetPoint("BOTTOMLEFT"); r.bar:SetWidth(1)
    r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(); r.bg:SetTexture(0, 0, 0, 0.35)
    r.left = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.left:SetPoint("LEFT", 4, 0); r.left:SetJustifyH("LEFT")
    r.right = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.right:SetPoint("RIGHT", -4, 0); r.right:SetJustifyH("RIGHT")
    rows[i] = r
    return r
end

local function VisibleRows()
    return math.max(1, math.floor((frame:GetHeight() - 24) / ROW_H))
end

-- flash overlay for the pull warning
local flash = frame:CreateTexture(nil, "OVERLAY")
flash:SetAllPoints(); flash:SetTexture(1, 0, 0, 0.25); flash:Hide()
local flashT = 0

Redraw = function()
    if not frame:IsShown() then return end
    local mob = "target"
    local haveMob = UnitExists(mob) and UnitCanAttack("player", mob)
    frame.title:SetText(haveMob and ("|cffffd100Threat:|r " .. (UnitName(mob) or "")) or "|cffffd100Threat|r")

    -- collect group threat on the mob
    local list, topVal, myPct, myTanking = {}, 1, 0, false
    if haveMob then
        for _, u in ipairs(GroupUnits()) do
            if UnitExists(u) then
                local isTanking, _, threatpct, _, threatval = UnitDetailedThreatSituation(u, mob)
                if threatval and threatval > 0 then
                    list[#list + 1] = { unit = u, name = UnitName(u) or "?", pct = threatpct or 0,
                                        val = threatval, tanking = isTanking }
                    if threatval > topVal then topVal = threatval end
                    if UnitIsUnit(u, "player") then myPct = threatpct or 0; myTanking = isTanking end
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.val > b.val end)

    local shown = VisibleRows()
    for i = 1, shown do
        local r = Row(i)
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", 4, -22 - (i - 1) * ROW_H); r:SetPoint("TOPRIGHT", -4, -22 - (i - 1) * ROW_H)
        local e = list[i]
        if e then
            local cr, cg, cb = ClassColor(e.unit)
            if e.tanking then cr, cg, cb = 0.85, 0.2, 0.2 end   -- aggro holder = red
            r.bar:SetWidth((frame:GetWidth() - 8) * (e.val / topVal))
            r.bar:SetVertexColor(cr, cg, cb, 0.9)
            local tag = e.tanking and "|cffff4040<|r " or ""
            local me = UnitIsUnit(e.unit, "player") and "|cffffff00>|r " or ""
            r.left:SetText(("%s%s%s"):format(tag, me, e.name)); r.left:SetTextColor(1, 1, 1)
            r.right:SetText(("%d%%  %s"):format(e.pct, ShortNum(e.val))); r.right:SetTextColor(1, 1, 1)
            r:Show()
        else
            r:Hide()
        end
    end
    for i = shown + 1, #rows do rows[i]:Hide() end

    -- pull warning: high threat and not tanking
    if DB().warn and haveMob and not myTanking and myPct >= 90 then
        flash:Show()
        if DB().sound and not frame._warned then PlaySound("igQuestFailed"); frame._warned = true end
    else
        flash:Hide(); frame._warned = false
    end
end

-- flash pulse + throttled redraw
local acc = 0
frame:SetScript("OnUpdate", function(_, e)
    if flash:IsShown() then
        flashT = flashT + e * 4
        flash:SetAlpha(0.15 + 0.15 * math.abs(math.sin(flashT)))
    end
    acc = acc + e
    if acc >= 0.25 then acc = 0; Redraw() end
end)

-- resize grip
local grip = CreateFrame("Button", nil, frame)
grip:SetSize(16, 16); grip:SetPoint("BOTTOMRIGHT", -2, 2)
grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
grip:SetScript("OnMouseUp", function() frame:StopMovingOrSizing(); SavePos(); Redraw() end)

-- right-click config
local menuFrame = CreateFrame("Frame", "DeepwardThreatMenu", UIParent, "UIDropDownMenuTemplate")
local function Menu()
    return {
        { text = ADDON, isTitle = true, notCheckable = true },
        { text = "Auto show in combat", checked = DB().autoShow, keepShownOnClick = true,
          func = function() DB().autoShow = not DB().autoShow end },
        { text = "Pull warning (flash)", checked = DB().warn, keepShownOnClick = true,
          func = function() DB().warn = not DB().warn end },
        { text = "Warning sound", checked = DB().sound, keepShownOnClick = true,
          func = function() DB().sound = not DB().sound end },
        { text = "Close", notCheckable = true, func = function() end },
    }
end
frame:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then EasyMenu(Menu(), menuFrame, "cursor", 0, 0, "MENU") end
end)

-- ---------------------------------------------------------------------------
-- Auto show/hide + events
-- ---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if DB().shown then frame:Show(); Redraw() end   -- restore persistent visibility
    elseif event == "PLAYER_REGEN_DISABLED" then
        if DB().autoShow and not frame:IsShown() then frame:Show(); DB().shown = true; Redraw() end
    else
        if frame:IsShown() then Redraw() end
    end
end)

SLASH_DEEPWARDTHREAT1 = "/dwthreat"
SLASH_DEEPWARDTHREAT2 = "/dwt"
SlashCmdList["DEEPWARDTHREAT"] = function()
    if frame:IsShown() then frame:Hide(); DB().shown = false
    else frame:Show(); DB().shown = true; Redraw() end
end

-- expose a toggle for the Deepward panel button
function DeepwardThreat_Toggle() SlashCmdList["DEEPWARDTHREAT"]("") end
_G.DeepwardThreat_Toggle = DeepwardThreat_Toggle
