# Keyboard layout indicator

A thin blue-and-yellow stripe down the left edge of the active screen, shown
while a non-Latin keyboard layout is selected.

macOS already shows the current input source in the menu bar, but the menu bar
is hidden in fullscreen — exactly where it is easiest to start typing in the
wrong layout. This draws an overlay instead, so the indicator stays visible
everywhere.

## Install

Requires [Hammerspoon](https://www.hammerspoon.org/).

```sh
cp hammerspoon/init.lua ~/.hammerspoon/init.lua
```

Reload the config from the Hammerspoon menu bar icon, and grant Accessibility
permission if prompted.

## Configure

Everything worth changing sits at the top of `init.lua`:

| Setting | Default | Meaning |
| --- | --- | --- |
| `BORDER_WIDTH` | `3` | Stripe thickness in points |
| `BORDER_COLOR_TOP` | blue | Upper half; any Hammerspoon colour table |
| `BORDER_COLOR_BOTTOM` | yellow | Lower half; any Hammerspoon colour table |
| `POLL_INTERVAL` | `0.1` | How often the layout is checked, in seconds |
| `HIGHLIGHT_SOURCES` | Ukrainian | Input source IDs that light up the stripe |

### Setting your own layout

`HIGHLIGHT_SOURCES` is keyed by exact input source ID. To find yours, switch to
the layout you want highlighted and run:

```sh
hs -c 'print(hs.keycodes.currentSourceID())'
```

Then add it:

```lua
local HIGHLIGHT_SOURCES = {
    ["com.apple.keylayout.Ukrainian"] = true,
}
```

Matching on a substring like `"Ukrainian"` is tempting but unreliable: custom
`.bundle` layouts get an `org.unknown.keylayout.` prefix and may carry a
non-Latin name, so their ID contains no recognisable English word at all.

## How it works

The stripe is an `hs.canvas` overlay at `windowLevels.overlay`, with
`canJoinAllSpaces` and `stationary` behaviour so it survives Space switches and
draws above fullscreen windows.

The canvas spans the entire screen and paints only its left edge, so it must
not intercept input: `clickActivating(false)` keeps it from raising Hammerspoon,
and `canvasMouseEvents(false, false, false, false)` leaves the window without
mouse tracking, so clicks fall through to the windows underneath.

A bottom bar was the first design, but a few points along the bottom edge is
easy to miss in peripheral vision; a vertical edge is much easier to catch.

Two implementation notes, both learned the hard way:

**Polling, not just the notification.** `hs.keycodes.inputSourceChanged` fires
from a system notification that arrives up to ~1.5s late. A 100ms timer is the
primary trigger; the notification stays subscribed as a backstop.

**Globals, not locals, for the timer and watcher.** A `hs.timer` or
`hs.screen.watcher` held only in a `local` is garbage collected once the config
finishes loading, and then stops firing silently — no error, it just quietly
stops working.

## Troubleshooting

```sh
hs -c 'print(layoutIndicatorState())'
```

Prints the current input source, whether the stripe is shown, whether the poll
timer is alive, the screen it considers active, and the canvas frame (which
matches the full screen size, not the stripe).

- `poller=false` — the timer died; the stripe will be frozen where it last was.
- `activeScreen` and `barFrame` disagreeing — position is not being applied.

## Known limitations

- The active screen is taken from the focused window, falling back to the mouse
  position. Apps with no standard window can make this guess wrong for a tick.
- Per-window layout memory is a macOS feature
  ("Automatically switch to a document's input source"). Tools such as Input
  Source Pro override it; this script only reads the layout, never sets it.
