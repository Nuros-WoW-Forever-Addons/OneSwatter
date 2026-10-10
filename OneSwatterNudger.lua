--[[
    OneSwatter - OneSwatterNudger.lua
    Popout Frame Nudger & Element Inspector HUD.
    Features:
      - Floating movable micro-inspector panel
      - Mouse-over element picker with green selection overlay
      - 4-way D-Pad move control with center Reset button
      - Uniform sizing control (Up - Reset - Down)
      - Independent Width & Height sizing controls (Toggleable via checkbox)
      - Configurable step increments (1px, 5px, 10px)
      - Live Lua code generator with auto-select copy box
--]]

local addonName, addonTable = ...
local OneSwatter = _G.OneSwatter or addonTable
local Nudger = {}
OneSwatter.Nudger = Nudger

local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil

local function ApplyBackdrop(frame, backdropInfo)
    if BackdropTemplateMixin and not frame.SetBackdrop then
        Mixin(frame, BackdropTemplateMixin)
    end
    if frame.SetBackdrop then
        frame:SetBackdrop(backdropInfo)
    end
end

-- State variables
Nudger.selectedFrame = nil
Nudger.origPoints = nil
Nudger.origWidth = nil
Nudger.origHeight = nil
Nudger.stepSize = 1
Nudger.isIndependentSizing = false
Nudger.isPicking = false

-------------------------------------------------------------------------------
-- Helper Constructors
-------------------------------------------------------------------------------

local function CreateButton(parent, text, width, height, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width or 80, height or 22)
    btn:SetText(text)
    if onClick then
        btn:SetScript("OnClick", onClick)
    end
    return btn
end

local function Round(num)
    return math.floor((num or 0) + 0.5)
end

-------------------------------------------------------------------------------
-- Selection Highlight Overlay
-------------------------------------------------------------------------------

local highlightFrame = CreateFrame("Frame", "OneSwatterHighlightFrame", UIParent, backdropTemplate)
highlightFrame:SetFrameStrata("TOOLTIP")
highlightFrame:Hide()

ApplyBackdrop(highlightFrame, {
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
})
highlightFrame:SetBackdropBorderColor(0.0, 1.0, 0.2, 0.9)

-- Pulsing alpha animation
local pulseElapsed = 0
highlightFrame:SetScript("OnUpdate", function(self, elapsed)
    pulseElapsed = pulseElapsed + (elapsed * 4)
    local alpha = 0.5 + 0.4 * math.sin(pulseElapsed)
    self:SetAlpha(alpha)
end)

-------------------------------------------------------------------------------
-- Element Picker Logic
-------------------------------------------------------------------------------

local pickerFrame = CreateFrame("Frame", "OneSwatterPickerFrame", UIParent)
pickerFrame:Hide()

local function GetTargetUnderMouse()
    local focus = nil
    if GetMouseFoci then
        local foci = GetMouseFoci()
        focus = foci and foci[1]
    elseif GetMouseFocus then
        focus = GetMouseFocus()
    end

    if not focus or focus == WorldFrame or focus == UIParent or focus == highlightFrame then
        return nil
    end

    -- Ignore Nudger frame and its children
    if Nudger.frame then
        local parent = focus
        while parent do
            if parent == Nudger.frame or parent == highlightFrame then
                return nil
            end
            parent = parent:GetParent()
        end
    end

    return focus
end

function Nudger:StartPicking()
    self.isPicking = true
    if self.pickBtn then
        self.pickBtn:SetText("|cff00ff00Click Element...|r")
    end
    pickerFrame:Show()
end

function Nudger:StopPicking()
    self.isPicking = false
    if self.pickBtn then
        self.pickBtn:SetText("🎯 Pick Element")
    end
    pickerFrame:Hide()
    highlightFrame:Hide()
end

pickerFrame:SetScript("OnUpdate", function()
    if not Nudger.isPicking then return end
    local hovered = GetTargetUnderMouse()
    if hovered and hovered:IsVisible() then
        highlightFrame:ClearAllPoints()
        highlightFrame:SetPoint("TOPLEFT", hovered, "TOPLEFT", -2, 2)
        highlightFrame:SetPoint("BOTTOMRIGHT", hovered, "BOTTOMRIGHT", 2, -2)
        highlightFrame:Show()
    else
        highlightFrame:Hide()
    end
end)

