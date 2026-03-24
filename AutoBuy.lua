----------------------------------------------------------------------
-- Gimme - Auto-Purchase System
----------------------------------------------------------------------
local addonName, ns = ...
local G = Gimme

local buyFrame = nil
local merchantOpen = false
local gimmeVendorBtn = nil

function G:StartAutoBuy()
    self:RegisterEvent("MERCHANT_SHOW", "OnMerchantShow")
    self:RegisterEvent("MERCHANT_CLOSED", "OnMerchantClosed")
end

function G:OnMerchantShow()
    local ok, err = pcall(function() G:DoMerchantShow() end)
    if not ok then
        G:Msg("|cffff0000AutoBuy error: " .. tostring(err) .. "|r")
    end
end

function G:DoMerchantShow()
    merchantOpen = true

    -- Show Gimme button on merchant frame
    self:ShowMerchantGimmeButton()

    if not self:HasEnoughGold() then
        return
    end

    local tracked = self.db.profile.reagents
    if not tracked or not next(tracked) then
        return
    end

    local shoppingList = self:BuildShoppingList()
    if not shoppingList or #shoppingList == 0 then

        return
    end

    if self.db.profile.autoBuy then
        self:ExecutePurchases(shoppingList)
    else
        self:ShowBuyButton(shoppingList)
    end
end

function G:OnMerchantClosed()
    merchantOpen = false
    if buyFrame then
        buyFrame:Hide()
    end
    if gimmeVendorBtn then
        gimmeVendorBtn:Hide()
    end
end

-- Build list of what we need to buy
function G:BuildShoppingList()
    local tracked = self.db.profile.reagents
    if not tracked then return {} end

    local counts = self:GetBagReagentCounts()
    local shopping = {}

    -- Get all merchant items
    local merchantItems = {}
    local numMerchant = GetMerchantNumItems()
    for i = 1, numMerchant do
        local name, texture, price, quantity, numAvailable, isPurchasable, isUsable, extendedCost = GetMerchantItemInfo(i)
        if name then
            merchantItems[name] = { index = i, price = price or 0, stackSize = quantity or 1 }
        end
    end

    for itemName, data in pairs(tracked) do
        local desired = data.desired or 0
        if desired > 0 then
            local have = counts[itemName] or 0
            local need = desired - have
            if need > 0 and merchantItems[itemName] then
                local mi = merchantItems[itemName]
                local perItem = mi.price / mi.stackSize
                local totalCost = math.floor(need * perItem)
                local goldAfter = math.floor((GetMoney() - totalCost) / 10000)
                if goldAfter >= self.db.profile.minimumGold then
                    table.insert(shopping, {
                        itemName = itemName,
                        merchantIndex = mi.index,
                        need = need,
                        stackSize = mi.stackSize,
                        totalCost = totalCost,
                    })
                end
            end
        end
    end

    return shopping
end

function G:ExecutePurchases(shoppingList)
    -- BuyMerchantItem(index, qty) — qty = number of ITEMS to buy
    -- API has a per-call limit, so we chunk into small batches
    local MAX_PER_CALL = 10
    local queue = {}
    for _, item in ipairs(shoppingList) do
        local remaining = item.need
        while remaining > 0 do
            local buyQty = math.min(remaining, MAX_PER_CALL)
            table.insert(queue, {
                merchantIndex = item.merchantIndex,
                quantity = buyQty,
                itemName = item.itemName,
            })
            remaining = remaining - buyQty
        end
    end

    if #queue == 0 then return end

    -- Process one buy at a time with a delay between each
    local BUY_DELAY = 0.3 -- seconds between each purchase
    local current = 0
    local bought = {} -- [itemName] = totalBought

    local function ProcessNext()
        current = current + 1
        if current > #queue then
            -- Done — print summary
            for itemName, count in pairs(bought) do
                G:Msg(string.format("Purchased %s%s|r x%d", ns.GREEN_COLOR, itemName, count))
            end
            return
        end

        -- Check merchant is still open
        if not merchantOpen then
            G:Msg("Merchant closed — stopped purchasing.")
            return
        end

        local op = queue[current]

        -- Gold check
        if not G:HasEnoughGold() then
            G:Msg("Stopped — would drop below minimum gold.")
            return
        end

        BuyMerchantItem(op.merchantIndex, op.quantity)
        bought[op.itemName] = (bought[op.itemName] or 0) + op.quantity

        -- Schedule next purchase
        C_Timer.After(BUY_DELAY, ProcessNext)
    end

    G:Msg("Purchasing items...")
    ProcessNext()
