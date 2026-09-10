--[[
  DeepwardUI: Frame Style — X-Perl-inspired tweaks to the default unit frames.
  Step 1 (this pass):
    * Class-coloured health bars for player units (player/target/focus/pet/party); NPC target/focus keep
      Blizzard's reaction colour.
    * Bigger, outlined text with a PERCENT on every health AND power bar ("cur/max  NN%").

  Client-side only (law I). More X-Perl features (portraits, buffs, thresholds) can follow.
]]

local _G = _G

local function DB()
    if type(DeepwardUIDB) ~= "table" then DeepwardUIDB = {} end
    local d = DeepwardUIDB
    if d.frameClassColor == nil then d.frameClassColor = true end
    if d.frameBarText   == nil then d.frameBarText   = true end
    if d.frameFontSize  == nil then d.frameFontSize  = 12 end
    if d.framePortraits == nil then d.framePortraits = true end   -- class-coloured portrait border
    if d.frameThreshold == nil then d.frameThreshold = true end   -- recolour health bar on low HP
    return d
end

-- health bar, power bar, unit token, portrait texture
local FRAMES = {
    { h = "PlayerFrameHealthBar",       m = "PlayerFrameManaBar",       u = "player", p = "PlayerPortrait" },
    { h = "TargetFrameHealthBar",       m = "TargetFrameManaBar",       u = "target", p = "TargetPortrait" },
    { h = "FocusFrameHealthBar",        m = "FocusFrameManaBar",        u = "focus",  p = "FocusPortrait" },
    { h = "PetFrameHealthBar",          m = "PetFrameManaBar",          u = "pet",    p = "PetPortrait" },
    { h = "PartyMemberFrame1HealthBar", m = "PartyMemberFrame1ManaBar", u = "party1", p = "PartyMemberFrame1Portrait" },
    { h = "PartyMemberFrame2HealthBar", m = "PartyMemberFrame2ManaBar", u = "party2", p = "PartyMemberFrame2Portrait" },
    { h = "PartyMemberFrame3HealthBar", m = "PartyMemberFrame3ManaBar", u = "party3", p = "PartyMemberFrame3Portrait" },
    { h = "PartyMemberFrame4HealthBar", m = "PartyMemberFrame4ManaBar", u = "party4", p = "PartyMemberFrame4Portrait" },
}

-- Threshold-aware health colour: low HP overrides class colour (orange < 35%, red < 20%).
local function ApplyHealthColor(bar, unit)
    if not bar or not bar.SetStatusBarColor then return end
    if not DB().frameClassColor or not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return end
    local hp, hpm = UnitHealth(unit), UnitHealthMax(unit)
    local pct = (hpm and hpm > 0) and (hp / hpm) or 1
    if DB().frameThreshold and pct <= 0.20 then bar:SetStatusBarColor(0.95, 0.12, 0.12)
    elseif DB().frameThreshold and pct <= 0.35 then bar:SetStatusBarColor(1.0, 0.55, 0.0)
    else
        local _, cls = UnitClass(unit)
        local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
        if c then bar:SetStatusBarColor(c.r, c.g, c.b) end
    end
end

-- Class-coloured border ring around a portrait (X-Perl look). Created once, cached on the portrait.
local function PortraitBorder(portraitName, unit)
    local pt = _G[portraitName]
    if not pt then return end
    if not pt._dwBorder then
        local b = CreateFrame("Frame", nil, pt:GetParent())
        b:SetFrameLevel((pt:GetParent():GetFrameLevel() or 0) + 1)
        b:SetPoint("TOPLEFT", pt, "TOPLEFT", -3, 3)
        b:SetPoint("BOTTOMRIGHT", pt, "BOTTOMRIGHT", 3, -3)
        b:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
        pt._dwBorder = b
    end
    local b = pt._dwBorder
    if not DB().framePortraits or not UnitExists(unit) then
        b:Hide()
        if pt.SetTexCoord then pt:SetTexCoord(0, 1, 0, 1) end
        return
    end
    -- Square the portrait: crop the round edges so it fills the square border instead of looking round.
    if pt.SetTexCoord then pt:SetTexCoord(0.16, 0.86, 0.16, 0.86) end
    local r, g, bl = 0.6, 0.6, 0.6
    if UnitIsPlayer(unit) then
        local _, cls = UnitClass(unit)
        local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
        if c then r, g, bl = c.r, c.g, c.b end
    end   -- NPCs keep the neutral grey border
    b:SetBackdropBorderColor(r, g, bl)
    b:Show()
