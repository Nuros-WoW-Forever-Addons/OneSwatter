--[[
    OneSwatter - OneSwatterUI.lua
    Full-featured diagnostic UI with dual-tab layout (Errors & Suite Debug Logs),
    addon debug mode master toggles, search/filtering, and copyable text frames.
--]]

local addonName, addonTable = ...
local OneSwatter = _G.OneSwatter or addonTable
local UI = {}
OneSwatter.UI = UI

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
UI.activeTab = 1 -- 1: Errors, 2: Debug Logs, 3: Settings
UI.currentErrorPos = 1
UI.selectedAddonFilter = "ALL"
UI.selectedLevelFilter = "ALL"
UI.searchQuery = ""

-------------------------------------------------------------------------------
-- UI Helper Constructors
-------------------------------------------------------------------------------

local function CreateButton(parent, text, width, height, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width or 100, height or 22)
    btn:SetText(text)
    if onClick then
        btn:SetScript("OnClick", onClick)
    end
    return btn
end

local function CreateTabButton(parent, id, labelText, onClick)
    local tab = CreateFrame("Button", nil, parent, backdropTemplate)
    tab:SetSize(110, 26)
    ApplyBackdrop(tab, {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    tab:SetBackdropColor(0.1, 0.1, 0.15, 0.9)
    tab:SetBackdropBorderColor(0.4, 0.4, 0.5, 1.0)

    tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tab.text:SetPoint("CENTER", tab, "CENTER", 0, 0)
    tab.text:SetText(labelText)

    tab:SetScript("OnClick", function()
        onClick(id)
    end)
    return tab
end

-------------------------------------------------------------------------------
-- Master Window Initialization
-------------------------------------------------------------------------------

function UI:Init()
    if self.frame then return end

    local frame = CreateFrame("Frame", "OneSwatterUIFrame", UIParent, backdropTemplate)
    self.frame = frame
    frame:SetSize(680, 520)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:Hide()

    ApplyBackdrop(frame, {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 11, top = 12, bottom = 11 }
    })

    -- Draggable Header Bar
    local titleBar = CreateFrame("Button", nil, frame)
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -12)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -36, -12)
    titleBar:SetHeight(28)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    -- Icon & Title
    local icon = titleBar:CreateTexture(nil, "OVERLAY")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", titleBar, "LEFT", 4, 0)
    icon:SetTexture("Interface\\AddOns\\OneSwatter\\Textures\\SwatterIcon")

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    title:SetText("|cff00ccffOneSwatter|r v" .. OneSwatter.version .. " - Suite Addon Diagnostics")

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Register for Esc Key
    tinsert(UISpecialFrames, "OneSwatterUIFrame")

    -- Tab Container
    local tabContainer = CreateFrame("Frame", nil, frame)
    tabContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -42)
    tabContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -42)
    tabContainer:SetHeight(30)

    self.tabs = {}
    self.tabs[1] = CreateTabButton(tabContainer, 1, "Lua Errors", function(id) self:SelectTab(id) end)
    self.tabs[1]:SetPoint("LEFT", tabContainer, "LEFT", 0, 0)

    self.tabs[2] = CreateTabButton(tabContainer, 2, "Debug Logs", function(id) self:SelectTab(id) end)
    self.tabs[2]:SetPoint("LEFT", self.tabs[1], "RIGHT", 6, 0)

    self.tabs[3] = CreateTabButton(tabContainer, 3, "Settings & Suite", function(id) self:SelectTab(id) end)
    self.tabs[3]:SetPoint("LEFT", self.tabs[2], "RIGHT", 6, 0)

    -- Main Content Area Panels
    self:InitErrorsTab()
    self:InitDebugLogsTab()
    self:InitSettingsTab()

    -- Master Reload UI Button at bottom right
    local reloadBtn = CreateButton(frame, "Reload UI", 100, 22, function()
        if ReloadUI then
            ReloadUI()
        elseif ConsoleExec then
            ConsoleExec("reloadui")
        end
    end)
    reloadBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 10)

    -- MouseOver Tooltip
    reloadBtn:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_TOPRIGHT")
        GameTooltip:SetText("Reload UI", 1, 1, 1)
        GameTooltip:AddLine("Reloads the WoW User Interface.\n\n|cffffcc00Note:|r You must reload the UI (or log out) for newly captured errors and debug logs to be written to disk in SavedVariables.", 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    reloadBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Master Frame Nudger Button
    local nudgerBtn = CreateButton(frame, "Frame Nudger", 100, 22, function()
        if OneSwatter.Nudger then
            OneSwatter.Nudger:Toggle()
        end
    end)
    nudgerBtn:SetPoint("RIGHT", reloadBtn, "LEFT", -8, 0)
    nudgerBtn:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_TOPRIGHT")
        GameTooltip:SetText("Frame Nudger", 1, 1, 1)
        GameTooltip:AddLine("Opens the popout Frame Nudger HUD for pixel-precise element alignment, sizing, and code generation.", 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    nudgerBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self:SelectTab(1)
end

-------------------------------------------------------------------------------
-- TAB 1: ERRORS PANEL
-------------------------------------------------------------------------------

function UI:InitErrorsTab()
    local panel = CreateFrame("Frame", nil, self.frame)
    panel:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 16, -76)
    panel:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -16, 38)
    self.errorsPanel = panel

    -- Header Info
    local infoText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    infoText:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, 0)
    infoText:SetText("No errors recorded.")
    self.errorInfoText = infoText

    -- Error Display ScrollFrame & EditBox
    local scroll = CreateFrame("ScrollFrame", "OneSwatterErrorScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -26)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 42)

    local editBox = CreateFrame("EditBox", "OneSwatterErrorEditBox", scroll)
    editBox:SetWidth(610)
    editBox:SetHeight(320)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetScript("OnEscapePressed", function() self.frame:Hide() end)
    editBox:SetScript("OnEditFocusGained", function(eb) eb:HighlightText() end)

    scroll:SetScrollChild(editBox)
    self.errorEditBox = editBox
    self.errorScroll = scroll

    -- Bottom Controls
    local prevBtn = CreateButton(panel, "< Prev", 80, 22, function() self:PrevError() end)
    prevBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 6, 6)
    self.errorPrevBtn = prevBtn

    local nextBtn = CreateButton(panel, "Next >", 80, 22, function() self:NextError() end)
    nextBtn:SetPoint("LEFT", prevBtn, "RIGHT", 6, 0)
    self.errorNextBtn = nextBtn

    local clearBtn = CreateButton(panel, "Clear Errors", 100, 22, function()
        OneSwatterDB.errors = {}
        self.currentErrorPos = 1
        self:RefreshErrors()
    end)
    clearBtn:SetPoint("LEFT", nextBtn, "RIGHT", 16, 0)

    local copyBtn = CreateButton(panel, "Select All", 90, 22, function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)
    copyBtn:SetPoint("LEFT", clearBtn, "RIGHT", 6, 0)

    -- Auto-Show Checkbox
    local autoCb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    autoCb:SetPoint("LEFT", copyBtn, "RIGHT", 16, -1)
    autoCb.text = autoCb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    autoCb.text:SetPoint("LEFT", autoCb, "RIGHT", 4, 0)
    autoCb.text:SetText("Auto-Show UI")
    autoCb:SetScript("OnShow", function(cb) cb:SetChecked(OneSwatterDB.autoshow) end)
    autoCb:SetScript("OnClick", function(cb) OneSwatterDB.autoshow = cb:GetChecked() end)
