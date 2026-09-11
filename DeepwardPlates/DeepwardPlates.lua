--[[
  Deepward Plates — a custom nameplate addon for 3.3.5a. ORIGINAL code, inspired by the feature set of
  modern nameplate addons — NOT a copy of any other addon's code, art or layout.

  Approach: 3.3.5a has no nameplate unit API, so we cannot create nameplates from scratch. Instead we let
  Blizzard spawn its default plate, then HIDE its art and build our OWN frame on top of it — our own health
  bar, cast bar, name/level and text — reading the live values (health, cast progress, name, reaction colour)
  from the hidden default widgets. That gives full control over size, position, layering and styling while
  still tracking the unit the default plate is bound to.

  Features:
    * Custom flat health bar (configurable width/height) with dark backdrop + 1px black border.
    * Colour by reaction (read from the default bar), by class (target only), by health %, or solid; execute
      tint under a threshold.
    * Name above the bar, level at the top-right; health text (off/percent/current); threat % + target-of-
      target on the target plate.
    * Custom cast bar with spell icon, its own backdrop + border.
    * Target highlight (border + scale); role-aware threat colour + aggro glow on the target plate.
    * Non-target shading (dims plates that are not your current target).

  Per-plate auras, click-casting, spell names on casts and per-plate threat are impossible on 3.3.5a (no unit
  API) — threat / threat% / target-of-target therefore apply to your current target only. All client-side.
  Options: /dwplates.
]]

local _G = _G
local WorldFrame = WorldFrame
local BAR_TEX = "Interface\\TargetingFrame\\UI-StatusBar"
local WHITE = "Interface\\Buttons\\WHITE8x8"

local function DB()
    if type(DeepwardPlatesDB) ~= "table" then DeepwardPlatesDB = {} end
    local d = DeepwardPlatesDB
    if d.enabled     == nil then d.enabled = true end
    if d.width       == nil then d.width = 120 end
    if d.height      == nil then d.height = 12 end
    if d.castHeight  == nil then d.castHeight = 9 end
    if d.colorMode   == nil then d.colorMode = "reaction" end   -- reaction | class | health | solid
    if d.solid       == nil then d.solid = { 0.2, 0.6, 1.0 } end
    if d.execute     == nil then d.execute = true end
    if d.executePct  == nil then d.executePct = 20 end
    if d.healthText  == nil then d.healthText = "percent" end     -- off | percent | current
    if d.nameSize    == nil then d.nameSize = 11 end
    if d.targetHi    == nil then d.targetHi = true end
    if d.targetScale == nil then d.targetScale = 1.15 end
    if d.threat      == nil then d.threat = true end
    if d.threatText  == nil then d.threatText = true end
    if d.role        == nil then d.role = "dps" end
    if d.dimOthers   == nil then d.dimOthers = true end
    if d.dimAlpha    == nil then d.dimAlpha = 0.55 end
    if d.totText     == nil then d.totText = true end
    return d
end

local styled = {}   -- default plate -> our overlay table

-- The default 3.3.5 nameplate: two StatusBar children (health, cast) + a set of regions in a fixed order.
local function Parse(plate)
    local hb, cb = plate:GetChildren()
    local glow, hpBorder, castBorder, castNoStop, spellIcon, highlight, name, level, boss, raid, elite = plate:GetRegions()
    return hb, cb, { glow = glow, hpBorder = hpBorder, castBorder = castBorder, spellIcon = spellIcon,
                     highlight = highlight, name = name, level = level, boss = boss, raid = raid, elite = elite }
end

local function IsPlate(frame)
    if frame:GetName() then return false end
    local hb = frame:GetChildren()
    if not hb or not hb.GetObjectType or hb:GetObjectType() ~= "StatusBar" then return false end
    local _, _, _, _, _, _, name = frame:GetRegions()
    return name and name.GetObjectType and name:GetObjectType() == "FontString"
end

local function BorderFrame(parent, level, size)
    local bd = CreateFrame("Frame", nil, parent)
    bd:SetFrameLevel(level)
    bd:SetPoint("TOPLEFT", -1, 1); bd:SetPoint("BOTTOMRIGHT", 1, -1)
    bd:SetBackdrop({ edgeFile = WHITE, edgeSize = size or 1 })
    bd:SetBackdropBorderColor(0, 0, 0, 1)
    return bd
end

local function ApplySize(o)
    o.health:SetSize(DB().width, DB().height)
    o.cast:SetSize(DB().width, DB().castHeight)
    o.cast.icon:SetSize(DB().castHeight + 8, DB().castHeight + 8)
end

