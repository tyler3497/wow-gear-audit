-- GearAudit: Core.lua
-- Group roster, inspect queue, and cached audit results.
-- Inspecting is throttled by the game, so players are inspected
-- one at a time and only when you press Refresh (or open the
-- window). Nothing inspects in the background on its own.
local _, GA = ...

GA.data = {}          -- unit -> audit summary (see Audit.lua)
GA.inspectQueue = {}  -- units waiting to be inspected
GA.inspecting = nil   -- unit currently being inspected
GA.inspectDeadline = 0

local function GetGroupUnits()
    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            units[#units + 1] = "raid" .. i
        end
    elseif IsInGroup() then
        units[#units + 1] = "player"
        for i = 1, GetNumGroupMembers() - 1 do
            units[#units + 1] = "party" .. i
        end
    else
        units[#units + 1] = "player"
    end
    return units
end
GA.GetGroupUnits = GetGroupUnits

local function UnitDisplayName(unit)
    local name, realm = UnitName(unit)
    if not name then return unit end
    if realm and realm ~= "" and realm ~= GetRealmName() then
        return name .. "-" .. realm
    end
    return name
end
GA.UnitDisplayName = UnitDisplayName

-- Inspect the next unit in the queue, or finish the queue.
local function InspectNext()
    GA.inspecting = nil
    local unit = table.remove(GA.inspectQueue, 1)
    if not unit then
        GA.OnInspectFinished()
        return
    end
    if not UnitExists(unit) or not UnitIsPlayer(unit) then
        InspectNext()
        return
    end
    if unit == "player" then
        -- Your own gear needs no inspect round-trip.
        GA.data[unit] = GA.AuditUnit(unit)
        GA.OnUnitAudited(unit)
        InspectNext()
        return
    end
    if CanInspect and not CanInspect(unit) then
        GA.data[unit] = { notInspectable = true, reason = "Out of range" }
        GA.OnUnitAudited(unit)
        InspectNext()
        return
    end
    GA.inspecting = unit
    GA.inspectDeadline = GetTime() + 5
    NotifyInspect(unit)
    -- INSPECT_READY (or the timeout in the OnUpdate handler)
    -- advances the queue.
end
GA.InspectNext = InspectNext

function GA.RefreshAll()
    GA.inspectQueue = {}
    GA.inspecting = nil
    local units = GetGroupUnits()
    for _, unit in ipairs(units) do
        if UnitExists(unit) and UnitIsPlayer(unit) then
            GA.inspectQueue[#GA.inspectQueue + 1] = unit
        end
    end
    GA.OnRefreshStarted(#GA.inspectQueue)
    InspectNext()
end

function GA.RefreshUnit(unit)
    if not UnitExists(unit) then return end
    GA.inspectQueue = { unit }
    GA.inspecting = nil
    InspectNext()
end

-- Event frame: roster changes, inspect results, inspect timeout.
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("INSPECT_READY")

events:SetScript("OnEvent", function(_, event, guid)
    if event == "INSPECT_READY" then
        if GA.inspecting and UnitGUID(GA.inspecting) == guid then
            GA.data[GA.inspecting] = GA.AuditUnit(GA.inspecting)
            GA.OnUnitAudited(GA.inspecting)
            ClearInspectPlayer()
            InspectNext()
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        -- Roster changed: keep cached data for units still in
        -- the group, drop the rest, and redraw the list.
        local stillHere = {}
        for _, unit in ipairs(GetGroupUnits()) do
            stillHere[UnitGUID(unit) or unit] = true
        end
        for unit, _ in pairs(GA.data) do
            if UnitExists(unit) and not stillHere[UnitGUID(unit) or unit] then
                GA.data[unit] = nil
            end
        end
        GA.OnRosterChanged()
    end
end)

events:SetScript("OnUpdate", function()
    if GA.inspecting and GetTime() > GA.inspectDeadline then
        -- Inspect timed out (target moved out of range, left,
        -- or the server never answered). Do not stall the queue.
        GA.data[GA.inspecting] = { notInspectable = true, reason = "Inspect timed out" }
        GA.OnUnitAudited(GA.inspecting)
        ClearInspectPlayer()
        InspectNext()
    end
end)

SLASH_GEARAUDIT1 = "/gearaudit"
SLASH_GEARAUDIT2 = "/ga"
SLASH_GEARAUDIT3 = "/gear"
SlashCmdList["GEARAUDIT"] = function(msg)
    msg = strtrim((msg or ""):lower())
    if msg == "refresh" then
        GA.ToggleWindow(true)
        GA.RefreshAll()
    elseif msg == "hide" then
        GA.ToggleWindow(false)
    else
        GA.ToggleWindow()
    end
end
