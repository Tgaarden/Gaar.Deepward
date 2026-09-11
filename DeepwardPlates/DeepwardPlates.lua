--[[
  Deepward Plates — a feature-rich nameplate restyler for 3.3.5a. ORIGINAL code, inspired by the feature set
  of modern nameplate addons — NOT a copy of any other addon's code, art or layout.

  3.3.5a has no nameplate unit API (that arrived in Cataclysm), so per-plate auras, click-casting, spell
  names on casts and per-plate threat are not possible; those are the only gaps. Everything else is here:

    * Clean flat health bar at a configurable width/height, with a dark backdrop.
    * Colour by reaction (default), by class for players (best-effort), by health percent, or a solid colour;
      an "execute" tint under a health threshold.
    * Health text: off / percent / current / current+percent, styled font.
    * Name + level, elite/rare/boss marker, bigger raid-target icon.
    * Styled cast bar (flat + backdrop).
    * Target highlight: a bright border (and optional scale-up) on your current target's plate.
    * Threat mode: colours the TARGET plate by your threat (role-aware) + an aggro glow.

  All client-side (law I). Options: /dwplates.
]]

local _G = _G
local WorldFrame = WorldFrame
local BAR_TEX = "Interface\\TargetingFrame\\UI-StatusBar"

local function DB()
    if type(DeepwardPlatesDB) ~= "table" then DeepwardPlatesDB = {} end
    local d = DeepwardPlatesDB
    if d.enabled     == nil then d.enabled = true end
    if d.width       == nil then d.width = 120 end
    if d.height      == nil then d.height = 12 end
    if d.colorMode   == nil then d.colorMode = "reaction" end   -- reaction | class | health | solid
    if d.solid       == nil then d.solid = { 0.2, 0.6, 1.0 } end
    if d.execute     == nil then d.execute = true end            -- dark tint under executePct
    if d.executePct  == nil then d.executePct = 20 end
    if d.healthText  == nil then d.healthText = "percent" end     -- off | percent | current | both
    if d.nameSize    == nil then d.nameSize = 11 end
    if d.targetHi    == nil then d.targetHi = true end
    if d.targetScale == nil then d.targetScale = 1.15 end
    if d.threat      == nil then d.threat = true end
    if d.threatText  == nil then d.threatText = true end        -- threat % on target plate
    if d.role        == nil then d.role = "dps" end
    if d.dimOthers   == nil then d.dimOthers = true end          -- non-target shading
    if d.dimAlpha    == nil then d.dimAlpha = 0.55 end
    if d.totText     == nil then d.totText = true end            -- target-of-target name
    return d
end

local styled = {}

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

