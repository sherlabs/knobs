# Knobs

<p align="center"><img src="Assets/AppIcon.png" width="128" alt="Knobs icon"></p>

A small, glassy menu bar toolkit for your Mac. One rotary knob for the fans, a quiet line of
live numbers, and switches for the little things macOS hides.

- **Fans:** live RPM for every fan. Drag the knob to set a speed, or choose Auto, Manual or
  Max. Fans always return to automatic when you quit, if Knobs stops responding, or if the CPU
  gets dangerously hot.
- **At a glance:** CPU and GPU load, memory use, system power (or battery), and a CPU
  temperature status.
- **Logo light:** switch the backlit Apple logo on MacBook Pro on or off.
- **Touch input:** the same switch as System Settings > Touch.
- **Self-updating:** checks GitHub Releases, verifies the checksum and the developer signature,
  then replaces itself. Turn it off from the `...` menu.

## Download

Get the notarized zip from [Releases](https://github.com/sherlabs/knobs/releases/latest), unzip, and
drag Knobs.app to Applications. Requires macOS 13 or later.

The first time, Knobs asks you to allow its helper in **System Settings > Login Items**. That is
the only approval: after it, fan control and the logo light work without password prompts.

## How it works

- **Menu bar app** (SwiftUI) reads sensors through the AppleSMC driver, with no privileges.
- **Helper** (`knobs-helper`, a launchd daemon registered with `SMAppService`) is the only part
  that runs as root. It exposes a deliberately narrow XPC interface (set fan speed as a fraction
  of each fan's range, full speed, back to auto, logo light) and refuses any caller that is not
  the Knobs app signed by the same developer team. Manual fan control expires without
  heartbeats from the app, and a thermal guard forces full speed at 98 C.
- **Updater** only installs a download whose SHA-256 matches the release checksum and that is
  signed by the same team as the running app.
- The SMC layer (`Sources/CSMC`) is original code written against the publicly known AppleSMC
  interface. No third-party fan-control code or assets are included.

## Build

Needs macOS 13+, Xcode (SwiftUI macros ship with Xcode, not the Command Line Tools) and Swift 5.9+.

```sh
./build.sh                      # ad-hoc signed: UI works, the fan helper does not
SIGN_IDENTITY="Developer ID Application: You (TEAMID)" ./build.sh   # full build
open build/Knobs.app
```

The helper only trusts an app signed by the same team as itself, so a fork needs its own
Developer ID. To produce a notarized release, run `Tools/notarize.sh` after `build.sh` (see the
script for the environment variables).

`smcprobe` is a small read-only diagnostic: `swift run smcprobe` prints the fans and
temperatures your Mac exposes. `swift run smcprobe --stats` prints load and power samples.

## Notes and limits

- Fan writes are tested on an Apple silicon MacBook Pro; other models may differ. Intel Macs are
  untested.
- The logo light switch writes `LEBacklightMode` in `com.apple.CoreBrightness`; the logo may need
  a display sleep and wake before it reacts.
- Not affiliated with Apple. Use at your own risk: setting fans below what macOS would choose can
  make your Mac run hotter.

## License

MIT, see [LICENSE](LICENSE).
