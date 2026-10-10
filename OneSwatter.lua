--[[
    OneSwatter - OneSwatter.lua
    Error capture, stack tracing, debug logging API, table dumper, and suite debug mode registry.
    Compatible with Vanilla 1.12, TBC 2.4.3, WotLK 3.3.5, and Modern WoW clients.
--]]

local addonName, addonTable = ...

-- Global Namespace Export
_G.OneSwatter = _G.OneSwatter or addonTable
local OneSwatter = _G.OneSwatter

OneSwatter.name = addonName
OneSwatter.version = "1.0.0"
OneSwatter.origHandler = geterrorhandler()
OneSwatter.origItemRef = SetItemRef
OneSwatter.HISTORY_SIZE_DEFAULT = 50
OneSwatter.MAX_LOGS_DEFAULT = 500

-- Default SavedVariables Structure
local defaultDB = {
    enabled = true,
    autoshow = true,
    soundAlert = false,
    maxErrors = 50,
    maxLogs = 500,
    errors = {},
    debugLogs = {},
    debugModes = {},
    registeredAddons = {
        ["MovableFrames"] = true,
        ["OnePanel"] = true,
        ["OnePanelUtils"] = true,
        ["OnePanel_Character"] = true,
        ["ShortKeybinds"] = true,
    },
}

-------------------------------------------------------------------------------
-- Helper Utilities & Table Dumper
-------------------------------------------------------------------------------

--- Serialize a table or value into formatted, human-readable text for debug inspection
-- @param val any: The value or table to dump
-- @param maxDepth number|nil: Maximum recursion depth (default 4)
-- @return string: Formatted string representation
function OneSwatter:Dump(val, maxDepth)
    maxDepth = maxDepth or 4
    local visited = {}

    local function dumpValue(v, depth, indent)
        if v == nil then return "nil" end
        local t = type(v)
        if t == "number" or t == "boolean" then
            return tostring(v)
        elseif t == "string" then
            return string.format("%q", v)
        elseif t == "function" then
            return "<function>"
        elseif t == "userdata" then
            return "<userdata>"
        elseif t == "table" then
            if visited[v] then return "<circular reference>" end
            if depth > maxDepth then return "{ ... }" end
            visited[v] = true

            local entries = {}
            local isArray = true
            local count = 0
            for k in pairs(v) do
                count = count + 1
                if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
                    isArray = false
                end
            end

            local nextIndent = indent .. "  "
            if isArray and count > 0 then
                for i = 1, #v do
                    table.insert(entries, nextIndent .. dumpValue(v[i], depth + 1, nextIndent))
                end
            else
                for k, subVal in pairs(v) do
                    local keyStr = type(k) == "string" and k or ("[" .. dumpValue(k, depth + 1, nextIndent) .. "]")
                    table.insert(entries, nextIndent .. keyStr .. " = " .. dumpValue(subVal, depth + 1, nextIndent))
                end
            end

            visited[v] = nil
            if #entries == 0 then return "{}" end
            return "{\n" .. table.concat(entries, ",\n") .. "\n" .. indent .. "}"
        end
        return tostring(v)
    end

    return dumpValue(val, 1, "")
end

-------------------------------------------------------------------------------
-- AddOn Metadata & Diagnostics Helper
-------------------------------------------------------------------------------

--- Gather list of loaded WoW AddOns and their version info
-- @return string: Formatted multiline list of active addons
function OneSwatter:GetAddOnList()
    local addlist = ""
    local numAddons = GetNumAddOns and GetNumAddOns() or 0
    for i = 1, numAddons do
        local name, title, notes, enabled, loadable, reason = GetAddOnInfo(i)
        local loaded = IsAddOnLoaded and IsAddOnLoaded(i)
        if loaded then
            name = name or "Unknown"
            local cleanName = name:gsub("[^a-zA-Z0-9_]+", "")
            local version = GetAddOnMetadata and GetAddOnMetadata(i, "Version")

            -- Fallback check global variables for version string
            if not version and cleanName ~= "" then
                local gObj = _G[cleanName] or _G[cleanName:lower()]
                if type(gObj) == "table" then
                    version = gObj.version or gObj.Version or gObj.VERSION
                end
                local gConst = _G[cleanName:upper() .. "_VERSION"]
                if gConst then version = gConst end
            end

            if type(version) == "table" then
                version = table.concat(version, ".")
            end

            if version and version ~= "" then
                addlist = addlist .. "  " .. name .. " (v" .. tostring(version) .. ")\n"
            else
                addlist = addlist .. "  " .. name .. "\n"
            end
        end
    end
    return addlist
