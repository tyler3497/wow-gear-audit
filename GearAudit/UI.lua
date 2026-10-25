-- GearAudit: UI.lua
-- Overview list + detail panel. Click a player in the overview
-- to see every slot, its item level, and its audit flags.
local _, GA = ...

local ROW_HEIGHT = 26
local MAX_ROWS = 40

local function ClassColor(unit)
    local _, class = UnitClass(unit)
    if class and RAID_CLASS_COLORS[class] then
        return RAID_CLASS_COLORS[class]
    end
    return { r = 1, g = 1, b = 1 }
end

local function ItemNameFromLink(link)
    local name = link:match("%[(.-)%]")
    if name then return name end
    local itemName = GetItemInfo(link)
    return itemName or "Unknown item"
end

-- ------------------------------------------------------------------
-- Main window
-- ------------------------------------------------------------------
local main = CreateFrame("Frame", "GearAuditFrame", UIParent, "BackdropTemplate")
main:SetSize(420, 560)
main:SetPoint("CENTER")
main:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
main:SetMovable(true)
main:EnableMouse(true)
main:RegisterForDrag("LeftButton")
main:SetScript("OnDragStart", main.StartMoving)
main:SetScript("OnDragStop", main.StopMovingOrSizing)
main:Hide()

local title = main:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
title:SetPoint("TOP", main, "TOP", 0, -16)
title:SetText("Gear Audit")

local close = CreateFrame("Button", nil, main, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", main, "TOPRIGHT", -6, -6)
close:SetScript("OnClick", function() main:Hide() end)

local status = main:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
status:SetPoint("TOPLEFT", main, "TOPLEFT", 18, -44)
status:SetPoint("TOPRIGHT", main, "TOPRIGHT", -18, -44)
status:SetJustifyH("LEFT")
status:SetText("Press Refresh to inspect your party or raid.")

local refreshBtn = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
refreshBtn:SetSize(120, 24)
refreshBtn:SetPoint("TOPLEFT", main, "TOPLEFT", 18, -64)
refreshBtn:SetText("Refresh All")
refreshBtn:SetScript("OnClick", function() GA.RefreshAll() end)

local hint = main:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hint:SetPoint("LEFT", refreshBtn, "RIGHT", 10, 0)
hint:SetText("Click a player for full gear.")

-- Header row
local header = main:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
header:SetPoint("TOPLEFT", main, "TOPLEFT", 22, -98)
header:SetText("Player                          iLvl    Ench    Gems")

local scroll = CreateFrame("ScrollFrame", nil, main, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", main, "TOPLEFT", 18, -116)
scroll:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -34, 16)
local scrollChild = CreateFrame("Frame", nil, scroll)
scrollChild:SetSize(360, 1)
scroll:SetScrollChild(scrollChild)

local rows = {}
for i = 1, MAX_ROWS do
    local row = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
    row:SetSize(360, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    row:SetBackdropColor(0, 0, 0, 0)
    row:SetScript("OnEnter", function(self)
        self:SetBackdropColor(1, 1, 1, 0.08)
    end)
    row:SetScript("OnLeave", function(self)
        if GA.selectedUnit == self.unit then
            self:SetBackdropColor(0.2, 0.4, 0.8, 0.25)
        else
            self:SetBackdropColor(0, 0, 0, 0)
        end
    end)
    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.nameText:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.nameText:SetWidth(170)
    row.nameText:SetJustifyH("LEFT")
    row.ilvlText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.ilvlText:SetPoint("LEFT", row, "LEFT", 178, 0)
    row.ilvlText:SetWidth(50)
    row.enchText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.enchText:SetPoint("LEFT", row, "LEFT", 232, 0)
    row.enchText:SetWidth(50)
    row.gemText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.gemText:SetPoint("LEFT", row, "LEFT", 286, 0)
    row.gemText:SetWidth(50)
    row:SetScript("OnClick", function(self)
        GA.selectedUnit = self.unit
        GA.RefreshOverview()
        GA.ShowDetail(self.unit)
    end)
    rows[i] = row
end

-- ------------------------------------------------------------------
-- Detail panel
-- ------------------------------------------------------------------
local detail = CreateFrame("Frame", "GearAuditDetailFrame", UIParent, "BackdropTemplate")
detail:SetSize(420, 560)
detail:SetPoint("LEFT", main, "RIGHT", 8, 0)
detail:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
detail:SetMovable(true)
detail:EnableMouse(true)
detail:RegisterForDrag("LeftButton")
detail:SetScript("OnDragStart", detail.StartMoving)
detail:SetScript("OnDragStop", detail.StopMovingOrSizing)
detail:Hide()

local detailTitle = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
detailTitle:SetPoint("TOP", detail, "TOP", 0, -16)
detailTitle:SetText("Gear Detail")

local detailClose = CreateFrame("Button", nil, detail, "UIPanelCloseButton")
detailClose:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -6, -6)
detailClose:SetScript("OnClick", function() detail:Hide() end)

local detailSummary = detail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
detailSummary:SetPoint("TOPLEFT", detail, "TOPLEFT", 18, -44)
detailSummary:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -18, -44)
detailSummary:SetJustifyH("LEFT")

