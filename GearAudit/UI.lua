-- GearAudit: UI.lua
-- Modern dark UI: flat panels, thin borders, a single accent
-- colour, item icons, and no chunky DialogBox chrome. This is
-- deliberately built from plain frames, not the old gold
-- UIPanel templates, so it matches newer addons.
local _, GA = ...

local ROW_HEIGHT = 34
local MAX_ROWS = 40

-- Palette (Ellesmere-style: near-black panels, soft grey text,
-- one blue accent, green / red only for pass / fail).
local COL_BG     = { 0.07, 0.08, 0.11, 0.97 }
local COL_PANEL  = { 0.11, 0.13, 0.18, 1 }
local COL_HOVER  = { 0.16, 0.18, 0.25, 1 }
local COL_BORDER = { 0.24, 0.27, 0.34, 1 }
local COL_ACCENT = { 0.25, 0.65, 0.95, 1 }
local COL_TEXT   = { 0.92, 0.93, 0.96, 1 }
local COL_DIM    = { 0.62, 0.65, 0.71, 1 }
local COL_GREEN  = { 0.35, 0.85, 0.55, 1 }
local COL_RED    = { 0.95, 0.35, 0.35, 1 }

local function SetModernBackdrop(frame, bg, border)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
    frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
end

local function CreateModernFrame(name, width, height)
    local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    frame:SetSize(width, height)
    SetModernBackdrop(frame, COL_BG, COL_BORDER)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    -- Thin accent bar across the top, the one splash of colour.
    local bar = frame:CreateTexture(nil, "OVERLAY")
    bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    bar:SetHeight(3)
    bar:SetColorTexture(COL_ACCENT[1], COL_ACCENT[2], COL_ACCENT[3], 1)
    return frame
end

local function CreateFlatButton(parent, text, width, height, accent)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    if accent then
        SetModernBackdrop(btn, { 0.15, 0.38, 0.60, 1 }, COL_ACCENT)
    else
        SetModernBackdrop(btn, COL_PANEL, COL_BORDER)
    end
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetAllPoints(btn)
    label:SetText(text)
    label:SetTextColor(COL_TEXT[1], COL_TEXT[2], COL_TEXT[3])
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(COL_HOVER[1], COL_HOVER[2], COL_HOVER[3], 1)
        self:SetBackdropBorderColor(COL_ACCENT[1], COL_ACCENT[2], COL_ACCENT[3], 1)
    end)
    btn:SetScript("OnLeave", function(self)
        if accent then
            self:SetBackdropColor(0.15, 0.38, 0.60, 1)
            self:SetBackdropBorderColor(COL_ACCENT[1], COL_ACCENT[2], COL_ACCENT[3], 1)
        else
            self:SetBackdropColor(COL_PANEL[1], COL_PANEL[2], COL_PANEL[3], 1)
            self:SetBackdropBorderColor(COL_BORDER[1], COL_BORDER[2], COL_BORDER[3], 1)
        end
    end)
    return btn
end

local function CreateCloseButton(parent)
    local btn = CreateFlatButton(parent, "×", 26, 26, false)
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -10)
    return btn
end

local function ClassColor(unit)
    if not UnitClass then return { r = 1, g = 1, b = 1 } end
    local _, classFile = UnitClass(unit)
    return GA.GetClassColor(classFile)
end

local function CleanItemName(name)
    if not name then return nil end
    -- Midnight item links can carry an atlas quality icon in
    -- the display name, e.g. "Name |A:...|a". Strip it, or the
    -- UI shows raw atlas markup.
    name = name:gsub("|A:[^|]*|a", "")
    name = name:gsub("|T[^|]*|t", "")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    return name
end

local function ItemNameFromLink(link)
    local name = link:match("%[(.-)%]")
    if name then return CleanItemName(name) or "Unknown item" end
    -- GA.GetItemInfo (Audit.lua) uses C_Item.GetItemInfo in
    -- Midnight; the old global GetItemInfo no longer exists.
    local itemName = GA.GetItemInfo(link)
    return CleanItemName(itemName) or "Unknown item"
end

-- ------------------------------------------------------------------
-- Main window
-- ------------------------------------------------------------------
local main = CreateModernFrame("GearAuditFrame", 460, 600)
main:SetPoint("CENTER")

local title = main:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", main, "TOPLEFT", 16, -16)
title:SetText("Gear Audit")
title:SetTextColor(COL_TEXT[1], COL_TEXT[2], COL_TEXT[3])

