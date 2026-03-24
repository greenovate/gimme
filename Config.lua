----------------------------------------------------------------------
-- Gimme - Configuration UI
----------------------------------------------------------------------
local addonName, ns = ...
local G = Gimme

local configFrame = nil
local addItemEditBox = nil  -- reference for shift-click item insertion
local FRAME_WIDTH = 540
local FRAME_HEIGHT = 640

-- Color palette
local C = {
    bg        = { 0.06, 0.06, 0.08, 0.97 },
    accent    = { 0.00, 0.80, 1.00 },
    gold      = { 1.00, 0.84, 0.00 },
    text      = { 0.90, 0.90, 0.90 },
    textDim   = { 0.55, 0.55, 0.60 },
    rowEven   = { 0.12, 0.12, 0.16, 0.6 },
    rowOdd    = { 0.08, 0.08, 0.11, 0.4 },
    rowHover  = { 0.18, 0.25, 0.35, 0.7 },
    border    = { 0.25, 0.25, 0.30, 0.8 },
    inputBg   = { 0.05, 0.05, 0.07, 0.9 },
    btnNormal = { 0.15, 0.15, 0.20, 0.9 },
    btnHover  = { 0.00, 0.50, 0.70, 0.9 },
    btnDanger = { 0.60, 0.15, 0.15, 0.9 },
    btnDangerH= { 0.80, 0.20, 0.20, 0.9 },
    green     = { 0.20, 0.70, 0.20 },
    red       = { 1.00, 0.30, 0.30 },
    sliderTrack = { 0.20, 0.20, 0.25, 1.0 },
    sliderFill  = { 0.00, 0.50, 0.70, 0.8 },
}

local function MakePixel(parent, r, g, b, a)
    local t = parent:CreateTexture(nil, "BACKGROUND")
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

local function MakeSectionHeader(parent, text, yOffset)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(FRAME_WIDTH - 40, 24)
    container:SetPoint("TOP", parent, "TOP", 0, yOffset)

    local bar = MakePixel(container, C.accent[1], C.accent[2], C.accent[3], 1)
    bar:SetSize(3, 16)
    bar:SetPoint("LEFT", 0, 0)

    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", bar, "RIGHT", 8, 0)
    label:SetText(text)
    label:SetTextColor(C.accent[1], C.accent[2], C.accent[3])

    local line = MakePixel(container, C.border[1], C.border[2], C.border[3], 0.5)
    line:SetHeight(1)
    line:SetPoint("LEFT", label, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", container, "RIGHT", 0, 0)

    return container
end

local function MakeStyledCheckbox(parent, label, x, y, getValue, setValue)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(FRAME_WIDTH - 60, 22)
    row:SetPoint("TOPLEFT", x, y)

    local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    cb:SetPoint("LEFT", 0, 0)
    cb:SetSize(22, 22)
    cb:SetChecked(getValue())

    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    text:SetText(label)
    text:SetTextColor(C.text[1], C.text[2], C.text[3])

    cb:SetScript("OnClick", function(self)
        setValue(self:GetChecked())
        PlaySound(856)
    end)

    row:EnableMouse(true)
    row:SetScript("OnMouseDown", function()
        cb:SetChecked(not cb:GetChecked())
        setValue(cb:GetChecked())
        PlaySound(856)
    end)

    return row, cb
end

local function MakeStyledSlider(parent, label, x, y, minVal, maxVal, step, getValue, setValue, formatFn)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(FRAME_WIDTH - 60, 44)
    container:SetPoint("TOPLEFT", x, y)

    local nameText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("TOPLEFT", 0, 0)
    nameText:SetTextColor(C.text[1], C.text[2], C.text[3])

    local valueText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    valueText:SetPoint("TOPRIGHT", 0, 0)
    valueText:SetTextColor(C.gold[1], C.gold[2], C.gold[3])

    -- Track background (the line you slide on)
    local trackBg = CreateFrame("Frame", nil, container, "BackdropTemplate")
    trackBg:SetSize(FRAME_WIDTH - 80, 6)
    trackBg:SetPoint("TOPLEFT", 0, -22)
    trackBg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    trackBg:SetBackdropColor(C.sliderTrack[1], C.sliderTrack[2], C.sliderTrack[3], C.sliderTrack[4])
    trackBg:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.5)

    -- Fill bar showing current value
    local fillBar = trackBg:CreateTexture(nil, "ARTWORK")
    fillBar:SetPoint("TOPLEFT", 1, -1)
    fillBar:SetHeight(4)
    fillBar:SetColorTexture(C.sliderFill[1], C.sliderFill[2], C.sliderFill[3], C.sliderFill[4])

    local slider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
    slider:SetSize(FRAME_WIDTH - 80, 14)
    slider:SetPoint("TOPLEFT", 0, -18)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(getValue())
    slider.Low:SetText("")
    slider.High:SetText("")
    slider.Text:SetText("")

    local function UpdateDisplay(value)
        nameText:SetText(label)
        valueText:SetText(formatFn and formatFn(value) or tostring(value))
        -- Update fill bar width
        local pct = (value - minVal) / (maxVal - minVal)
        fillBar:SetWidth(math.max(1, pct * (FRAME_WIDTH - 82)))
    end
    UpdateDisplay(getValue())

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        setValue(value)
        UpdateDisplay(value)
    end)

    return container
