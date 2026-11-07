# AI Context & Living Specification — OneSwatter

> **Living Document**: This file serves as the primary context, architectural specification, and state-handoff document for AI-assisted development across sessions. Update this file on every development cycle ("spin").

---

## 🎯 Overview & Scope

- **Addon Name**: OneSwatter
- **Current Version**: 1.0.1
- **Suite**: Part of the **OneSuite** family (Core Diagnostic Backbone)
- **GitHub Repository**:
  - Exists: TRUE
  - URL: https://github.com/Nuros-WoW-Forever-Addons/OneSwatter
  *(For any new addon, initialize with Exists: FALSE until first commit/push)*
- **Branching Policy**: All new features must be developed on a branch != `main` (e.g. `feature/<name>`)
- **Live Sync Path**: `/Applications/World of Warcraft/_forever_/Interface/AddOns/OneSwatter/`
- **Rollback Target**: Last working `main` branch commit
- **Release Package**: `.github/workflows/package.yml` generates `OneSwatter-latest.zip` on push to `main`
- **Target WoW Runtimes**: WoW Forever Beta (v1.60.1 / Interface 16001)
- **Primary Goal**: Provide non-blocking runtime error capture, call stack extraction (`debugstack`), suite debug logging, table serialization, and interactive pixel inspection HUD (`/oneswat nudge`) for rapid development and testing across all OneSuite addons.

---

## 🏗️ Architecture & Component Map

### File Structure
- `OneSwatter.toc`: Manifest, load order, SavedVariables declaration (`OneSwatterDB`), optional dependencies (`OnePanelUtils`, `SlideBar`).
- `OneSwatter.lua`: Core runtime engine, `seterrorhandler` hook, error deduplication ring-buffer, table serializer (`Dump`), logger API (`Log`, `LogDebug`), and slash commands (`/oneswatter`, `/oneswat`, `/swat`).
- `OneSwatterUI.lua`: Tabbed diagnostic viewer (Errors Tab, Debug Logs Tab with search filter, Settings Tab with master suite checklist).
- `OneSwatterNudger.lua`: Floating pixel-nudging micro-inspector HUD (`/oneswat nudge`) with mouse target picker, 4-way D-Pad, dimension scalers, and live Lua code generator.
- `Textures/SwatterIcon.blp`: Minimap and launcher icon asset.

### Global State & Database Schema (`OneSwatterDB`)
```lua
OneSwatterDB = {
    enabled = true,                    -- Global error interception toggle
    autoShow = false,                  -- Automatically popup UI on first error
    maxErrors = 100,                   -- Maximum captured error records
    maxLogs = 500,                     -- Maximum debug log records
    registeredAddons = {               -- Registered addons and debug status
        ["MovableFrames"] = false,
        ["OnePanel"] = true,
        ["OneStorageBag"] = false,
        ...
    },
    errorHistory = {},                 -- Array of error objects { msg, stack, count, timestamp }
    logHistory = {},                   -- Array of log records { addon, level, module, msg, data, timestamp }
}
```

---

## 🔄 AI Development Cycle & Handoff Protocol

When picking up development on this addon:

1. **Orientation**: Read `CONTEXT.md` (this file) to verify current state, known issues, and active backlog items.
2. **Implementation**: Execute changes. For code refactoring or boilerplate, delegate to `qwen2.5-coder:32b` via the local `gx10_ollama` MCP server as mandated by user rules.
3. **Verification**: Verify in-game syntax and test using `/oneswat` and `/oneswat nudge`.
4. **Handoff Update**:
   - Move completed tasks from **Upcoming Backlog** to **Recent Completed Work**.
   - If user-facing features or commands changed, update `README.md` and append a new section in `CHANGELOG.md`.
   - Document newly discovered backlog items or edge cases in **Upcoming Backlog**.

---

## ✅ Recent Completed Work (Latest Spins)

### Spin 1.0.1
- Added automatic `"OneAddon"` chat tab integration:
  - Ensured standalone tab creation, docked to `GENERAL_CHAT_DOCK` with public channel isolation.
  - Routed all `OneSwatter:Print`, caught error notifications, and slash command outputs to `"OneAddon"` chat tab instead of General chat.
  - Deferred initial startup announcement to `PLAYER_ENTERING_WORLD` with a `C_Timer.After(0.4)` settling delay.

### Spin 1.0.0
- Replaced classic `!Swatter` with modern multi-client error interception engine.
- Implemented error deduplication, table serializer, and dual-tab copyable UI.
- Built floating pixel-level Frame Nudger HUD (`/oneswat nudge`) with interactive target picker and live code generation.
- Integrated automatic listener hooks for `OnePanelUtils.Logger` and `OneStorageUtils.Logger`.

---

## 📋 Living Roadmap & Upcoming Backlog (Next Spins)

### Priority 1: High Priority (Immediate Next Spin)
- [ ] **SavedVariables Error Export**: Option to serialize captured errors directly to a clean table in `WTF/SavedVariables/OneSwatter.lua` for easy copy-pasting outside the game.
- [ ] **Frame Nudger Multi-Point Mode**: Extend Frame Nudger code generator to support dual-anchor frames (`TOPLEFT` + `BOTTOMRIGHT`).

### Priority 2: Medium Priority (Enhancements)
- [ ] **Minimap Launcher Icon**: Optional minimap button via `LibDataBroker` / `LibDBIcon` or native frame button to open `/oneswat` on click.
- [ ] **Sound Notification on Error**: Optional subtle audible click or chime when an error occurs while `autoShow` is disabled.

### Priority 3: Low Priority / Exploration
- [ ] **Stack Frame Symbolizer**: Clean Lua chunk strings in `debugstack` (e.g. `@Interface\AddOns\...`) into compact readable filenames and line numbers.

---

## 🧪 Testing & Verification Guide

- **Error Capture Test**: Run `/run error("OneSwatter verification test")`. Verify OneSwatter captures the error, tracks repeat count, and formats the stack trace cleanly.
- **Nudger Test**: Run `/oneswat nudge`. Click "Pick Target", mouse over any UI frame (e.g. ChatFrame1), verify green highlight, click, and use D-Pad to move by 1px.
- **Suite Debug Toggle**: Run `/oneswat debug MovableFrames on`. Verify `_G.OneSwatter:IsDebugMode("MovableFrames")` returns `true`.

---

## ⚠️ Technical Constraints & Engine Gotchas

- **Error Handler Infinite Loops**: Never allow code inside `seterrorhandler` or logging paths to trigger secondary errors. Always use guarded pcalls and string formatting fallbacks.
- **Combat Lockdown**: The diagnostic UI and Nudger HUD should never block or interfere with protected frames during combat lockdown.
