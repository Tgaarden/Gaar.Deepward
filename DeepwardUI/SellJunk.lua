-- Deepward UI — "Sell All" button on the merchant window.
-- Everything on Deepward is free to buy back, so a wrong sell is undoable — the sell therefore clears
-- EVERY normal bag INCLUDING the default backpack (bag 0). What is kept:
--   * Resources (Trade Goods + Gems) — ore, herbs, cloth, leather, elementals, parts, gems…
--   * The Hearthstone and Field Repair Bot (eternal key items).
--   * Contents of specialized bags (quiver/ammo/soul-shard/herb/enchanting/mining/… bags) — skipped whole.
--   * Items with no vendor value (most quest items) — can't be sold, skipped automatically.
-- A confirm popup guards against an accidental sell (buyback only holds the last 12 items).

local PROTECTED = {
    [6948]  = true,   -- Hearthstone (only way out of an instance)
    [34113] = true,   -- Field Repair Bot 110G (eternal convenience item, re-granted on login)
}

-- ---------------------------------------------------------------------------
-- User "keep" flags: SHIFT-click a bag item to mark its item type as never-sell. A small padlock shows on
-- the bottom-right of every stack of it, and "Sell All" skips it. Keyed by itemID (protects all copies),
-- persisted PER CHARACTER (DeepwardUIDB, SavedVariablesPerCharacter) — for dual-spec gear. Shift is used
-- (Alt/Option is unreliable on Mac); for the intended use (non-stackable GEAR) shift-click has no default
-- bag action, so it stays clean. The always-locked key items (Hearthstone, Field Repair Bot) also show the
-- padlock so it's visible that they're protected.
-- ---------------------------------------------------------------------------
DeepwardUIDB = DeepwardUIDB or {}
if type(DeepwardUIDB.noSell) ~= "table" then DeepwardUIDB.noSell = {} end

local function DwIsKept(itemId)   -- user flag OR an always-protected key item
    return itemId and (DeepwardUIDB.noSell[itemId] == true or PROTECTED[itemId] == true)
end

-- Draw/refresh the padlock overlay on every slot of one container frame.
local function DwUpdateKeepMarkers(frame)
    if not frame or not frame.GetID then return end
    local bag  = frame:GetID()
    local name = frame:GetName()
    local size = frame.size or GetContainerNumSlots(bag) or 0
    for i = 1, size do
        local btn = _G[name and (name .. "Item" .. i)]
        if btn then
            if not btn.dwKeepLock then
                local t = btn:CreateTexture(nil, "OVERLAY")  -- OVERLAY = top layer (no sublevel arg; 3.3.5-safe)
                t:SetSize(16, 16)
                t:SetPoint("BOTTOMRIGHT", -1, 1)             -- bottom-right (gear has no stack-count there)
                t:SetTexture("Interface\\AddOns\\DeepwardUI\\keeplock")   -- custom gold padlock
                btn.dwKeepLock = t
            end
            local link = GetContainerItemLink(bag, btn:GetID())
            local id = link and tonumber(link:match("item:(%d+)"))
            if DwIsKept(id) then btn.dwKeepLock:Show() else btn.dwKeepLock:Hide() end
        end
    end
end
hooksecurefunc("ContainerFrame_Update", DwUpdateKeepMarkers)

-- Belt-and-suspenders: refresh every open bag on bag events too (independent of the update hook's timing).
local function DwRefreshAllBags()
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local cf = _G["ContainerFrame" .. i]
        if cf and cf:IsShown() then DwUpdateKeepMarkers(cf) end
    end
end
local dwBagEv = CreateFrame("Frame")
dwBagEv:RegisterEvent("BAG_UPDATE")
dwBagEv:RegisterEvent("BAG_OPEN")
dwBagEv:RegisterEvent("PLAYER_ENTERING_WORLD")
dwBagEv:SetScript("OnEvent", DwRefreshAllBags)

-- /dwlock — diagnostic: open your bags first, then run it. Puts a RED test square (solid colour, always
-- renders) on the first slot of every open bag + prints what it finds, so we can see whether the overlay
-- mechanism works (red shows) vs the padlock texture failing to load (red shows but no lock).
-- Shift-click a bag item -> toggle its keep flag. Always-protected key items (HS/Repair Bot) can't be toggled.
hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function(self, button)
    if not IsShiftKeyDown() or button ~= "LeftButton" then return end
    local parent = self:GetParent()
    local bag, slot = parent and parent:GetID(), self:GetID()
    if not bag then return end
    local link = GetContainerItemLink(bag, slot)
    local id = link and tonumber(link:match("item:(%d+)"))
    if not id then return end
    if PROTECTED[id] then
        print("|cff33ff99Deepward:|r " .. link .. " is always kept (key item).")
        return
    end
    if DeepwardUIDB.noSell[id] then
        DeepwardUIDB.noSell[id] = nil
        print("|cff33ff99Deepward:|r " .. link .. " will be SOLD by Sell All.")
    else
        DeepwardUIDB.noSell[id] = true
        print("|cff33ff99Deepward:|r " .. link .. " is now KEPT (Sell All skips it).")
    end
    DwUpdateKeepMarkers(parent)
end)