end

-- ===== Small icon button =====
local function MakeIconButton(parent, text, width, height, color, hoverColor, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, height)

    local bg = MakePixel(btn, color[1], color[2], color[3], color[4] or 0.9)
    bg:SetAllPoints()
    btn.bg = bg
    btn.baseColor = color
    btn.hoverColor = hoverColor

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER")
    label:SetText(text)
    label:SetTextColor(1, 1, 1)
    btn.label = label

    btn:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(self.hoverColor[1], self.hoverColor[2], self.hoverColor[3], self.hoverColor[4] or 0.9)
    end)
    btn:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(self.baseColor[1], self.baseColor[2], self.baseColor[3], self.baseColor[4] or 0.9)
    end)
    btn:SetScript("OnClick", function()
        PlaySound(856)
        onClick()
    end)

    return btn
end

local function MakeStyledButton(parent, text, width, height, x, y, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, height)
    btn:SetPoint("TOPLEFT", x, y)

    local bg = MakePixel(btn, C.btnNormal[1], C.btnNormal[2], C.btnNormal[3], C.btnNormal[4])
    bg:SetAllPoints()
    btn.bg = bg

    local border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    border:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.6)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER")
    label:SetText(text)
    label:SetTextColor(C.text[1], C.text[2], C.text[3])

    btn:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(C.btnHover[1], C.btnHover[2], C.btnHover[3], C.btnHover[4])
        label:SetTextColor(1, 1, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(C.btnNormal[1], C.btnNormal[2], C.btnNormal[3], C.btnNormal[4])
        label:SetTextColor(C.text[1], C.text[2], C.text[3])
    end)
    btn:SetScript("OnClick", function()
        PlaySound(856)
        onClick()
    end)

    return btn
end

