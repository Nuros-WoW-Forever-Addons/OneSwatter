# OneSwatter 

**OneSwatter** is an error capture, stack tracing, and debug logging tool built for World of Warcraft UI development and the **OneSuite** addon ecosystem (compatible with Vanilla 1.12, TBC 2.4.3, WotLK 3.3.5, and Modern WoW clients).

It modernizes and extends the classic `!Swatter` addon, providing both unhandled Lua error interception and a **Suite Debug Mode** system that allows `OneXXX` addons (e.g. `MovableFrames`, `OnePanel`, `OnePanel_Character`, `ShortKeybinds`) to record detailed debug logs, state dumps, and event traces.

---

## Key Features

- **Automatic Lua Error Interception**: Overrides `seterrorhandler()` to capture unhandled runtime errors, frame contexts, call stacks (`debugstack`), and active addon versions.
- **Error Deduplication & Count Tracking**: Groups identical errors and tracks repeat counts without cluttering chat or spamming windows.
- **Suite Debug Mode System**: Register debug modes for individual addons (e.g., `MovableFrames`, `OnePanel`). When debug mode is enabled for an addon, detailed diagnostic logs and table dumps are stored.
- **Table Serialization (`Dump`)**: Built-in pretty-printer for inspecting Lua tables, frame states, and event payloads directly in the debug viewer.
- **Dual-Tab In-Game Diagnostic UI**:
  - **Errors Tab**: Inspect captured Lua errors, cycle with `< Prev` / `Next >`, auto-select all text for 1-click copy-pasting into bug reports or IDEs.
  - **Debug Logs Tab**: Live filtering by Addon and Log Level (`DEBUG`, `INFO`, `WARN`, `ERROR`), live text search, and toggle debug mode on the fly per addon.
  - **Settings Tab**: Master checklist to toggle Debug Mode for every `OneXXX` addon from a single window.
- **Popout Frame Nudger HUD (`/oneswat nudge`)**:
  - Compact, draggable floating micro-inspector.
  - **Mouse-Over Element Picker**: Highlights elements with a green outline and locks onto the selected target on click.
  - **4-Way Cross D-Pad**: Move elements pixel-by-pixel (1px, 5px, 10px) with center Reset (↺) button.
  - **Dynamic Sizing Control**: Uniform sizing (Up / Reset / Down) by default, or independent Width (◄ ↺ ►) & Height (▲ ↺ ▼) controls via checkbox.
  - **Live Code Generator**: Generates clean `SetPoint` and `SetSize` Lua snippets with 1-click select/copy.
- **Seamless `OnePanelUtils` Integration**: Automatically hooks into `OnePanelUtils.Logger` so existing suite log calls stream directly into `OneSwatter`.

---

## How to Enable & Use Debug Mode in `OneXXX` Addons

### 1. In-Game Debug Mode Toggles
You can toggle Debug Mode for any `OneXXX` addon in three ways:
1. **Slash Command**: `/oneswat debug MovableFrames on` (or `/oneswat debug MovableFrames off`)
2. **UI Checkbox**: Open `/oneswat`, go to **Debug Logs**, select the addon from the dropdown, and check **[X] Debug Mode**.
3. **Master Checklist**: Open `/oneswat`, go to **Settings & Suite**, and check/uncheck any addon in the checklist.

### 2. Adding Debug Logging to your Addon Code

In your `OneXXX` addon, you can log debug details directly using `OneSwatter`:

```lua
-- Register your addon with OneSwatter on load (optional, happens automatically on first log)
if _G.OneSwatter then
    _G.OneSwatter:RegisterAddon("MovableFrames", false) -- Addon name, default state (false)
end

-- Check if Debug Mode is enabled for your addon
if _G.OneSwatter and _G.OneSwatter:IsDebugMode("MovableFrames") then
    -- Log a debug message with an optional table dump payload!
    _G.OneSwatter:LogDebug("MovableFrames", "Bags", "Container position updated", {
        frame = "ContainerFrame1",
        x = 120,
        y = -45,
        userLocked = true
    })
end
```

### 3. General Logging API

`OneSwatter` supports multiple log severity levels (`"TRACE"`, `"DEBUG"`, `"INFO"`, `"WARN"`, `"ERROR"`):

```lua
-- Warn and Error levels are captured regardless of debug mode state
_G.OneSwatter:Log("MovableFrames", "WARN", "Layout", "Target frame was protected during combat!")

-- Debug and Trace levels are only recorded when Debug Mode is active for that addon
_G.OneSwatter:Log("OnePanel", "DEBUG", "TabManager", "Switching active tab to Professions", { tabId = 3 })
```

---

## Slash Commands

| Command | Action |
| :--- | :--- |
| `/oneswatter` or `/oneswat` or `/swat` | Toggle the OneSwatter diagnostic window |
| `/oneswat nudge` | Toggle the popout Frame Nudger HUD |
| `/oneswat enable` / `/oneswat disable` | Enable or disable global error catching & logging |
| `/oneswat autoshow` | Toggle automatic window popup when an error occurs |
| `/oneswat debug <Addon> [on\|off]` | Enable, disable, or toggle debug mode for a suite addon |
| `/oneswat debuglist` | List all registered suite addons and their debug status |
| `/oneswat clear` | Clear all recorded errors and debug logs |
| `/oneswat help` | Display in-game command assistance |

---

## File Structure

```
OneSwatter/
├── OneSwatter.toc       # Addon manifest
├── OneSwatter.lua       # Core error handler, debug logging API, table serializer, slash commands
├── OneSwatterUI.lua     # Dual-tab UI frame (Errors, Debug Logs, Settings)
├── OneSwatterNudger.lua # Popout Frame Nudger HUD (D-Pad, sizing controls, picker)
├── Textures/
│   └── SwatterIcon.blp  # OneSwatter launcher icon
└── README.md            # Documentation
```