end

-- Party frames have very thin health/mana bars — the two lines of text overlap and can't be read. Give the
-- party bars more height and stack mana cleanly under health. Re-applied from the driver since Blizzard
-- relays the party frames on updates.
local function StylePartyBars(idx)
    local hb = _G["PartyMemberFrame" .. idx .. "HealthBar"]
    local mb = _G["PartyMemberFrame" .. idx .. "ManaBar"]
    if not hb or not mb then return end
    if math.abs(hb:GetHeight() - 13) > 0.5 then hb:SetHeight(13) end
    local p, rel, rp, x, y = mb:GetPoint()
    if rel ~= hb or math.abs((y or 0) + 1) > 0.5 then   -- re-stack mana under health if Blizzard reset it
        mb:ClearAllPoints()
        mb:SetPoint("TOPLEFT", hb, "BOTTOMLEFT", 0, -1)
        mb:SetPoint("TOPRIGHT", hb, "BOTTOMRIGHT", 0, -1)
    end
    if math.abs(mb:GetHeight() - 9) > 0.5 then mb:SetHeight(9) end
end

local function Short(n)
    n = n or 0
    if n >= 1e6 then return ("%.1fM"):format(n / 1e6) end
    if n >= 1e3 then return ("%.1fk"):format(n / 1e3) end
    return tostring(n)
end

-- Overlay a bigger, outlined fontstring on a status bar (created once, cached on the bar).
local function BarText(bar)
    if not bar then return nil end
    if not bar._dwText then
        local fs = bar:CreateFontString(nil, "OVERLAY")
        fs:SetFont(STANDARD_TEXT_FONT, DB().frameFontSize, "OUTLINE")
        fs:SetPoint("CENTER", bar, "CENTER", 0, 0)
        fs:SetTextColor(1, 1, 1)
        bar._dwText = fs
        -- dim Blizzard's own bar text so it doesn't double up with ours
        if bar.TextString then bar.TextString:SetAlpha(0) end
    end
    return bar._dwText
end

local function UpdateBarText(barName, unit, powerBar)
    local bar = _G[barName]
    if not bar then return end
    local fs = BarText(bar)
    if not fs then return end
    if not DB().frameBarText or not UnitExists(unit) then fs:SetText(""); return end
    local cur, max
    if powerBar then cur, max = UnitPower(unit), UnitPowerMax(unit)
    else cur, max = UnitHealth(unit), UnitHealthMax(unit) end
    if not max or max <= 0 then fs:SetText(""); return end
    local pct = math.floor(cur / max * 100 + 0.5)
    fs:SetText(("%s/%s  %d%%"):format(Short(cur), Short(max), pct))
end

-- Class-colour (+ low-HP threshold) health bars for player units, after every Blizzard health update.
if type(UnitFrameHealthBar_Update) == "function" then
    hooksecurefunc("UnitFrameHealthBar_Update", function(bar, unit)
        ApplyHealthColor(bar, unit)
    end)
end

-- Live updater (0.2s): bar text, threshold re-colour, portrait borders.
local driver = CreateFrame("Frame")
local acc = 0
driver:SetScript("OnUpdate", function(_, e)
    acc = acc + e
    if acc < 0.2 then return end
    acc = 0
    for _, f in ipairs(FRAMES) do
        UpdateBarText(f.h, f.u, false)
        UpdateBarText(f.m, f.u, true)
        ApplyHealthColor(_G[f.h], f.u)
        PortraitBorder(f.p, f.u)
    end
    for i = 1, 4 do StylePartyBars(i) end   -- keep party bars tall + readable
end)

-- Re-assert class colour when the target/focus/party changes (Blizzard repaints these).
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("PLAYER_FOCUS_CHANGED")
ev:RegisterEvent("PARTY_MEMBERS_CHANGED")
ev:RegisterEvent("UNIT_PET")
ev:SetScript("OnEvent", function()
    if type(UnitFrameHealthBar_Update) ~= "function" then return end
    for _, f in ipairs(FRAMES) do
        local bar = _G[f.h]
        if bar and UnitExists(f.u) then UnitFrameHealthBar_Update(bar, f.u) end
    end
end)

