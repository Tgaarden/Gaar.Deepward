-- Deepward UI — "Sell Bags" button on the merchant window.
-- Model: your DEFAULT BACKPACK (bag 0) is the keep zone — nothing there is ever sold. Everything in
-- your other NORMAL bag slots (bags 1-4) that has a vendor value is sold. So to keep something, move it
-- into the backpack; anything you leave in a normal side bag gets vendored.
-- Specialized bags (quiver, ammo pouch, soul shard bag, herb/enchanting/mining/etc.) are skipped
-- entirely — their contents (ammo, shards, herbs…) are never sold.
-- The Hearthstone and Field Repair Bot are NEVER sold, even if they end up in a side bag.
-- Items with no sell price (most quest items) can't be vendored and are skipped automatically.
-- A confirm popup guards against an accidental sell (buyback only holds the last 12 items).

local PROTECTED = {
    [6948]  = true,   -- Hearthstone (only way out of an instance)
    [34113] = true,   -- Field Repair Bot 110G (eternal convenience item, re-granted on login)
}

local function DeepwardSellAll()
    local sold, earned = 0, 0
    -- Bags 1-4 only: bag 0 (the default backpack) is the protected keep zone.
    for bag = 1, 4 do
        -- Skip specialized bags entirely (quiver, ammo pouch, soul shard bag, herb/enchanting/mining/
        -- engineering/inscription/gem bags). GetContainerNumFreeSlots returns bagType as its 2nd value:
        -- 0 = normal bag, anything non-zero = a profession/ammo bag whose contents must be kept.
        local _, bagType = GetContainerNumFreeSlots(bag)
        if not bagType or bagType == 0 then
            for slot = 1, (GetContainerNumSlots(bag) or 0) do
                local link = GetContainerItemLink(bag, slot)
                if link then
                    local itemId = tonumber(link:match("item:(%d+)"))
                    local _, _, _, _, _, _, _, _, _, _, sellPrice = GetItemInfo(link)
                    if itemId and not PROTECTED[itemId] and sellPrice and sellPrice > 0 then
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
        print("|cff33ff99Deepward:|r nothing to sell (backpack items are kept).")
    end
end

StaticPopupDialogs["DEEPWARD_SELL_ALL"] = {
    text = "Sell everything in your side bags?\n(Items in your backpack are kept. Hearthstone & Repair Bot are never sold.)",
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
btn:SetText("Sell Bags")
-- Just left of the merchant's money display at the bottom of the window.
btn:SetPoint("RIGHT", MerchantMoneyFrame, "LEFT", -8, 0)
btn:SetScript("OnClick", function() StaticPopup_Show("DEEPWARD_SELL_ALL") end)
