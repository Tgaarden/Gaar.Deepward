--[[
  Deepward Cast — original movable cast bars for 3.3.5a, written from scratch.

  Inspired by the feel of standalone cast-bar addons (spell icon, timer, and a "latency safe-zone" at the end
  of the bar showing the window where you can safely queue the next cast). NOT derived from any other addon's
  code — all logic here is our own. Client-side only (law I).

  Bars for player / target / focus / pet (toggle each). Player bar is movable: hold SHIFT and drag it (or
  /dwcast unlock). /dwcast toggles the player bar, /dwcast config for options.
]]

local _G = _G
local ADDON = "Deepward Cast"

local function DB()
    if type(DeepwardCastDB) ~= "table" then DeepwardCastDB = {} end
    local d = DeepwardCastDB
    if d.show == nil then d.show = { player = true, target = true, focus = true, pet = false } end
    if d.locked == nil then d.locked = false end
    if d.showLatency == nil then d.showLatency = true end
    if d.pos == nil then d.pos = {} end   -- [unit] = {point, x, y}
    return d
end

-- default anchor per unit
local DEFAULTS = {
    player = { "CENTER", 0, -170, 240, 20 },
    target = { "CENTER", 0, -200, 200, 16 },
    focus  = { "CENTER", 260, -140, 180, 14 },
    pet    = { "CENTER", -260, -140, 160, 12 },
}

local UNITS = { "player", "target", "focus", "pet" }
local bars = {}

local function CastInfo(unit)
    -- returns: name, icon, startMs, endMs, notInterruptible, channel(bool)
    local name, _, _, icon, startTime, endTime, _, _, notInterruptible = UnitCastingInfo(unit)
    if name then return name, icon, startTime, endTime, notInterruptible, false end
    local cname, _, _, cicon, cstart, cend, _, cnotInt = UnitChannelInfo(unit)
    if cname then return cname, cicon, cstart, cend, cnotInt, true end
    return nil
end

-- ---------------------------------------------------------------------------
-- Cast bar factory
-- ---------------------------------------------------------------------------
local function MakeBar(unit)
    local def = DEFAULTS[unit]
    local f = CreateFrame("Frame", "DeepwardCast_" .. unit, UIParent)
    f.unit = unit
    f:SetSize(def[4], def[5])
    local pos = DB().pos[unit]
    if pos then f:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 0)
    else f:SetPoint(def[1], UIParent, def[1], def[2], def[3]) end
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) if IsShiftKeyDown() and not DB().locked then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, _, x, y = self:GetPoint()
        DB().pos[unit] = { point = p, x = x, y = y }
    end)
    f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
                    insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    f:SetBackdropColor(0, 0, 0, 0.6); f:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)

    -- spell icon (left)
    local iconSize = def[5] + 2
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(iconSize, iconSize)
    f.icon:SetPoint("RIGHT", f, "LEFT", -2, 0)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- the fill bar
    f.bar = CreateFrame("StatusBar", nil, f)
    f.bar:SetPoint("TOPLEFT", 2, -2); f.bar:SetPoint("BOTTOMRIGHT", -2, 2)
    f.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    f.bar:SetMinMaxValues(0, 1); f.bar:SetValue(0)

    -- latency safe-zone (overlaid at the right end)
    f.lag = f.bar:CreateTexture(nil, "OVERLAY")
    f.lag:SetTexture(1, 0.1, 0.1, 0.35)
    f.lag:SetPoint("TOPRIGHT"); f.lag:SetPoint("BOTTOMRIGHT")
    f.lag:SetWidth(0); f.lag:Hide()

    -- texts
    f.name = f.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.name:SetPoint("LEFT", 4, 0); f.name:SetJustifyH("LEFT")
    f.time = f.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.time:SetPoint("RIGHT", -4, 0); f.time:SetJustifyH("RIGHT")

    f:Hide()
    return f
end