-- ===== Tracked Item Row =====
local function CreateTrackedItemRow(parent, itemName, data, yOffset, index)
    local rowWidth = FRAME_WIDTH - 60
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(rowWidth, 28)
    row:SetPoint("TOPLEFT", 12, yOffset)

    local qty = data.desired or 0
    local vendorStack = data.vendorStack or 1

    local bgColor = (index % 2 == 0) and C.rowEven or C.rowOdd
    local rowBg = MakePixel(row, bgColor[1], bgColor[2], bgColor[3], bgColor[4])
    rowBg:SetAllPoints()
    row.rowBg = rowBg

    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        self.rowBg:SetColorTexture(C.rowHover[1], C.rowHover[2], C.rowHover[3], C.rowHover[4])
    end)
    row:SetScript("OnLeave", function(self)
        self.rowBg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
    end)

    -- Item name
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("LEFT", 8, 0)
    nameText:SetWidth(200)
    nameText:SetJustifyH("LEFT")
    nameText:SetText(itemName)
    nameText:SetTextColor(1, 1, 1)

    -- Current count in bags
    local have = G:CountItemInBags(itemName)
    local countText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("LEFT", 215, 0)
    if have >= qty then
        countText:SetText("|cff00ff00" .. have .. "|r")
    elseif have > 0 then
        countText:SetText("|cffffff00" .. have .. "|r")
    else
        countText:SetText("|cffff4444" .. have .. "|r")
    end

    -- Minus button
    local minusBtn = MakeIconButton(row, "-", 22, 22,
        C.btnNormal, C.btnDanger,
        function()
            local d = G.db.profile.reagents[itemName]
            if d then
                d.desired = math.max(0, (d.desired or 0) - 5)
            end
            G:RefreshConfig()
        end)
    minusBtn:SetPoint("RIGHT", row, "RIGHT", -158, 0)

    -- Quantity display
    local qtyFrame = CreateFrame("Frame", nil, row, "BackdropTemplate")
    qtyFrame:SetSize(50, 22)
    qtyFrame:SetPoint("RIGHT", row, "RIGHT", -106, 0)
    qtyFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    qtyFrame:SetBackdropColor(C.inputBg[1], C.inputBg[2], C.inputBg[3], C.inputBg[4])
    qtyFrame:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.6)

    local qtyEdit = CreateFrame("EditBox", nil, qtyFrame)
    qtyEdit:SetAllPoints()
    qtyEdit:SetFontObject("GameFontNormalSmall")
    qtyEdit:SetAutoFocus(false)
    qtyEdit:SetNumeric(true)
    qtyEdit:SetMaxLetters(5)
    qtyEdit:SetJustifyH("CENTER")
    qtyEdit:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
    qtyEdit:SetText(tostring(qty))

    qtyEdit:SetScript("OnEnterPressed", function(self)
        local d = G.db.profile.reagents[itemName]
        if d then d.desired = tonumber(self:GetText()) or 0 end
        self:ClearFocus()
    end)
    qtyEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    qtyEdit:SetScript("OnEditFocusGained", function()
        qtyFrame:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
    end)
    qtyEdit:SetScript("OnEditFocusLost", function(self)
        local d = G.db.profile.reagents[itemName]
        if d then d.desired = tonumber(self:GetText()) or 0 end
        qtyFrame:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.6)
    end)

    -- Plus button
    local plusBtn = MakeIconButton(row, "+", 22, 22,
        C.btnNormal, { C.green[1], C.green[2], C.green[3], 0.9 },
        function()
            local d = G.db.profile.reagents[itemName]
            if d then d.desired = (d.desired or 0) + 5 end
            G:RefreshConfig()
        end)
    plusBtn:SetPoint("RIGHT", row, "RIGHT", -82, 0)

    -- Vendor stack label
    local stackLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    stackLabel:SetPoint("RIGHT", row, "RIGHT", -48, 0)
    if vendorStack > 1 then
        stackLabel:SetText("|cff888888x" .. vendorStack .. "|r")
    else
        stackLabel:SetText("|cff555560x1|r")
    end

    -- Remove button
    local removeBtn = MakeIconButton(row, "X", 22, 22,
        C.btnDanger, C.btnDangerH,
        function()
            G:RemoveTrackedItem(itemName)
            G:RefreshConfig()
        end)
    removeBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)

    return row
end