local function StylePlate(plate)
    local hb, cb, r = Parse(plate)
    if not (hb and r.name) then return end

    hb:SetStatusBarTexture(BAR_TEX)
    hb:SetWidth(DB().width); hb:SetHeight(DB().height)
    if r.hpBorder and r.hpBorder.SetTexture then r.hpBorder:SetTexture(nil) end
    if r.glow and r.glow.SetTexture then r.glow:SetTexture(nil) end     -- drop the default chunky threat glow art

    -- dark backdrop behind the health bar
    if not plate._bg then
        local bg = plate:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(0, 0, 0, 0.6)
        bg:SetPoint("TOPLEFT", hb, "TOPLEFT", -1, 1)
        bg:SetPoint("BOTTOMRIGHT", hb, "BOTTOMRIGHT", 1, -1)
        plate._bg = bg
    end

    -- target-highlight / aggro border frame
    if not plate._hi then
        local hi = CreateFrame("Frame", nil, plate)
        hi:SetFrameLevel(hb:GetFrameLevel() + 2)
        hi:SetPoint("TOPLEFT", hb, "TOPLEFT", -2, 2)
        hi:SetPoint("BOTTOMRIGHT", hb, "BOTTOMRIGHT", 2, -2)
        hi:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
        hi:Hide()
        plate._hi = hi
    end

    -- health percent/value text
    if not plate._ht then
        local fs = hb:CreateFontString(nil, "OVERLAY")
        fs:SetPoint("CENTER", hb, "CENTER", 0, 0)
        plate._ht = fs
    end
    plate._ht:SetFont(STANDARD_TEXT_FONT, math.max(8, DB().height - 2), "OUTLINE")

    -- threat % text (target only) — sits at the right end of the bar
    if not plate._tt then
        local fs = hb:CreateFontString(nil, "OVERLAY")
        fs:SetPoint("RIGHT", hb, "RIGHT", -2, 0)
        plate._tt = fs
    end
    plate._tt:SetFont(STANDARD_TEXT_FONT, math.max(8, DB().height - 2), "OUTLINE")

    -- target-of-target name — below the bar
    if not plate._tot then
        local fs = hb:CreateFontString(nil, "OVERLAY")
        fs:SetPoint("TOP", hb, "BOTTOM", 0, -1)
        plate._tot = fs
    end
    plate._tot:SetFont(STANDARD_TEXT_FONT, math.max(7, DB().nameSize - 3), "OUTLINE")

    r.name:SetFont(STANDARD_TEXT_FONT, DB().nameSize, "OUTLINE")
    if r.level then r.level:SetFont(STANDARD_TEXT_FONT, DB().nameSize - 2, "OUTLINE") end
    if r.raid and r.raid.SetSize then r.raid:SetSize(20, 20) end   -- bigger raid-target marker

    if cb and cb.SetStatusBarTexture then
        cb:SetStatusBarTexture(BAR_TEX)
        cb:SetWidth(DB().width)
        if r.castBorder and r.castBorder.SetTexture then r.castBorder:SetTexture(nil) end
    end

    plate._hb, plate._name, plate._regions = hb, r.name, r
    styled[plate] = true
end

local function BarColor(hb, name)
    local mode = DB().colorMode
    if mode == "solid" then return DB().solid[1], DB().solid[2], DB().solid[3] end
    if mode == "class" and name and UnitExists("target") and UnitName("target") == name:GetText() and UnitIsPlayer("target") then
        local _, cls = UnitClass("target"); local c = cls and RAID_CLASS_COLORS[cls]
        if c then return c.r, c.g, c.b end
    end
    if mode == "health" then
        local _, max = hb:GetMinMaxValues(); local cur = hb:GetValue()
        local p = (max and max > 0) and cur / max or 1
        return (1 - p), p, 0   -- red -> green
    end
    return nil   -- reaction: keep Blizzard's colour
end

local function UpdatePlate(plate)
    local hb = plate._hb
    if not hb then return end
    local name = plate._name
    local _, max = hb:GetMinMaxValues()
    local cur = hb:GetValue()
    local pct = (max and max > 0) and (cur / max) or 1
    local isTarget = name and UnitExists("target") and UnitCanAttack("player", "target")
                     and name:GetText() == UnitName("target")

    -- colour
    local cr, cg, cb = BarColor(hb, name)
    if cr then hb:SetStatusBarColor(cr, cg, cb) end
    if DB().execute and pct * 100 <= DB().executePct then hb:SetStatusBarColor(0.5, 0.0, 0.0) end   -- execute tint

    -- threat (target only) — colour + differential text
    local aggro
    plate._tt:SetText("")
    if DB().threat and isTarget then
        local tanking, status, pctThreat, _, rawThreat = UnitDetailedThreatSituation("player", "target")
        if DB().role == "tank" then
            if tanking then hb:SetStatusBarColor(0.2, 0.9, 0.2) else hb:SetStatusBarColor(0.9, 0.2, 0.2); aggro = true end
        else
            if tanking then hb:SetStatusBarColor(0.9, 0.2, 0.2); aggro = true
            elseif status and status >= 1 then hb:SetStatusBarColor(1.0, 0.8, 0.0) end
        end
        if DB().threatText and pctThreat then
            plate._tt:SetText(("%d%%"):format(pctThreat + 0.5))   -- your share of threat on this mob
        end
    end

    -- health text
    local ht = plate._ht
    local mode = DB().healthText
    if mode == "off" or not plate:IsShown() then ht:SetText("")
    elseif mode == "percent" then ht:SetText(math.floor(pct * 100 + 0.5) .. "%")
    elseif mode == "current" then ht:SetText(AbbreviateLargeNumbers and AbbreviateLargeNumbers(cur) or tostring(cur))
    else ht:SetText(("%d%%"):format(pct * 100 + 0.5)) end

    -- target-of-target (target plate only)
    if DB().totText and isTarget and UnitExists("targettarget") then
        plate._tot:SetText("-> " .. (UnitName("targettarget") or ""))
    else
        plate._tot:SetText("")
    end

    -- target highlight / aggro border
    local hi = plate._hi
    if aggro then hi:SetBackdropBorderColor(1, 0, 0, 1); hi:Show()
    elseif DB().targetHi and isTarget then hi:SetBackdropBorderColor(1, 1, 1, 1); hi:Show()
    else hi:Hide() end
    if DB().targetHi and isTarget then hb:SetScale(DB().targetScale) else hb:SetScale(1) end

    -- non-target shading
    if DB().dimOthers then
        plate:SetAlpha((not UnitExists("target") or isTarget) and 1 or DB().dimAlpha)
    else
        plate:SetAlpha(1)
    end