end

function UI:RefreshErrors()
    local errors = OneSwatterDB.errors or {}
    local total = #errors

    if total == 0 then
        self.errorInfoText:SetText("|cff808080No Lua errors recorded.|r")
        self.errorEditBox:SetText("No errors caught during this session.")
        self.errorPrevBtn:Disable()
        self.errorNextBtn:Disable()
        return
    end

    if self.currentErrorPos < 1 then self.currentErrorPos = 1 end
    if self.currentErrorPos > total then self.currentErrorPos = total end

    local err = errors[self.currentErrorPos]
    if not err then return end

    self.errorInfoText:SetText(string.format(
        "|cffffcc00Error %d of %d|r | (Count: |cffff3333%d|r) | Context: |cff00ccff%s|r",
        self.currentErrorPos, total, err.count or 1, err.context or "Global"
    ))

    local formatted = string.format(
        "Date/Time: %s\nLast Seen: %s\nContext: %s\nCount: %d\n\nError Message:\n%s\n\nStack Trace:\n%s\n\nLoaded AddOns:\n%s",
        err.timestamp or "N/A",
        err.lastSeen or err.timestamp or "N/A",
        err.context or "Global",
        err.count or 1,
        err.message or "",
        err.stack or "",
        err.addons or "N/A"
    )

    self.errorEditBox:SetText(formatted)
    self.errorScroll:UpdateScrollChildRect()

    if self.currentErrorPos > 1 then self.errorPrevBtn:Enable() else self.errorPrevBtn:Disable() end
    if self.currentErrorPos < total then self.errorNextBtn:Enable() else self.errorNextBtn:Disable() end