-- Click detector frame to intercept click while picking
local clickInterceptor = CreateFrame("Button", "OneSwatterClickInterceptor", UIParent)
clickInterceptor:SetFrameStrata("FULLSCREEN_DIALOG")
clickInterceptor:SetAllPoints(UIParent)
clickInterceptor:EnableMouse(true)
clickInterceptor:Hide()

clickInterceptor:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" and Nudger.isPicking then
        self:Hide()
        local selected = GetTargetUnderMouse()
        Nudger:StopPicking()
        if selected then
            Nudger:SelectFrame(selected)
        end
    elseif button == "RightButton" then
        self:Hide()
        Nudger:StopPicking()
    end
end)

function Nudger:TogglePicking()
    if self.isPicking then
        clickInterceptor:Hide()
        self:StopPicking()
    else
        clickInterceptor:Show()
        self:StartPicking()
    end
end

-------------------------------------------------------------------------------
-- Frame Selection & State Capture
-------------------------------------------------------------------------------

function Nudger:SelectFrame(target)
    if not target then return end
    self.selectedFrame = target

    -- Capture original points
    self.origPoints = {}
    local numPoints = target:GetNumPoints() or 1
    for i = 1, numPoints do
        local point, relTo, relPoint, x, y = target:GetPoint(i)
        if point then
            table.insert(self.origPoints, {
                point = point,
                relTo = relTo,
                relPoint = relPoint,
                x = x or 0,
                y = y or 0,
            })
        end
    end

    -- Capture original size
    self.origWidth = Round(target:GetWidth() or 0)
    self.origHeight = Round(target:GetHeight() or 0)

    self:RefreshDisplay()
end

-------------------------------------------------------------------------------
-- Nudging (Movement) Operations
-------------------------------------------------------------------------------

function Nudger:Move(deltaX, deltaY)
    local target = self.selectedFrame
    if not target then return end

    local point, relTo, relPoint, curX, curY = target:GetPoint(1)
    if not point then
        point = "TOPLEFT"
        relTo = target:GetParent() or UIParent
        relPoint = "TOPLEFT"
        curX = 0
        curY = 0
    end

    local newX = Round((curX or 0) + (deltaX * self.stepSize))
    local newY = Round((curY or 0) + (deltaY * self.stepSize))

    target:ClearAllPoints()
    target:SetPoint(point, relTo, relPoint, newX, newY)

    self:RefreshDisplay()
end

function Nudger:ResetPosition()
    local target = self.selectedFrame
    if not target or not self.origPoints or #self.origPoints == 0 then return end

    target:ClearAllPoints()
    for _, pt in ipairs(self.origPoints) do
        target:SetPoint(pt.point, pt.relTo, pt.relPoint, pt.x, pt.y)
    end

    self:RefreshDisplay()
end

-------------------------------------------------------------------------------
-- Sizing Operations
-------------------------------------------------------------------------------

function Nudger:AdjustSize(deltaW, deltaH)
    local target = self.selectedFrame
    if not target then return end

    local curW = Round(target:GetWidth() or 0)
    local curH = Round(target:GetHeight() or 0)

    local newW = math.max(1, curW + (deltaW * self.stepSize))
    local newH = math.max(1, curH + (deltaH * self.stepSize))

    if deltaW ~= 0 and deltaH ~= 0 then
        target:SetSize(newW, newH)
    elseif deltaW ~= 0 then
        target:SetWidth(newW)
    elseif deltaH ~= 0 then
        target:SetHeight(newH)
    end

    self:RefreshDisplay()
end

function Nudger:ResetSize(resetW, resetH)
    local target = self.selectedFrame
    if not target then return end

    if resetW and self.origWidth then
        target:SetWidth(self.origWidth)
    end
    if resetH and self.origHeight then
        target:SetHeight(self.origHeight)
    end

    self:RefreshDisplay()
end

-------------------------------------------------------------------------------
-- HUD UI Construction
-------------------------------------------------------------------------------