-- GetItemInfo's 6th return (itemType) for things that count as "resources" — never auto-sold, wherever
-- they sit (backpack included).
local KEEP_TYPE = {
    ["Trade Goods"] = true,   -- ore, herbs, cloth, leather, elementals, parts, etc.
    ["Gem"]         = true,   -- cut / uncut gems
}

local function DeepwardSellAll()
    local sold, earned = 0, 0
    -- Bags 0-4 (the backpack, 0, is now included). Specialized bags are skipped whole.
    for bag = 0, 4 do
        -- GetContainerNumFreeSlots returns bagType as its 2nd value: 0 = normal bag, non-zero = a
        -- profession/ammo/shard bag whose contents (ammo, shards, herbs…) must be kept.
        local _, bagType = GetContainerNumFreeSlots(bag)
        if not bagType or bagType == 0 then
            for slot = 1, (GetContainerNumSlots(bag) or 0) do
                local link = GetContainerItemLink(bag, slot)
                if link then
                    local itemId = tonumber(link:match("item:(%d+)"))
                    local _, _, _, _, _, itemType, _, _, _, _, sellPrice = GetItemInfo(link)
                    if itemId and not PROTECTED[itemId] and not DwIsKept(itemId)
                       and not KEEP_TYPE[itemType or ""]
                       and sellPrice and sellPrice > 0 then
                        local _, count = GetContainerItemInfo(bag, slot)
                        UseContainerItem(bag, slot)      -- with a merchant open, this vendors the item
                        sold = sold + 1
                        earned = earned + sellPrice * (count or 1)
                    end
                end
            end
        end
    end
    if sold > 0 then
        print(string.format("|cff33ff99Deepward:|r sold %d item(s) for %dg %ds %dc.",
            sold, math.floor(earned/10000), math.floor((earned%10000)/100), earned%100))
    else
        print("|cff33ff99Deepward:|r nothing to sell (resources, Hearthstone & Repair Bot are kept).")
    end
end

