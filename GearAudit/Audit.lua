-- GearAudit: Audit.lua
-- Pure gear-parsing helpers. No UI code lives here, so the audit
-- rules are easy to review and change for a new expansion.
local _, GA = ...

-- Slot IDs used by GetInventoryItemLink. These are WoW's fixed
-- inventory slot numbers, NOT paper-doll display order: slot 4
-- is a shirt and slot 19 is a tabard, so both are left out.
-- Correct mapping: 5 Chest, 6 Waist, 7 Legs, 8 Feet, 9 Wrist,
-- 10 Hands, 11 Finger 1, 12 Finger 2, 13 Trinket 1,
-- 14 Trinket 2, 15 Back, 16 Main Hand, 17 Off Hand.
GA.SLOTS = {
    { id = 1,  name = "Head" },
    { id = 2,  name = "Neck" },
    { id = 3,  name = "Shoulder" },
    { id = 5,  name = "Chest" },
    { id = 6,  name = "Waist" },
    { id = 7,  name = "Legs" },
    { id = 8,  name = "Feet" },
    { id = 9,  name = "Wrist" },
    { id = 10, name = "Hands" },
    { id = 11, name = "Finger 1" },
    { id = 12, name = "Finger 2" },
    { id = 13, name = "Trinket 1" },
    { id = 14, name = "Trinket 2" },
    { id = 15, name = "Back" },
    { id = 16, name = "Main Hand" },
    { id = 17, name = "Off Hand" },
}

-- Slots that can currently take an enchant in retail WoW.
-- This list is deliberately conservative: a slot that is not
-- listed here is never flagged as "missing an enchant", so the
-- audit does not produce false positives when an expansion
-- removes an enchant slot. Update it if Blizzard changes this.
-- Waist, Hands and Trinkets take no enchant and are NOT here.
GA.ENCHANTABLE_SLOTS = {
    [5] = true,   -- Chest
    [7] = true,   -- Legs
    [8] = true,   -- Feet
    [9] = true,   -- Wrist
    [11] = true,  -- Finger 1
    [12] = true,  -- Finger 2
    [15] = true,  -- Back
    [16] = true,  -- Main Hand
    [17] = true,  -- Off Hand (weapon / shield only, checked below)
}

