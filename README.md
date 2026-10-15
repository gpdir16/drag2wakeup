# drag2wakeup

A tiny macOS menu bar app. Drag the icon down to keep your Mac awake.

## Usage

Press and hold the cup icon in the menu bar, drag down, then let go.

- **How far down**: duration (5 min to 12 h, drag all the way for no limit)
- **Center**: Keep Awake. The display stays on.
- **Right**: Screen Off. The display can sleep, but the Mac stays awake.
- **Left** (only while on): Turn Off.

A plain click opens the menu (Turn Off, Launch at Login, Quit).

No permissions needed.

## Build

Requires macOS 14+ and Xcode.

```bash
./build.sh
```

The app is created at `build/drag2wakeup.app`.

## How it works

Same as the `caffeinate` command. The app asks macOS not to sleep (an IOPMAssertion) and releases the request when time runs out.

## License

[Unlicense](LICENSE) (public domain)