end

function UI:PrevError()
    if self.currentErrorPos > 1 then
        self.currentErrorPos = self.currentErrorPos - 1
        self:RefreshErrors()
    end
end

function UI:NextError()
    local errors = OneSwatterDB.errors or {}
    if self.currentErrorPos < #errors then
        self.currentErrorPos = self.currentErrorPos + 1
        self:RefreshErrors()
    end
end

function UI:ShowError(index)
    self:Init()
    self.frame:Show()
    self:SelectTab(1)
    if index then
        self.currentErrorPos = index
    else
        self.currentErrorPos = #(OneSwatterDB.errors or {})
    end
    self:RefreshErrors()
end

-------------------------------------------------------------------------------
-- TAB 2: DEBUG LOGS PANEL
-------------------------------------------------------------------------------

function UI:InitDebugLogsTab()
    local panel = CreateFrame("Frame", nil, self.frame)
    panel:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 16, -76)
    panel:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -16, 38)
    self.debugPanel = panel

    -- Filter Bar (Addon selector, Debug Mode Checkbox, Level Selector, Search Box)
    local filterBar = CreateFrame("Frame", nil, panel)
    filterBar:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    filterBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    filterBar:SetHeight(32)

    -- Addon Cycle Button / Dropdown
    local addonBtn = CreateButton(filterBar, "Addon: ALL", 140, 22, function(btn)
        self:CycleAddonFilter(btn)
    end)
    addonBtn:SetPoint("LEFT", filterBar, "LEFT", 0, 0)
    self.addonFilterBtn = addonBtn

    -- Enable Debug Mode Checkbox for selected Addon
    local debugCb = CreateFrame("CheckButton", nil, filterBar, "UICheckButtonTemplate")
    debugCb:SetPoint("LEFT", addonBtn, "RIGHT", 8, 0)
    debugCb.text = debugCb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    debugCb.text:SetPoint("LEFT", debugCb, "RIGHT", 4, 0)
    debugCb.text:SetText("Debug Mode")
    debugCb:SetScript("OnClick", function(cb)
        if self.selectedAddonFilter and self.selectedAddonFilter ~= "ALL" then
            OneSwatter:SetDebugMode(self.selectedAddonFilter, cb:GetChecked())
        end
    end)
    self.debugModeCb = debugCb

    -- Log Level Filter Button
    local levelBtn = CreateButton(filterBar, "Level: ALL", 90, 22, function(btn)
        self:CycleLevelFilter(btn)
    end)
    levelBtn:SetPoint("LEFT", debugCb.text, "RIGHT", 12, 0)
    self.levelFilterBtn = levelBtn

    -- Search Box
    local searchLabel = filterBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    searchLabel:SetPoint("LEFT", levelBtn, "RIGHT", 10, 0)
    searchLabel:SetText("Search:")

    local searchBox = CreateFrame("EditBox", "OneSwatterSearchBox", filterBar, "InputBoxTemplate")
    searchBox:SetSize(110, 20)
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 6, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function(eb)
        self.searchQuery = eb:GetText():lower()
        self:RefreshDebugLogs()
    end)

    -- Log Display ScrollFrame & EditBox
    local scroll = CreateFrame("ScrollFrame", "OneSwatterLogScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 6, -8)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 42)

    local editBox = CreateFrame("EditBox", "OneSwatterLogEditBox", scroll)
    editBox:SetWidth(610)
    editBox:SetHeight(320)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetScript("OnEscapePressed", function() self.frame:Hide() end)
    editBox:SetScript("OnEditFocusGained", function(eb) eb:HighlightText() end)

    scroll:SetScrollChild(editBox)
    self.logEditBox = editBox
    self.logScroll = scroll

    -- Bottom Action Buttons
    local clearLogsBtn = CreateButton(panel, "Clear Logs", 100, 22, function()
        OneSwatterDB.debugLogs = {}
        self:RefreshDebugLogs()
    end)
    clearLogsBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 6, 6)

    local copyLogsBtn = CreateButton(panel, "Select All", 90, 22, function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)
    copyLogsBtn:SetPoint("LEFT", clearLogsBtn, "RIGHT", 6, 0)
end