local function SetFonts(o)
    local ns = DB().nameSize
    local hs = math.max(8, DB().height - 2)
    o.name:SetFont(STANDARD_TEXT_FONT, ns, "OUTLINE")
    o.level:SetFont(STANDARD_TEXT_FONT, ns - 2, "OUTLINE")
    o.htext:SetFont(STANDARD_TEXT_FONT, hs, "OUTLINE")
    o.ttext:SetFont(STANDARD_TEXT_FONT, hs, "OUTLINE")
    o.tot:SetFont(STANDARD_TEXT_FONT, math.max(7, ns - 3), "OUTLINE")
end

-- Build our overlay on top of a default plate (once per plate; plates are pooled so this is bounded).
local function BuildOverlay(plate)
    local hb, cb, r = Parse(plate)
    if not (hb and r.name) then return end

    local o = { plate = plate, hb = hb, cb = cb, r = r }

    local f = CreateFrame("Frame", nil, plate)
    f:SetFrameLevel((plate:GetFrameLevel() or 0) + 2)
    o.frame = f

    -- health bar, anchored to the (hidden) default health bar so it tracks the unit
    local h = CreateFrame("StatusBar", nil, f)
    h:SetStatusBarTexture(BAR_TEX)
    h:SetPoint("CENTER", hb, "CENTER", 0, 0)
    o.health = h
    local bg = h:CreateTexture(nil, "BACKGROUND"); bg:SetTexture(0, 0, 0, 0.85)
    bg:SetPoint("TOPLEFT", -1, 1); bg:SetPoint("BOTTOMRIGHT", 1, -1)
    o.hbd = BorderFrame(h, h:GetFrameLevel(), 1)

    -- target / aggro highlight border (outside the bar)
    local hi = CreateFrame("Frame", nil, h); hi:SetFrameLevel(h:GetFrameLevel() + 2)
    hi:SetPoint("TOPLEFT", -2, 2); hi:SetPoint("BOTTOMRIGHT", 2, -2)
    hi:SetBackdrop({ edgeFile = WHITE, edgeSize = 2 }); hi:Hide()
    o.hi = hi

    -- texts
    o.name  = h:CreateFontString(nil, "OVERLAY"); o.name:SetPoint("BOTTOM", h, "TOP", 0, 2)
    o.level = h:CreateFontString(nil, "OVERLAY"); o.level:SetPoint("BOTTOMRIGHT", h, "TOPRIGHT", 0, 2)
    o.htext = h:CreateFontString(nil, "OVERLAY"); o.htext:SetPoint("CENTER", h, "CENTER", 0, 0)
    o.ttext = h:CreateFontString(nil, "OVERLAY"); o.ttext:SetPoint("RIGHT", h, "RIGHT", -2, 0)

    -- cast bar
    local c = CreateFrame("StatusBar", nil, f); c:SetStatusBarTexture(BAR_TEX)
    c:SetPoint("TOP", h, "BOTTOM", 0, -3)
    local cbg = c:CreateTexture(nil, "BACKGROUND"); cbg:SetTexture(0, 0, 0, 0.85)
    cbg:SetPoint("TOPLEFT", -1, 1); cbg:SetPoint("BOTTOMRIGHT", 1, -1)
    BorderFrame(c, c:GetFrameLevel(), 1)
    local ci = c:CreateTexture(nil, "OVERLAY"); ci:SetPoint("RIGHT", c, "LEFT", -2, 0)
    ci:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    c.icon = ci; c:Hide()
    o.cast = c

    o.tot = h:CreateFontString(nil, "OVERLAY"); o.tot:SetPoint("TOP", c, "BOTTOM", 0, -1)

    ApplySize(o); SetFonts(o)
    return o
end

-- Hide the default plate's own art (re-asserted each update since pooled plates get re-shown on reuse).
local function HideDefault(o)
    o.hb:SetAlpha(0)
    if o.cb then o.cb:SetAlpha(0) end
    local r = o.r
    if r.name then r.name:SetAlpha(0) end
    if r.level then r.level:SetAlpha(0) end
    for _, reg in ipairs({ r.hpBorder, r.castBorder, r.glow, r.highlight, r.boss, r.elite }) do
        if reg and reg.SetAlpha then reg:SetAlpha(0) end
    end
end

local function BarColor(o, isTarget)
    local mode = DB().colorMode
    if mode == "solid" then return DB().solid[1], DB().solid[2], DB().solid[3] end
    if mode == "class" and isTarget and UnitIsPlayer("target") then
        local _, cls = UnitClass("target"); local c = cls and RAID_CLASS_COLORS[cls]
        if c then return c.r, c.g, c.b end
    end
    if mode == "health" then
        local _, max = o.hb:GetMinMaxValues(); local cur = o.hb:GetValue()
        local p = (max and max > 0) and cur / max or 1
        return (1 - p), p, 0
    end
    -- reaction: mirror the colour Blizzard already set on the default bar
    return o.hb:GetStatusBarColor()