end

-------------------------------------------------------------------------------
-- Debug Mode Registry & Logging API
-------------------------------------------------------------------------------

--- Register a suite addon with OneSwatter
-- @param addon string: Addon name (e.g. "MovableFrames")
-- @param defaultDebugState boolean|nil: Initial debug flag if not already set in DB
function OneSwatter:RegisterAddon(addon, defaultDebugState)
    if not addon or type(addon) ~= "string" then return end
    OneSwatterDB.registeredAddons = OneSwatterDB.registeredAddons or {}
    OneSwatterDB.registeredAddons[addon] = true

    if defaultDebugState ~= nil and OneSwatterDB.debugModes[addon] == nil then
        OneSwatterDB.debugModes[addon] = defaultDebugState
    end

    if self.UI and self.UI.UpdateAddonDropdown then
        self.UI:UpdateAddonDropdown()
    end
end

--- Check if Debug Mode is enabled for a given addon
-- @param addon string: Addon name (e.g. "MovableFrames")
-- @return boolean: True if debug mode is enabled for this addon or globally
function OneSwatter:IsDebugMode(addon)
    if not OneSwatterDB or not OneSwatterDB.enabled then return false end
    if OneSwatterDB.debugModes["ALL"] then return true end
    if not addon then return false end
    return OneSwatterDB.debugModes[addon] == true
end

--- Enable or disable Debug Mode for a specific addon
-- @param addon string: Addon name (e.g. "MovableFrames")
-- @param enabled boolean: Debug mode state
function OneSwatter:SetDebugMode(addon, enabled)
    if not addon or type(addon) ~= "string" then return end
    OneSwatterDB.debugModes = OneSwatterDB.debugModes or {}
    OneSwatterDB.debugModes[addon] = enabled and true or false

    self:RegisterAddon(addon)

    local statusStr = enabled and "|cff00ff00ENABLED|r" or "|cffff3333DISABLED|r"
    self:Print("Debug mode for |cff00ccff" .. addon .. "|r is now " .. statusStr)

    if self.UI and self.UI.RefreshDebugLogs then
        self.UI:RefreshDebugLogs()
    end
end

--- Toggle Debug Mode state for a specific addon
-- @param addon string: Addon name
-- @return boolean: New debug mode state
function OneSwatter:ToggleDebugMode(addon)
    local newState = not self:IsDebugMode(addon)
    self:SetDebugMode(addon, newState)
    return newState
end

