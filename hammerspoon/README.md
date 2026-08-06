# Keyboard layout indicator

A thin coloured bar along the bottom of the active screen, shown while a
non-Latin keyboard layout is selected.

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
| `BAR_HEIGHT` | `2` | Bar thickness in points |
| `BAR_COLOR` | amber | Any Hammerspoon colour table |
| `POLL_INTERVAL` | `0.1` | How often the layout is checked, in seconds |
| `HIGHLIGHT_SOURCES` | Ukrainian | Input source IDs that light up the bar |

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
    ["com.apple.keylayout.Russian"] = true,
}
```

Matching on a substring like `"Ukrainian"` is tempting but unreliable: custom
`.bundle` layouts get an `org.unknown.keylayout.` prefix and may carry a
non-Latin name, so their ID contains no recognisable English word at all.

## How it works

The bar is an `hs.canvas` overlay at `windowLevels.overlay`, with
`canJoinAllSpaces` and `stationary` behaviour so it survives Space switches and
draws above fullscreen windows. `clickActivating(false)` lets clicks pass
straight through.

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

Prints the current input source, whether the bar is shown, whether the poll
timer is alive, the screen it considers active, and the bar's actual frame.

- `poller=false` — the timer died; the bar will be frozen wherever it last was.
- `activeScreen` and `barFrame` disagreeing — position is not being applied.

## Known limitations

- The active screen is taken from the focused window, falling back to the mouse
  position. Apps with no standard window can make this guess wrong for a tick.
- Per-window layout memory is a macOS feature
  ("Automatically switch to a document's input source"). Tools such as Input
  Source Pro override it; this script only reads the layout, never sets it.
