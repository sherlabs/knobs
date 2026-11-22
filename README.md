# GlowBar

<p align="center"><img src="Assets/AppIcon.png" width="128" alt="GlowBar icon"></p>

A tiny, glassmorphic menu bar app that turns the backlit Apple logo on the
MacBook Pro on or off.

Under the hood it toggles:

```sh
sudo defaults write com.apple.CoreBrightness LEBacklightMode -int 0   # off
sudo defaults write com.apple.CoreBrightness LEBacklightMode -int 1   # on
```

GlowBar runs this through the standard macOS administrator prompt (password or
Touch ID), so it never stores credentials.

It also has a **Touch Input** switch, which flips the same setting as the Touch
pane in System Settings (`SidecarTouchInputDisabled` in `com.apple.universalaccess`).
No admin prompt is needed for that one.

![UI preview](Assets/ui-preview.svg)

## Download

Grab the notarized zip from [Releases](https://github.com/sherlabs/glowbar/releases/latest),
unzip, and drag GlowBar.app to Applications.

## Build

Requires macOS 13+ and Xcode or the Command Line Tools (Swift 5.9+).

```sh
./build.sh
open build/GlowBar.app
```

The app is menu bar only (no Dock icon). `build.sh` ad-hoc signs the bundle.

Releases are signed with a Developer ID and notarized by Apple. To produce one
yourself, run `Tools/notarize.sh` after `build.sh` (see the script for the
required environment variables).

## Notes

- The current state is remembered by the app; if it starts out of sync, toggle once.
- The logo may need a display sleep/wake before it reacts.
- Not affiliated with Apple. Use at your own risk.

## License

MIT, see [LICENSE](LICENSE).