end

function G:ForceBuyCheck()
    if not merchantOpen then
        self:Msg("You need to be at a merchant to buy reagents.")
        return
    end
    local shoppingList = self:BuildShoppingList()
    if not shoppingList or #shoppingList == 0 then
        self:Msg("Nothing to buy — you're fully stocked!")
        return
    end
    self:ExecutePurchases(shoppingList)
end

-- Show a buy button at the merchant instead of auto-purchasing
function G:ShowBuyButton(shoppingList)
    if not buyFrame then
        buyFrame = CreateFrame("Frame", "GimmeBuyFrame", UIParent, "BackdropTemplate")
        buyFrame:SetSize(280, 120)
        buyFrame:SetPoint("TOP", UIParent, "TOP", 0, -100)
        buyFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        buyFrame:SetBackdropColor(0, 0, 0, 0.9)
        buyFrame:SetMovable(true)
        buyFrame:EnableMouse(true)
        buyFrame:RegisterForDrag("LeftButton")
        buyFrame:SetScript("OnDragStart", buyFrame.StartMoving)
        buyFrame:SetScript("OnDragStop", buyFrame.StopMovingOrSizing)
        buyFrame:SetFrameStrata("DIALOG")

        local title = buyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -10)
        title:SetText(ns.ADDON_COLOR .. "Gimme|r")
        buyFrame.title = title

        local text = buyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("TOP", title, "BOTTOM", 0, -4)
        text:SetWidth(260)
        text:SetJustifyH("CENTER")
        buyFrame.text = text

        local btn = CreateFrame("Button", nil, buyFrame, "UIPanelButtonTemplate")
        btn:SetSize(120, 28)
        btn:SetPoint("BOTTOM", 0, 12)
        btn:SetText("Buy All")
        btn:SetScript("OnClick", function()
            local list = G:BuildShoppingList()
            if list and #list > 0 then
                G:ExecutePurchases(list)
            end
            buyFrame:Hide()
        end)
        buyFrame.buyBtn = btn

        local closeBtn = CreateFrame("Button", nil, buyFrame, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -2, -2)
    end

    -- Populate text
    local lines = {}
    local totalCost = 0
    for _, item in ipairs(shoppingList) do
        table.insert(lines, string.format("%s x%d", item.itemName, item.need))
        totalCost = totalCost + item.totalCost
    end

    buyFrame.text:SetText(table.concat(lines, "\n") .. "\n\nTotal: " .. G:FormatMoney(math.floor(totalCost)))

    -- Resize to fit
    local textHeight = buyFrame.text:GetStringHeight()
    buyFrame:SetHeight(textHeight + 80)

    buyFrame:Show()
end