local detailRefresh = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
detailRefresh:SetSize(140, 24)
detailRefresh:SetPoint("TOPLEFT", detail, "TOPLEFT", 18, -76)
detailRefresh:SetText("Re-inspect Player")
detailRefresh:SetScript("OnClick", function()
    if GA.selectedUnit then GA.RefreshUnit(GA.selectedUnit) end
end)

local detailSlots = {}
for i, slot in ipairs(GA.SLOTS) do
    local y = -108 - (i - 1) * 26
    local label = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", detail, "TOPLEFT", 18, y)
    label:SetWidth(70)
    label:SetJustifyH("LEFT")
    label:SetText(slot.name)

    local itemBtn = CreateFrame("Button", nil, detail)
    itemBtn:SetPoint("LEFT", label, "RIGHT", 6, 0)
    itemBtn:SetSize(210, 20)
    itemBtn.text = itemBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    itemBtn.text:SetAllPoints(itemBtn)
    itemBtn.text:SetJustifyH("LEFT")
    itemBtn:SetScript("OnEnter", function(self)
        if self.link then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.link)
            GameTooltip:Show()
        end
    end)
    itemBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    itemBtn:SetScript("OnClick", function(self)
        -- Shift-click drops the item link into chat, like the
        -- default UI. A plain click just shows the tooltip.
        if IsShiftKeyDown() and self.link then
            ChatEdit_InsertLink(self.link)
        end
    end)

    local flags = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    flags:SetPoint("LEFT", itemBtn, "RIGHT", 6, 0)
    flags:SetWidth(110)
    flags:SetJustifyH("LEFT")

    detailSlots[i] = { slot = slot, label = label, itemBtn = itemBtn, flags = flags }
end

local detailNote = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
detailNote:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 18, 18)
detailNote:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -18, 18)
detailNote:SetJustifyH("LEFT")
detailNote:SetText("Enchant audit covers Back, Chest, Wrist, Legs, Feet,\nRings, and weapons. Other slots take no enchant in\nretail and are never flagged. Gem flags need tooltip\nsocket data; if that is unavailable, gems are not flagged.")

