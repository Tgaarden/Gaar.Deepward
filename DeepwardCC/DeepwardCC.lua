--[[
  Deepward CC — cooldown-count text, written from scratch (not derived from any other addon's code).

  Draws a shrinking countdown number on top of any Cooldown swipe (action buttons, items, buffs, ...) by
  hooking the stock CooldownFrame_SetTimer. Colour + precision ramp up as the cooldown runs out. GCD-length
  cooldowns are ignored. Client-side only (law I).

  /dwcc — toggle on/off + options.
]]

local _G = _G
local ADDON = "Deepward CC"
local format = string.format

local function DB()
    if type(DeepwardCCDB) ~= "table" then DeepwardCCDB = {} end
    local d = DeepwardCCDB
    if d.enabled     == nil then d.enabled = true end
    if d.minDuration == nil then d.minDuration = 2 end    -- ignore GCD / very short cooldowns
    if d.minSize     == nil then d.minSize = 16 end       -- don't draw on tiny cooldown frames
    if d.scale       == nil then d.scale = 0.42 end       -- text size as a fraction of the frame size
    if d.tenths      == nil then d.tenths = 3 end         -- show tenths below this many seconds
    return d
end

-- remaining seconds -> text + colour
local function Fmt(t)
    if t >= 3600 then return format("%dh", t / 3600 + 0.5), 0.7, 0.7, 0.7
    elseif t >= 60 then return format("%dm", t / 60 + 0.5), 0.7, 0.7, 0.7
    elseif t >= 10 then return format("%d", t + 0.5), 1, 1, 0            -- yellow
    elseif t >= DB().tenths then return format("%d", t + 0.5), 1, 0.55, 0  -- orange
    else return format("%.1f", t), 1, 0.1, 0.1 end                       -- red tenths
end

local function Text(cd)
    if not cd._ccText then
        local fs = cd:CreateFontString(nil, "OVERLAY")
        fs:SetPoint("CENTER", cd, "CENTER", 0, 0)
        cd._ccText = fs
    end
    return cd._ccText
end

local function Stop(cd)
    cd._ccStart = nil
    if cd._ccText then cd._ccText:Hide() end
    cd:SetScript("OnUpdate", nil)
end

local function OnUpdate(cd, elapsed)
    cd._ccAcc = (cd._ccAcc or 0) + elapsed
    if cd._ccAcc < 0.1 then return end
    cd._ccAcc = 0
    if not cd._ccStart then Stop(cd); return end
    local remain = cd._ccStart + cd._ccDur - GetTime()
    if remain <= 0 then Stop(cd); return end
    local txt, r, g, b = Fmt(remain)
    local fs = cd._ccText
    fs:SetText(txt); fs:SetTextColor(r, g, b); fs:Show()
end

-- The stock timer setter fires for every cooldown swipe in the UI.
hooksecurefunc("CooldownFrame_SetTimer", function(cd, start, duration, enable)
    if not cd or cd.noCooldownCount then return end          -- respect frames that already show a count
    if not DB().enabled then Stop(cd); return end
    if start and duration and start > 0 and duration > DB().minDuration and (enable == nil or enable ~= 0) then
        cd._ccStart, cd._ccDur, cd._ccAcc = start, duration, 0
        local fs = Text(cd)
        local sz = cd:GetWidth() or 0
        fs:SetFont(STANDARD_TEXT_FONT, math.max(9, sz * DB().scale), "OUTLINE")
        if sz < DB().minSize then fs:Hide() else fs:Show() end
        cd:SetScript("OnUpdate", OnUpdate)
    else
        Stop(cd)
    end
end)

-- ---------------------------------------------------------------------------
-- Config
-- ---------------------------------------------------------------------------
local menuFrame = CreateFrame("Frame", "DeepwardCCMenu", UIParent, "UIDropDownMenuTemplate")
local function Menu()
    return {
        { text = ADDON, isTitle = true, notCheckable = true },
        { text = "Enabled", checked = DB().enabled, keepShownOnClick = true,
          func = function() DB().enabled = not DB().enabled
              print("|cff5599ff" .. ADDON .. ":|r " .. (DB().enabled and "on — cooldown numbers shown." or "off (reload to clear existing).")) end },
        { text = "Text size", notCheckable = true, hasArrow = true, menuList = {
            { text = "Small",  checked = (DB().scale == 0.34), func = function() DB().scale = 0.34 end },
            { text = "Normal", checked = (DB().scale == 0.42), func = function() DB().scale = 0.42 end },
            { text = "Large",  checked = (DB().scale == 0.5),  func = function() DB().scale = 0.5 end },
        } },
        { text = "Close", notCheckable = true, func = function() end },
    }
end
function DeepwardCC_Config() EasyMenu(Menu(), menuFrame, "cursor", 0, 0, "MENU") end
_G.DeepwardCC_Config = DeepwardCC_Config

SLASH_DEEPWARDCC1 = "/dwcc"
SlashCmdList["DEEPWARDCC"] = function(msg)
    msg = (msg or ""):lower():gsub("%s+", "")
    if msg == "on" then DB().enabled = true; print("|cff5599ff" .. ADDON .. ":|r on.")
    elseif msg == "off" then DB().enabled = false; print("|cff5599ff" .. ADDON .. ":|r off (reload to clear).")
    else DeepwardCC_Config() end
end
