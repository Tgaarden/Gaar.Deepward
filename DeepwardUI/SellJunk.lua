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
                local t = btn:CreateTexture(nil, "OVERLAY")
                t:SetDrawLayer("OVERLAY", 7)                 -- above the stack-count text
                t:SetSize(16, 16)
                t:SetPoint("BOTTOMRIGHT", -1, 1)             -- bottom-right (gear has no stack-count there)
                t:SetTexture("Interface\\AddOns\\DeepwardUI\\keeplock")   -- custom gold padlock (guaranteed to render)
                btn.dwKeepLock = t
            end
            local link = GetContainerItemLink(bag, btn:GetID())
            local id = link and tonumber(link:match("item:(%d+)"))
            if DwIsKept(id) then btn.dwKeepLock:Show() else btn.dwKeepLock:Hide() end
        end
    end
end
hooksecurefunc("ContainerFrame_Update", DwUpdateKeepMarkers)

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