function UI:GetRegisteredAddonList()
    local list = { "ALL" }
    for addon in pairs(OneSwatterDB.registeredAddons or {}) do
        table.insert(list, addon)
    end
    table.sort(list, function(a, b)
        if a == "ALL" then return true end
        if b == "ALL" then return false end
        return a < b
    end)
    return list
end

function UI:CycleAddonFilter(btn)
    local list = self:GetRegisteredAddonList()
    local currIdx = 1
    for i, addon in ipairs(list) do
        if addon == self.selectedAddonFilter then
            currIdx = i
            break
        end
    end
    local nextIdx = (currIdx % #list) + 1
    self.selectedAddonFilter = list[nextIdx]
    btn:SetText("Addon: " .. self.selectedAddonFilter)

    -- Update debug mode checkbox state
    if self.selectedAddonFilter == "ALL" then
        self.debugModeCb:Disable()
        self.debugModeCb:SetChecked(false)
    else
        self.debugModeCb:Enable()
        self.debugModeCb:SetChecked(OneSwatter:IsDebugMode(self.selectedAddonFilter))
    end

    self:RefreshDebugLogs()
end

function UI:CycleLevelFilter(btn)
    local levels = { "ALL", "DEBUG", "INFO", "WARN", "ERROR" }
    local currIdx = 1
    for i, lvl in ipairs(levels) do
        if lvl == self.selectedLevelFilter then
            currIdx = i
            break
        end
    end
    local nextIdx = (currIdx % #levels) + 1
    self.selectedLevelFilter = levels[nextIdx]
    btn:SetText("Level: " .. self.selectedLevelFilter)
    self:RefreshDebugLogs()
end

function UI:RefreshDebugLogs()
    local logs = OneSwatterDB.debugLogs or {}
    local lines = {}

    local colors = {
        TRACE = "|cffaaaaaa",
        DEBUG = "|cff808080",
        INFO  = "|cff00ccff",
        WARN  = "|cffffcc00",
        ERROR = "|cffff3333",
    }

    for _, entry in ipairs(logs) do
        local addonMatch = (self.selectedAddonFilter == "ALL") or (entry.addon == self.selectedAddonFilter)
        local levelMatch = (self.selectedLevelFilter == "ALL") or (entry.level == self.selectedLevelFilter)

        local queryMatch = true
        if self.searchQuery ~= "" then
            local textStr = (entry.addon .. " " .. entry.category .. " " .. entry.message .. " " .. (entry.details or "")):lower()
            if not textStr:find(self.searchQuery, 1, true) then
                queryMatch = false
            end
        end

        if addonMatch and levelMatch and queryMatch then
            local color = colors[entry.level] or "|cffffffff"
            local line = string.format(
                "[%s] %s[%s]|r |cff00ccff[%s:%s]|r %s",
                entry.timestamp or "",
                color,
                entry.level or "INFO",
                entry.addon or "General",
                entry.category or "General",
                entry.message or ""
            )
            if entry.details and entry.details ~= "" then
                line = line .. "\n   |cffaaaaaaDetails:|r " .. entry.details:gsub("\n", "\n   ")
            end
            table.insert(lines, line)
        end
    end

    if #lines == 0 then
        self.logEditBox:SetText("No debug logs matching current filter settings.")
    else
        self.logEditBox:SetText(table.concat(lines, "\n"))
    end
    self.logScroll:UpdateScrollChildRect()
end

-------------------------------------------------------------------------------
-- TAB 3: SETTINGS & SUITE MASTER CONTROL PANEL
-------------------------------------------------------------------------------

function UI:InitSettingsTab()
    local panel = CreateFrame("Frame", nil, self.frame)
    panel:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 16, -76)
    panel:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -16, 38)
    self.settingsPanel = panel

    -- General Settings Header
    local hdr1 = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hdr1:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -10)
    hdr1:SetText("|cff00ccffGeneral OneSwatter Preferences|r")

    -- Enable OneSwatter Checkbox
    local enableCb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    enableCb:SetPoint("TOPLEFT", hdr1, "BOTTOMLEFT", 0, -8)
    enableCb.text = enableCb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    enableCb.text:SetPoint("LEFT", enableCb, "RIGHT", 6, 0)
    enableCb.text:SetText("Enable Error Capture & Debug System")
    enableCb:SetScript("OnShow", function(cb) cb:SetChecked(OneSwatterDB.enabled) end)
    enableCb:SetScript("OnClick", function(cb) OneSwatterDB.enabled = cb:GetChecked() end)

    -- Auto-Show Checkbox
    local autoShowCb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    autoShowCb:SetPoint("TOPLEFT", enableCb, "BOTTOMLEFT", 0, -4)
    autoShowCb.text = autoShowCb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    autoShowCb.text:SetPoint("LEFT", autoShowCb, "RIGHT", 6, 0)
    autoShowCb.text:SetText("Automatically Popup Window on Unhandled Lua Errors")
    autoShowCb:SetScript("OnShow", function(cb) cb:SetChecked(OneSwatterDB.autoshow) end)
    autoShowCb:SetScript("OnClick", function(cb) OneSwatterDB.autoshow = cb:GetChecked() end)

    -- Sound Alert Checkbox
    local soundCb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    soundCb:SetPoint("TOPLEFT", autoShowCb, "BOTTOMLEFT", 0, -4)
    soundCb.text = soundCb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    soundCb.text:SetPoint("LEFT", soundCb, "RIGHT", 6, 0)
    soundCb.text:SetText("Play Warning Sound Alert on Error")
    soundCb:SetScript("OnShow", function(cb) cb:SetChecked(OneSwatterDB.soundAlert) end)
    soundCb:SetScript("OnClick", function(cb) OneSwatterDB.soundAlert = cb:GetChecked() end)

    -- Suite Addon Debug Mode Master Control Header
    local hdr2 = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hdr2:SetPoint("TOPLEFT", soundCb, "BOTTOMLEFT", 0, -18)
    hdr2:SetText("|cff00ccffOneSuite Addons - Debug Mode Master Checklist|r")

    local desc2 = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc2:SetPoint("TOPLEFT", hdr2, "BOTTOMLEFT", 0, -4)
    desc2:SetText("Toggle Debug Mode for individual suite addons to record detailed traces and dumps in OneSwatter.")

    -- ScrollFrame for Suite Addon Checklist
    local scroll = CreateFrame("ScrollFrame", "OneSwatterSettingsScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", desc2, "BOTTOMLEFT", 0, -10)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 10)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(600, 200)
    scroll:SetScrollChild(content)

    self.suiteChecklistContent = content