-- ===== Gimme button on merchant frame =====
function G:ShowMerchantGimmeButton()
    if not gimmeVendorBtn then
        gimmeVendorBtn = CreateFrame("Button", "GimmeMerchantBtn", MerchantFrame)
        gimmeVendorBtn:SetSize(60, 18)
        gimmeVendorBtn:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT", 62, -4)

        local bg = gimmeVendorBtn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.5)
        gimmeVendorBtn.bg = bg

        local label = gimmeVendorBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("CENTER")
        label:SetText("|cff00ccffGimme|r")
        gimmeVendorBtn.label = label

        gimmeVendorBtn:SetScript("OnClick", function()
            G:OpenConfig()
        end)
        gimmeVendorBtn:SetScript("OnEnter", function(self)
            self.bg:SetColorTexture(0, 0.3, 0.5, 0.7)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("|cff00ccffGimme|r", 1, 1, 1)
            GameTooltip:AddLine("Open Gimme settings to manage tracked items.", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        gimmeVendorBtn:SetScript("OnLeave", function(self)
            self.bg:SetColorTexture(0, 0, 0, 0.5)
            GameTooltip:Hide()
        end)
    end
    gimmeVendorBtn:Show()
end

-- ===== Alt+Click unified popup: Track or Buy =====
local gimmePopup = nil

local function ShowGimmePopup(itemName, merchantIndex, price, vendorStackSize)
    if not itemName or itemName == "" then return end

    local isMerchant = merchantIndex ~= nil

    if not gimmePopup then
        gimmePopup = CreateFrame("Frame", "GimmePopupFrame", UIParent, "BackdropTemplate")
        gimmePopup:SetSize(280, 130)
        gimmePopup:SetPoint("CENTER")
        gimmePopup:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        gimmePopup:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
        gimmePopup:SetBackdropBorderColor(0, 0.8, 1, 0.6)
        gimmePopup:SetFrameStrata("DIALOG")
        gimmePopup:SetMovable(true)
        gimmePopup:EnableMouse(true)
        gimmePopup:RegisterForDrag("LeftButton")
        gimmePopup:SetScript("OnDragStart", gimmePopup.StartMoving)
        gimmePopup:SetScript("OnDragStop", gimmePopup.StopMovingOrSizing)

        local topBar = gimmePopup:CreateTexture(nil, "BACKGROUND")
        topBar:SetColorTexture(0, 0.8, 1, 0.6)
        topBar:SetSize(278, 2)
        topBar:SetPoint("TOP", 0, -1)

        local title = gimmePopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -10)
        title:SetText("|cff00ccffGimme|r")
        gimmePopup.title = title

        local nameLabel = gimmePopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameLabel:SetPoint("TOP", title, "BOTTOM", 0, -4)
        nameLabel:SetTextColor(1, 1, 1)
        gimmePopup.nameLabel = nameLabel

        local costLabel = gimmePopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        costLabel:SetPoint("TOP", nameLabel, "BOTTOM", 0, -2)
        costLabel:SetTextColor(0.7, 0.7, 0.7)
        gimmePopup.costLabel = costLabel

        -- Tip bar at the bottom
        local tipBar = CreateFrame("Frame", nil, gimmePopup, "BackdropTemplate")
        tipBar:SetHeight(20)
        tipBar:SetPoint("BOTTOMLEFT", 1, 1)
        tipBar:SetPoint("BOTTOMRIGHT", -1, 1)
        tipBar:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
        })
        tipBar:SetBackdropColor(0, 0, 0, 0.4)
        gimmePopup.tipBar = tipBar

        local tipText = tipBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tipText:SetPoint("CENTER")
        tipText:SetTextColor(0.7, 0.7, 0.7)
        gimmePopup.tipText = tipText

        -- Qty label
        local qtyLabel = gimmePopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        qtyLabel:SetPoint("BOTTOMLEFT", 16, 26)
        qtyLabel:SetText("Qty:")
        qtyLabel:SetTextColor(0.7, 0.7, 0.7)

        -- Qty input
        local qtyBg = CreateFrame("Frame", nil, gimmePopup, "BackdropTemplate")
        qtyBg:SetSize(60, 24)
        qtyBg:SetPoint("LEFT", qtyLabel, "RIGHT", 6, 0)
        qtyBg:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        qtyBg:SetBackdropColor(0.05, 0.05, 0.07, 0.9)
        qtyBg:SetBackdropBorderColor(0.25, 0.25, 0.3, 0.8)

        local qtyEdit = CreateFrame("EditBox", nil, qtyBg)
        qtyEdit:SetAllPoints()
        qtyEdit:SetFontObject("GameFontNormalSmall")
        qtyEdit:SetAutoFocus(false)
        qtyEdit:SetNumeric(true)
        qtyEdit:SetMaxLetters(5)
        qtyEdit:SetJustifyH("CENTER")
        qtyEdit:SetTextColor(1, 0.84, 0)
        gimmePopup.qtyEdit = qtyEdit

        -- Track button
        local trackBtn = CreateFrame("Button", nil, gimmePopup, "UIPanelButtonTemplate")
        trackBtn:SetSize(60, 24)
        trackBtn:SetPoint("LEFT", qtyBg, "RIGHT", 6, 0)
        trackBtn:SetText("Track")
        gimmePopup.trackBtn = trackBtn

        -- Buy button (merchant only, will be shown/hidden)
        local buyBtn = CreateFrame("Button", nil, gimmePopup, "UIPanelButtonTemplate")
        buyBtn:SetSize(50, 24)
        buyBtn:SetPoint("LEFT", trackBtn, "RIGHT", 4, 0)
        buyBtn:SetText("Buy")
        gimmePopup.buyBtn = buyBtn

        -- Untrack button (shown only for tracked items, after Buy)
        local untrackBtn = CreateFrame("Button", nil, gimmePopup, "UIPanelButtonTemplate")
        untrackBtn:SetSize(70, 24)
        untrackBtn:SetPoint("LEFT", buyBtn, "RIGHT", 4, 0)
        untrackBtn:SetText("Untrack")
        gimmePopup.untrackBtn = untrackBtn

        -- Cancel
        local cancelBtn = CreateFrame("Button", nil, gimmePopup, "UIPanelButtonTemplate")
        cancelBtn:SetSize(24, 24)
        cancelBtn:SetPoint("TOPRIGHT", -4, -4)
        cancelBtn:SetText("X")
        cancelBtn:SetScript("OnClick", function() gimmePopup:Hide() end)

        qtyEdit:SetScript("OnEscapePressed", function() gimmePopup:Hide() end)

        -- Live cost update + tip
        qtyEdit:SetScript("OnTextChanged", function(self, userInput)
            if not userInput then return end
            local stackSz = gimmePopup.vendorStackSize or 1
            local qty = tonumber(self:GetText()) or 0
            -- Update cost (per-item pricing)
            if gimmePopup.itemPrice and gimmePopup.itemPrice > 0 and qty > 0 then
                local perItem = gimmePopup.itemPrice / stackSz
                gimmePopup.costLabel:SetText("Cost: " .. G:FormatMoney(math.floor(qty * perItem)))
            else
                gimmePopup.costLabel:SetText("")
            end
            -- Update tip
            if stackSz > 1 then
                gimmePopup.tipText:SetText("Vendor sells in stacks of " .. stackSz)
            else
                gimmePopup.tipText:SetText("Alt+Click items to track or buy")
            end
        end)
    end

    -- Configure for this item
    gimmePopup.nameLabel:SetText(itemName)
    gimmePopup.itemPrice = price or 0
    gimmePopup.vendorStackSize = vendorStackSize or 1

    -- Check if already tracked
    local existingData = G.db.profile.reagents[itemName]
    local isTracked = existingData ~= nil
    local defaultQty = isTracked and (existingData.desired or 40) or 40

    gimmePopup.qtyEdit:SetText(tostring(defaultQty))
    gimmePopup.qtyEdit:SetFocus()

    -- Track/Update button label
    gimmePopup.trackBtn:SetText(isTracked and "Update" or "Track")

    -- Untrack button
    if isTracked then
        gimmePopup.untrackBtn:Show()
        gimmePopup.untrackBtn:SetScript("OnClick", function()
            G:RemoveTrackedItem(itemName)
            G:Msg("Stopped tracking: |cffff4444" .. itemName .. "|r")
            gimmePopup:Hide()
        end)
    else
        gimmePopup.untrackBtn:Hide()
    end

    -- Tip bar
    local stackSz = vendorStackSize or 1
    if isMerchant and stackSz > 1 then
        gimmePopup.tipText:SetText("Vendor sells in stacks of " .. stackSz)
        gimmePopup.tipBar:Show()
        gimmePopup:SetHeight(145)
    elseif isTracked then
        local have = G:CountItemInBags(itemName)
        gimmePopup.tipText:SetText("In bags: " .. have .. " / " .. defaultQty)
        gimmePopup.tipBar:Show()
        gimmePopup:SetHeight(145)
    else
        gimmePopup.tipText:SetText("Alt+Click items to track or buy")
        gimmePopup.tipBar:Show()
        gimmePopup:SetHeight(145)
    end

    -- Cost label (per-item pricing)
    if isMerchant and price and price > 0 then
        local perItem = price / (vendorStackSize or 1)
        gimmePopup.costLabel:SetText("Cost: " .. G:FormatMoney(math.floor(defaultQty * perItem)))
        gimmePopup.costLabel:Show()
    else
        gimmePopup.costLabel:SetText("")
        gimmePopup.costLabel:Hide()
    end

    -- Track button
    gimmePopup.trackBtn:SetScript("OnClick", function()
        local qty = tonumber(gimmePopup.qtyEdit:GetText()) or 40
        G:AddTrackedItem(itemName, qty, gimmePopup.vendorStackSize)
        if isTracked then
            G:Msg("Updated: |cff00ff00" .. itemName .. "|r x" .. qty)
        else
            G:Msg("Now tracking: |cff00ff00" .. itemName .. "|r x" .. qty)
        end
        gimmePopup:Hide()
    end)

    -- Buy button (merchant only, will be shown/hidden)
    if isMerchant then
        gimmePopup.buyBtn:Show()
        -- Anchor Untrack after Buy
        if isTracked then
            gimmePopup.untrackBtn:ClearAllPoints()
            gimmePopup.untrackBtn:SetPoint("LEFT", gimmePopup.buyBtn, "RIGHT", 4, 0)
        end
        gimmePopup.buyBtn:SetScript("OnClick", function()
            local qty = tonumber(gimmePopup.qtyEdit:GetText()) or 0
            if qty <= 0 then return end
            gimmePopup:Hide()

            -- BuyMerchantItem has a per-call limit, chunk into small batches
            local remaining = qty
            local queue = {}
            while remaining > 0 do
                local batch = math.min(remaining, 10)
                table.insert(queue, batch)
                remaining = remaining - batch
            end

            local current = 0
            local totalBought = 0
            local function ProcessNext()
                current = current + 1
                if current > #queue then
                    G:Msg(string.format("Purchased %s%s|r x%d", ns.GREEN_COLOR, itemName, qty))
                    return
                end
                if not merchantOpen then
                    G:Msg("Merchant closed.")
                    return
                end
                BuyMerchantItem(merchantIndex, queue[current])
                totalBought = totalBought + queue[current]
                C_Timer.After(0.3, ProcessNext)
            end

            G:Msg("Buying " .. itemName .. " x" .. qty .. "...")
            ProcessNext()
        end)

        -- Enter defaults to Buy at merchant
        gimmePopup.qtyEdit:SetScript("OnEnterPressed", function()
            gimmePopup.buyBtn:Click()
        end)
    else
        gimmePopup.buyBtn:Hide()
        -- Anchor Untrack after Track when Buy is hidden
        if isTracked then
            gimmePopup.untrackBtn:ClearAllPoints()
            gimmePopup.untrackBtn:SetPoint("LEFT", gimmePopup.trackBtn, "RIGHT", 4, 0)
        end

        -- Enter defaults to Track from bags
        gimmePopup.qtyEdit:SetScript("OnEnterPressed", function()
            gimmePopup.trackBtn:Click()
        end)
    end

    gimmePopup:Show()
