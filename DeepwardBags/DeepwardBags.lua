--[[
  Deepward Bags — a lightweight one-bag window (original code). Shows every bag (0-4) in one grid, with
  sorting and a footer of gold + Deepward token counts. Item buttons use the secure container template so
  clicking/using/moving works normally. Opened with /dwbags or the panel button; does not replace the
  default bags. Client-side only (law I).
]]

local _G = _G
local COLS = 12
local SIZE = 34     -- button size + spacing
local DT_ITEM, VT_ITEM = 47241, 40753   -- Deepward Token / Vanilla Token (emblem items)

local function DB()
    if type(DeepwardBagsDB) ~= "table" then DeepwardBagsDB = {} end
    local d = DeepwardBagsDB
    if d.sort == nil then d.sort = "slot" end   -- slot | quality | name
    return d
end

-- ---------------------------------------------------------------------------
-- Window
-- ---------------------------------------------------------------------------
local f = CreateFrame("Frame", "DeepwardBagsFrame", UIParent)
f:SetFrameStrata("HIGH"); f:SetMovable(true); f:EnableMouse(true)
f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 24,
    insets = { left = 8, right = 8, top = 8, bottom = 8 } })
f:SetPoint("CENTER"); f:Hide()
table.insert(UISpecialFrames, "DeepwardBagsFrame")

local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", 14, -12); title:SetText("Deepward Bags")

local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -6, -6)

local dragBar = CreateFrame("Frame", nil, f); dragBar:SetPoint("TOPLEFT"); dragBar:SetPoint("TOPRIGHT"); dragBar:SetHeight(26)
dragBar:EnableMouse(true); dragBar:RegisterForDrag("LeftButton")
dragBar:SetScript("OnDragStart", function() f:StartMoving() end)
dragBar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

local sortBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
sortBtn:SetSize(90, 20); sortBtn:SetPoint("TOPRIGHT", -30, -10)

local footer = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
footer:SetPoint("BOTTOMLEFT", 14, 12)

-- per-bag parent frames carry the bag id so the secure item template resolves bag+slot on click
local bagParents = {}
for bag = 0, 4 do
    local p = CreateFrame("Frame", "DeepwardBagsBag" .. bag, f)
    p:SetID(bag); p:SetAllPoints(f)
    bagParents[bag] = p
end

local buttons = {}   -- key "bag:slot" -> button
local function GetButton(bag, slot)
    local key = bag .. ":" .. slot
    local b = buttons[key]
    if not b then
        b = CreateFrame("Button", "DeepwardBagsBtn" .. bag .. "_" .. slot, bagParents[bag], "ContainerFrameItemButtonTemplate")
        b:SetID(slot)
        b:SetSize(SIZE - 4, SIZE - 4)
        buttons[key] = b
    end
    return b
end

local RefreshList

local function Layout()
    -- collect all slots
    local slots = {}
    for bag = 0, 4 do
        local n = GetContainerNumSlots(bag) or 0
        for slot = 1, n do
            local tex, count, _, quality = GetContainerItemInfo(bag, slot)
            local name
            local link = GetContainerItemLink(bag, slot)
            if link then name = link:match("%[(.-)%]") end
            slots[#slots + 1] = { bag = bag, slot = slot, tex = tex, quality = quality or -1, name = name or "" }
        end
    end
    -- sort
    local mode = DB().sort
    if mode == "quality" then
        table.sort(slots, function(a, b)
            if (a.tex and 1 or 0) ~= (b.tex and 1 or 0) then return a.tex and true or false end   -- items before empties
            if a.quality ~= b.quality then return a.quality > b.quality end
            return a.name < b.name
        end)
    elseif mode == "name" then
        table.sort(slots, function(a, b)
            if (a.tex and 1 or 0) ~= (b.tex and 1 or 0) then return a.tex and true or false end
            return a.name < b.name
        end)
    end
    -- place
    local top = -40
    for i, s in ipairs(slots) do
        local b = GetButton(s.bag, s.slot)
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", f, "TOPLEFT", 14 + col * SIZE, top - row * SIZE)
        b:Show()
    end
    local rows = math.max(1, math.ceil(#slots / COLS))
    f:SetSize(14 * 2 + COLS * SIZE, 40 + rows * SIZE + 30)
    sortBtn:SetText("Sort: " .. mode)
end

-- fill one button's icon/count/quality/lock/cooldown (mirrors ContainerFrame_Update for a single slot)
local function UpdateButton(bag, slot)
    local b = GetButton(bag, slot)
    local tex, count, locked, quality, _, _, link = GetContainerItemInfo(bag, slot)
    SetItemButtonTexture(b, tex or "")
    SetItemButtonCount(b, count or 0)
    SetItemButtonDesaturated(b, locked)
    if b.SetBackdrop then end
    local q = link and quality or nil
    if SetItemButtonQuality then SetItemButtonQuality(b, q, link) end
    local start, dur, en = GetContainerItemCooldown(bag, slot)
    local cd = _G[b:GetName() .. "Cooldown"]
    if cd then CooldownFrame_SetTimer(cd, start, dur, en) end
end

RefreshList = function()
    if not f:IsShown() then return end
    for bag = 0, 4 do
        local n = GetContainerNumSlots(bag) or 0
        for slot = 1, n do UpdateButton(bag, slot) end
    end
    Layout()
    -- footer: gold + tokens
    local g = math.floor(GetMoney() / 10000)
    footer:SetText(("|cffffd700%dg|r    |cff33ff99DT:|r %d   |cff33ccffVT:|r %d"):format(
        g, GetItemCount(DT_ITEM) or 0, GetItemCount(VT_ITEM) or 0))
end

sortBtn:SetScript("OnClick", function()
    local m = DB().sort
    DB().sort = (m == "slot") and "quality" or (m == "quality") and "name" or "slot"
    RefreshList()
end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("BAG_UPDATE")
ev:RegisterEvent("ITEM_LOCK_CHANGED")
ev:RegisterEvent("BAG_UPDATE_COOLDOWN")
ev:RegisterEvent("PLAYER_MONEY")
ev:SetScript("OnEvent", function() RefreshList() end)

local function Toggle()
    if f:IsShown() then f:Hide() else f:Show(); RefreshList() end
end
_G.DeepwardBags_Toggle = Toggle

SLASH_DEEPWARDBAGS1 = "/dwbags"
SLASH_DEEPWARDBAGS2 = "/dwbag"
SlashCmdList["DEEPWARDBAGS"] = Toggle
