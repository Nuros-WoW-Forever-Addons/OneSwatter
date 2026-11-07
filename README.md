# OneSwatter

**OneSwatter** is an error capture, stack tracing, and real-time debug logging tool built for World of Warcraft UI development and the **OneSuite** addon ecosystem (compatible with Vanilla 1.12, TBC 2.4.3, WotLK 3.3.5, and Modern WoW clients).

Part of the **OneSuite** family of addons.

---

## 🚀 Features

- 🪲 **Automatic Lua Error Interception**: Overrides `seterrorhandler()` to capture unhandled runtime errors, frame contexts, call stacks (`debugstack`), and active addon versions without blocking client gameplay.
- 🔢 **Error Deduplication & Frequency Tracking**: Automatically groups identical errors and tracks repeat counts without cluttering chat or spamming popup dialogs.
- 📡 **Suite Debug Mode System**: Register debug modes for individual addons (e.g. `MovableFrames`, `OnePanel`, `OneStorageBag`). When enabled, detailed diagnostic traces and serialized table dumps are recorded.
- 🖥️ **Multi-Tab Diagnostic Interface**:
  - **Errors Tab**: Inspect captured errors, cycle with `< Prev` / `Next >`, and 1-click select/copy text into bug reports or IDEs.
  - **Debug Logs Tab**: Filter by Addon and Severity Level (`DEBUG`, `INFO`, `WARN`, `ERROR`), with live text search.
  - **Settings Tab**: Master checklist to toggle Debug Mode across all registered `OneSuite` addons simultaneously.
- 🎯 **Popout Frame Nudger HUD (`/oneswat nudge`)**:
  - Compact, draggable floating micro-inspector.
  - **Mouse Target Picker**: Hover over any UI element with bright green highlight and lock target on click.
  - **4-Way Cross D-Pad**: Move elements pixel-by-pixel (1px, 5px, 10px) with center Reset (↺) button.
  - **Dynamic Sizing**: Uniform sizing or independent Width & Height adjustments.
  - **Live Code Generator**: Generates clean `SetPoint` and `SetSize` Lua snippets with 1-click copy.
- 🔗 **Deep Suite Integration**: Automatically intercepts logging from `OnePanelUtils.Logger` and `OneStorageUtils.Logger`.

---

## 🛠️ Installation

Copy the `OneSwatter` directory into your World of Warcraft `Interface/AddOns/` directory:

```text
World of Warcraft/Interface/AddOns/OneSwatter/
├── OneSwatter.toc
├── OneSwatter.lua
├── OneSwatterUI.lua
├── OneSwatterNudger.lua
├── Textures/
│   └── SwatterIcon.blp
├── CHANGELOG.md
├── CONTEXT.md
└── README.md
```

Then start or reload World of Warcraft (`/reload`).

---

## 💻 Slash Commands

| Command | Description |
|---|---|
| `/oneswatter` or `/oneswat` or `/swat` | Open / toggle the OneSwatter diagnostic window |
| `/oneswat nudge` | Open / toggle the popout Frame Nudger HUD |
| `/oneswat enable` / `/oneswat disable` | Enable or disable global error interception |
| `/oneswat autoshow` | Toggle automatic window popup when an error occurs |
| `/oneswat debug <Addon> [on\|off]` | Toggle debug mode for a specific suite addon |
| `/oneswat debuglist` | List all registered suite addons and their debug status |
| `/oneswat clear` | Clear all recorded errors and debug logs |
| `/oneswat help` | Display in-game command assistance |

---

## 🔌 Suite Developer API

In any `OneSuite` or third-party addon, register and log diagnostics:

```lua
-- Optional registration on load
if _G.OneSwatter then
    _G.OneSwatter:RegisterAddon("MyAddon", false)
end

-- Check if Debug Mode is active for your addon
if _G.OneSwatter and _G.OneSwatter:IsDebugMode("MyAddon") then
    _G.OneSwatter:LogDebug("MyAddon", "Module", "Event processed", { id = 42, state = true })
end

-- Severity-based logging (WARN and ERROR are always captured)
if _G.OneSwatter then
    _G.OneSwatter:Log("MyAddon", "WARN", "Layout", "Protected frame during combat")
end
```

---

For detailed version history and release notes, see [CHANGELOG.md](CHANGELOG.md).
