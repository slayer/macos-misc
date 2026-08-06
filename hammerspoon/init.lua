-- Keyboard layout indicator: yellow bar at the bottom of the active screen
-- while a non-Latin (Ukrainian) input source is selected.
--
-- Why a canvas overlay instead of a menubar item: the menubar hides in
-- fullscreen, and this indicator has to stay visible there.

local BAR_HEIGHT = 2
local BAR_COLOR = { red = 1.0, green = 0.8, blue = 0.0, alpha = 0.9 }

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
bar[1] = {
    type = "rectangle",
    action = "fill",
    fillColor = BAR_COLOR,
}
-- overlay sits above fullscreen windows; the behavior flags keep it present
-- when switching Spaces instead of being tied to one Space.
bar:level(hs.canvas.windowLevels.overlay)
-- Sum, not bitwise OR: these are distinct bits, and addition works on
-- every LuaJIT build regardless of 5.2-extension support.
bar:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces
    + hs.canvas.windowBehaviors.stationary)
bar:clickActivating(false)

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
    local f = screen:fullFrame()
    local want = {
        x = f.x,
        y = f.y + f.h - BAR_HEIGHT,
        w = f.w,
        h = BAR_HEIGHT,
    }
    local have = bar:frame()
    if have.x ~= want.x or have.y ~= want.y or have.w ~= want.w then
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
