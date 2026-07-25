# Changelog

## 2.1.0 — 2026-07-25

- 🧩 **Real WidgetKit widget** — add *Rota → Now Playing* from macOS's widget
  gallery (right-click the desktop → Edit Widgets). Small, medium and large
  sizes with working play/pause, next/previous and favourite buttons.
- 🖼 **Hover-only chrome** — at rest the desktop widget shows *just* the album
  cover, like a photo widget; title, seek bar and controls fade in on hover.
- 🧊 **Native behaviours** — position locked by default (⌘-drag to move),
  drawn above macOS's own desktop widgets, pixel-exact placement via
  `rota://move` (corners, coordinates, or a full `gx/gy/w/h` frame).
- 🔁 **Launch at login** registered automatically on first run, so the widget
  is simply there after every reboot.
- ⬆️ Requires macOS 14+ (interactive widgets).

## 2.0.0 — 2026-07-25

Complete rewrite. 🎉

**Why:** v1 was built on MusicKit's `ApplicationMusicPlayer`, which is unreliable
on macOS outside of App Store distribution (authorization flows, entitlement and
App Group requirements, widget extensions that silently fail to control
playback). In practice the app didn't work when installed from source.

**What changed:**

- 🪟 Rota is now a **floating desktop widget** — a borderless, always-available
  mini player styled after Apple Music's own MiniPlayer.
- 🔌 Playback control now uses a direct **Apple Events bridge** to the Music
  app (the same proven approach used by established third-party mini players).
  No sign-in, no entitlements, no App Groups — it just works with whatever
  Apple Music is playing.
- 🎤 **New synced-lyrics mode** powered by LRCLIB, with karaoke-style
  highlighting, auto-scroll and click-to-seek.
- 🖱 Draggable seek bar, shuffle / repeat, volume, favourite, keyboard
  shortcuts, menu bar controls, launch at login.
- 📦 Build simplified to a pure SwiftPM package: `make app`. No Xcode project,
  no xcodegen, no signing setup.

**Removed:** MusicKit dependency, WidgetKit extension, iPod click-wheel mode
(may return as an easter egg), xcodegen setup.

## 1.0.0 — 2026-07-21

Initial release: MusicKit-based Liquid Glass player with WidgetKit widgets.
