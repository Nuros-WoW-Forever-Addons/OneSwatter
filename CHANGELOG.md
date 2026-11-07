# Changelog — OneSwatter

All notable changes to **OneSwatter** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.1] - 2026-11-06
### Added
- **OneAddon Chat Tab Integration**:
  - Automatically routes all addon prints, caught error chat links, and slash command feedback to the dedicated `"OneAddon"` chat tab instead of General chat.
  - Automatically creates and docks the `"OneAddon"` chat tab if missing, keeping public chat channels isolated.
- **Settled Startup Announcement**:
  - Deferred initial startup announcement to `PLAYER_ENTERING_WORLD` with a `C_Timer.After(0.4)` delay, ensuring Blizzard chat frame docking and tabs are fully settled before printing.

## [1.0.0] - 2026-10-10
### Added
- **Automatic Lua Error Interception**: Replaced standard `seterrorhandler()` to capture unhandled errors, frame context, and call stacks (`debugstack`) without freezing the client.
- **Error Deduplication & Counter**: Intelligently groups identical errors and tracks repeat counts to eliminate chat spam.
- **Suite Debug Mode Infrastructure**: Addon registration API (`RegisterAddon`) enabling selective debug tracing, table dumps, and event logs per addon.
- **Dual-Tab In-Game Diagnostic UI**:
  - **Errors Tab**: Visual error list with `< Prev` / `Next >` navigation and 1-click select/copy box.
  - **Debug Logs Tab**: Live filtering by Addon and Severity (`DEBUG`, `INFO`, `WARN`, `ERROR`), with live text searching.
  - **Settings Tab**: Master checklist to toggle debug logging for all registered suite addons.
- **Popout Frame Nudger HUD (`/oneswat nudge`)**: Floating pixel-nudging micro-inspector with interactive mouse target picker, D-Pad movement controls, sizing adjustments, and live Lua `SetPoint` code generator.
- **OnePanelUtils & OneStorageUtils Integration**: Seamless bridge listening to suite `Logger` instances for unified error monitoring.