-- ===== Add Item Row =====
local function CreateAddItemRow(parent, yOffset)
    local rowWidth = FRAME_WIDTH - 60
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(rowWidth, 30)
    container:SetPoint("TOPLEFT", 12, yOffset)

    -- Input background
    local inputFrame = CreateFrame("Frame", nil, container, "BackdropTemplate")
    inputFrame:SetSize(220, 26)
    inputFrame:SetPoint("LEFT", 0, 0)
    inputFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 4, right = 4, top = 2, bottom = 2 },
    })
    inputFrame:SetBackdropColor(C.inputBg[1], C.inputBg[2], C.inputBg[3], C.inputBg[4])
    inputFrame:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.6)

    local nameEdit = CreateFrame("EditBox", nil, inputFrame)
    nameEdit:SetAllPoints()
    nameEdit:SetFontObject("GameFontNormalSmall")
    nameEdit:SetAutoFocus(false)
    nameEdit:SetMaxLetters(60)
    nameEdit:SetTextColor(C.text[1], C.text[2], C.text[3])
    nameEdit:SetTextInsets(4, 4, 0, 0)
    addItemEditBox = nameEdit  -- store reference for shift-click hook

    -- Placeholder
    local placeholder = inputFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    placeholder:SetPoint("LEFT", 6, 0)
    placeholder:SetText("|cff555560Type item name...|r")
    nameEdit:SetScript("OnEditFocusGained", function()
        placeholder:Hide()
        inputFrame:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
    end)
    nameEdit:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then placeholder:Show() end
        inputFrame:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.6)
    end)

    -- Qty input
    local qtyFrame = CreateFrame("Frame", nil, container, "BackdropTemplate")
    qtyFrame:SetSize(50, 26)
    qtyFrame:SetPoint("LEFT", inputFrame, "RIGHT", 6, 0)
    qtyFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    qtyFrame:SetBackdropColor(C.inputBg[1], C.inputBg[2], C.inputBg[3], C.inputBg[4])
    qtyFrame:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.6)

    local qtyEdit = CreateFrame("EditBox", nil, qtyFrame)
    qtyEdit:SetAllPoints()
    qtyEdit:SetFontObject("GameFontNormalSmall")
    qtyEdit:SetAutoFocus(false)
    qtyEdit:SetNumeric(true)
    qtyEdit:SetMaxLetters(5)
    qtyEdit:SetJustifyH("CENTER")
    qtyEdit:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
    qtyEdit:SetText("20")

    -- Stack size label
    local stackLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    stackLabel:SetPoint("LEFT", qtyFrame, "RIGHT", 8, 0)
    stackLabel:SetText("Stack:")
    stackLabel:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])

    -- Stack size input
    local stackFrame = CreateFrame("Frame", nil, container, "BackdropTemplate")
    stackFrame:SetSize(36, 26)
    stackFrame:SetPoint("LEFT", stackLabel, "RIGHT", 4, 0)
    stackFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    stackFrame:SetBackdropColor(C.inputBg[1], C.inputBg[2], C.inputBg[3], C.inputBg[4])
    stackFrame:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.6)

    local stackEdit = CreateFrame("EditBox", nil, stackFrame)
    stackEdit:SetAllPoints()
    stackEdit:SetFontObject("GameFontNormalSmall")
    stackEdit:SetAutoFocus(false)
    stackEdit:SetNumeric(true)
    stackEdit:SetMaxLetters(3)
    stackEdit:SetJustifyH("CENTER")
    stackEdit:SetTextColor(C.text[1], C.text[2], C.text[3])
    stackEdit:SetText("1")
    stackEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- Add button
    local addBtn = CreateFrame("Button", nil, container)
    addBtn:SetSize(60, 26)
    addBtn:SetPoint("LEFT", stackFrame, "RIGHT", 6, 0)

    local addBg = MakePixel(addBtn, C.btnNormal[1], C.btnNormal[2], C.btnNormal[3], C.btnNormal[4])
    addBg:SetAllPoints()
    addBtn.bg = addBg

    local addBorder = CreateFrame("Frame", nil, addBtn, "BackdropTemplate")
    addBorder:SetAllPoints()
    addBorder:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    addBorder:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.6)

    local addLabel = addBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    addLabel:SetPoint("CENTER")
    addLabel:SetText("Add")
    addLabel:SetTextColor(C.text[1], C.text[2], C.text[3])

    addBtn:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(C.btnHover[1], C.btnHover[2], C.btnHover[3], C.btnHover[4])
        addLabel:SetTextColor(1, 1, 1)
    end)
    addBtn:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(C.btnNormal[1], C.btnNormal[2], C.btnNormal[3], C.btnNormal[4])
        addLabel:SetTextColor(C.text[1], C.text[2], C.text[3])
    end)
    addBtn:SetScript("OnClick", function()
        PlaySound(856)
        local name = nameEdit:GetText():trim()
        local qty = tonumber(qtyEdit:GetText()) or 20
        local stack = tonumber(stackEdit:GetText()) or 1
        if stack < 1 then stack = 1 end
        if name ~= "" then
            G:AddTrackedItem(name, qty, stack)
            nameEdit:SetText("")
            nameEdit:ClearFocus()
            G:RefreshConfig()
            G:Msg("Now tracking: " .. name .. " x" .. qty)
        end
    end)

    -- Enter to add
    nameEdit:SetScript("OnEnterPressed", function(self)
        local name = self:GetText():trim()
        local qty = tonumber(qtyEdit:GetText()) or 20
        local stack = tonumber(stackEdit:GetText()) or 1
        if stack < 1 then stack = 1 end
        if name ~= "" then
            G:AddTrackedItem(name, qty, stack)
            self:SetText("")
            self:ClearFocus()
            G:RefreshConfig()
            G:Msg("Now tracking: " .. name .. " x" .. qty)
        end
    end)
    nameEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    return container