end

-- Scan for new plates + drive live updates, throttled.
local driver = CreateFrame("Frame")
local acc, lastCount = 0, 0
driver:SetScript("OnUpdate", function(_, e)
    if not DB().enabled then return end
    acc = acc + e
    if acc < 0.1 then return end
    acc = 0
    local n = WorldFrame:GetNumChildren()
    if n ~= lastCount then
        lastCount = n
        for _, child in ipairs({ WorldFrame:GetChildren() }) do
            if not styled[child] and IsPlate(child) then StylePlate(child) end
        end
    end
    for plate in pairs(styled) do
        if plate:IsShown() then UpdatePlate(plate) end
    end
end)

-- ---------------------------------------------------------------------------
-- Config
-- ---------------------------------------------------------------------------
local menuFrame = CreateFrame("Frame", "DeepwardPlatesMenu", UIParent, "UIDropDownMenuTemplate")
local function restyleAll() styled = {} end   -- forces a re-style on next scan
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
            { text = "Narrow (100)", checked = (DB().width == 100), func = function() DB().width = 100; restyleAll() end },
            { text = "Normal (120)", checked = (DB().width == 120), func = function() DB().width = 120; restyleAll() end },
            { text = "Wide (140)", checked = (DB().width == 140), func = function() DB().width = 140; restyleAll() end },
        } },
        { text = "Bar height", notCheckable = true, hasArrow = true, menuList = {
            { text = "Thin (10)", checked = (DB().height == 10), func = function() DB().height = 10; restyleAll() end },
            { text = "Normal (12)", checked = (DB().height == 12), func = function() DB().height = 12; restyleAll() end },
            { text = "Tall (16)", checked = (DB().height == 16), func = function() DB().height = 16; restyleAll() end },
        } },
        { text = "Name size", notCheckable = true, hasArrow = true, menuList = {
            { text = "Small (10)", checked = (DB().nameSize == 10), func = function() DB().nameSize = 10; restyleAll() end },
            { text = "Normal (11)", checked = (DB().nameSize == 11), func = function() DB().nameSize = 11; restyleAll() end },
            { text = "Large (13)", checked = (DB().nameSize == 13), func = function() DB().nameSize = 13; restyleAll() end },
        } },
        { text = "Close", notCheckable = true, func = function() end },
    }
end
function DeepwardPlates_Config() EasyMenu(Menu(), menuFrame, "cursor", 0, 0, "MENU") end
_G.DeepwardPlates_Config = DeepwardPlates_Config

SLASH_DEEPWARDPLATES1 = "/dwplates"
SlashCmdList["DEEPWARDPLATES"] = function() DeepwardPlates_Config() end