StaticPopupDialogs["DEEPWARD_SELL_ALL"] = {
    text = "Sell everything in all your bags?\n(Resources, Hearthstone, Repair Bot & Shift-click 'kept' items are skipped. Everything is free to buy back.)",
    button1 = YES,
    button2 = NO,
    OnAccept = DeepwardSellAll,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local btn = CreateFrame("Button", "DeepwardSellAllButton", MerchantFrame, "UIPanelButtonTemplate")
btn:SetSize(90, 22)
btn:SetText("Sell All")
-- Just left of the merchant's money display at the bottom of the window.
btn:SetPoint("RIGHT", MerchantMoneyFrame, "LEFT", -8, 0)
btn:SetScript("OnClick", function() StaticPopup_Show("DEEPWARD_SELL_ALL") end)

-- ---------------------------------------------------------------------------
-- "Sort bags" — a small broom button at the far LEFT of the backpack's gold bar. It packs every item
-- tightly into the NEWEST bag first (the bag that currently holds the Hearthstone / Field Repair Bot),
-- then spills into the other bags, sorted by itemID. The Hearthstone and Field Repair Bot NEVER move —
-- they stay in their exact slots (they are PROTECTED); packing fills the slots around them.
-- Moves are done one swap per frame (items lock for a tick after a move), selection-sort style.
-- ---------------------------------------------------------------------------

-- Find the "newest bag" = the normal bag holding the Hearthstone (pref) or Field Repair Bot; else backpack.
local function DwNewestBag()
    for _, want in ipairs({ 6948, 34113 }) do
        for bag = 0, 4 do
            local _, bagType = GetContainerNumFreeSlots(bag)
            if not bagType or bagType == 0 then
                for slot = 1, (GetContainerNumSlots(bag) or 0) do
                    if GetContainerItemID(bag, slot) == want then return bag end
                end
            end
        end
    end
    return 0
end

-- Build the plan: ordered destination slots (newest bag first, then 4..0), the pinned HS/Bot slots
-- (excluded from destinations so they stay put), and the sorted list of items to place.
local function DwBuildSortPlan()
    local newest = DwNewestBag()
    local order = { newest }
    for bag = 4, 0, -1 do if bag ~= newest then order[#order + 1] = bag end end

    local dest, want = {}, {}
    for _, bag in ipairs(order) do
        local _, bagType = GetContainerNumFreeSlots(bag)
        if not bagType or bagType == 0 then                 -- normal bags only (skip profession/ammo bags)
            for slot = 1, (GetContainerNumSlots(bag) or 0) do
                local id = GetContainerItemID(bag, slot)
                if id and PROTECTED[id] then
                    -- pinned: HS / Field Bot stay exactly here — not a destination, not moved
                else
                    dest[#dest + 1] = { bag = bag, slot = slot }
                    if id then
                        local _, count = GetContainerItemInfo(bag, slot)
                        want[#want + 1] = { id = id, count = count or 1 }
                    end
                end
            end
        end
    end
    table.sort(want, function(a, b)
        if a.id ~= b.id then return a.id < b.id end
        return (a.count or 1) > (b.count or 1)
    end)
    return dest, want
end

local sortDriver = CreateFrame("Frame")
sortDriver:Hide()
local planDest, planWant, planIdx, planTick
local function DwStartSort()
    if sortDriver:IsShown() then return end                 -- already sorting
    planDest, planWant = DwBuildSortPlan()
    planIdx, planTick = 1, 0
    sortDriver:Show()
end
local function DwLocked(bag, slot)
    return select(3, GetContainerItemInfo(bag, slot)) and true or false
end
sortDriver:SetScript("OnUpdate", function(self, elapsed)
    planTick = planTick + elapsed
    if planTick < 0.08 then return end                      -- throttle: one swap per ~0.08s (items lock a tick)
    planTick = 0
    if not planDest then self:Hide() return end
    -- skip destination slots already holding the right thing
    while planIdx <= #planDest do
        local d = planDest[planIdx]
        local cur = GetContainerItemID(d.bag, d.slot)
        local w = planWant[planIdx]
        if w then
            if cur == w.id then planIdx = planIdx + 1 else break end
        else
            if not cur then planIdx = planIdx + 1 else break end
        end
    end
    if planIdx > #planDest then
        planDest = nil; self:Hide()
        print("|cff33ff99Deepward:|r bags sorted.")
        return
    end
    local d = planDest[planIdx]
    if DwLocked(d.bag, d.slot) then return end              -- wait for the dest to settle
    local w = planWant[planIdx]
    if w then
        -- pull the wanted item from a later (unfinalized) slot into this slot
        for j = planIdx + 1, #planDest do
            local s = planDest[j]
            if GetContainerItemID(s.bag, s.slot) == w.id and not DwLocked(s.bag, s.slot) then
                ClearCursor()
                PickupContainerItem(s.bag, s.slot)
                PickupContainerItem(d.bag, d.slot)
                return
            end
        end
        planIdx = planIdx + 1                               -- not found (shouldn't happen) — don't stall
    else
        -- this slot should be empty but isn't: move its item to a later empty slot
        for j = planIdx + 1, #planDest do
            local s = planDest[j]
            if not GetContainerItemID(s.bag, s.slot) and not DwLocked(s.bag, s.slot) then
                ClearCursor()
                PickupContainerItem(d.bag, d.slot)
                PickupContainerItem(s.bag, s.slot)
                return
            end
        end
        planIdx = planIdx + 1
    end
end)

-- The button (broom icon). Positioned on the backpack frame (bag 0) at the far left of its gold bar,
-- re-anchored each time ContainerFrame_Update runs for bag 0 (container frames are reused/repositioned).
local sortBtn = CreateFrame("Button", "DeepwardSortButton", UIParent)
sortBtn:SetSize(22, 22)
sortBtn:SetNormalTexture("Interface\\Icons\\INV_Misc_Broom_01")
sortBtn:SetPushedTexture("Interface\\Icons\\INV_Misc_Broom_01")
sortBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
if sortBtn:GetNormalTexture() then sortBtn:GetNormalTexture():SetTexCoord(0.08, 0.92, 0.08, 0.92) end
sortBtn:SetScript("OnClick", DwStartSort)
sortBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Sort bags")
    GameTooltip:AddLine("Pack items into the bag with your Hearthstone first.\nHearthstone & Repair Bot stay put.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)
sortBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
sortBtn:Hide()

hooksecurefunc("ContainerFrame_Update", function(frame)
    if frame and frame.GetID and frame:GetID() == 0 then    -- the backpack frame carries the gold bar
        sortBtn:SetParent(frame)
        sortBtn:ClearAllPoints()
        sortBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 6)
        sortBtn:SetFrameLevel(frame:GetFrameLevel() + 5)
        sortBtn:Show()
    end
end)
