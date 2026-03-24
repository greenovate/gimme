----------------------------------------------------------------------
-- Gimme - Reagent Manager
-- Created by Evildz on Nightslayer
----------------------------------------------------------------------
local addonName, ns = ...

Gimme = LibStub("AceAddon-3.0"):NewAddon("Gimme", "AceEvent-3.0", "AceConsole-3.0")
local G = Gimme
ns.G = G

-- Addon color
local ADDON_COLOR = "|cff00ccff"
local ALERT_COLOR = "|cffff4444"
local GOLD_COLOR  = "|cffffd700"
local GREEN_COLOR = "|cff00ff00"

ns.ADDON_COLOR = ADDON_COLOR
ns.ALERT_COLOR = ALERT_COLOR
ns.GOLD_COLOR  = GOLD_COLOR
ns.GREEN_COLOR = GREEN_COLOR

local defaults = {
    profile = {
        minimumGold = 5, -- minimum gold on character before rules fire
        reagents = {},   -- [itemName] = { desired = count, vendorStack = size }
        alertThreshold = 0.5, -- alert when below 50% of desired
        alertCooldown = 5, -- minutes between alerts
        alertChat = true,
        alertSound = true,
        alertScreen = true,
        autoBuy = false, -- auto purchase vs button
    },
}

function G:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("GimmeDB", defaults, true)

    _, self.playerClass = UnitClass("player")
    self.playerClass = self.playerClass or "UNKNOWN"

    -- Migrate old format: reagents[name] = number → reagents[name] = { desired, vendorStack }
    for name, val in pairs(self.db.profile.reagents) do
        if type(val) == "number" then
            self.db.profile.reagents[name] = { desired = val, vendorStack = 1 }
        end
    end

    self:RegisterChatCommand("gimme", "SlashCommand")
    self:RegisterChatCommand("gim", "SlashCommand")

    -- Minimap icon
    self:SetupMinimapIcon()
end

function G:SetupMinimapIcon()
    local LDB = LibStub("LibDataBroker-1.1")
    local LDBIcon = LibStub("LibDBIcon-1.0")

    local dataBroker = LDB:NewDataObject("Gimme", {
        type = "launcher",
        icon = "Interface\\Icons\\INV_Misc_Bag_10",
        OnClick = function(_, button)
            if button == "LeftButton" then
                G:OpenConfig()
            elseif button == "RightButton" then
                G:ForceScan()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine(ADDON_COLOR .. "Gimme|r")
            tooltip:AddLine("Left-click: Open settings", 1, 1, 1)
            tooltip:AddLine("Right-click: Scan bags", 1, 1, 1)
        end,
    })

    if not self.db.profile.minimap then
        self.db.profile.minimap = { hide = false }
    end
    LDBIcon:Register("Gimme", dataBroker, self.db.profile.minimap)
end

function G:OnEnable()
    self:StartBagTracker()
    self:StartAutoBuy()

    self:Print(ADDON_COLOR .. "Gimme|r loaded. Type " .. GOLD_COLOR .. "/gimme|r to configure.")
end

function G:SlashCommand(input)
    input = (input or ""):trim():lower()
    if input == "config" or input == "" then
        self:OpenConfig()
    elseif input == "buy" then
        self:ForceBuyCheck()
    elseif input == "scan" then
        self:ForceScan()
    elseif input == "reset" then
        self.db:ResetProfile()
        self:Print("Profile reset to defaults.")
    else
        self:Print(ADDON_COLOR .. "Gimme|r commands:")
        self:Print("  /gimme - Open settings")
        self:Print("  /gimme scan - Force reagent scan")
        self:Print("  /gimme buy - Force buy check at vendor")
        self:Print("  /gimme reset - Reset settings")
    end
end

-- Add an item to the tracking list
function G:AddTrackedItem(itemName, qty, vendorStack)
    if not itemName or itemName == "" then return false end
    qty = tonumber(qty) or 20
    vendorStack = tonumber(vendorStack) or 1
    if vendorStack < 1 then vendorStack = 1 end
    self.db.profile.reagents[itemName] = { desired = qty, vendorStack = vendorStack }
    return true
end

-- Remove an item from the tracking list
function G:RemoveTrackedItem(itemName)
    self.db.profile.reagents[itemName] = nil
end

function G:Msg(text)
    print(ADDON_COLOR .. "Gimme|r: " .. text)
end

function G:AlertMsg(text)
    self:Msg(ALERT_COLOR .. text .. "|r")
    if self.db.profile.alertSound then
        PlaySound(8959) -- RAID_WARNING
    end
    if self.db.profile.alertScreen then
        UIErrorsFrame:AddMessage(ADDON_COLOR .. "Gimme|r: " .. text, 1.0, 0.3, 0.3, 1.0, 3)
    end
end

-- Copper to readable gold string
function G:FormatMoney(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop = copper % 100
    return string.format("%s%dg|r %ds %dc", GOLD_COLOR, gold, silver, cop)
end

function G:HasEnoughGold()
    local gold = math.floor(GetMoney() / 10000)
    return gold >= self.db.profile.minimumGold
end