local function StartCast(f)
    local name, icon, startMs, endMs, notInt, channel = CastInfo(f.unit)
    if not name then f:Hide(); return end
    f.startMs, f.endMs, f.channel = startMs, endMs, channel
    f.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    f.name:SetText(name)
    -- colour: channel green, uninterruptible grey, normal gold
    if notInt then f.bar:SetStatusBarColor(0.6, 0.6, 0.6)
    elseif channel then f.bar:SetStatusBarColor(0.2, 0.75, 0.3)
    else f.bar:SetStatusBarColor(1.0, 0.75, 0.1) end
    -- latency safe-zone: the last <lag> ms of the cast (only meaningful for the player's own casts)
    f.lag:Hide()
    if DB().showLatency and f.unit == "player" then
        local _, _, _, lagMs = GetNetStats()
        local dur = (endMs - startMs)
        if lagMs and lagMs > 0 and dur > 0 then
            f.lag:SetWidth((f.bar:GetWidth()) * math.min(lagMs / dur, 1))
            f.lag:Show()
        end
    end
    f:Show()
end

local function StopCast(f, failed)
    if failed then
        f.bar:SetStatusBarColor(0.8, 0.1, 0.1)
        f.name:SetText(f.name:GetText() or "")
        f.fadeAt = GetTime() + 0.5   -- brief red flash then hide
    else
        f:Hide()
    end
    f.startMs, f.endMs = nil, nil
end

local function OnUpdate(f)
    if not f.startMs then
        if f.fadeAt and GetTime() > f.fadeAt then f.fadeAt = nil; f:Hide() end
        return
    end
    local now = GetTime() * 1000
    local dur = f.endMs - f.startMs
    if dur <= 0 then return end
    local elapsed = now - f.startMs
    local frac = elapsed / dur
    if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
    if f.channel then frac = 1 - frac end   -- channels drain
    f.bar:SetValue(frac)
    local remain = (f.endMs - now) / 1000
    if remain < 0 then remain = 0 end
    f.time:SetText(("%.1f"):format(remain))
    if now >= f.endMs then f:Hide(); f.startMs = nil end
end

-- ---------------------------------------------------------------------------
-- Build bars + drive them
-- ---------------------------------------------------------------------------
for _, u in ipairs(UNITS) do bars[u] = MakeBar(u) end

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function()
    for _, u in ipairs(UNITS) do
        local f = bars[u]
        if f:IsShown() or f.fadeAt then OnUpdate(f) end
    end
end)

-- refresh a unit's bar from scratch (used on target/focus swap while a cast is already in progress)
local function Refresh(u)
    local f = bars[u]
    if not DB().show[u] then f:Hide(); return end
    if CastInfo(u) then StartCast(f) else f:Hide() end
end

-- Spellcast events carry the unit as arg1. Register the player-affecting ones plus target/focus refresh.
local ev = CreateFrame("Frame")
local EVENTS = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE",
}
for _, e in ipairs(EVENTS) do ev:RegisterEvent(e) end
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("PLAYER_FOCUS_CHANGED")
ev:RegisterEvent("UNIT_PET")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_TARGET_CHANGED" then Refresh("target"); return end
    if event == "PLAYER_FOCUS_CHANGED" then Refresh("focus"); return end
    if event == "UNIT_PET" then Refresh("pet"); return end
    local f = bars[arg1]
    if not f or not DB().show[arg1] then return end
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        StartCast(f)
    elseif event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        if f:IsShown() then StartCast(f) end   -- re-read new start/end (pushback / haste)
    elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        StopCast(f, true)
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        StopCast(f, false)
    end
end)

-- ---------------------------------------------------------------------------
-- Config + slash
-- ---------------------------------------------------------------------------
local menuFrame = CreateFrame("Frame", "DeepwardCastMenu", UIParent, "UIDropDownMenuTemplate")
local function Menu()
    local t = { { text = ADDON, isTitle = true, notCheckable = true } }
    for _, u in ipairs(UNITS) do
        local unit = u
        t[#t + 1] = { text = "Show " .. unit .. " cast bar", checked = DB().show[unit], keepShownOnClick = true,
            func = function() DB().show[unit] = not DB().show[unit]; if not DB().show[unit] then bars[unit]:Hide() end end }
    end
    t[#t + 1] = { text = "Latency safe-zone", checked = DB().showLatency, keepShownOnClick = true,
        func = function() DB().showLatency = not DB().showLatency end }
    t[#t + 1] = { text = (DB().locked and "Unlock (shift-drag to move)" or "Lock position"), notCheckable = true,
        func = function() DB().locked = not DB().locked
            print("|cff5599ff" .. ADDON .. ":|r " .. (DB().locked and "locked." or "unlocked — shift-drag the bars to move.")) end }
    t[#t + 1] = { text = "Test player bar (3s)", notCheckable = true, func = function()
        local f = bars.player; f.startMs = GetTime() * 1000; f.endMs = f.startMs + 3000; f.channel = false
        f.icon:SetTexture("Interface\\Icons\\Spell_Fire_FlameBolt"); f.name:SetText("Test Cast")
        f.bar:SetStatusBarColor(1, 0.75, 0.1); f:Show()
    end }
    t[#t + 1] = { text = "Close", notCheckable = true, func = function() end }
    return t
end
function DeepwardCast_Config() EasyMenu(Menu(), menuFrame, "cursor", 0, 0, "MENU") end
_G.DeepwardCast_Config = DeepwardCast_Config

SLASH_DEEPWARDCAST1 = "/dwcast"
SlashCmdList["DEEPWARDCAST"] = function(msg)
    msg = (msg or ""):lower():gsub("%s+", "")
    if msg == "unlock" then DB().locked = false; print("|cff5599ff" .. ADDON .. ":|r unlocked — shift-drag the bars.")
    elseif msg == "lock" then DB().locked = true; print("|cff5599ff" .. ADDON .. ":|r locked.")
    elseif msg == "config" then DeepwardCast_Config()
    else DeepwardCast_Config() end
end