-- An item link looks like:
--   |cffa335ee|Hitem:12345:6789:111:222:0:0:0:0:0:0:0|h[Name]|h|r
-- Field 1 is the item ID, field 2 is the enchant ID, and the
-- next fields are gem IDs. Split on ":" and read those fields.
function GA.ParseItemLink(link)
    if not link then return nil end
    local itemString = link:match("item:([^|]+)")
    if not itemString then return nil end
    local parts = { strsplit(":", itemString) }
    local function numAt(i)
        return tonumber(parts[i]) or 0
    end
    local gems = {}
    for i = 3, 6 do
        if numAt(i) ~= 0 then
            gems[#gems + 1] = numAt(i)
        end
    end
    return {
        itemId = numAt(1),
        enchantId = numAt(2),
        gems = gems,
    }
end

-- Best-effort socket count for one equipped slot.
-- Retail tooltip data marks gem sockets explicitly. If that
-- API is not available (or returns nothing), return nil so
-- callers do not flag a missing gem they cannot prove.
function GA.CountSockets(unit, slotId)
    if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local ok, data = pcall(C_TooltipInfo.GetInventoryItem, unit, slotId)
        if ok and data and data.lines then
            local total, filled = 0, 0
            for _, line in ipairs(data.lines) do
                -- TooltipDataLineType.GemSocket == 7 in retail, but
                -- compare by name when the enum is available so
                -- this survives an enum renumber.
                local isSocket = false
                if Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.GemSocket then
                    isSocket = (line.type == Enum.TooltipDataLineType.GemSocket)
                end
                if not isSocket and line.gemSocket then
                    isSocket = true
                end
                if isSocket then
                    total = total + 1
                    -- A filled socket line carries gem info; an
                    -- empty one does not. Never guess from the
                    -- line text, or empty sockets get miscounted.
                    if line.gem ~= nil then
                        filled = filled + 1
                    end
                end
            end
            if total > 0 then
                return total, filled
            end
            return 0, 0
        end
    end
    return nil, nil
end

-- Audit one equipped slot. Returns a table with:
--   link, itemLevel, hasEnchant, enchantMissing, gemsFilled,
--   sockets, gemsMissing
function GA.AuditSlot(unit, slotId)
    local link = GetInventoryItemLink(unit, slotId)
    if not link then
        return { empty = true }
    end
    local parsed = GA.ParseItemLink(link)
    local itemLevel = 0
    -- Modern retail exposes this as C_Item.GetDetailedItemLevelInfo;
    -- keep the old global as a fallback. GetItemInfo's level below
    -- is only the base level, so it is a last resort, not a
    -- substitute for the upgraded level.
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        local ok, lvl = pcall(C_Item.GetDetailedItemLevelInfo, link)
        if ok then itemLevel = lvl or 0 end
    end
    if itemLevel == 0 and GetDetailedItemLevelInfo then
        itemLevel = GetDetailedItemLevelInfo(link) or 0
    end
    if itemLevel == 0 then
        local _, _, _, lvl = GetItemInfo(link)
        itemLevel = lvl or 0
    end

    local result = {
        link = link,
        itemLevel = itemLevel,
        hasEnchant = parsed and parsed.enchantId ~= 0,
        gemsFilled = parsed and #parsed.gems or 0,
        sockets = 0,
        gemsMissing = 0,
        enchantMissing = false,
    }

    -- Off-hand: only flag a missing enchant on a weapon or
    -- shield, never on a held-off-hand frill / focus item.
    if GA.ENCHANTABLE_SLOTS[slotId] then
        local isWeaponOrShield = true
        if slotId == 17 then
            local _, _, _, _, _, _, itemSubType = GetItemInfo(link)
            isWeaponOrShield = (itemSubType == "Shields")
                or (itemSubType == "One-Handed Axes" or itemSubType == "One-Handed Swords"
                or itemSubType == "One-Handed Maces" or itemSubType == "Daggers"
                or itemSubType == "Fist Weapons" or itemSubType == "Warglaives")
            -- Main-hand style weapons in the off hand are also
            -- enchantable; if the subtype is unknown, do not flag.
            if itemSubType == nil then isWeaponOrShield = false end
        end
        if isWeaponOrShield and not result.hasEnchant then
            result.enchantMissing = true
        end
    end

    local totalSockets, filledSockets = GA.CountSockets(unit, slotId)
    if totalSockets ~= nil then
        result.sockets = totalSockets
        -- Prefer the tooltip's filled count when available;
        -- otherwise fall back to the gem IDs in the link.
        if filledSockets ~= nil and filledSockets > 0 then
            result.gemsFilled = filledSockets
        end
        result.gemsMissing = math.max(0, totalSockets - result.gemsFilled)
    end
    return result
end

-- Audit a whole unit. Returns a summary table used by the UI.
function GA.AuditUnit(unit)
    local gear = {}
    local totalLevel, counted = 0, 0
    local missingEnchants, missingGems = {}, 0
    for _, slot in ipairs(GA.SLOTS) do
        local audit = GA.AuditSlot(unit, slot.id)
        audit.slotId = slot.id
        audit.slotName = slot.name
        gear[slot.id] = audit
        if not audit.empty and audit.itemLevel and audit.itemLevel > 0 then
            totalLevel = totalLevel + audit.itemLevel
            counted = counted + 1
        end
        if audit.enchantMissing then
            missingEnchants[#missingEnchants + 1] = slot.name
        end
        missingGems = missingGems + (audit.gemsMissing or 0)
    end
    local avgLevel = 0
    if counted > 0 then
        avgLevel = totalLevel / counted
    end
    return {
        gear = gear,
        avgLevel = avgLevel,
        itemCount = counted,
        missingEnchants = missingEnchants,
        missingEnchantCount = #missingEnchants,
        missingGemCount = missingGems,
    }
end
