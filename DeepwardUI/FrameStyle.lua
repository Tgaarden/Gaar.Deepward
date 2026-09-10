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
    if d.frameBarText  == nil then d.frameBarText  = true end
    if d.frameFontSize == nil then d.frameFontSize = 12 end
    return d
end

-- health bar, power bar, unit token
local FRAMES = {
    { h = "PlayerFrameHealthBar",       m = "PlayerFrameManaBar",       u = "player" },
    { h = "TargetFrameHealthBar",       m = "TargetFrameManaBar",       u = "target" },
    { h = "FocusFrameHealthBar",        m = "FocusFrameManaBar",        u = "focus" },
    { h = "PetFrameHealthBar",          m = "PetFrameManaBar",          u = "pet" },
    { h = "PartyMemberFrame1HealthBar", m = "PartyMemberFrame1ManaBar", u = "party1" },
    { h = "PartyMemberFrame2HealthBar", m = "PartyMemberFrame2ManaBar", u = "party2" },
    { h = "PartyMemberFrame3HealthBar", m = "PartyMemberFrame3ManaBar", u = "party3" },
    { h = "PartyMemberFrame4HealthBar", m = "PartyMemberFrame4ManaBar", u = "party4" },
}

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

-- Class-colour health bars for player units, after every Blizzard health update.
if type(UnitFrameHealthBar_Update) == "function" then
    hooksecurefunc("UnitFrameHealthBar_Update", function(bar, unit)
        if not DB().frameClassColor or not bar or not unit then return end
        if UnitIsPlayer(unit) and bar.SetStatusBarColor then
            local _, cls = UnitClass(unit)
            local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
            if c then bar:SetStatusBarColor(c.r, c.g, c.b) end
        end
    end)
end

-- Live text updater (0.2s).
local driver = CreateFrame("Frame")
local acc = 0
driver:SetScript("OnUpdate", function(_, e)
    acc = acc + e
    if acc < 0.2 then return end
    acc = 0
    for _, f in ipairs(FRAMES) do
        UpdateBarText(f.h, f.u, false)
        UpdateBarText(f.m, f.u, true)
    end
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

-- Config toggles (share DeepwardUIDB with FrameMover; /dwframes covers moving, this adds style toggles).
SLASH_DEEPWARDFRAMESTYLE1 = "/dwstyle"
SlashCmdList["DEEPWARDFRAMESTYLE"] = function(msg)
    msg = (msg or ""):lower()
    local cmd, arg = msg:match("^(%S*)%s*(.*)$")
    if cmd == "class" then
        DB().frameClassColor = not DB().frameClassColor
        print("|cff5599ffDeepward frames:|r class colour " .. (DB().frameClassColor and "on." or "off (reload to restore)."))
    elseif cmd == "text" then
        DB().frameBarText = not DB().frameBarText
        print("|cff5599ffDeepward frames:|r bar text " .. (DB().frameBarText and "on." or "off."))
    elseif cmd == "font" then
        local s = tonumber(arg)
        if s and s >= 8 and s <= 20 then
            DB().frameFontSize = s
            for _, f in ipairs(FRAMES) do
                for _, bn in ipairs({ f.h, f.m }) do
                    local bar = _G[bn]
                    if bar and bar._dwText then bar._dwText:SetFont(STANDARD_TEXT_FONT, s, "OUTLINE") end
                end
            end
            print(("|cff5599ffDeepward frames:|r font size %d."):format(s))
        else
            print("|cff5599ffDeepward frames:|r usage /dwstyle font 8-20")
        end
    else
        print("|cff5599ffDeepward frames:|r /dwstyle class  ·  /dwstyle text  ·  /dwstyle font <8-20>")
    end
end