end

-- ===== Quick-Add Suggestions =====
local function CreateQuickAddRow(parent, itemName, defaultQty, yOffset, index)
    local rowWidth = FRAME_WIDTH - 60
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(rowWidth, 24)
    row:SetPoint("TOPLEFT", 12, yOffset)

    -- Already tracked?
    local isTracked = G.db.profile.reagents[itemName] ~= nil

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("LEFT", 8, 0)
    nameText:SetText(itemName)

    if isTracked then
        nameText:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
        local check = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        check:SetPoint("RIGHT", -8, 0)
        check:SetText("|cff00ff00Already tracking|r")
    else
        nameText:SetTextColor(C.text[1], C.text[2], C.text[3])
        local addBtn = MakeIconButton(row, "+ Add", 50, 20,
            C.btnNormal, { C.green[1], C.green[2], C.green[3], 0.9 },
            function()
                G:AddTrackedItem(itemName, defaultQty)
                G:RefreshConfig()
                G:Msg("Now tracking: " .. itemName .. " x" .. defaultQty)
            end)
        addBtn:SetPoint("RIGHT", -8, 0)
    end

    return row
end

-- ===== Main Config Window =====
function G:OpenConfig()
    if configFrame then
        if configFrame:IsShown() then
            configFrame:Hide()
        else
            configFrame:Show()
            self:RefreshConfig()
        end
        return
    end

    configFrame = CreateFrame("Frame", "GimmeConfigFrame", UIParent, "BackdropTemplate")
    configFrame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    configFrame:SetPoint("CENTER")
    configFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    configFrame:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], C.bg[4])
    configFrame:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 0.4)
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetScript("OnDragStart", configFrame.StartMoving)
    configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)
    configFrame:SetFrameStrata("HIGH")
    configFrame:SetClampedToScreen(true)
    tinsert(UISpecialFrames, "GimmeConfigFrame")

    -- Top accent
    local topLine = MakePixel(configFrame, C.accent[1], C.accent[2], C.accent[3], 0.8)
    topLine:SetSize(FRAME_WIDTH - 2, 2)
    topLine:SetPoint("TOP", 0, -1)

    -- Header bg
    local headerBg = MakePixel(configFrame, 0, 0, 0, 0.3)
    headerBg:SetSize(FRAME_WIDTH - 2, 48)
    headerBg:SetPoint("TOP", 0, -3)

    local title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("|cff00ccffGIMME|r")

    local subtitle = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)
    subtitle:SetText("|cff555560Reagent Manager  ·  by Evildz on Nightslayer|r")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, configFrame)
    closeBtn:SetSize(28, 28)
    closeBtn:SetPoint("TOPRIGHT", -6, -6)
    local closeBg = MakePixel(closeBtn, 0, 0, 0, 0)
    closeBg:SetAllPoints()
    closeBtn.bg = closeBg
    local closeX = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    closeX:SetPoint("CENTER")
    closeX:SetText("|cff888888X|r")
    closeBtn:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(C.red[1], C.red[2], C.red[3], 0.3)
        closeX:SetText("|cffff4444X|r")
    end)
    closeBtn:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0, 0, 0, 0)
        closeX:SetText("|cff888888X|r")
    end)
    closeBtn:SetScript("OnClick", function() configFrame:Hide() end)

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "GimmeConfigScroll", configFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -54)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(FRAME_WIDTH - 50, 1200)
    scrollFrame:SetScrollChild(content)
    configFrame.content = content

    self:BuildConfigContent(content)
    configFrame:Show()
