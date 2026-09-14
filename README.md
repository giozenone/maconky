# Maconky

Conky for Mac. A native macOS desktop HUD that sits on the wallpaper and reports clock, host, CPU (per-core + history), memory, GPU, disks, network, battery, and top processes.

Linux has [Conky](https://github.com/brndnmtthw/conky). Maconky is a from-scratch Swift app for that same always-on desktop monitor on macOS 14+.

## Download

Universal app for Intel and Apple Silicon:

**[Download Maconky](https://github.com/giozenone/maconky/releases/latest)**

Unzip `Maconky-universal.zip`. If macOS blocks it, right-click **Maconky.app** → **Open**.

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

On first launch macOS may ask you to allow an unsigned local build. The package script ad-hoc signs the app for that reason. Shared copies are not notarized: right-click the app → **Open** if Gatekeeper blocks it.

## Notes

- GPU numbers come from `IOAccelerator` performance statistics when the driver publishes them.
- Process CPU% can exceed 100% on multi-core chips, matching Activity Monitor.
- Apple Silicon die temperature is not exposed through public APIs; Maconky shows thermal pressure instead.
