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
close:SetPoint("BOTTOMRIGHT", -18, -2)   -- bottom-right, just left of the resize grip

local sortBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
sortBtn:SetSize(96, 22); sortBtn:SetPoint("TOPRIGHT", -32, -9)

local cleanBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
cleanBtn:SetSize(66, 22); cleanBtn:SetPoint("RIGHT", sortBtn, "LEFT", -4, 0)

-- drag bar: only the LEFT part of the title row, so it never sits under the buttons and steal their clicks
local dragBar = CreateFrame("Frame", nil, f); dragBar:SetPoint("TOPLEFT"); dragBar:SetHeight(26)
dragBar:SetPoint("TOPRIGHT", cleanBtn, "TOPLEFT", -6, 0)
dragBar:EnableMouse(true); dragBar:RegisterForDrag("LeftButton")
dragBar:SetScript("OnDragStart", function() f:StartMoving() end)
dragBar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
-- buttons above everything else in the title row
sortBtn:SetFrameLevel(dragBar:GetFrameLevel() + 5)
cleanBtn:SetFrameLevel(dragBar:GetFrameLevel() + 5)

local footer = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
footer:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")   -- bigger; coin icons scale with the font height
footer:SetPoint("BOTTOMLEFT", 18, 18)

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
local DoSort   -- forward declaration (defined with the cleanup engine below)