local subtitle = main:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
subtitle:SetText("Party & raid gear  •  Retail 12.1.5")
subtitle:SetTextColor(COL_DIM[1], COL_DIM[2], COL_DIM[3])

local close = CreateCloseButton(main)
close:SetScript("OnClick", function() main:Hide() end)

local status = main:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
status:SetPoint("TOPLEFT", main, "TOPLEFT", 16, -62)
status:SetPoint("TOPRIGHT", main, "TOPRIGHT", -16, -62)
status:SetJustifyH("LEFT")
status:SetText("Press Refresh to inspect your party or raid.")
status:SetTextColor(COL_DIM[1], COL_DIM[2], COL_DIM[3])

local refreshBtn = CreateFlatButton(main, "Refresh All", 120, 28, true)
refreshBtn:SetPoint("TOPLEFT", main, "TOPLEFT", 16, -84)
refreshBtn:SetScript("OnClick", function() GA.RefreshAll() end)

local hint = main:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hint:SetPoint("LEFT", refreshBtn, "RIGHT", 12, 0)
hint:SetText("Click a player for full gear.")
hint:SetTextColor(COL_DIM[1], COL_DIM[2], COL_DIM[3])

-- Column headers, small and grey, like a modern list view.
local header = main:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
header:SetPoint("TOPLEFT", main, "TOPLEFT", 28, -124)
header:SetText("PLAYER                    ILVL      ENCHANTS      GEMS")
header:SetTextColor(COL_DIM[1], COL_DIM[2], COL_DIM[3])

local headerLine = main:CreateTexture(nil, "OVERLAY")
headerLine:SetPoint("TOPLEFT", main, "TOPLEFT", 16, -138)
headerLine:SetPoint("TOPRIGHT", main, "TOPRIGHT", -16, -138)
headerLine:SetHeight(1)
headerLine:SetColorTexture(COL_BORDER[1], COL_BORDER[2], COL_BORDER[3], 1)

-- Plain scroll frame with mouse-wheel scrolling: no chunky
-- old scrollbar, which is most of the dated look.
local scroll = CreateFrame("ScrollFrame", nil, main)
scroll:SetPoint("TOPLEFT", main, "TOPLEFT", 16, -144)
scroll:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -16, 36)
local scrollChild = CreateFrame("Frame", nil, scroll)
scrollChild:SetSize(428, 1)
scroll:SetScrollChild(scrollChild)
scroll:SetScript("OnMouseWheel", function(self, delta)
    local cur = self:GetVerticalScroll()
    local max = self:GetVerticalScrollRange()
    self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * ROW_HEIGHT)))
end)
scroll:EnableMouseWheel(true)

local summary = main:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
summary:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", 16, 14)
summary:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -16, 14)
summary:SetJustifyH("LEFT")
summary:SetTextColor(COL_DIM[1], COL_DIM[2], COL_DIM[3])
summary:SetText("")

