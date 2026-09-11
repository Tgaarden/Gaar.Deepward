--[[
  Deepward Pawn — item scoring from stat weights (original code, not derived from any other addon).

  Reads an item's stats via GetItemStats, multiplies by a per-class weight set, and shows a "Deepward score"
  on the tooltip. For equippable gear it also compares against what you have equipped in that slot and marks
  an upgrade. Weights live in DeepwardPawnDB.weights (seeded per class) and can be edited there. Client-side
  only (law I).  /dwpawn to print the active weights.
]]

local _G = _G

-- Default stat weights keyed by class. Keys are the tokens GetItemStats returns (ITEM_MOD_*). These are
-- reasonable generic starting points; edit DeepwardPawnDB.weights to taste.
local PHYS = { ITEM_MOD_STRENGTH = 1.0, ITEM_MOD_AGILITY = 0.6, ITEM_MOD_ATTACK_POWER = 0.5,
    ITEM_MOD_CRIT_RATING = 0.8, ITEM_MOD_HIT_RATING = 0.9, ITEM_MOD_HASTE_RATING = 0.7,
    ITEM_MOD_EXPERTISE_RATING = 0.9, ITEM_MOD_ARMOR_PENETRATION_RATING = 0.6, ITEM_MOD_STAMINA = 0.3 }
local AGI = { ITEM_MOD_AGILITY = 1.0, ITEM_MOD_ATTACK_POWER = 0.5, ITEM_MOD_CRIT_RATING = 0.8,
    ITEM_MOD_HIT_RATING = 0.9, ITEM_MOD_HASTE_RATING = 0.6, ITEM_MOD_STRENGTH = 0.4, ITEM_MOD_STAMINA = 0.3 }
local CASTER = { ITEM_MOD_SPELL_POWER = 1.0, ITEM_MOD_INTELLECT = 0.4, ITEM_MOD_CRIT_RATING = 0.7,
    ITEM_MOD_HASTE_RATING = 0.8, ITEM_MOD_HIT_RATING = 0.9, ITEM_MOD_SPIRIT = 0.3, ITEM_MOD_STAMINA = 0.3 }
local TANK = { ITEM_MOD_STAMINA = 1.0, ITEM_MOD_DODGE_RATING = 0.8, ITEM_MOD_PARRY_RATING = 0.8,
    ITEM_MOD_DEFENSE_SKILL_RATING = 0.9, ITEM_MOD_STRENGTH = 0.5, ITEM_MOD_BLOCK_RATING = 0.5,
    ITEM_MOD_AGILITY = 0.4, RESISTANCE0_NAME = 0 }
local HEAL = { ITEM_MOD_SPELL_POWER = 1.0, ITEM_MOD_INTELLECT = 0.5, ITEM_MOD_SPIRIT = 0.6,
    ITEM_MOD_HASTE_RATING = 0.7, ITEM_MOD_CRIT_RATING = 0.6, ITEM_MOD_MP5 = 0.8, ITEM_MOD_STAMINA = 0.2 }

local DEFAULT_BY_CLASS = {
    WARRIOR = PHYS, DEATHKNIGHT = PHYS, ROGUE = AGI, HUNTER = AGI,
    MAGE = CASTER, WARLOCK = CASTER, PRIEST = CASTER,
    PALADIN = PHYS, SHAMAN = CASTER, DRUID = CASTER,
}

local function DB()
    if type(DeepwardPawnDB) ~= "table" then DeepwardPawnDB = {} end
    local d = DeepwardPawnDB
    if type(d.weights) ~= "table" then
        local _, cls = UnitClass("player")
        local base = DEFAULT_BY_CLASS[cls] or PHYS
        d.weights = {}
        for k, v in pairs(base) do d.weights[k] = v end   -- copy so the user can edit freely
    end
    return d
end

local function Score(link)
    if not link then return nil end
    local stats = GetItemStats(link)
    if not stats then return nil end
    local w = DB().weights
    local total = 0
    for stat, val in pairs(stats) do
        local weight = w[stat]
        if weight then total = total + val * weight end
    end
    return total
end

-- equip location -> inventory slot id(s) to compare an upgrade against
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 },
    INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 },
    INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 },
    INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_SHIELD = { 17 }, INVTYPE_RANGED = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RANGEDRIGHT = { 18 },
}

local function BestEquippedScore(equipLoc)
    local slots = SLOTS[equipLoc]
    if not slots then return nil end
    local best
    for _, sid in ipairs(slots) do
        local eq = GetInventoryItemLink("player", sid)
        local s = eq and Score(eq)
        if s and (not best or s < best) then best = s end   -- compare vs the WORST-scoring equipped (the one you'd replace)
    end
    return best
end

local function AddScore(tooltip)
    local _, link = tooltip:GetItem()
    if not link then return end
    local s = Score(link)
    if not s or s <= 0 then return end
    tooltip:AddLine(("|cff33ff99Deepward score:|r %.0f"):format(s))
    local equipLoc = select(9, GetItemInfo(link))
    local eqBest = equipLoc and BestEquippedScore(equipLoc)
    if eqBest and eqBest > 0 then
        if s > eqBest then
            tooltip:AddLine(("|cff40ff40▲ Upgrade|r  (equipped %.0f, +%.0f)"):format(eqBest, s - eqBest))
        else
            tooltip:AddLine(("|cffff8040▼ Sidegrade/lower|r  (equipped %.0f)"):format(eqBest))
        end
    end
    tooltip:Show()
end

GameTooltip:HookScript("OnTooltipSetItem", AddScore)
if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipSetItem", AddScore) end

SLASH_DEEPWARDPAWN1 = "/dwpawn"
SlashCmdList["DEEPWARDPAWN"] = function()
    print("|cff33ff99Deepward Pawn|r active stat weights (edit DeepwardPawnDB.weights):")
    local w = DB().weights
    local keys = {}
    for k in pairs(w) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        print(("  %s = %.2f"):format(k:gsub("ITEM_MOD_", ""):gsub("_RATING", ""), w[k]))
    end
end
