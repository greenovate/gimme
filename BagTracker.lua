----------------------------------------------------------------------
-- Gimme - Bag Tracker & Alert System
----------------------------------------------------------------------
local addonName, ns = ...
local G = Gimme

local scanTimer = nil
local SCAN_INTERVAL = 5 -- seconds between scans while not at vendor

function G:StartBagTracker()
    self:RegisterEvent("BAG_UPDATE", "OnBagUpdate")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnBagUpdate")
    self:RegisterEvent("PLAYER_MONEY", "OnMoneyChange")
    -- Initial scan after a short delay
    C_Timer.After(2, function() self:ScanBags() end)
end

function G:OnBagUpdate()
    -- Debounce: don't scan every single bag update in rapid succession
    if scanTimer then return end
    scanTimer = C_Timer.NewTimer(0.5, function()
        scanTimer = nil
        G:ScanBags()
    end)
end

function G:OnMoneyChange()
    -- Re-evaluate if we crossed the gold threshold
    self:ScanBags()
end

-- Returns { [itemName] = count } for all tracked reagents
function G:GetBagReagentCounts()
    local counts = {}
    local tracked = self.db.profile.reagents

    -- Init all tracked items to 0
    for itemName, _ in pairs(tracked) do
        counts[itemName] = 0
    end

    -- Scan all bags
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.hyperlink then
                local name = GetItemInfo(info.hyperlink)
                if name and tracked[name] then
                    counts[name] = (counts[name] or 0) + (info.stackCount or 0)
                end
            end
        end
    end

    return counts
end

-- Count a specific item across bags
function G:CountItemInBags(itemName)
    local count = 0
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.hyperlink then
                local name = GetItemInfo(info.hyperlink)
                if name and name == itemName then
                    count = count + (info.stackCount or 0)
                end
            end
        end
    end
    return count
end

function G:ScanBags()
    local tracked = self.db.profile.reagents
    if not tracked or not next(tracked) then return end

    local counts = self:GetBagReagentCounts()
    local threshold = self.db.profile.alertThreshold
    local hasEnoughGold = self:HasEnoughGold()
    local alerts = {}

    for itemName, data in pairs(tracked) do
        local desired = data.desired or 0
        if desired > 0 then
            local have = counts[itemName] or 0
            local triggerAt = math.floor(desired * threshold)
            if have <= triggerAt then
                table.insert(alerts, {
                    itemName = itemName,
                    have = have,
                    desired = desired,
                    deficit = desired - have,
                })
            end
        end
    end

    -- Rogue smart logic: if low on poisons but has mats, don't alert
    if G.playerClass == "ROGUE" and #alerts > 0 then
        local hasMats = false
        if ns.RoguePoisonMats then
            for _, matName in ipairs(ns.RoguePoisonMats) do
                local matCount = self:CountItemInBags(matName)
                if matCount > 0 then
                    hasMats = true
                    break
                end
            end
        end
        -- Filter: only keep Flash Powder alerts if they have mats for poisons
        -- (Flash Powder is bought, not crafted — always alert on it)
        if hasMats then
            local filtered = {}
            for _, a in ipairs(alerts) do
                if a.itemName == "Flash Powder" then
                    table.insert(filtered, a)
                end
            end
            alerts = filtered
        end
    end

    if #alerts > 0 and hasEnoughGold then
        self:FireAlerts(alerts)
    end

    -- Store last scan for config UI
    self.lastScan = counts
    self.lastAlerts = alerts
end

function G:ForceScan()
    self:ScanBags()
    local counts = self.lastScan or {}
    local tracked = self.db.profile.reagents

    self:Msg("--- Reagent Inventory ---")
    for itemName, data in pairs(tracked) do
        local desired = data.desired or 0
        if desired > 0 then
            local have = counts[itemName] or 0
            local color = have >= desired and ns.GREEN_COLOR or ns.ALERT_COLOR
            self:Msg(string.format("  %s: %s%d|r / %d", itemName, color, have, desired))
        end
    end
    self:Msg(string.format("Gold: %s (min: %s%dg|r)",
        self:FormatMoney(GetMoney()),
        self:HasEnoughGold() and ns.GREEN_COLOR or ns.ALERT_COLOR,
        self.db.profile.minimumGold))
end

local lastAlertTime = 0

function G:FireAlerts(alerts)
    local now = GetTime()
    local cooldown = (self.db.profile.alertCooldown or 5) * 60
    if now - lastAlertTime < cooldown then return end
    lastAlertTime = now

    local lines = {}
    for _, a in ipairs(alerts) do
        table.insert(lines, string.format("%s: %d/%d (need %d)", a.itemName, a.have, a.desired, a.deficit))
    end

    local msg = "Low reagents! " .. table.concat(lines, ", ")
    self:AlertMsg(msg)
end