--- Primary Log Capture API for OneSuite AddOns
-- @param targetAddon string: Name of calling addon (e.g. "MovableFrames", "OnePanel")
-- @param level string: Log severity ("TRACE", "DEBUG", "INFO", "WARN", "ERROR")
-- @param category string: Subsystem/category tag (e.g. "Bags", "Layout", "EventBus")
-- @param message string: Primary log text
-- @param extraData any|nil: Optional data payload, table, or state object to inspect
function OneSwatter:Log(targetAddon, level, category, message, extraData)
    if not OneSwatterDB or not OneSwatterDB.enabled then return end

    level = (level or "INFO"):upper()
    targetAddon = targetAddon or "General"
    category = category or "General"

    -- Register addon automatically when it logs
    self:RegisterAddon(targetAddon)

    -- Filter DEBUG and TRACE logs unless Debug Mode is active for this addon
    if (level == "DEBUG" or level == "TRACE") and not self:IsDebugMode(targetAddon) then
        return
    end

    local detailText = nil
    if extraData ~= nil then
        detailText = self:Dump(extraData)
    end

    local logEntry = {
        id = (#(OneSwatterDB.debugLogs or {}) + 1),
        timestamp = date("%Y-%m-%d %H:%M:%S"),
        addon = targetAddon,
        category = category,
        level = level,
        message = tostring(message or ""),
        details = detailText,
    }

    table.insert(OneSwatterDB.debugLogs, logEntry)

    -- Limit history size
    local maxLogs = OneSwatterDB.maxLogs or self.MAX_LOGS_DEFAULT
    while #OneSwatterDB.debugLogs > maxLogs do
        table.remove(OneSwatterDB.debugLogs, 1)
    end

    -- Live refresh UI if open
    if self.UI and self.UI.frame and self.UI.frame:IsShown() then
        self.UI:RefreshDebugLogs()
    end
end

--- Convenient shortcut for logging debug messages from OneSuite addons
-- @param targetAddon string
-- @param category string
-- @param message string
-- @param extraData any|nil
function OneSwatter:LogDebug(targetAddon, category, message, extraData)
    self:Log(targetAddon, "DEBUG", category, message, extraData)
end

-------------------------------------------------------------------------------
-- Lua Error Handler & Deduplication
-------------------------------------------------------------------------------

local nilFrame = {
    GetName = function() return "Global" end
}

--- Catch unhandled Lua runtime errors
-- @param msg string: Error message
-- @param frame table|nil: Associated UI frame context
-- @param stack string|nil: Custom stack trace
-- @param etype string|nil: Event type (for protected action errors)
-- @return any
function OneSwatter.OnError(msg, frame, stack, etype, ...)
    if not OneSwatterDB or not OneSwatterDB.enabled then
        if etype then
            return UIParent_OnEvent and UIParent_OnEvent(etype, ...)
        elseif OneSwatter.origHandler then
            return OneSwatter.origHandler(msg, frame)
        else
            return
        end
    end

    msg = msg or "Unknown error"
    frame = frame or nilFrame
    stack = stack or (debugstack and debugstack(2, 20, 20)) or ""

    local context = "Global"
    if frame and type(frame) == "table" and frame.GetName and frame:GetName() then
        context = frame:GetName()
    end

    -- Clean & format context / stack
    local timestamp = date("%Y-%m-%d %H:%M:%S")

    -- Check for existing duplicate error
    local existingIndex = nil
    for idx, errObj in ipairs(OneSwatterDB.errors) do
        if errObj.message == msg and errObj.context == context then
            existingIndex = idx
            break
        end
    end

    if existingIndex then
        local errObj = table.remove(OneSwatterDB.errors, existingIndex)
        errObj.count = (errObj.count or 1) + 1
        errObj.lastSeen = timestamp
        errObj.stack = stack
        table.insert(OneSwatterDB.errors, errObj) -- Push to end (most recent)
    else
        local newErr = {
            id = #OneSwatterDB.errors + 1,
            context = context,
            timestamp = timestamp,
            lastSeen = timestamp,
            message = msg,
            stack = stack,
            addons = OneSwatter:GetAddOnList(),
            count = 1,
        }
        table.insert(OneSwatterDB.errors, newErr)
    end

    -- Enforce history limit
    local maxErrors = OneSwatterDB.maxErrors or OneSwatter.HISTORY_SIZE_DEFAULT
    while #OneSwatterDB.errors > maxErrors do
        table.remove(OneSwatterDB.errors, 1)
    end

    -- Play optional sound alert
    if OneSwatterDB.soundAlert then
        PlaySoundFile("Sound\\Interface\\RaidWarning.wav")
    end

    -- Show UI or Chat link
    local errId = #OneSwatterDB.errors
    if OneSwatterDB.autoshow then
        if OneSwatter.UI and OneSwatter.UI.ShowError then
            OneSwatter.UI:ShowError(errId)
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "|cffffcc00[OneSwatter]|r |cffff3333Error caught in [%s]:|r |Honeswatter:%d|h|cff00ccff[Click to View #%d]|r|h",
            context, errId, errId
        ))
    end
end

-------------------------------------------------------------------------------
-- Hyperlink Link Handler Hook (|Honeswatter:<id>|h)
-------------------------------------------------------------------------------