end

local function UpdatePlate(o)
    HideDefault(o)

    local hb = o.hb
    local mn, mx = hb:GetMinMaxValues()
    local cur = hb:GetValue()
    local pct = (mx and mx > 0) and (cur / mx) or 1
    o.health:SetMinMaxValues(mn, mx); o.health:SetValue(cur)

    local nameText = o.r.name and o.r.name:GetText() or ""
    local isTarget = nameText ~= "" and UnitExists("target") and UnitCanAttack("player", "target")
                     and nameText == UnitName("target")

    -- colour
    local cr, cg, cb = BarColor(o, isTarget)
    if cr then o.health:SetStatusBarColor(cr, cg, cb) end
    if DB().execute and pct * 100 <= DB().executePct then o.health:SetStatusBarColor(0.5, 0, 0) end

    -- threat (target only) + differential text
    local aggro
    o.ttext:SetText("")
    if DB().threat and isTarget then
        local tanking, status, pctThreat = UnitDetailedThreatSituation("player", "target")
        if DB().role == "tank" then
            if tanking then o.health:SetStatusBarColor(0.2, 0.9, 0.2) else o.health:SetStatusBarColor(0.9, 0.2, 0.2); aggro = true end
        else
            if tanking then o.health:SetStatusBarColor(0.9, 0.2, 0.2); aggro = true
            elseif status and status >= 1 then o.health:SetStatusBarColor(1.0, 0.8, 0.0) end
        end
        if DB().threatText and pctThreat then o.ttext:SetText(("%d%%"):format(pctThreat + 0.5)) end
    end

    -- name + level
    o.name:SetText(nameText)
    if isTarget and DB().colorMode == "class" and UnitIsPlayer("target") then
        local _, cls = UnitClass("target"); local c = cls and RAID_CLASS_COLORS[cls]
        if c then o.name:SetTextColor(c.r, c.g, c.b) else o.name:SetTextColor(1, 1, 1) end
    else
        o.name:SetTextColor(1, 1, 1)
    end
    o.level:SetText(o.r.level and o.r.level:GetText() or "")

    -- health text
    local mode = DB().healthText
    if mode == "off" then o.htext:SetText("")
    elseif mode == "current" then o.htext:SetText(AbbreviateLargeNumbers and AbbreviateLargeNumbers(cur) or tostring(cur))
    else o.htext:SetText(math.floor(pct * 100 + 0.5) .. "%") end

    -- target-of-target
    if DB().totText and isTarget and UnitExists("targettarget") then
        o.tot:SetText("-> " .. (UnitName("targettarget") or ""))
    else
        o.tot:SetText("")
    end

    -- cast bar mirror (the default cast bar is shown/hidden by Blizzard while casting)
    local cb = o.cb
    if cb and cb:IsShown() then
        local a, b = cb:GetMinMaxValues()
        o.cast:SetMinMaxValues(a, b); o.cast:SetValue(cb:GetValue())
        if o.r.spellIcon and o.r.spellIcon.GetTexture then o.cast.icon:SetTexture(o.r.spellIcon:GetTexture()) end
        o.cast:SetStatusBarColor(1.0, 0.7, 0.0)
        o.cast:Show()
    else
        o.cast:Hide()
    end

    -- highlight + scale
    if aggro then o.hi:SetBackdropBorderColor(1, 0, 0, 1); o.hi:Show()
    elseif DB().targetHi and isTarget then o.hi:SetBackdropBorderColor(1, 1, 1, 1); o.hi:Show()
    else o.hi:Hide() end
    o.frame:SetScale((DB().targetHi and isTarget) and DB().targetScale or 1)

    -- non-target shading
    if DB().dimOthers then
        o.frame:SetAlpha((not UnitExists("target") or isTarget) and 1 or DB().dimAlpha)
    else
        o.frame:SetAlpha(1)
    end
end

-- Scan for new plates + drive live updates, throttled.
local driver = CreateFrame("Frame")
local acc, lastCount = 0, 0
driver:SetScript("OnUpdate", function(_, e)
    if not DB().enabled then return end
    acc = acc + e
    if acc < 0.08 then return end
    acc = 0
    local n = WorldFrame:GetNumChildren()
    if n ~= lastCount then
        lastCount = n
        for _, child in ipairs({ WorldFrame:GetChildren() }) do
            if not styled[child] and IsPlate(child) then
                local o = BuildOverlay(child)
                if o then styled[child] = o end
            end
        end
    end
    for plate, o in pairs(styled) do
        if plate:IsShown() then UpdatePlate(o) end
    end
end)