end

function UI:RefreshSettingsTab()
    local content = self.suiteChecklistContent
    if not content then return end

    -- Clear existing checkbuttons
    if content.checkButtons then
        for _, cb in ipairs(content.checkButtons) do
            cb:Hide()
        end
    end
    content.checkButtons = {}

    local addons = self:GetRegisteredAddonList()
    local yOffset = 0
    for _, addon in ipairs(addons) do
        if addon ~= "ALL" then
            local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
            cb:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -yOffset)
            cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            cb.text:SetPoint("LEFT", cb, "RIGHT", 6, 0)
            cb.text:SetText(addon .. " Debug Mode")

            cb:SetChecked(OneSwatter:IsDebugMode(addon))
            cb:SetScript("OnClick", function(c)
                OneSwatter:SetDebugMode(addon, c:GetChecked())
            end)

            table.insert(content.checkButtons, cb)
            yOffset = yOffset + 24
        end
    end
    content:SetHeight(math.max(200, yOffset + 20))
end

-------------------------------------------------------------------------------
-- TAB MANAGEMENT & REFRESH LOGIC
-------------------------------------------------------------------------------

function UI:SelectTab(tabId)
    self.activeTab = tabId

    for id, tabBtn in pairs(self.tabs) do
        if id == tabId then
            tabBtn:SetBackdropColor(0.2, 0.4, 0.7, 1.0)
            tabBtn:SetBackdropBorderColor(0.0, 0.8, 1.0, 1.0)
        else
            tabBtn:SetBackdropColor(0.1, 0.1, 0.15, 0.9)
            tabBtn:SetBackdropBorderColor(0.4, 0.4, 0.5, 1.0)
        end
    end

    if self.errorsPanel then self.errorsPanel:Hide() end
    if self.debugPanel then self.debugPanel:Hide() end
    if self.settingsPanel then self.settingsPanel:Hide() end

    if tabId == 1 then
        self.errorsPanel:Show()
        self:RefreshErrors()
    elseif tabId == 2 then
        self.debugPanel:Show()
        self:RefreshDebugLogs()
    elseif tabId == 3 then
        self.settingsPanel:Show()
        self:RefreshSettingsTab()
    end
end

function UI:RefreshAll()
    if self.activeTab == 1 then self:RefreshErrors() end
    if self.activeTab == 2 then self:RefreshDebugLogs() end
    if self.activeTab == 3 then self:RefreshSettingsTab() end
end

function UI:Toggle()
    self:Init()
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
        self:RefreshAll()
    end
end