local rows = {}
for i = 1, MAX_ROWS do
    local row = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
    row:SetSize(428, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
    SetModernBackdrop(row, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
    -- Selected accent bar on the left edge.
    row.accentBar = row:CreateTexture(nil, "OVERLAY")
    row.accentBar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.accentBar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.accentBar:SetWidth(3)
    row.accentBar:SetColorTexture(COL_ACCENT[1], COL_ACCENT[2], COL_ACCENT[3], 1)
    row.accentBar:Hide()
    row:SetScript("OnEnter", function(self)
        self:SetBackdropColor(COL_HOVER[1], COL_HOVER[2], COL_HOVER[3], 1)
    end)
    row:SetScript("OnLeave", function(self)
        if GA.selectedUnit == self.unit then
            self:SetBackdropColor(COL_PANEL[1], COL_PANEL[2], COL_PANEL[3], 1)
        else
            self:SetBackdropColor(0, 0, 0, 0)
        end
    end)
    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.nameText:SetPoint("LEFT", row, "LEFT", 12, 0)
    row.nameText:SetWidth(178)
    row.nameText:SetJustifyH("LEFT")
    row.ilvlText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.ilvlText:SetPoint("LEFT", row, "LEFT", 196, 0)
    row.ilvlText:SetWidth(52)
    row.ilvlText:SetTextColor(COL_TEXT[1], COL_TEXT[2], COL_TEXT[3])
    row.enchText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.enchText:SetPoint("LEFT", row, "LEFT", 254, 0)
    row.enchText:SetWidth(78)
    row.gemText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.gemText:SetPoint("LEFT", row, "LEFT", 338, 0)
    row.gemText:SetWidth(78)
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
local detail = CreateModernFrame("GearAuditDetailFrame", 460, 640)
detail:SetPoint("LEFT", main, "RIGHT", 8, 0)

local detailTitle = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
detailTitle:SetPoint("TOPLEFT", detail, "TOPLEFT", 16, -16)
detailTitle:SetText("Gear Detail")
detailTitle:SetTextColor(COL_TEXT[1], COL_TEXT[2], COL_TEXT[3])

local detailClose = CreateCloseButton(detail)
detailClose:SetScript("OnClick", function() detail:Hide() end)

local detailSummary = detail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
detailSummary:SetPoint("TOPLEFT", detail, "TOPLEFT", 16, -48)
detailSummary:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -16, -48)
detailSummary:SetJustifyH("LEFT")
detailSummary:SetTextColor(COL_TEXT[1], COL_TEXT[2], COL_TEXT[3])

local detailRefresh = CreateFlatButton(detail, "Re-inspect Player", 150, 28, true)
detailRefresh:SetPoint("TOPLEFT", detail, "TOPLEFT", 16, -96)
detailRefresh:SetScript("OnClick", function()
    if GA.selectedUnit then GA.RefreshUnit(GA.selectedUnit) end
end)

local detailSlots = {}
for i, slot in ipairs(GA.SLOTS) do
    local y = -132 - (i - 1) * 28
    -- Item icon, bordered in the item's quality colour.
    local iconFrame = CreateFrame("Frame", nil, detail, "BackdropTemplate")
    iconFrame:SetSize(26, 26)
    iconFrame:SetPoint("TOPLEFT", detail, "TOPLEFT", 16, y)
    SetModernBackdrop(iconFrame, COL_PANEL, COL_BORDER)
    local icon = iconFrame:CreateTexture(nil, "OVERLAY")
    icon:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local label = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", iconFrame, "RIGHT", 8, 0)
    label:SetWidth(62)
    label:SetJustifyH("LEFT")
    label:SetText(slot.name)
    label:SetTextColor(COL_DIM[1], COL_DIM[2], COL_DIM[3])

    local itemBtn = CreateFrame("Button", nil, detail)
    itemBtn:SetPoint("LEFT", label, "RIGHT", 6, 0)
    itemBtn:SetSize(188, 20)
    itemBtn.text = itemBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    itemBtn.text:SetAllPoints(itemBtn)
    itemBtn.text:SetJustifyH("LEFT")
    itemBtn:SetScript("OnEnter", function(self)
        if self.link and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.link)
            GameTooltip:Show()
        end
    end)
    itemBtn:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    itemBtn:SetScript("OnClick", function(self)
        if IsShiftKeyDown and IsShiftKeyDown() and self.link and ChatEdit_InsertLink then
            ChatEdit_InsertLink(self.link)
        end
    end)

    local flags = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    flags:SetPoint("LEFT", itemBtn, "RIGHT", 6, 0)
    flags:SetWidth(108)
    flags:SetJustifyH("LEFT")

    detailSlots[i] = { slot = slot, iconFrame = iconFrame, icon = icon, label = label, itemBtn = itemBtn, flags = flags }
end

