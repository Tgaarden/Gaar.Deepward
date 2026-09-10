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
    if d.framePortraits == nil then d.framePortraits = true end   -- square portrait with our own border
    if d.frameThreshold == nil then d.frameThreshold = true end   -- recolour health bar on low HP
    if d.frameStripBorders == nil then d.frameStripBorders = true end   -- hide Blizzard's ornate borders
    if d.frameBackdrop == nil then d.frameBackdrop = true end           -- black see-through backing panel
    if d.framePartyBuffs == nil then d.framePartyBuffs = true end        -- always show buffs on party members
    return d
end

-- health bar, power bar, unit token, portrait texture
local FRAMES = {
    { h = "PlayerFrameHealthBar",       m = "PlayerFrameManaBar",       u = "player", p = "PlayerPortrait" },
    { h = "TargetFrameHealthBar",       m = "TargetFrameManaBar",       u = "target", p = "TargetFramePortrait" },
    { h = "FocusFrameHealthBar",        m = "FocusFrameManaBar",        u = "focus",  p = "FocusFramePortrait" },
    { h = "PetFrameHealthBar",          m = "PetFrameManaBar",          u = "pet",    p = "PetPortrait" },
    { h = "PartyMemberFrame1HealthBar", m = "PartyMemberFrame1ManaBar", u = "party1", p = "PartyMemberFrame1Portrait" },
    { h = "PartyMemberFrame2HealthBar", m = "PartyMemberFrame2ManaBar", u = "party2", p = "PartyMemberFrame2Portrait" },
    { h = "PartyMemberFrame3HealthBar", m = "PartyMemberFrame3ManaBar", u = "party3", p = "PartyMemberFrame3Portrait" },
    { h = "PartyMemberFrame4HealthBar", m = "PartyMemberFrame4ManaBar", u = "party4", p = "PartyMemberFrame4Portrait" },
}

-- unit token -> its top-level Blizzard frame (for the backdrop panel)
local FRAME_OF = {
    player = "PlayerFrame", target = "TargetFrame", focus = "FocusFrame", pet = "PetFrame",
    party1 = "PartyMemberFrame1", party2 = "PartyMemberFrame2", party3 = "PartyMemberFrame3", party4 = "PartyMemberFrame4",
}

-- Black, semi-transparent backing panel tight around a unit frame's portrait + bars (+ name). Uses absolute
-- screen bounds (min/max of portrait & bars) so it works for the mirrored target/focus frames too.
local function StyleBackdrop(f)
    local uf, pt, hb, mb = _G[FRAME_OF[f.u]], _G[f.p], _G[f.h], _G[f.m]
    if not (uf and pt and hb and mb) then return end
    if not (hb:GetLeft() and mb:GetLeft() and pt:GetLeft()) then return end   -- not laid out yet
    if not f._bd then
        local bd = CreateFrame("Frame", nil, uf)
        bd:SetFrameLevel(math.max(0, uf:GetFrameLevel() - 1))
        bd:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        bd:SetBackdropColor(0, 0, 0, 0.5)
        bd:SetBackdropBorderColor(0, 0, 0, 0.9)
        f._bd = bd
        -- round backing disc behind the round portrait (minimap background = a dark circle)
        local c = uf:CreateTexture(nil, "BACKGROUND")
        c:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
        c:SetVertexColor(0, 0, 0, 0.55)
        f._circle = c
    end
    local bd = f._bd
    if not DB().frameBackdrop then bd:Hide(); if f._circle then f._circle:Hide() end; return end
    -- Square panel: behind the BAR BLOCK only (name -> mana), not the portrait.
    local l = math.min(hb:GetLeft(), mb:GetLeft())
    local r = math.max(hb:GetRight(), mb:GetRight())
    local t = hb:GetTop()
    local b = mb:GetBottom()
    local topPad = (f.u:find("party")) and 14 or 16   -- reach up over the name row
    bd:ClearAllPoints()
    bd:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l - 5, t + topPad)
    bd:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", r + 5, b - 5)
    bd:Show()
    -- Round panel: a dark circle behind the portrait.
    local c = f._circle
    c:ClearAllPoints()
    c:SetPoint("CENTER", pt, "CENTER", 0, 0)
    c:SetSize(pt:GetWidth() * 1.35, pt:GetHeight() * 1.35)
    c:Show()
end

-- Blizzard's ornate frame/portrait border art — hidden (we don't want it). Combat/aggro flash effects are
-- left alone. Re-applied because Blizzard re-shows them on updates.
local BLIZZ_BORDERS = {
    "PlayerFrameTexture", "TargetFrameTextureFrameTexture", "FocusFrameTextureFrameTexture", "PetFrameTexture",
    "PartyMemberFrame1Texture", "PartyMemberFrame2Texture", "PartyMemberFrame3Texture", "PartyMemberFrame4Texture",
}
local function StripBlizzardBorders()
    for _, n in ipairs(BLIZZ_BORDERS) do
        local t = _G[n]
        if t and t:IsShown() then t:Hide() end
    end
end

-- Portraits keep their default texture (full crop); clear any leftover square crop/border from older versions.
local function ResetPortraits()
    for _, f in ipairs(FRAMES) do
        local pt = _G[f.p]
        if pt then
            if pt.SetTexCoord then pt:SetTexCoord(0, 1, 0, 1) end
            if pt._dwBorder then pt._dwBorder:Hide() end
        end
    end
