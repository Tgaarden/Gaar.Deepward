--[[
  Deepward Plates — cleaner default nameplates for 3.3.5a. Original code (not derived from any other addon).

  3.3.5a has no nameplate API, so we scan WorldFrame's children for the default nameplates and restyle them:
  a flat health bar, a bigger name, a health-percent readout, a slim styled cast bar and a dark backing.
  Reaction colour (green/red/yellow) that Blizzard already sets on the bar is kept. Client-side only (law I).

  /dwplates — options.
]]

local _G = _G
local WorldFrame = WorldFrame
local BAR_TEX = "Interface\\TargetingFrame\\UI-StatusBar"

local function DB()
    if type(DeepwardPlatesDB) ~= "table" then DeepwardPlatesDB = {} end
    local d = DeepwardPlatesDB
    if d.enabled  == nil then d.enabled = true end
    if d.percent  == nil then d.percent = true end
    if d.hpHeight == nil then d.hpHeight = 10 end
    if d.nameSize == nil then d.nameSize = 11 end
    return d
end

-- Is this WorldFrame child a default nameplate? (unnamed frame; first child is the health StatusBar; the
-- 7th region is the name fontstring in the stock layout).
local function IsPlate(frame)
    if frame:GetName() then return false end
    local hb = frame:GetChildren()
    if not hb or not hb.GetObjectType or hb:GetObjectType() ~= "StatusBar" then return false end
    local _, _, _, _, _, _, name = frame:GetRegions()
    return name and name.GetObjectType and name:GetObjectType() == "FontString"
end

local styled = {}

local function StylePlate(plate)
    local hb, cb = plate:GetChildren()
    local _, hpBorder, castBorder, _, _, _, name, level = plate:GetRegions()
    if not (hb and name) then return end

    hb:SetStatusBarTexture(BAR_TEX)
    hb:SetHeight(DB().hpHeight)
    if hpBorder and hpBorder.SetTexture then hpBorder:SetTexture(nil) end   -- drop the chunky default border

    -- dark backing behind the health bar
    if not plate._bg then
        local bg = plate:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(0, 0, 0, 0.6)
        bg:SetPoint("TOPLEFT", hb, "TOPLEFT", -1, 1)
        bg:SetPoint("BOTTOMRIGHT", hb, "BOTTOMRIGHT", 1, -1)
        plate._bg = bg
    end

    -- health percent text
    if not plate._pct then
        local fs = hb:CreateFontString(nil, "OVERLAY")
        fs:SetPoint("CENTER", hb, "CENTER", 0, 0)
        fs:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
        plate._pct = fs
    end

    -- name styling
    name:SetFont(STANDARD_TEXT_FONT, DB().nameSize, "OUTLINE")
    if level then level:SetFont(STANDARD_TEXT_FONT, DB().nameSize - 2, "OUTLINE") end

    -- cast bar (if present)
    if cb and cb.SetStatusBarTexture then
        cb:SetStatusBarTexture(BAR_TEX)
        if castBorder and castBorder.SetTexture then castBorder:SetTexture(nil) end
    end

    plate._hb = hb
    styled[plate] = true
end

local function UpdatePlate(plate)
    local hb = plate._hb
    if not hb then return end
    if DB().percent and plate:IsShown() then
        local _, max = hb:GetMinMaxValues()
        local cur = hb:GetValue()
        if max and max > 0 then
            plate._pct:SetText(math.floor(cur / max * 100 + 0.5) .. "%")
            plate._pct:Show()
        else
            plate._pct:SetText("")
        end
    elseif plate._pct then
        plate._pct:SetText("")
    end
end

-- Scan for new plates + drive percent text, throttled.
local driver = CreateFrame("Frame")
local acc, lastCount = 0, 0
driver:SetScript("OnUpdate", function(_, e)
    if not DB().enabled then return end
    acc = acc + e
    if acc < 0.1 then return end
    acc = 0
    local n = WorldFrame:GetNumChildren()
    if n ~= lastCount then            -- new plate(s) appeared -> scan
        lastCount = n
        local kids = { WorldFrame:GetChildren() }
        for _, child in ipairs(kids) do
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
local function Menu()
    return {
        { text = "Deepward Plates", isTitle = true, notCheckable = true },
        { text = "Enabled", checked = DB().enabled, keepShownOnClick = true,
          func = function() DB().enabled = not DB().enabled end },
        { text = "Health percent", checked = DB().percent, keepShownOnClick = true,
          func = function() DB().percent = not DB().percent end },
        { text = "Name size", notCheckable = true, hasArrow = true, menuList = {
            { text = "Small (10)",  checked = (DB().nameSize == 10), func = function() DB().nameSize = 10; styled = {} end },
            { text = "Normal (11)", checked = (DB().nameSize == 11), func = function() DB().nameSize = 11; styled = {} end },
            { text = "Large (13)",  checked = (DB().nameSize == 13), func = function() DB().nameSize = 13; styled = {} end },
        } },
        { text = "Close", notCheckable = true, func = function() end },
    }
end
function DeepwardPlates_Config() EasyMenu(Menu(), menuFrame, "cursor", 0, 0, "MENU") end
_G.DeepwardPlates_Config = DeepwardPlates_Config

SLASH_DEEPWARDPLATES1 = "/dwplates"
SlashCmdList["DEEPWARDPLATES"] = function() DeepwardPlates_Config() end