-- ---------------------------------------------------------------------------
-- Config
-- ---------------------------------------------------------------------------
local function refreshAll()
    for _, o in pairs(styled) do ApplySize(o); SetFonts(o) end
end

local menuFrame = CreateFrame("Frame", "DeepwardPlatesMenu", UIParent, "UIDropDownMenuTemplate")
local function Menu()
    return {
        { text = "Deepward Plates", isTitle = true, notCheckable = true },
        { text = "Enabled", checked = DB().enabled, keepShownOnClick = true, func = function() DB().enabled = not DB().enabled end },
        { text = "Colour by", notCheckable = true, hasArrow = true, menuList = {
            { text = "Reaction", checked = (DB().colorMode == "reaction"), func = function() DB().colorMode = "reaction" end },
            { text = "Class (players)", checked = (DB().colorMode == "class"), func = function() DB().colorMode = "class" end },
            { text = "Health %", checked = (DB().colorMode == "health"), func = function() DB().colorMode = "health" end },
            { text = "Solid", checked = (DB().colorMode == "solid"), func = function() DB().colorMode = "solid" end },
        } },
        { text = "Health text", notCheckable = true, hasArrow = true, menuList = {
            { text = "Off", checked = (DB().healthText == "off"), func = function() DB().healthText = "off" end },
            { text = "Percent", checked = (DB().healthText == "percent"), func = function() DB().healthText = "percent" end },
            { text = "Current", checked = (DB().healthText == "current"), func = function() DB().healthText = "current" end },
        } },
        { text = "Execute tint (low HP)", checked = DB().execute, keepShownOnClick = true, func = function() DB().execute = not DB().execute end },
        { text = "Target highlight", checked = DB().targetHi, keepShownOnClick = true, func = function() DB().targetHi = not DB().targetHi end },
        { text = "Threat colour on target", checked = DB().threat, keepShownOnClick = true, func = function() DB().threat = not DB().threat end },
        { text = "Threat % text", checked = DB().threatText, keepShownOnClick = true, func = function() DB().threatText = not DB().threatText end },
        { text = "Target-of-target name", checked = DB().totText, keepShownOnClick = true, func = function() DB().totText = not DB().totText end },
        { text = "Dim non-target plates", checked = DB().dimOthers, keepShownOnClick = true, func = function() DB().dimOthers = not DB().dimOthers end },
        { text = "My role", notCheckable = true, hasArrow = true, menuList = {
            { text = "DPS / Healer", checked = (DB().role == "dps"), func = function() DB().role = "dps" end },
            { text = "Tank", checked = (DB().role == "tank"), func = function() DB().role = "tank" end },
        } },
        { text = "Bar width", notCheckable = true, hasArrow = true, menuList = {
            { text = "Narrow (100)", checked = (DB().width == 100), func = function() DB().width = 100; refreshAll() end },
            { text = "Normal (120)", checked = (DB().width == 120), func = function() DB().width = 120; refreshAll() end },
            { text = "Wide (140)", checked = (DB().width == 140), func = function() DB().width = 140; refreshAll() end },
        } },
        { text = "Bar height", notCheckable = true, hasArrow = true, menuList = {
            { text = "Thin (10)", checked = (DB().height == 10), func = function() DB().height = 10; refreshAll() end },
            { text = "Normal (12)", checked = (DB().height == 12), func = function() DB().height = 12; refreshAll() end },
            { text = "Tall (16)", checked = (DB().height == 16), func = function() DB().height = 16; refreshAll() end },
        } },
        { text = "Name size", notCheckable = true, hasArrow = true, menuList = {
            { text = "Small (10)", checked = (DB().nameSize == 10), func = function() DB().nameSize = 10; refreshAll() end },
            { text = "Normal (11)", checked = (DB().nameSize == 11), func = function() DB().nameSize = 11; refreshAll() end },
            { text = "Large (13)", checked = (DB().nameSize == 13), func = function() DB().nameSize = 13; refreshAll() end },
        } },
        { text = "Close", notCheckable = true, func = function() end },
    }
end
function DeepwardPlates_Config() EasyMenu(Menu(), menuFrame, "cursor", 0, 0, "MENU") end
_G.DeepwardPlates_Config = DeepwardPlates_Config

SLASH_DEEPWARDPLATES1 = "/dwplates"
SlashCmdList["DEEPWARDPLATES"] = function() DeepwardPlates_Config() end
