# Overwatch

A native macOS desktop monitor in the spirit of [Conky](https://github.com/brndnmtthw/conky). Overwatch draws a translucent, always-available HUD on the desktop and reports the usual system stats: clock, host, CPU (per-core + history), memory, GPU, disks, network, battery, and top processes.

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

That compiles a release binary, wraps it as `Overwatch.app`, and opens it. After launch, look for the gauge icon in the menu bar.

```bash
make app                 # universal (arm64 + x86_64)
make ARCHS=x86_64 app    # Intel only
make ARCHS=arm64 app     # Apple Silicon only
make clean
```

GitHub Actions on `main` uploads a universal `Overwatch-universal.zip` artifact.

## Using it

1. The widget appears on the **top-left** of the leftmost display by default.
2. Open the **Overwatch** menu bar extra.
3. Turn on **Edit / move**, then drag the panel. Turn **Click-through** back on when it is placed.
4. **Show as → Desktop** is the Conky-like mode. Overlay and Always on top keep it visible over apps.
5. Settings control opacity, width, accent color, modules, and refresh rate.

On first launch macOS may ask you to allow an unsigned local build. The package script ad-hoc signs the app for that reason.

## Notes

- GPU numbers come from `IOAccelerator` performance statistics when the driver publishes them.
- Process CPU% can exceed 100% on multi-core chips, matching Activity Monitor.
- Apple Silicon die temperature is not exposed through public APIs; Overwatch shows thermal pressure instead.