-- ------------------------------------------------------------------
-- Rendering
-- ------------------------------------------------------------------
function GA.RefreshOverview()
    local units = GA.GetGroupUnits()
    -- Sort inspected players by item level, highest first.
    -- Uninspected / uninspectable players go to the bottom.
    table.sort(units, function(a, b)
        local da, db = GA.data[a], GA.data[b]
        local la = (da and da.avgLevel) or -1
        local lb = (db and db.avgLevel) or -1
        if la ~= lb then return la > lb end
        return (GA.UnitDisplayName(a) or "") < (GA.UnitDisplayName(b) or "")
    end)

    for i, row in ipairs(rows) do
        local unit = units[i]
        row.unit = unit
        if not unit then
            row:Hide()
        else
            row:Show()
            local color = ClassColor(unit)
            row.nameText:SetText(GA.UnitDisplayName(unit))
            row.nameText:SetTextColor(color.r, color.g, color.b)
            local audit = GA.data[unit]
            if not audit then
                row.ilvlText:SetText("—")
                row.enchText:SetText("—")
                row.gemText:SetText("—")
            elseif audit.notInspectable then
                row.ilvlText:SetText("—")
                row.enchText:SetText("—")
                row.gemText:SetText(audit.reason or "—")
            else
                row.ilvlText:SetText(string.format("%.0f", audit.avgLevel or 0))
                if audit.missingEnchantCount == 0 then
                    row.enchText:SetText("|cff00ff00OK|r")
                else
                    row.enchText:SetText("|cffff0000" .. audit.missingEnchantCount .. " missing|r")
                end
                if audit.missingGemCount == 0 then
                    row.gemText:SetText("|cff00ff00OK|r")
                else
                    row.gemText:SetText("|cffff0000" .. audit.missingGemCount .. " missing|r")
                end
            end
            if GA.selectedUnit == unit then
                row:SetBackdropColor(0.2, 0.4, 0.8, 0.25)
            else
                row:SetBackdropColor(0, 0, 0, 0)
            end
        end
    end
    scrollChild:SetHeight(math.max(1, #units * ROW_HEIGHT))
end

function GA.ShowDetail(unit)
    if not unit or not UnitExists(unit) then return end
    GA.selectedUnit = unit
    local audit = GA.data[unit]
    local color = ClassColor(unit)
    detailTitle:SetText(GA.UnitDisplayName(unit))
    detailTitle:SetTextColor(color.r, color.g, color.b)
    if not audit then
        detailSummary:SetText("Not inspected yet. Press Re-inspect Player.")
        for _, entry in ipairs(detailSlots) do
            entry.itemBtn.text:SetText("—")
            entry.itemBtn.link = nil
            entry.flags:SetText("")
        end
    elseif audit.notInspectable then
        detailSummary:SetText(audit.reason or "Could not inspect this player.")
        for _, entry in ipairs(detailSlots) do
            entry.itemBtn.text:SetText("—")
            entry.itemBtn.link = nil
            entry.flags:SetText("")
        end
    else
        local enchSummary = "No missing enchants"
        if audit.missingEnchantCount > 0 then
            enchSummary = "Missing enchants: " .. table.concat(audit.missingEnchants, ", ")
        end
        detailSummary:SetText(string.format(
            "Average item level: %.1f  (%d items)\n%s\nMissing gems: %d",
            audit.avgLevel or 0, audit.itemCount or 0, enchSummary, audit.missingGemCount or 0))
        for _, entry in ipairs(detailSlots) do
            local slotAudit = audit.gear[entry.slot.id]
            if not slotAudit or slotAudit.empty then
                entry.itemBtn.text:SetText("|cff888888(empty)|r")
                entry.itemBtn.link = nil
                entry.flags:SetText("")
            else
                local _, _, quality = GetItemInfo(slotAudit.link)
                local r, g, b = 1, 1, 1
                if quality then
                    r, g, b = GetItemQualityColor(quality)
                end
                entry.itemBtn.text:SetText(string.format("%d  %s", slotAudit.itemLevel or 0, ItemNameFromLink(slotAudit.link)))
                entry.itemBtn.text:SetTextColor(r, g, b)
                entry.itemBtn.link = slotAudit.link
                local parts = {}
                if GA.ENCHANTABLE_SLOTS[entry.slot.id] then
                    if slotAudit.enchantMissing then
                        parts[#parts + 1] = "|cffff0000No enchant|r"
                    else
                        parts[#parts + 1] = "|cff00ff00Enchant|r"
                    end
                end
                if slotAudit.sockets and slotAudit.sockets > 0 then
                    if slotAudit.gemsMissing > 0 then
                        parts[#parts + 1] = "|cffff0000" .. slotAudit.gemsMissing .. " gem(s) missing|r"
                    else
                        parts[#parts + 1] = "|cff00ff00Gems OK|r"
                    end
                end
                entry.flags:SetText(table.concat(parts, "  "))
            end
        end
    end
    detail:Show()
end

-- Core.lua calls these hooks.
function GA.OnUnitAudited(unit)
    GA.RefreshOverview()
    if GA.selectedUnit == unit and detail:IsShown() then
        GA.ShowDetail(unit)
    end
end

function GA.OnRefreshStarted(count)
    status:SetText(string.format("Inspecting %d player(s)...", count))
end

function GA.OnInspectFinished()
    status:SetText("Done. Click a player for full gear.")
    GA.RefreshOverview()
end

function GA.OnRosterChanged()
    GA.RefreshOverview()
end

function GA.ToggleWindow(force)
    if force == true then
        main:Show()
        GA.RefreshOverview()
    elseif force == false then
        main:Hide()
        detail:Hide()
    elseif main:IsShown() then
        main:Hide()
        detail:Hide()
    else
        main:Show()
        GA.RefreshOverview()
    end
end
