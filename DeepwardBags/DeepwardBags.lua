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

local cleanBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
cleanBtn:SetSize(60, 20); cleanBtn:SetPoint("RIGHT", sortBtn, "LEFT", -4, 0)

local footer = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
footer:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")   -- bigger; coin icons scale with the font height
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
    -- Clean/compact: push all occupied slots to the top-left (keeping their sorted order), empties after.
    if DB().compact then
        local occ, emp = {}, {}
        for _, s in ipairs(slots) do if s.tex then occ[#occ + 1] = s else emp[#emp + 1] = s end end
        for _, e in ipairs(emp) do occ[#occ + 1] = e end
        slots = occ
    end
    -- columns derived from the current window width (so resizing reflows the grid)
    COLS = math.max(6, math.floor((f:GetWidth() - 28) / SIZE))
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
    f:SetHeight(40 + rows * SIZE + 30)   -- width is user-controlled (resize); only height auto-fits
    sortBtn:SetText("Sort: " .. mode)
    cleanBtn:SetText(DB().compact and "Clean: on" or "Clean")
end

-- fill one button's icon/count/quality/lock/cooldown (mirrors ContainerFrame_Update for a single slot)
local function UpdateButton(bag, slot)
    local b = GetButton(bag, slot)
    local tex, count, locked, quality, _, _, link = GetContainerItemInfo(bag, slot)
    SetItemButtonTexture(b, tex or "")
    SetItemButtonCount(b, count or 0)
    SetItemButtonDesaturated(b, locked)
    -- rarity border: a solid coloured edge frame (3.3.5 has no SetItemButtonQuality / IconBorder)
    if not b._qf then
        local qf = CreateFrame("Frame", nil, b)
        qf:SetFrameLevel(b:GetFrameLevel() + 1)
        qf:SetPoint("TOPLEFT", -1, 1); qf:SetPoint("BOTTOMRIGHT", 1, -1)
        qf:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
        b._qf = qf
    end
    if tex and quality and quality >= 2 then
        local r, g, bl = GetItemQualityColor(quality)
        b._qf:SetBackdropBorderColor(r, g, bl, 1); b._qf:Show()
    else
        b._qf:Hide()
    end
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
    -- footer: money with real g/s/c coin icons + token item icons
    local coins = GetCoinTextureString(GetMoney())
    local dtIcon = GetItemIcon(DT_ITEM); local vtIcon = GetItemIcon(VT_ITEM)
    local dt = dtIcon and ("|T" .. dtIcon .. ":20:20|t ") or "DT "
    local vt = vtIcon and ("|T" .. vtIcon .. ":20:20|t ") or "VT "
    footer:SetText(("%s     %s%d    %s%d"):format(coins, dt, GetItemCount(DT_ITEM) or 0, vt, GetItemCount(VT_ITEM) or 0))
end

sortBtn:SetScript("OnClick", function()
    local m = DB().sort
    DB().sort = (m == "slot") and "quality" or (m == "quality") and "name" or "slot"
    RefreshList()
end)
cleanBtn:SetScript("OnClick", function()
    DB().compact = not DB().compact
    RefreshList()
end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("BAG_UPDATE")
ev:RegisterEvent("ITEM_LOCK_CHANGED")
ev:RegisterEvent("BAG_UPDATE_COOLDOWN")
ev:RegisterEvent("PLAYER_MONEY")
ev:SetScript("OnEvent", function() RefreshList() end)

-- resize + scale
f:SetResizable(true)
f:SetMinResize(6 * SIZE + 28, 120)
f:SetMaxResize(20 * SIZE + 28, 900)
f:SetWidth(12 * SIZE + 28); f:SetHeight(320)
f:SetScale(DB().scale or 1)
local grip = CreateFrame("Button", nil, f)
grip:SetSize(16, 16); grip:SetPoint("BOTTOMRIGHT", -4, 4)
grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing(); RefreshList() end)
f:SetScript("OnSizeChanged", function() RefreshList() end)
f:EnableMouseWheel(true)
f:SetScript("OnMouseWheel", function(_, dir)
    local s = math.max(0.6, math.min(2.0, (DB().scale or 1) + (dir > 0 and 0.05 or -0.05)))
    DB().scale = s; f:SetScale(s)
end)

local function Show() f:Show(); RefreshList() end
local function Hide() f:Hide() end
local function Toggle() if f:IsShown() then Hide() else Show() end end
_G.DeepwardBags_Toggle = Toggle
_G.DeepwardBags_Show = Show
_G.DeepwardBags_Hide = Hide

SLASH_DEEPWARDBAGS1 = "/dwbags"
SLASH_DEEPWARDBAGS2 = "/dwbag"
SlashCmdList["DEEPWARDBAGS"] = Toggle

-- Override the default bag open/close so the "B" key, the bag-bar buttons and "Open all bags" all drive our
-- window (and Blizzard's container frames stay closed). Gated by DB().override.
local function DB2() local d = DB(); if d.override == nil then d.override = true end; return d end
if DB2().override then
    local function openAll() if DB2().override then Show() else return end end
    ToggleBackpack = function() if DB2().override then Toggle() else end end
    ToggleBag      = function() if DB2().override then Toggle() else end end
    ToggleAllBags  = function() if DB2().override then Toggle() else end end
    OpenAllBags    = function() if DB2().override then Show() else end end
    OpenBackpack   = function() if DB2().override then Show() else end end
    CloseAllBags   = function() if DB2().override then Hide() else end end
    CloseBackpack  = function() if DB2().override then Hide() else end end
    -- keep Blizzard container frames shut if anything still opens them
    for i = 1, NUM_CONTAINER_FRAMES or 13 do
        local cf = _G["ContainerFrame" .. i]
        if cf then cf:HookScript("OnShow", function(self) if DB2().override then self:Hide() end end) end
    end
end