local function Layout()
    -- The LIVE view is always in fixed slot order (bag 0..4, slot 1..n). It never re-sorts on its own, so an
    -- item stays exactly where you drop it — manual arrangement is free and never snaps back. "Sort" and
    -- "Clean" are one-shot actions that physically move items in the bags (below), not a live display filter.
    local slots = {}
    for bag = 0, 4 do
        local n = GetContainerNumSlots(bag) or 0
        for slot = 1, n do slots[#slots + 1] = { bag = bag, slot = slot } end
    end
    -- columns derived from the current window width (so resizing reflows the grid)
    COLS = math.max(8, math.floor((f:GetWidth() - 28) / SIZE))   -- never narrower than 8 columns
    local top = -40
    for i, s in ipairs(slots) do
        local b = GetButton(s.bag, s.slot)
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", f, "TOPLEFT", 14 + col * SIZE, top - row * SIZE)
        b:Show()
    end
    local rows = math.max(1, math.ceil(#slots / COLS))   -- height follows the last bag slot exactly
    f:SetHeight(40 + rows * SIZE + 46)   -- width is user-controlled (resize); height always fits content
    sortBtn:SetText("Sort: " .. DB().sort)
    cleanBtn:SetText("Clean")
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
    -- keep/no-sell padlock (mirrors DeepwardUI's Sell All "kept" flag; shift-click a slot to toggle)
    if not b._keepLock then
        local t = b:CreateTexture(nil, "OVERLAY")
        t:SetSize(16, 16)
        t:SetPoint("BOTTOMRIGHT", -1, 1)
        t:SetTexture(_G.DeepwardUI_KeepLockTexture or "Interface\\AddOns\\DeepwardUI\\keeplock")
        b._keepLock = t
    end
    local id = link and tonumber(link:match("item:(%d+)"))
    if id and _G.DeepwardUI_IsKept and _G.DeepwardUI_IsKept(id) then b._keepLock:Show() else b._keepLock:Hide() end

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
    footer:SetText(("%s          %s%d       %s%d"):format(coins, dt, GetItemCount(DT_ITEM) or 0, vt, GetItemCount(VT_ITEM) or 0))
end

-- Sort = a ONE-SHOT physical sort by the cycled key (slot = leave as-is / free). It moves the real items,
-- then the live slot-order view shows the result and it stays put until you move something by hand.
sortBtn:SetScript("OnClick", function()
    local m = DB().sort
    DB().sort = (m == "slot") and "quality" or (m == "quality") and "name" or "slot"
    sortBtn:SetText("Sort: " .. DB().sort)
    if DoSort then DoSort() end
end)
-- ---------------------------------------------------------------------------
-- Clean: a real one-shot bag cleanup — merge partial stacks, then sort every
-- item to the front (quality desc, then name). One move per frame so item
-- locks resolve between steps; runs only out of combat.
-- ---------------------------------------------------------------------------
-- a slot is "pinned" if its item carries the keep/no-sell padlock — Clean never moves or stacks it
local function isPinned(bag, slot)
    if not _G.DeepwardUI_IsKept then return false end
    local link = GetContainerItemLink(bag, slot)
    local id = link and tonumber(link:match("item:(%d+)"))
    return id and _G.DeepwardUI_IsKept(id) and true or false
end

local function orderSlots()
    local t = {}
    for bag = 0, 4 do
        local n = GetContainerNumSlots(bag) or 0
        for slot = 1, n do
            if not isPinned(bag, slot) then t[#t + 1] = { bag = bag, slot = slot } end
        end
    end
    return t
end

local function itemAt(bag, slot)
    local link = GetContainerItemLink(bag, slot)
    if not link then return nil end
    local _, count, locked, quality = GetContainerItemInfo(bag, slot)
    local id = tonumber(link:match("item:(%d+)"))
    local _, _, _, _, _, _, _, maxStack = GetItemInfo(link)
    return { link = link, id = id, count = count or 1, quality = quality or 1,
             locked = locked, max = maxStack or 1, name = (link:match("%[(.-)%]") or "") }
end

-- comparators for the one-shot physical sort (chosen by the Sort button); default is by quality
local function cmpQuality(a, b)
    if a.quality ~= b.quality then return a.quality > b.quality end
    if a.name ~= b.name then return a.name < b.name end
    return a.count > b.count
end
local function cmpName(a, b)
    if a.name ~= b.name then return a.name < b.name end
    return a.quality > b.quality
end
local activeCmp = cmpQuality

-- merge one partial stack onto an earlier partial of the same item; true = did work
local function stackStep(order)
    local firstPartial = {}
    for _, p in ipairs(order) do
        local it = itemAt(p.bag, p.slot)
        if it and it.id and it.max > 1 and it.count < it.max and not it.locked then
            local prev = firstPartial[it.id]
            if prev then
                ClearCursor()
                PickupContainerItem(p.bag, p.slot)
                PickupContainerItem(prev.bag, prev.slot)   -- fills prev toward max, remainder back on cursor
                ClearCursor()                              -- returns any remainder to its source
                return true
            end
            firstPartial[it.id] = p
        end
    end
    return false
end

-- selection-sort by swaps: put the correct item into the first wrong slot; true = did work / waiting
local function sortStep(order)
    local items = {}
    for _, p in ipairs(order) do
        local it = itemAt(p.bag, p.slot)
        if it then it.bag, it.slot = p.bag, p.slot; items[#items + 1] = it end
    end
    table.sort(items, activeCmp)
    for i, p in ipairs(order) do
        local want = items[i]
        if not want then return false end       -- rest are empty slots; done
        local cur = itemAt(p.bag, p.slot)
        if not (cur and cur.link == want.link and cur.count == want.count) then
            for j = i, #order do
                local q = order[j]
                local it = itemAt(q.bag, q.slot)
                if it and it.link == want.link and it.count == want.count then
                    if q.bag == p.bag and q.slot == p.slot then break end
                    if it.locked or (cur and cur.locked) then return true end   -- wait a frame
                    ClearCursor()
                    PickupContainerItem(q.bag, q.slot)
                    PickupContainerItem(p.bag, p.slot)
                    if GetCursorInfo() then PickupContainerItem(q.bag, q.slot) end
                    ClearCursor()
                    return true
                end
            end
        end
    end
    return false
end

local cleanDriver = CreateFrame("Frame"); cleanDriver:Hide()
local cleanPhase
local cleanTicks = 0
cleanDriver:SetScript("OnUpdate", function(self)
    if InCombatLockdown() then self:Hide(); cleanPhase = nil; return end
    cleanTicks = cleanTicks + 1
    if cleanTicks > 400 then self:Hide(); cleanPhase = nil; RefreshList(); return end   -- safety stop
    local order = orderSlots()
    if cleanPhase == "stack" then
        if not stackStep(order) then cleanPhase = "sort" end
        return
    end
    if not sortStep(order) then
        self:Hide(); cleanPhase = nil; RefreshList()   -- done — driver stops, so items stay movable
    end
end)

local function startCleanRun(cmp)
    if cleanDriver:IsShown() then return end   -- already running; one click = one pass
    if InCombatLockdown() then
        DEFAULT_CHAT_FRAME:AddMessage("Deepward Bags: kan ikke rydde i kamp.")
        return
    end
    activeCmp = cmp
    cleanTicks = 0; cleanPhase = "stack"; cleanDriver:Show()
end

local function DoClean() startCleanRun(cmpQuality) end

-- assigned to the forward-declared DoSort so the Sort button (defined earlier) can call it
DoSort = function()
    local key = DB().sort
    if key == "quality" then startCleanRun(cmpQuality)
    elseif key == "name" then startCleanRun(cmpName) end
    -- "slot": free/natural order — no physical sort
end

cleanBtn:SetScript("OnClick", DoClean)

local ev = CreateFrame("Frame")
ev:RegisterEvent("BAG_UPDATE")
ev:RegisterEvent("ITEM_LOCK_CHANGED")
ev:RegisterEvent("BAG_UPDATE_COOLDOWN")
ev:RegisterEvent("PLAYER_MONEY")
ev:SetScript("OnEvent", function() RefreshList() end)

-- resize + scale
f:SetResizable(true)
f:SetMinResize(8 * SIZE + 28, 100)   -- min width = 8 columns; height is driven by content, not the user
f:SetMaxResize(20 * SIZE + 28, 900)
f:SetWidth(8 * SIZE + 28); f:SetHeight(320)   -- default to the narrowest allowed width (8 columns)
f:SetScale(DB().scale or 1)
local grip = CreateFrame("Button", nil, f)
grip:SetSize(16, 16); grip:SetPoint("BOTTOMRIGHT", -4, 4)
grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
grip:SetScript("OnMouseDown", function() f:StartSizing("RIGHT") end)   -- width only; height follows content
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
_G.DeepwardBags_Refresh = RefreshList

SLASH_DEEPWARDBAGS1 = "/dwbags"
SLASH_DEEPWARDBAGS2 = "/dwbag"
SlashCmdList["DEEPWARDBAGS"] = Toggle

-- Override the default bag open/close so the "B" key, the bag-bar buttons and "Open all bags" all drive our
-- window (and Blizzard's container frames stay closed). Gated by DB().override.
local function DB2() local d = DB(); if d.override == nil then d.override = true end; return d end
if DB2().override then
    local function openAll() if DB2().override then Show() else return end end
    -- Every "open/toggle" entry points at Toggle so the B key (whichever of these its binding calls) both
    -- opens AND closes our window. Only the explicit Close* stay as Hide.
    ToggleBackpack = function() if DB2().override then Toggle() else end end
    ToggleBag      = function() if DB2().override then Toggle() else end end
    ToggleAllBags  = function() if DB2().override then Toggle() else end end
    OpenAllBags    = function() if DB2().override then Toggle() else end end
    OpenBackpack   = function() if DB2().override then Toggle() else end end
    CloseAllBags   = function() if DB2().override then Hide() else end end
    CloseBackpack  = function() if DB2().override then Hide() else end end
    -- keep Blizzard container frames shut if anything still opens them
    for i = 1, NUM_CONTAINER_FRAMES or 13 do
        local cf = _G["ContainerFrame" .. i]
        if cf then cf:HookScript("OnShow", function(self) if DB2().override then self:Hide() end end) end
    end
end
