# Maconky

Conky for Mac. A native macOS desktop HUD that sits on the wallpaper and reports clock, host, CPU (per-core + history), memory, GPU, disks, network, battery, and top processes.

Linux has [Conky](https://github.com/brndnmtthw/conky). Maconky is a from-scratch Swift app for that same always-on desktop monitor on macOS 14+.

## Install

Needs macOS 14+ and [Xcode Command Line Tools](https://developer.apple.com/download/all/?q=command%20line%20tools) (`xcode-select --install`). The app is **compiled on your Mac**, so Gatekeeper does not block it.

```bash
git clone https://github.com/giozenone/maconky.git
cd maconky
./install.sh
```

That builds for this machine’s CPU, puts `Maconky.app` in `~/Applications`, and launches it. Look for the gauge icon in the menu bar. First compile takes a minute or so.

Homebrew (builds from source, same idea):

```bash
brew tap giozenone/maconky https://github.com/giozenone/maconky
brew install --HEAD maconky
open "$(brew --prefix maconky)/Maconky.app"
```

A prebuilt zip is on [Releases](https://github.com/giozenone/maconky/releases/latest) if you would rather not compile. Unsigned downloads are blocked on current macOS unless you run `xattr -cr` on the app, or until the project is notarized.

## Features

- **Desktop widget** — sits above the wallpaper and desktop icons, underneath other windows
- **Overlay / always-on-top** modes from the menu bar
- **Conky-style transparency** — borderless, ARGB panel; optional frosted blur
- **Click-through** so the desktop stays usable
- Menu bar extra for show/hide, snap-to-corner, settings, and launch-at-login
- No Dock icon (`LSUIElement`)

## Build and run

Requires macOS 14+ and Swift 6 (Xcode or Command Line Tools). Release builds are **universal** (Intel + Apple Silicon) by default.

```bash
make run
```

That compiles a release binary, wraps it as `Maconky.app`, and opens it. After launch, look for the gauge icon in the menu bar.

```bash
make app                 # universal (arm64 + x86_64)
make ARCHS=x86_64 app    # Intel only
make ARCHS=arm64 app     # Apple Silicon only
make clean
```

GitHub Actions on `main` uploads a universal `Maconky-universal.zip` artifact.

## Using it

1. The widget appears on the **top-left** of the leftmost display by default.
2. Open the **Maconky** menu bar extra.
3. Turn on **Edit / move**, then drag the panel. Turn **Click-through** back on when it is placed.
4. **Show as → Desktop** is the Conky-like mode. Overlay and Always on top keep it visible over apps.
5. Settings control opacity, width, accent color, modules, and refresh rate.

Install from source with `./install.sh` if you want to skip Gatekeeper. A GitHub `.app` zip is still quarantined until the project is notarized.

## Notes

- GPU numbers come from `IOAccelerator` performance statistics when the driver publishes them.
- Process CPU% can exceed 100% on multi-core chips, matching Activity Monitor.
- Apple Silicon die temperature is not exposed through public APIs; Maconky shows thermal pressure instead.