end

function G:BuildConfigContent(parent)
    local y = -8

    -- ===== General Settings =====
    MakeSectionHeader(parent, "SETTINGS", y)
    y = y - 30

    MakeStyledSlider(parent, "Minimum Gold Reserve", 18, y, 0, 100, 1,
        function() return self.db.profile.minimumGold end,
        function(v) self.db.profile.minimumGold = v end,
        function(v) return "|cffffd700" .. v .. "g|r" end)
    y = y - 50

    MakeStyledSlider(parent, "Alert Threshold", 18, y, 10, 100, 5,
        function() return self.db.profile.alertThreshold * 100 end,
        function(v) self.db.profile.alertThreshold = v / 100 end,
        function(v) return "|cffffd700" .. v .. "%%|r" end)
    y = y - 50

    MakeStyledSlider(parent, "Alert Cooldown", 18, y, 1, 30, 1,
        function() return self.db.profile.alertCooldown or 5 end,
        function(v) self.db.profile.alertCooldown = v end,
        function(v) return "|cffffd700" .. v .. " min|r" end)
    y = y - 50

    MakeStyledCheckbox(parent, "Chat alerts", 18, y,
        function() return self.db.profile.alertChat end,
        function(v) self.db.profile.alertChat = v end)
    y = y - 24

    MakeStyledCheckbox(parent, "Sound alerts", 18, y,
        function() return self.db.profile.alertSound end,
        function(v) self.db.profile.alertSound = v end)
    y = y - 24

    MakeStyledCheckbox(parent, "Screen alerts", 18, y,
        function() return self.db.profile.alertScreen end,
        function(v) self.db.profile.alertScreen = v end)
    y = y - 24

    MakeStyledCheckbox(parent, "Auto-buy at vendor", 18, y,
        function() return self.db.profile.autoBuy end,
        function(v) self.db.profile.autoBuy = v end)
    y = y - 36

    -- ===== Tracked Items =====
    MakeSectionHeader(parent, "TRACKED ITEMS", y)
    y = y - 8

    -- Column headers
    local colFrame = CreateFrame("Frame", nil, parent)
    colFrame:SetSize(FRAME_WIDTH - 60, 18)
    colFrame:SetPoint("TOPLEFT", 12, y)
    local colBg = MakePixel(colFrame, C.accent[1], C.accent[2], C.accent[3], 0.08)
    colBg:SetAllPoints()

    local col1 = colFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    col1:SetPoint("LEFT", 8, 0)
    col1:SetText("ITEM")
    col1:SetTextColor(C.accent[1], C.accent[2], C.accent[3], 0.7)

    local col2 = colFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    col2:SetPoint("LEFT", 215, 0)
    col2:SetText("HAVE")
    col2:SetTextColor(C.accent[1], C.accent[2], C.accent[3], 0.7)

    local col3 = colFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    col3:SetPoint("RIGHT", -133, 0)
    col3:SetText("WANT")
    col3:SetTextColor(C.accent[1], C.accent[2], C.accent[3], 0.7)

    local col4 = colFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    col4:SetPoint("RIGHT", -48, 0)
    col4:SetText("STACK")
    col4:SetTextColor(C.accent[1], C.accent[2], C.accent[3], 0.7)

    y = y - 20

    -- Display tracked items
    local reagents = self.db.profile.reagents
    local sortedNames = {}
    for name, _ in pairs(reagents) do
        table.insert(sortedNames, name)
    end
    table.sort(sortedNames)

    if #sortedNames == 0 then
        local empty = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        empty:SetPoint("TOPLEFT", 20, y)
        empty:SetText("|cff555560No items tracked. Add items below or use quick-add.|r")
        y = y - 28
    else
        for i, name in ipairs(sortedNames) do
            CreateTrackedItemRow(parent, name, reagents[name], y, i)
            y = y - 30
        end
    end

    y = y - 10

    -- Add item row
    MakeSectionHeader(parent, "ADD ITEM", y)
    y = y - 28

    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", 18, y)
    hint:SetText("|cff555560Enter the exact item name. Set stack size to match vendor quantity per purchase.|r")
    y = y - 18

    CreateAddItemRow(parent, y)
    y = y - 40

    -- ===== Quick-Add Suggestions =====
    local classReagents = ns.ClassReagents[self.playerClass]
    if classReagents and #classReagents > 0 then
        local className = self.playerClass:sub(1,1) .. self.playerClass:sub(2):lower()
        MakeSectionHeader(parent, "QUICK ADD — " .. className:upper(), y)
        y = y - 26

        for i, reagent in ipairs(classReagents) do
            if reagent.itemName ~= "Soul Shard" then
                CreateQuickAddRow(parent, reagent.itemName, 20, y, i)
                y = y - 26
            end
        end

        y = y - 10
    end

    -- ===== Common Items Quick-Add =====
    MakeSectionHeader(parent, "QUICK ADD — COMMON", y)
    y = y - 26

    local commonItems = {
        "Conjured Sparkling Water",
        "Conjured Croissant",
        "Star's Tears",
        "Heavy Runecloth Bandage",
        "Heavy Netherweave Bandage",
        "Super Healing Potion",
        "Super Mana Potion",
    }

    for i, name in ipairs(commonItems) do
        CreateQuickAddRow(parent, name, 20, y, i)
        y = y - 26
    end

    y = y - 10

    -- ===== Actions =====
    MakeSectionHeader(parent, "ACTIONS", y)
    y = y - 30

    MakeStyledButton(parent, "Scan Bags", 140, 28, 18, y, function()
        G:ForceScan()
    end)

    MakeStyledButton(parent, "Reset All", 100, 28, 168, y, function()
        G.db:ResetProfile()
        G:RefreshConfig()
        G:Msg("Settings reset to defaults.")
    end)

    y = y - 50

    parent:SetHeight(math.abs(y) + 20)
end

function G:RefreshConfig()
    if configFrame and configFrame.content then
        local kids = { configFrame.content:GetChildren() }
        for _, child in ipairs(kids) do
            child:Hide()
            child:SetParent(nil)
        end
        local regions = { configFrame.content:GetRegions() }
        for _, region in ipairs(regions) do
            region:Hide()
        end
        self:BuildConfigContent(configFrame.content)
    end
end

-- Hook shift-click item insertion into our add-item edit box
hooksecurefunc("ChatEdit_InsertLink", function(link)
    if not link or not addItemEditBox then return end
    if not addItemEditBox:HasFocus() then return end
    -- Extract plain item name from link like "|cff...|Hitem:...|h[Item Name]|h|r"
    local name = link:match("%[(.-)%]")
    if name then
        addItemEditBox:SetText(name)
    end
end)
