-- Keyboard layout indicator: blue-and-yellow stripe down the left edge of the
-- active screen while a non-Latin (Ukrainian) input source is selected.
--
-- A 4px bar along the bottom edge was too easy to miss in peripheral vision;
-- a vertical edge is far easier to catch than a horizontal one at the bottom.
--
-- Why a canvas overlay instead of a menubar item: the menubar hides in
-- fullscreen, and this indicator has to stay visible there.

local BORDER_WIDTH = 3
-- Ukrainian flag: blue on the top half of the stripe, yellow on the bottom.
-- Full alpha -- 0.9 washed the blue out against dark windows.
local BORDER_COLOR_TOP = { red = 0.0, green = 0.34, blue = 0.72, alpha = 1.0 }
local BORDER_COLOR_BOTTOM = { red = 1.0, green = 0.84, blue = 0.0, alpha = 1.0 }

-- macOS delivers kTISNotifySelectedKeyboardInputSourceChanged asynchronously,
-- often ~1s after the layout actually switched. Polling closes that gap; the
-- notification stays subscribed as a backstop so a missed poll still corrects
-- itself. 100ms is well below the ~200ms threshold where a UI change stops
-- feeling immediate, and currentSourceID() is a cheap Carbon lookup.
local POLL_INTERVAL = 0.1

-- Input sources that should light up the bar, matched by exact ID.
--
-- The custom layout carries the "org.unknown.keylayout." prefix macOS gives to
-- third-party .bundle layouts, and its name is Cyrillic -- so matching on the
-- substring "Ukrainian" would never fire here. Add IDs as needed; run
-- `hs.keycodes.currentSourceID()` in the Hammerspoon console to read one off.
local HIGHLIGHT_SOURCES = {
    ["org.unknown.keylayout.Українська"] = true,
}

-- The canvas is built once and only moved/shown/hidden afterwards. Recreating
-- it on every change was itself a visible part of the lag.
local bar = hs.canvas.new({ x = 0, y = 0, w = 0, h = 0 })
-- A single stripe down the left edge, split at the vertical midpoint so blue
-- sits above yellow -- the flag rotated onto its side.
--
-- Width is absolute pixels (same thickness on every display), height is a
-- fraction of the canvas, which is sized to the whole screen.
local W = BORDER_WIDTH
bar[1] = { -- upper half: blue
    type = "rectangle",
    action = "fill",
    fillColor = BORDER_COLOR_TOP,
    frame = { x = "0", y = "0", w = W, h = "0.5" },
}
bar[2] = { -- lower half: yellow
    type = "rectangle",
    action = "fill",
    fillColor = BORDER_COLOR_BOTTOM,
    frame = { x = "0", y = "0.5", w = W, h = "0.5" },
}
-- overlay sits above fullscreen windows; the behavior flags keep it present
-- when switching Spaces instead of being tied to one Space.
bar:level(hs.canvas.windowLevels.overlay)
-- Sum, not bitwise OR: these are distinct bits, and addition works on
-- every LuaJIT build regardless of 5.2-extension support.
bar:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces
    + hs.canvas.windowBehaviors.stationary)
bar:clickActivating(false)
-- The canvas covers the whole screen, so it MUST NOT swallow input. With no
-- mouseCallback registered and mouse tracking left off, the window is not
-- click-eligible and events fall through to the windows underneath.
bar:canvasMouseEvents(false, false, false, false)
bar:wantsLayer(true)

-- Tracks visibility only; position is reconciled against the live frame.
local shown = false

local function activeScreen()
    -- focusedWindow() returns nil often enough to matter -- fullscreen Spaces,
    -- apps with no standard window, the Finder desktop -- and mainScreen() then
    -- lags behind, which is what left the bar stranded on the old display.
    -- The mouse screen is always defined and tracks the display you are on.
    local win = hs.window.focusedWindow()
    if win then
        local s = win:screen()
        if s then return s end
    end
    return hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
end

local function isHighlighted()
    local id = hs.keycodes.currentSourceID()
    return id ~= nil and HIGHLIGHT_SOURCES[id] == true
end

local function refresh()
    if not isHighlighted() then
        if shown then
            bar:hide()
            shown = false
        end
        return
    end

    local screen = activeScreen()
    if not screen then return end

    -- Compare against the frame actually on screen rather than a cached screen
    -- id. Caching by id meant that any tick where activeScreen() guessed wrong
    -- left the bar stranded, with nothing to correct it on later ticks.
    -- The canvas spans the whole screen and draws only the left stripe; see
    -- canvasMouseEvents above for why the transparent area stays click-through.
    local f = screen:fullFrame()
    local want = { x = f.x, y = f.y, w = f.w, h = f.h }
    local have = bar:frame()
    if have.x ~= want.x or have.y ~= want.y or have.w ~= want.w or have.h ~= want.h then
        bar:frame(want)
    end

    if not shown then
        bar:show()
        shown = true
    end
end

-- These MUST be global. A timer or watcher held only in a local is garbage
-- collected once the config finishes loading, and then simply stops firing --
-- silently, which is exactly how the bar ended up stranded on one display.
layoutPoller = hs.timer.new(POLL_INTERVAL, refresh)
layoutPoller:start()

-- Backstop for anything the poll misses between ticks.
hs.keycodes.inputSourceChanged(refresh)

-- No hs.window.filter here: it would make Hammerspoon observe every app over
-- the Accessibility API just to learn about focus changes. The 100ms poll
-- already picks up display changes, and reconciling against the live frame
-- means a wrong guess on one tick is corrected on the next.

-- Monitor plugged/unplugged or resolution change moves the target frame.
layoutScreenWatcher = hs.screen.watcher.new(refresh)
layoutScreenWatcher:start()

refresh()

-- ---------------------------------------------------------------------------
-- App switching
-- ---------------------------------------------------------------------------
--
-- Jump straight to an app rather than to a Space number. Space numbers in macOS
-- are positional, not stable: closing a desktop renumbers the rest, and the
-- numbering runs across displays, so "the third desktop on the DELL" is not
-- something the system can express. Binding to apps sidesteps all of that --
-- macOS follows the app to wherever it is assigned.
local APP_KEYS = {
    -- Matched by bundle ID: survives the app being renamed or localised.
    { key = "F1", bundleID = "com.tinyspeck.slackmacgap" },
    { key = "F2", bundleID = "com.microsoft.VSCode" },
    { key = "F3", bundleID = "com.brave.Browser" },
}

for _, entry in ipairs(APP_KEYS) do
    hs.hotkey.bind({ "ctrl" }, entry.key, function()
        -- launchOrFocusByBundleID both starts the app if needed and pulls its
        -- Space into view, which is the whole point of switching by app.
        hs.application.launchOrFocusByBundleID(entry.bundleID)
    end)
end

-- Enables the `hs` command-line tool, so the indicator state can be inspected
-- from a terminal without opening the Hammerspoon console.
require("hs.ipc")

-- Exposed for inspection via `hs -c "..."`; locals are not reachable over IPC.
function layoutIndicatorState()
    local s = activeScreen()
    local f = bar:frame()
    return string.format("source=%s shown=%s poller=%s activeScreen=%s barFrame=%d,%d %dx%d",
        tostring(hs.keycodes.currentSourceID()), tostring(shown),
        tostring(layoutPoller and layoutPoller:running()),
        s and s:name() or "nil", f.x, f.y, f.w, f.h)
end

hs.alert.show("Hammerspoon config loaded")
