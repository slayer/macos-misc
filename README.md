# macos-misc

Misc macOS scripts and config files, kept here so they can be dropped onto a
fresh machine without rebuilding them from memory.

## Contents

| Directory | What it is |
| --- | --- |
| [`hammerspoon/`](hammerspoon/) | Keyboard layout indicator — a thin coloured bar along the bottom of the active screen while a non-Latin layout is selected. Stays visible in fullscreen, where the menu bar indicator is hidden. |
| [`keyboard-layouts/`](keyboard-layouts/) | Ukrainian `.keylayout` with extra characters on the Option layers, plus its menu bar icon. |

The two go together: the indicator is configured out of the box for the layout
in `keyboard-layouts/`, though it works with any input source.

Each directory has its own README with install steps.