end

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
    b:SetBackdropBorderColor(0, 0, 0, 1)   -- our own clean black edge (Blizzard's round ring is hidden)
    b:Show()
end

-- Party frames have very thin health/mana bars — the two lines of text overlap and can't be read. Give the
-- party bars more height and stack mana cleanly under health. Re-applied from the driver since Blizzard
-- relays the party frames on updates.
-- Portrait sized to the FULL bar block height (top of health to bottom of the last bar).
-- side "left"  (player): portrait sits left of the bars; `wide` extends it out toward the frame edge/crown.
-- side "right" (target, mirrored frame): portrait sits right of the bars, kept square.
-- opts: side "left"/"right"; wide = fraction 0..1 of the space out to the frame edge to fill; fillTop = grow
-- the portrait up to the frame's top edge (anchored at the bottom to the last bar so it grows upward).
local function StyleBigPortrait(portraitName, hbName, mbName, ufName, side, opts)
    opts = opts or {}
    local pt, hb, mb, uf = _G[portraitName], _G[hbName], _G[mbName], _G[ufName]
    if not (pt and hb and mb) then return end
    if not DB().framePortraits then return end
    local hTop, mBot = hb:GetTop(), mb:GetBottom()
    if not hTop or not mBot then return end
    local barH = hTop - mBot
    if barH < 8 then return end
    local topY = (opts.fillTop and uf and uf:GetTop()) or hTop
    local h = topY - mBot
    local w = barH                                   -- square base = bar-block height
    if opts.wide and opts.wide > 0 and uf then       -- widen toward the frame's left edge (player)
        local span = (hb:GetLeft() and uf:GetLeft()) and (hb:GetLeft() - uf:GetLeft() - 6) or barH
        if span > barH then w = barH + (span - barH) * opts.wide end
    end
    pt:ClearAllPoints()
    if side == "right" then pt:SetPoint("BOTTOMLEFT", mb, "BOTTOMRIGHT", 5, 0)
    else pt:SetPoint("BOTTOMRIGHT", mb, "BOTTOMLEFT", -5, 0) end
    pt:SetWidth(w); pt:SetHeight(h)
    if pt.SetTexCoord then pt:SetTexCoord(0.16, 0.86, 0.16, 0.86) end
end

-- Always-show buffs on party members: a small row of buff icons under each party frame.
local function StylePartyBuffs(idx)
    local pf = _G["PartyMemberFrame" .. idx]
    local mb = _G["PartyMemberFrame" .. idx .. "ManaBar"]
    if not (pf and mb) then return end
    pf._dwBuffs = pf._dwBuffs or {}
    local on = DB().framePartyBuffs
    local unit = "party" .. idx
    for i = 1, 8 do
        local b = pf._dwBuffs[i]
        local name, _, icon = (on and UnitExists(unit)) and UnitBuff(unit, i) or nil
        if name and icon then
            if not b then
                b = pf:CreateTexture(nil, "OVERLAY")
                b:SetSize(15, 15)
                b:SetPoint("TOPLEFT", mb, "BOTTOMLEFT", (i - 1) * 17, -2)
                b:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                pf._dwBuffs[i] = b
            end
            b:SetTexture(icon); b:Show()
        elseif b then
            b:Hide()
        end
    end
end

local PARTY_HB_W, PARTY_HB_H, PARTY_MB_H = 112, 16, 11
local function StylePartyBars(idx)
    local hb = _G["PartyMemberFrame" .. idx .. "HealthBar"]
    local mb = _G["PartyMemberFrame" .. idx .. "ManaBar"]
    local nm = _G["PartyMemberFrame" .. idx .. "Name"]
    if not hb or not mb then return end
    -- health bar: wide + tall, anchored under the name (fixed so Blizzard's relayout can't shrink it)
    if nm then
        hb:ClearAllPoints()
        hb:SetPoint("TOPLEFT", nm, "BOTTOMLEFT", 0, -2)
    end
    hb:SetWidth(PARTY_HB_W); hb:SetHeight(PARTY_HB_H)
    -- mana bar: same width, stacked right under health
    mb:ClearAllPoints()
    mb:SetPoint("TOPLEFT", hb, "BOTTOMLEFT", 0, -2)
    mb:SetWidth(PARTY_HB_W); mb:SetHeight(PARTY_MB_H)
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
        StyleBackdrop(f)                                          -- backdrop: all frames
    end
    for i = 1, 4 do StylePartyBars(i); StylePartyBuffs(i) end     -- tall readable bars + party buffs
    ResetPortraits()          -- default portrait texture (no square crop)
    StripBlizzardBorders()    -- remove the ornate border art (aggro/combat effects kept)
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
        { text = "Low-HP colour (orange/red)", checked = DB().frameThreshold, keepShownOnClick = true,
          func = function() DB().frameThreshold = not DB().frameThreshold end },
        { text = "Black backing panel", checked = DB().frameBackdrop, keepShownOnClick = true,
          func = function() DB().frameBackdrop = not DB().frameBackdrop end },
        { text = "Show party buffs", checked = DB().framePartyBuffs, keepShownOnClick = true,
          func = function() DB().framePartyBuffs = not DB().framePartyBuffs end },
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