function Nudger:Init()
    if self.frame then return end

    local frame = CreateFrame("Frame", "OneSwatterNudgerFrame", UIParent, backdropTemplate)
    self.frame = frame
    frame:SetSize(310, 420)
    frame:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:Hide()

    ApplyBackdrop(frame, {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 24, edgeSize = 24,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })

    -- Draggable Title Bar
    local titleBar = CreateFrame("Button", nil, frame)
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -8)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, -8)
    titleBar:SetHeight(24)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    local icon = titleBar:CreateTexture(nil, "OVERLAY")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", titleBar, "LEFT", 2, 0)
    icon:SetTexture("Interface\\AddOns\\OneSwatter\\Textures\\SwatterIcon")

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    title:SetText("|cff00ccffOneSwatter|r Frame Nudger")

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    tinsert(UISpecialFrames, "OneSwatterNudgerFrame")

    -- Target Info Box
    local infoBox = CreateFrame("Frame", nil, frame, backdropTemplate)
    infoBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -36)
    infoBox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -36)
    infoBox:SetHeight(64)
    ApplyBackdrop(infoBox, {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    infoBox:SetBackdropColor(0.05, 0.05, 0.08, 0.8)

    local targetLabel = infoBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    targetLabel:SetPoint("TOPLEFT", infoBox, "TOPLEFT", 8, -6)
    targetLabel:SetText("|cff00ccffTarget:|r None selected")
    self.targetLabel = targetLabel

    local posLabel = infoBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    posLabel:SetPoint("TOPLEFT", targetLabel, "BOTTOMLEFT", 0, -4)
    posLabel:SetText("Pos: N/A | Size: N/A")
    self.posLabel = posLabel

    -- Pick Element Button
    local pickBtn = CreateButton(infoBox, "🎯 Pick Element", 110, 20, function()
        self:TogglePicking()
    end)
    pickBtn:SetPoint("BOTTOMLEFT", infoBox, "BOTTOMLEFT", 8, 6)
    self.pickBtn = pickBtn

    -- Step Increments
    local stepRow = CreateFrame("Frame", nil, frame)
    stepRow:SetPoint("TOPLEFT", infoBox, "BOTTOMLEFT", 0, -6)
    stepRow:SetPoint("TOPRIGHT", infoBox, "BOTTOMRIGHT", 0, -6)
    stepRow:SetHeight(24)

    local stepLabel = stepRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    stepLabel:SetPoint("LEFT", stepRow, "LEFT", 4, 0)
    stepLabel:SetText("Step:")

    local step1 = CreateButton(stepRow, "1px", 42, 20, function() self:SetStep(1) end)
    step1:SetPoint("LEFT", stepLabel, "RIGHT", 6, 0)
    self.step1Btn = step1

    local step5 = CreateButton(stepRow, "5px", 42, 20, function() self:SetStep(5) end)
    step5:SetPoint("LEFT", step1, "RIGHT", 4, 0)
    self.step5Btn = step5

    local step10 = CreateButton(stepRow, "10px", 46, 20, function() self:SetStep(10) end)
    step10:SetPoint("LEFT", step5, "RIGHT", 4, 0)
    self.step10Btn = step10

    -- Section Divider / Control Area
    local controlsArea = CreateFrame("Frame", nil, frame)
    controlsArea:SetPoint("TOPLEFT", stepRow, "BOTTOMLEFT", 0, -6)
    controlsArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 90)
    self.controlsArea = controlsArea

    -- MOVE D-PAD (4-Way Cross with Center Reset)
    local moveLabel = controlsArea:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    moveLabel:SetPoint("TOPLEFT", controlsArea, "TOPLEFT", 38, 0)
    moveLabel:SetText("|cffffcc00MOVE|r")

    local btnUp = CreateButton(controlsArea, "▲", 32, 26, function() self:Move(0, 1) end)
    btnUp:SetPoint("TOPLEFT", controlsArea, "TOPLEFT", 44, -18)

    local btnLeft = CreateButton(controlsArea, "◄", 32, 26, function() self:Move(-1, 0) end)
    btnLeft:SetPoint("TOPRIGHT", btnUp, "BOTTOMLEFT", -2, -2)

    local btnResetMove = CreateButton(controlsArea, "↺", 32, 26, function() self:ResetPosition() end)
    btnResetMove:SetPoint("LEFT", btnLeft, "RIGHT", 2, 0)
    btnResetMove:SetScript("OnEnter", function(b)
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetText("Reset Position", 1, 1, 1)
        GameTooltip:AddLine("Restores the element to its original coordinates.", 1, 0.82, 0)
        GameTooltip:Show()
    end)
    btnResetMove:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local btnRight = CreateButton(controlsArea, "►", 32, 26, function() self:Move(1, 0) end)
    btnRight:SetPoint("LEFT", btnResetMove, "RIGHT", 2, 0)

    local btnDown = CreateButton(controlsArea, "▼", 32, 26, function() self:Move(0, -1) end)
    btnDown:SetPoint("TOPLEFT", btnResetMove, "BOTTOMLEFT", 0, -2)

    -- SIZING CONTROLS
    local sizeContainer = CreateFrame("Frame", nil, controlsArea)
    sizeContainer:SetPoint("TOPLEFT", controlsArea, "TOPLEFT", 155, 0)
    sizeContainer:SetPoint("BOTTOMRIGHT", controlsArea, "BOTTOMRIGHT", 0, 0)
    self.sizeContainer = sizeContainer

    local sizeLabel = sizeContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sizeLabel:SetPoint("TOPLEFT", sizeContainer, "TOPLEFT", 22, 0)
    sizeLabel:SetText("|cffffcc00SIZE (Both)|r")
    self.sizeLabel = sizeLabel

    -- Uniform Sizing Controls (Default: Up, Reset, Down)
    local uniformGroup = CreateFrame("Frame", nil, sizeContainer)
    uniformGroup:SetAllPoints(sizeContainer)
    self.uniformGroup = uniformGroup

    local btnSizeUp = CreateButton(uniformGroup, "▲", 36, 26, function() self:AdjustSize(1, 1) end)
    btnSizeUp:SetPoint("TOPLEFT", uniformGroup, "TOPLEFT", 36, -18)

    local btnSizeReset = CreateButton(uniformGroup, "↺", 36, 26, function() self:ResetSize(true, true) end)
    btnSizeReset:SetPoint("TOPLEFT", btnSizeUp, "BOTTOMLEFT", 0, -2)
    btnSizeReset:SetScript("OnEnter", function(b)
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetText("Reset Size", 1, 1, 1)
        GameTooltip:AddLine("Restores original width and height.", 1, 0.82, 0)
        GameTooltip:Show()
    end)
    btnSizeReset:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local btnSizeDown = CreateButton(uniformGroup, "▼", 36, 26, function() self:AdjustSize(-1, -1) end)
    btnSizeDown:SetPoint("TOPLEFT", btnSizeReset, "BOTTOMLEFT", 0, -2)

    -- Independent Sizing Controls (Height vertical column, Width horizontal row)
    local indepGroup = CreateFrame("Frame", nil, sizeContainer)
    indepGroup:SetAllPoints(sizeContainer)
    indepGroup:Hide()
    self.indepGroup = indepGroup

    -- Height Column
    local hLabel = indepGroup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hLabel:SetPoint("TOPLEFT", indepGroup, "TOPLEFT", 0, -18)
    hLabel:SetText("Height:")

    local btnHUp = CreateButton(indepGroup, "▲", 28, 22, function() self:AdjustSize(0, 1) end)
    btnHUp:SetPoint("LEFT", hLabel, "RIGHT", 4, 0)

    local btnHReset = CreateButton(indepGroup, "↺", 28, 22, function() self:ResetSize(false, true) end)
    btnHReset:SetPoint("LEFT", btnHUp, "RIGHT", 2, 0)

    local btnHDown = CreateButton(indepGroup, "▼", 28, 22, function() self:AdjustSize(0, -1) end)
    btnHDown:SetPoint("LEFT", btnHReset, "RIGHT", 2, 0)

    -- Width Row
    local wLabel = indepGroup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    wLabel:SetPoint("TOPLEFT", hLabel, "BOTTOMLEFT", 0, -16)
    wLabel:SetText("Width:")

    local btnWLeft = CreateButton(indepGroup, "◄", 28, 22, function() self:AdjustSize(-1, 0) end)
    btnWLeft:SetPoint("LEFT", wLabel, "RIGHT", 8, 0)

    local btnWReset = CreateButton(indepGroup, "↺", 28, 22, function() self:ResetSize(true, false) end)
    btnWReset:SetPoint("LEFT", btnWLeft, "RIGHT", 2, 0)

    local btnWRight = CreateButton(indepGroup, "►", 28, 22, function() self:AdjustSize(1, 0) end)
    btnWRight:SetPoint("LEFT", btnWReset, "RIGHT", 2, 0)

    -- Checkbox: Independent Width & Height Sizing
    local indepCb = CreateFrame("CheckButton", nil, controlsArea, "UICheckButtonTemplate")
    indepCb:SetPoint("BOTTOMLEFT", controlsArea, "BOTTOMLEFT", 4, -4)
    indepCb.text = indepCb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    indepCb.text:SetPoint("LEFT", indepCb, "RIGHT", 4, 0)
    indepCb.text:SetText("Size W & H Independently")

    indepCb:SetScript("OnClick", function(cb)
        self:SetIndependentSizing(cb:GetChecked())
    end)
    self.indepCb = indepCb

    -- CODE OUTPUT EDITBOX
    local codeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    codeLabel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 68)
    codeLabel:SetText("Lua Code Output:")

    local codeScroll = CreateFrame("ScrollFrame", "OneSwatterNudgerCodeScroll", frame, "UIPanelScrollFrameTemplate")
    codeScroll:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 12)
    codeScroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 12)
    codeScroll:SetHeight(52)

    local codeEditBox = CreateFrame("EditBox", "OneSwatterNudgerCodeEditBox", codeScroll)
    codeEditBox:SetWidth(250)
    codeEditBox:SetHeight(50)
    codeEditBox:SetMultiLine(true)
    codeEditBox:SetAutoFocus(false)
    codeEditBox:SetFontObject(GameFontHighlightSmall)
    codeEditBox:SetScript("OnEscapePressed", function() frame:Hide() end)
    codeEditBox:SetScript("OnEditFocusGained", function(eb) eb:HighlightText() end)

    codeScroll:SetScrollChild(codeEditBox)
    self.codeEditBox = codeEditBox

    self:SetStep(1)