end

-- Alt+Click on bag items
hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function(self, button)
    if IsAltKeyDown() and button == "LeftButton" then
        local bag = self:GetParent():GetID()
        local slot = self:GetID()
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info and info.hyperlink then
            local name = GetItemInfo(info.hyperlink)
            if name then
                ShowGimmePopup(name, nil, nil)
            end
        end
    end
end)

-- Alt+Click on merchant items
hooksecurefunc("MerchantItemButton_OnModifiedClick", function(self, button)
    if IsAltKeyDown() and button == "LeftButton" then
        local index = self:GetID()
        local name, _, price, quantity = GetMerchantItemInfo(index)
        if name then
            ShowGimmePopup(name, index, price, quantity or 1)
        end
    end
end)

-- ===== Tooltip hints =====
hooksecurefunc(GameTooltip, "SetMerchantItem", function(tip, index)
    local name = GetMerchantItemInfo(index)
    if name then
        local data = G.db.profile.reagents[name]
        if data then
            local have = G:CountItemInBags(name)
            local desired = data.desired or 0
            local color = have >= desired and "|cff00ff00" or "|cffff4444"
            tip:AddLine(" ")
            tip:AddLine("|cff00ccffGimme:|r Tracking " .. color .. have .. "|r / " .. desired, 0.5, 0.8, 1)
            tip:AddLine("|cff00ccffGimme:|r Alt+Click to modify or untrack", 0.5, 0.8, 1)
        else
            tip:AddLine(" ")
            tip:AddLine("|cff00ccffGimme:|r Alt+Click to track or buy", 0.5, 0.8, 1)
        end
    end
    tip:Show()
end)

hooksecurefunc(GameTooltip, "SetBagItem", function(tip, bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if info and info.hyperlink then
        local name = GetItemInfo(info.hyperlink)
        if name then
            local data = G.db.profile.reagents[name]
            if data then
                local have = G:CountItemInBags(name)
                local desired = data.desired or 0
                local color = have >= desired and "|cff00ff00" or "|cffff4444"
                tip:AddLine(" ")
                tip:AddLine("|cff00ccffGimme:|r Tracking " .. color .. have .. "|r / " .. desired, 0.5, 0.8, 1)
                tip:AddLine("|cff00ccffGimme:|r Alt+Click to modify or untrack", 0.5, 0.8, 1)
            else
                tip:AddLine(" ")
                tip:AddLine("|cff00ccffGimme:|r Alt+Click to track", 0.5, 0.8, 1)
            end
        end
    end
    tip:Show()
end)