local function SetFontSize(s)
    DB().frameFontSize = s
    for _, f in ipairs(FRAMES) do
        for _, bn in ipairs({ f.h, f.m }) do
            local bar = _G[bn]
            if bar and bar._dwText then bar._dwText:SetFont(STANDARD_TEXT_FONT, s, "OUTLINE") end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Unified Unit-Frames config menu (opened by /dwframes menu, /dwstyle, or the Deepward panel button).
-- ---------------------------------------------------------------------------
local menuFrame = CreateFrame("Frame", "DeepwardFramesMenu", UIParent, "UIDropDownMenuTemplate")
local function ConfigMenu()
    local locked = DeepwardUIDB and DeepwardUIDB.framesLocked
    return {
        { text = "Unit Frames", isTitle = true, notCheckable = true },
        { text = "Class-coloured bars", checked = DB().frameClassColor, keepShownOnClick = true,
          func = function() DB().frameClassColor = not DB().frameClassColor end },
        { text = "Bar text (percent)", checked = DB().frameBarText, keepShownOnClick = true,
          func = function() DB().frameBarText = not DB().frameBarText end },
        { text = "Class portraits", checked = DB().framePortraits, keepShownOnClick = true,
          func = function() DB().framePortraits = not DB().framePortraits end },
        { text = "Low-HP colour (orange/red)", checked = DB().frameThreshold, keepShownOnClick = true,
          func = function() DB().frameThreshold = not DB().frameThreshold end },
        { text = "Font size", notCheckable = true, hasArrow = true, menuList = {
            { text = "Small (11)",  checked = (DB().frameFontSize == 11), func = function() SetFontSize(11) end },
            { text = "Normal (12)", checked = (DB().frameFontSize == 12), func = function() SetFontSize(12) end },
            { text = "Large (14)",  checked = (DB().frameFontSize == 14), func = function() SetFontSize(14) end },
            { text = "Huge (16)",   checked = (DB().frameFontSize == 16), func = function() SetFontSize(16) end },
        } },
        { text = "Frame scale", notCheckable = true, hasArrow = true, menuList = {
            { text = "90%",  checked = (DeepwardUIDB and DeepwardUIDB.frameScale == 0.9),  func = function() DeepwardUIDB.frameScale = 0.9;  if DeepwardFrames_ApplyScale then DeepwardFrames_ApplyScale() end end },
            { text = "100%", checked = (DeepwardUIDB and (DeepwardUIDB.frameScale or 1) == 1), func = function() DeepwardUIDB.frameScale = 1.0;  if DeepwardFrames_ApplyScale then DeepwardFrames_ApplyScale() end end },
            { text = "110%", checked = (DeepwardUIDB and DeepwardUIDB.frameScale == 1.1),  func = function() DeepwardUIDB.frameScale = 1.1;  if DeepwardFrames_ApplyScale then DeepwardFrames_ApplyScale() end end },
            { text = "125%", checked = (DeepwardUIDB and DeepwardUIDB.frameScale == 1.25), func = function() DeepwardUIDB.frameScale = 1.25; if DeepwardFrames_ApplyScale then DeepwardFrames_ApplyScale() end end },
        } },
        { text = (locked and "Unlock moving (shift-drag)" or "Lock moving"), notCheckable = true,
          func = function() if DeepwardFrames_ToggleLock then DeepwardFrames_ToggleLock() end end },
        { text = "Reset positions (then /reload)", notCheckable = true,
          func = function() if DeepwardFrames_ResetPositions then DeepwardFrames_ResetPositions() end end },
        { text = "Close", notCheckable = true, func = function() end },
    }
end

function DeepwardFrames_Config()
    EasyMenu(ConfigMenu(), menuFrame, "cursor", 0, 0, "MENU")
end
_G.DeepwardFrames_Config = DeepwardFrames_Config

SLASH_DEEPWARDFRAMESTYLE1 = "/dwstyle"
SlashCmdList["DEEPWARDFRAMESTYLE"] = function() DeepwardFrames_Config() end