end

-------------------------------------------------------------------------------
-- Mode & State Toggles
-------------------------------------------------------------------------------

function Nudger:SetStep(step)
    self.stepSize = step or 1
    if self.step1Btn then self.step1Btn:SetText(step == 1 and "|cff00ff001px|r" or "1px") end
    if self.step5Btn then self.step5Btn:SetText(step == 5 and "|cff00ff005px|r" or "5px") end
    if self.step10Btn then self.step10Btn:SetText(step == 10 and "|cff00ff0010px|r" or "10px") end
end

function Nudger:SetIndependentSizing(enable)
    self.isIndependentSizing = enable and true or false
    if self.isIndependentSizing then
        self.uniformGroup:Hide()
        self.indepGroup:Show()
        self.sizeLabel:SetText("|cffffcc00SIZE (W / H)|r")
    else
        self.uniformGroup:Show()
        self.indepGroup:Hide()
        self.sizeLabel:SetText("|cffffcc00SIZE (Both)|r")
    end
end

-------------------------------------------------------------------------------
-- Display & Code Generator Refresh
-------------------------------------------------------------------------------

function Nudger:RefreshDisplay()
    local target = self.selectedFrame
    if not target then
        self.targetLabel:SetText("|cff00ccffTarget:|r None selected")
        self.posLabel:SetText("Pos: N/A | Size: N/A")
        self.codeEditBox:SetText("-- Pick an element using the button above.")
        return
    end

    local name = target:GetName() or "(Anonymous Frame)"
    local w = Round(target:GetWidth() or 0)
    local h = Round(target:GetHeight() or 0)

    local point, relTo, relPoint, x, y = target:GetPoint(1)
    x = Round(x or 0)
    y = Round(y or 0)

    local parentName = "UIParent"
    if relTo then
        if type(relTo) == "string" then
            parentName = relTo
        elseif relTo.GetName and relTo:GetName() then
            parentName = relTo:GetName()
        end
    end

    self.targetLabel:SetText("|cff00ccffTarget:|r " .. name)
    self.posLabel:SetText(string.format("X: |cffffd100%d|r, Y: |cffffd100%d|r | Size: |cffffd100%d|r x |cffffd100%d|r", x, y, w, h))

    -- Generate copyable code snippet
    local targetRef = target:GetName() or "frame"
    local codeSnippet = string.format(
        '%s:SetPoint("%s", %s, "%s", %d, %d)\n%s:SetSize(%d, %d)',
        targetRef,
        point or "TOPLEFT",
        parentName,
        relPoint or "TOPLEFT",
        x, y,
        targetRef,
        w, h
    )

    self.codeEditBox:SetText(codeSnippet)
end

-------------------------------------------------------------------------------
-- Public Visibility API
-------------------------------------------------------------------------------

function Nudger:Show()
    self:Init()
    self.frame:Show()
    self:RefreshDisplay()
end

function Nudger:Hide()
    if self.frame then
        self:StopPicking()
        self.frame:Hide()
    end
end

function Nudger:Toggle()
    self:Init()
    if self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end
