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
                    if itemId and not PROTECTED[itemId] and not KEEP_TYPE[itemType or ""]
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
    text = "Sell everything in all your bags?\n(Resources, Hearthstone & Repair Bot are kept. Everything is free to buy back.)",
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