function OneSwatter.SetItemRef(link, text, button, ...)
    if link and link:sub(1, 11) == "oneswatter:" then
        local errId = tonumber(link:sub(12))
        if errId and OneSwatter.UI and OneSwatter.UI.ShowError then
            OneSwatter.UI:ShowError(errId)
        end
        return
    end
    if OneSwatter.origItemRef then
        return OneSwatter.origItemRef(link, text, button, ...)
    end
end

-------------------------------------------------------------------------------
-- Addon Lifecycle Events & Initialization
-------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame", "OneSwatter_EventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("ADDON_ACTION_BLOCKED")
eventFrame:RegisterEvent("ADDON_ACTION_FORBIDDEN")

eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2, ...)
    if event == "ADDON_LOADED" and arg1:lower() == "oneswatter" then
        -- SavedVariables Setup
        _G.OneSwatterDB = _G.OneSwatterDB or {}
        for k, v in pairs(defaultDB) do
            if _G.OneSwatterDB[k] == nil then
                if type(v) == "table" then
                    _G.OneSwatterDB[k] = {}
                    for subK, subV in pairs(v) do
                        _G.OneSwatterDB[k][subK] = subV
                    end
                else
                    _G.OneSwatterDB[k] = v
                end
            end
        end

        -- Ensure errors and debugLogs tables exist
        _G.OneSwatterDB.errors = _G.OneSwatterDB.errors or {}
        _G.OneSwatterDB.debugLogs = _G.OneSwatterDB.debugLogs or {}
        _G.OneSwatterDB.debugModes = _G.OneSwatterDB.debugModes or {}
        _G.OneSwatterDB.registeredAddons = _G.OneSwatterDB.registeredAddons or {}

        -- Set active error handler
        seterrorhandler(OneSwatter.OnError)
        _G.SetItemRef = OneSwatter.SetItemRef

        -- Integrate with OnePanelUtils if present
        if _G.OnePanelUtils and _G.OnePanelUtils.Logger then
            local origLog = _G.OnePanelUtils.Logger.Log
            _G.OnePanelUtils.Logger.Log = function(loggerSelf, tag, level, message, ...)
                if origLog then origLog(loggerSelf, tag, level, message, ...) end
                OneSwatter:Log("OnePanelUtils", level, tag, message, ...)
            end
        end

        OneSwatter:Print("v" .. OneSwatter.version .. " loaded. Ready to catch errors and debug details.")
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "ADDON_ACTION_BLOCKED" then
        local addon, func = arg1, arg2
        local msg = string.format("Protected function call blocked: AddOn '%s' attempted to call '%s'", tostring(addon), tostring(func))
        OneSwatter.OnError(msg, OneSwatter.NamedFrame and OneSwatter.NamedFrame("AddOn: " .. tostring(addon)), (debugstack and debugstack(2, 20, 20)), event, arg1, arg2, ...)

    elseif event == "ADDON_ACTION_FORBIDDEN" then
        local addon, func = arg1, arg2
        local msg = string.format("Forbidden function call: AddOn '%s' attempted to call '%s'", tostring(addon), tostring(func))
        OneSwatter.OnError(msg, OneSwatter.NamedFrame and OneSwatter.NamedFrame("AddOn: " .. tostring(addon)), (debugstack and debugstack(2, 20, 20)), event, arg1, arg2, ...)
    end
end)

-------------------------------------------------------------------------------
-- Helper Utility Methods & Slash Commands
-------------------------------------------------------------------------------

function OneSwatter:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[OneSwatter]|r " .. tostring(msg))
end

SLASH_ONESWATTER1 = "/oneswatter"
SLASH_ONESWATTER2 = "/oneswat"
SLASH_ONESWATTER3 = "/swat"

