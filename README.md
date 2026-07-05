# Sura

Small Windows tray/overlay launcher for Steam games with optional [TcNo Account Switcher](https://github.com/Tc-No/TcNo-Acc-Switcher) integration. Shows a compact progress UI while switching accounts, launching games, and hiding transient Steam windows.

## What it does

- `start` — close Steam if needed, switch account via TcNo, launch a Steam game silently
- `start<appid>` — launch a game without a full account-switch flow
- `start nsg` — launch a non-Steam executable with progress watching
- `switch` — switch account and open Steam
- `close` — kill Steam, switch back to a default account, optional extra process cleanup
- `preview` — dry-run the loading UI without executing external tools
- `watch` — follow a status file written by the game watcher script

## Requirements

- Windows 10/11
- [Rust](https://rustup.rs/) and [Node.js](https://nodejs.org/) for building
- [.NET is not required](.) — native Tauri binary
- [TcNo Account Switcher](https://github.com/Tc-No/TcNo-Acc-Switcher) installed if you use account switching
- [AutoHotkey v1.1](https://www.autohotkey.com/) for the legacy helper scripts (optional)

## Configuration

Edit the defaults at the top of these files before first use:

**`src-tauri/src/lib.rs`**

```rust
const DEFAULT_CLOSE_ACCOUNT: &str = "+s:YOUR_STEAM_ID:0";
const DEFAULT_KILL_STEAM: &str = r"C:\Path\To\kill-steam.exe";
```

**`Steam Game CLI.ahk`** — same placeholders for `DefaultCloseAccount` and `DefaultKillSteam`.

TcNo account arguments use TcNo's `+s:STEAM_ID:INDEX` format. Get the values from TcNo Account Switcher.

## Build

```bash
npm install
npm run tauri build
```

The release binary lands under `src-tauri/target/release/`. Prebuilt `Sura.exe` is not checked into this repo.

## Usage examples

```text
Sura.exe start "+s:YOUR_STEAM_ID:0" 3017860 "My Game"
Sura.exe start3017860 "My Game"
Sura.exe switch "+s:YOUR_STEAM_ID:0"
Sura.exe close
Sura.exe preview start
```

Legacy AutoHotkey entry point:

```text
Steam Game CLI.ahk start "+s:YOUR_STEAM_ID:0" 3017860 "My Game"
```

## Notes

- Hides Steam "Launching..." and update splash windows during launch.
- Account switching depends on third-party tools and your own Steam library setup.
- Use responsibly and in line with Steam's terms of service.

## License

MIT