local detailNote = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
detailNote:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 16, 14)
detailNote:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -16, 14)
detailNote:SetJustifyH("LEFT")
detailNote:SetTextColor(COL_DIM[1], COL_DIM[2], COL_DIM[3])
detailNote:SetText("Enchant audit covers Back, Chest, Wrist, Legs, Feet, Rings, and weapons. Other slots take no enchant and are never flagged. Gem flags need tooltip socket data; if that is unavailable, gems are not flagged.")

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

    local inspected, totalEnch, totalGems = 0, 0, 0
    for _, unit in ipairs(units) do
        local audit = GA.data[unit]
        if audit and not audit.notInspectable then
            inspected = inspected + 1
            totalEnch = totalEnch + (audit.missingEnchantCount or 0)
            totalGems = totalGems + (audit.missingGemCount or 0)
        end
    end
    summary:SetText(string.format("%d of %d inspected  •  %d missing enchants  •  %d missing gems",
        inspected, #units, totalEnch, totalGems))

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
                row.enchText:SetTextColor(COL_DIM[1], COL_DIM[2], COL_DIM[3])
                row.gemText:SetText("—")
                row.gemText:SetTextColor(COL_DIM[1], COL_DIM[2], COL_DIM[3])
            elseif audit.notInspectable then
                row.ilvlText:SetText("—")
                row.enchText:SetText("—")
                row.gemText:SetText(audit.reason or "—")
                row.gemText:SetTextColor(COL_DIM[1], COL_DIM[2], COL_DIM[3])
            else
                row.ilvlText:SetText(string.format("%.0f", audit.avgLevel or 0))
                if audit.missingEnchantCount == 0 then
                    row.enchText:SetText("OK")
                    row.enchText:SetTextColor(COL_GREEN[1], COL_GREEN[2], COL_GREEN[3])
                else
                    row.enchText:SetText(audit.missingEnchantCount .. " missing")
                    row.enchText:SetTextColor(COL_RED[1], COL_RED[2], COL_RED[3])
                end
                if audit.missingGemCount == 0 then
                    row.gemText:SetText("OK")
                    row.gemText:SetTextColor(COL_GREEN[1], COL_GREEN[2], COL_GREEN[3])
                else
                    row.gemText:SetText(audit.missingGemCount .. " missing")
                    row.gemText:SetTextColor(COL_RED[1], COL_RED[2], COL_RED[3])
                end
            end
            if GA.selectedUnit == unit then
                row:SetBackdropColor(COL_PANEL[1], COL_PANEL[2], COL_PANEL[3], 1)
                row.accentBar:Show()
            else
                row:SetBackdropColor(0, 0, 0, 0)
                row.accentBar:Hide()
            end
        end
    end
    scrollChild:SetHeight(math.max(1, #units * ROW_HEIGHT))
    scroll:SetVerticalScroll(0)
end

function GA.ShowDetail(unit)
    if not unit or not UnitExists or not UnitExists(unit) then return end
    GA.selectedUnit = unit
    local audit = GA.data[unit]
    local color = ClassColor(unit)
    detailTitle:SetText(GA.UnitDisplayName(unit))
    detailTitle:SetTextColor(color.r, color.g, color.b)
    if not audit then
        detailSummary:SetText("Not inspected yet. Press Re-inspect Player.")
        for _, entry in ipairs(detailSlots) do
            entry.icon:SetTexture(nil)
            entry.iconFrame:SetBackdropBorderColor(COL_BORDER[1], COL_BORDER[2], COL_BORDER[3], 1)
            entry.itemBtn.text:SetText("—")
            entry.itemBtn.text:SetTextColor(COL_DIM[1], COL_DIM[2], COL_DIM[3])
            entry.itemBtn.link = nil
            entry.flags:SetText("")
        end
    elseif audit.notInspectable then
        detailSummary:SetText(audit.reason or "Could not inspect this player.")
        for _, entry in ipairs(detailSlots) do
            entry.icon:SetTexture(nil)
            entry.iconFrame:SetBackdropBorderColor(COL_BORDER[1], COL_BORDER[2], COL_BORDER[3], 1)
            entry.itemBtn.text:SetText("—")
            entry.itemBtn.text:SetTextColor(COL_DIM[1], COL_DIM[2], COL_DIM[3])
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
                entry.icon:SetTexture(nil)
                entry.iconFrame:SetBackdropBorderColor(COL_BORDER[1], COL_BORDER[2], COL_BORDER[3], 1)
                entry.itemBtn.text:SetText("(empty)")
                entry.itemBtn.text:SetTextColor(COL_DIM[1], COL_DIM[2], COL_DIM[3])
                entry.itemBtn.link = nil
                entry.flags:SetText("")
            else
                local r, g, b = GA.GetItemQualityColor(slotAudit.quality)
                if slotAudit.icon then
                    entry.icon:SetTexture(slotAudit.icon)
                else
                    entry.icon:SetTexture(nil)
                end
                entry.iconFrame:SetBackdropBorderColor(r, g, b, 1)
                entry.itemBtn.text:SetText(string.format("%d  %s", slotAudit.itemLevel or 0, ItemNameFromLink(slotAudit.link)))
                entry.itemBtn.text:SetTextColor(r, g, b)
                entry.itemBtn.link = slotAudit.link
                local parts = {}
                if GA.ENCHANTABLE_SLOTS[entry.slot.id] then
                    if slotAudit.enchantMissing then
                        parts[#parts + 1] = "|cffff5959No enchant|r"
                    else
                        parts[#parts + 1] = "|cff59d98cEnchant|r"
                    end
                end
                if slotAudit.sockets and slotAudit.sockets > 0 then
                    if slotAudit.gemsMissing > 0 then
                        parts[#parts + 1] = "|cffff5959" .. slotAudit.gemsMissing .. " gem(s) missing|r"
                    else
                        parts[#parts + 1] = "|cff59d98cGems OK|r"
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