SlashCmdList["ONESWATTER"] = function(msg)
    msg = msg and msg:match("^%s*(.-)%s*$") or ""
    local cmd, arg = msg:match("^(%S+)%s*(.-)$")
    cmd = cmd and cmd:lower() or ""

    if cmd == "" or cmd == "show" then
        if OneSwatter.UI then
            OneSwatter.UI:Toggle()
        end
    elseif cmd == "enable" then
        OneSwatterDB.enabled = true
        OneSwatter:Print("Error capture and debug logging |cff00ff00ENABLED|r.")
    elseif cmd == "disable" then
        OneSwatterDB.enabled = false
        OneSwatter:Print("Error capture and debug logging |cffff3333DISABLED|r.")
    elseif cmd == "autoshow" then
        OneSwatterDB.autoshow = not OneSwatterDB.autoshow
        local status = OneSwatterDB.autoshow and "|cff00ff00ENABLED|r" or "|cffff3333DISABLED|r"
        OneSwatter:Print("Auto-popup window on error is now " .. status)
    elseif cmd == "debug" then
        if arg == "" then
            OneSwatter:Print("Usage: /oneswat debug <AddonName> [on|off]")
        else
            local targetAddon, state = arg:match("^(%S+)%s*(%S*)$")
            if state:lower() == "on" or state:lower() == "1" or state:lower() == "enable" then
                OneSwatter:SetDebugMode(targetAddon, true)
            elseif state:lower() == "off" or state:lower() == "0" or state:lower() == "disable" then
                OneSwatter:SetDebugMode(targetAddon, false)
            else
                OneSwatter:ToggleDebugMode(targetAddon)
            end
        end
    elseif cmd == "debuglist" then
        OneSwatter:Print("--- Suite Addon Debug Modes ---")
        for addon in pairs(OneSwatterDB.registeredAddons or {}) do
            local isEnabled = OneSwatter:IsDebugMode(addon)
            local statusStr = isEnabled and "|cff00ff00ENABLED|r" or "|cff808080DISABLED|r"
            DEFAULT_CHAT_FRAME:AddMessage("  - " .. addon .. ": " .. statusStr)
        end
    elseif cmd == "nudge" then
        if OneSwatter.Nudger then
            OneSwatter.Nudger:Toggle()
        end
    elseif cmd == "clear" then
        OneSwatterDB.errors = {}
        OneSwatterDB.debugLogs = {}
        OneSwatter:Print("All recorded errors and debug logs have been cleared.")
        if OneSwatter.UI and OneSwatter.UI.frame and OneSwatter.UI.frame:IsShown() then
            OneSwatter.UI:RefreshAll()
        end
    elseif cmd == "help" then
        OneSwatter:Print("Available Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  /oneswat                 - Toggle OneSwatter window")
        DEFAULT_CHAT_FRAME:AddMessage("  /oneswat nudge           - Toggle popout Frame Nudger HUD")
        DEFAULT_CHAT_FRAME:AddMessage("  /oneswat enable|disable  - Enable or disable error capture")
        DEFAULT_CHAT_FRAME:AddMessage("  /oneswat autoshow        - Toggle automatic UI popup on error")
        DEFAULT_CHAT_FRAME:AddMessage("  /oneswat debug <Addon>  - Toggle debug mode for a suite addon")
        DEFAULT_CHAT_FRAME:AddMessage("  /oneswat debuglist      - View debug status for all registered addons")
        DEFAULT_CHAT_FRAME:AddMessage("  /oneswat clear          - Clear all recorded errors & logs")
        DEFAULT_CHAT_FRAME:AddMessage("  /oneswat help           - Display this help information")
    else
        OneSwatter:Print("Unknown command '" .. cmd .. "'. Type |cff00ccff/oneswat help|r for available commands.")
    end
end

-- SlideBar / LibStub Launcher Integration
if LibStub then
    local SlideBar = LibStub:GetLibrary("SlideBar", true)
    if SlideBar then
        local sideIcon = SlideBar.AddButton("OneSwatter", "Interface\\AddOns\\OneSwatter\\Textures\\SwatterIcon", 9000)
        if sideIcon then
            sideIcon:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            sideIcon:SetScript("OnClick", function()
                if OneSwatter.UI then OneSwatter.UI:Toggle() end
            end)
            sideIcon.tip = {
                "OneSwatter",
                "Error capture, debug logging, and diagnostic tool for OneSuite addons.",
                "|cff00ccffClick|r to open OneSwatter UI.",
            }
        end
    end
end
