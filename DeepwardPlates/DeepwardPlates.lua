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
local AURA_N, AURA_SZ = 8, 16   -- max debuff icons shown, and their pixel size

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
    if d.auras       == nil then d.auras = true end            -- my debuffs on the target plate
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

local HideDefault   -- forward declaration (defined below; hooked on each plate's OnShow)

-- Build our overlay on top of a default plate (once per plate; plates are pooled so this is bounded).
local function BuildOverlay(plate)
    local hb, cb, r = Parse(plate)
    if not (hb and r.name) then return end

    local o = { plate = plate, hb = hb, cb = cb, r = r }

    -- Collect the default textures generically (region-name guessing is fragile). Two groups:
    --   hideTex = the plate's own regions (glow, borders, highlight, elite/boss art) — these are CLEARED with
    --             SetTexture(nil) because Blizzard re-shows them every frame; nil'ing makes them render
    --             nothing regardless. The spell icon is a plate region too but kept (read for our cast bar).
    --   fadeTex = the health/cast bars' fill textures — only faded to alpha 0 (never nil'd, so the default
    --             bar's stored StatusBarColor stays readable for reaction colouring). Our bars sit on top.
    -- The raid-target marker (r.raid) is left fully visible.
    o.hideTex, o.fadeTex = {}, {}
    for _, reg in ipairs({ plate:GetRegions() }) do
        if reg and reg.GetObjectType and reg:GetObjectType() == "Texture" and reg ~= r.raid then
            o.hideTex[#o.hideTex + 1] = reg
        end
    end
    local function fade(frame)
        if not frame then return end
        for _, reg in ipairs({ frame:GetRegions() }) do
            if reg and reg.GetObjectType and reg:GetObjectType() == "Texture" then
                o.fadeTex[#o.fadeTex + 1] = reg
            end
        end
    end
    fade(hb); fade(cb)

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

    -- cast bar — floats just OVER the name (above the health bar), so a cast overlaps the name row
    local c = CreateFrame("StatusBar", nil, f); c:SetStatusBarTexture(BAR_TEX)
    c:SetPoint("BOTTOM", h, "TOP", 0, 1)
    c:SetFrameLevel(h:GetFrameLevel() + 4)   -- above the name text
    local cbg = c:CreateTexture(nil, "BACKGROUND"); cbg:SetTexture(0, 0, 0, 0.85)
    cbg:SetPoint("TOPLEFT", -1, 1); cbg:SetPoint("BOTTOMRIGHT", 1, -1)
    BorderFrame(c, c:GetFrameLevel(), 1)
    local ci = c:CreateTexture(nil, "OVERLAY"); ci:SetPoint("RIGHT", c, "LEFT", -2, 0)
    ci:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    c.icon = ci; c:Hide()
    o.cast = c

    -- my debuffs on the target — a centered row of icons UNDER the health bar (target plate only; 3.3.5 has
    -- no unit API for non-target plates, so auras can only be read for the current target).
    o.auraRow = CreateFrame("Frame", nil, f)
    o.auraRow:SetPoint("TOP", h, "BOTTOM", 0, -2)
    o.auraRow:SetSize(DB().width, AURA_SZ)
    o.auraIcons = {}
    for i = 1, AURA_N do
        local ic = CreateFrame("Frame", nil, o.auraRow)
        ic:SetSize(AURA_SZ, AURA_SZ)
        local t = ic:CreateTexture(nil, "ARTWORK"); t:SetAllPoints(); t:SetTexCoord(0.08, 0.92, 0.08, 0.92); ic.tex = t
        local cd = CreateFrame("Cooldown", nil, ic, "CooldownFrameTemplate"); cd:SetAllPoints(); ic.cd = cd
        local cnt = ic:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall"); cnt:SetPoint("BOTTOMRIGHT", 1, 0); ic.cnt = cnt
        BorderFrame(ic, ic:GetFrameLevel(), 1)
        ic:Hide()
        o.auraIcons[i] = ic
    end

    o.tot = h:CreateFontString(nil, "OVERLAY"); o.tot:SetPoint("TOP", o.auraRow, "BOTTOM", 0, -1)

    ApplySize(o); SetFonts(o)
    plate:HookScript("OnShow", function() HideDefault(o) end)   -- re-hide the instant Blizzard re-shows the plate
    return o
end

-- Hide the default plate's own art. Re-asserted each update AND on the plate's OnShow, because pooled plates
-- get re-shown (Blizzard bumps a target plate's art back to full alpha) — that was the "flicker" of the
-- native red bar coming back.
-- (HideDefault is forward-declared above so BuildOverlay's OnShow hook can call it)
HideDefault = function(o)
    -- Blizzard re-shows the target's glow/border every frame by resetting its vertex colour + alpha, so
    -- alpha 0 alone flickers back. Clearing the TEXTURE makes it render nothing regardless of those resets.
    -- The spell icon is kept (we read its texture for our own cast bar) and only faded.
    for _, tex in ipairs(o.hideTex) do
        if tex == o.r.spellIcon then tex:SetAlpha(0) else tex:SetTexture(nil) end
    end
    for _, tex in ipairs(o.fadeTex) do tex:SetAlpha(0) end   -- bar fills: fade only, keep colour readable
    if o.r.name then o.r.name:SetAlpha(0) end
    if o.r.level then o.r.level:SetAlpha(0) end
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

    -- Target detection: 3.3.5 has no unit API, so we match by name — but several mobs can share a name, so
    -- also require this plate to be the one Blizzard keeps at FULL alpha (it fades every non-target plate
    -- when you have a target). That disambiguates same-named mobs, so target-only features (auras, threat,
    -- cast, ToT) land on the real target plate instead of every same-named plate.
    local nameText = o.r.name and o.r.name:GetText() or ""
    local isTarget = nameText ~= "" and UnitExists("target") and UnitCanAttack("player", "target")
                     and nameText == UnitName("target") and o.plate:GetAlpha() > 0.9

    -- The mob under the cursor: Blizzard shows this plate's highlight region, and "mouseover" is a real unit
    -- token — so hovering any mob lets us read ITS own debuffs/threat/cast/ToT. Target + mouseover are the
    -- only per-mob tokens available on 3.3.5 (nameplate units arrived in Cataclysm).
    local isMouseover = not isTarget and o.r.highlight and o.r.highlight:IsShown()
                        and UnitExists("mouseover") and UnitCanAttack("player", "mouseover")
    local unit = isTarget and "target" or (isMouseover and "mouseover") or nil

    -- colour
    local cr, cg, cb = BarColor(o, isTarget)
    if cr then o.health:SetStatusBarColor(cr, cg, cb) end
    if DB().execute and pct * 100 <= DB().executePct then o.health:SetStatusBarColor(0.5, 0, 0) end

    -- threat (target only) + differential text.
    -- When YOU hold aggro (you are the mob's primary target) the bar goes bright GREEN — a deliberately
    -- non-native colour that reads at a glance. Rising-but-not-yet-aggro shows an orange warning.
    local aggro
    o.ttext:SetText("")
    if DB().threat and unit then
        local tanking, status, pctThreat = UnitDetailedThreatSituation("player", unit)
        if tanking then
            o.health:SetStatusBarColor(0.1, 1.0, 0.1); aggro = true      -- you have aggro
        elseif status and status >= 2 then
            o.health:SetStatusBarColor(1.0, 0.6, 0.0)                    -- high threat, about to pull
        end
        if DB().threatText and pctThreat then o.ttext:SetText(("%d%%"):format(pctThreat + 0.5)) end
    end

    -- name + level
    o.name:SetText(nameText)
    if unit and DB().colorMode == "class" and UnitIsPlayer(unit) then
        local _, cls = UnitClass(unit); local c = cls and RAID_CLASS_COLORS[cls]
        if c then o.name:SetTextColor(c.r, c.g, c.b) else o.name:SetTextColor(1, 1, 1) end
    else
        o.name:SetTextColor(1, 1, 1)
    end
    o.level:SetText(o.r.level and o.r.level:GetText() or "")

    -- health text (blank at 0 HP / dead, and clear threat text too, so nothing overlaps)
    local mode = DB().healthText
    if mode == "off" or cur <= 0 then o.htext:SetText("")
    elseif mode == "current" then o.htext:SetText(AbbreviateLargeNumbers and AbbreviateLargeNumbers(cur) or tostring(cur))
    else o.htext:SetText(math.floor(pct * 100 + 0.5) .. "%") end
    if cur <= 0 then o.ttext:SetText("") end

    -- target-of-target (of whichever mob this plate maps to)
    if DB().totText and unit and UnitExists(unit .. "target") then
        o.tot:SetText("-> " .. (UnitName(unit .. "target") or ""))
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

    -- highlight + scale (green border when you hold aggro, white on your target otherwise)
    if aggro then o.hi:SetBackdropBorderColor(0.1, 1.0, 0.1, 1); o.hi:Show()
    elseif DB().targetHi and isTarget then o.hi:SetBackdropBorderColor(1, 1, 1, 1); o.hi:Show()
    else o.hi:Hide() end
    o.frame:SetScale((DB().targetHi and isTarget) and DB().targetScale or 1)

    -- non-target shading (the hovered mob stays bright too)
    if DB().dimOthers then
        o.frame:SetAlpha((not UnitExists("target") or isTarget or isMouseover) and 1 or DB().dimAlpha)
    else
        o.frame:SetAlpha(1)
    end

    -- my debuffs on the target (target plate only). Player-cast HARMFUL auras, centered under the bar.
    -- Cached: the cooldown swipe and icon positions are only rewritten when they actually change, otherwise
    -- calling SetCooldown/SetPoint every tick restarts the swipe and makes the icons flicker.
    local shown = 0
    if DB().auras and unit then
        for i = 1, 40 do
            local aname, _, icon, count, _, duration, expiration, caster = UnitAura(unit, i, "HARMFUL")
            if not aname then break end
            if caster == "player" and shown < AURA_N then
                shown = shown + 1
                local ic = o.auraIcons[shown]
                if ic._icon ~= icon then ic.tex:SetTexture(icon); ic._icon = icon end
                local cn = (count and count > 1) and count or 0
                if ic._cnt ~= cn then ic.cnt:SetText(cn > 0 and cn or ""); ic._cnt = cn end
                if duration and duration > 0 and expiration then
                    if ic._exp ~= expiration then ic.cd:SetCooldown(expiration - duration, duration); ic.cd:Show(); ic._exp = expiration end
                elseif ic._exp ~= 0 then ic.cd:Hide(); ic._exp = 0 end
                if not ic:IsShown() then ic:Show() end
            end
        end
    end
    for i = shown + 1, AURA_N do
        if o.auraIcons[i]:IsShown() then o.auraIcons[i]:Hide() end
    end
    if shown ~= o._lastShown then   -- re-centre only when the icon count changes
        o._lastShown = shown
        local step = AURA_SZ + 2
        local startX = -((shown * step - 2) / 2) + AURA_SZ / 2
        for i = 1, shown do
            o.auraIcons[i]:ClearAllPoints()
            o.auraIcons[i]:SetPoint("CENTER", o.auraRow, "CENTER", startX + (i - 1) * step, 0)
        end
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
        { text = "My debuffs on target", checked = DB().auras, keepShownOnClick = true, func = function() DB().auras = not DB().auras end },
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
