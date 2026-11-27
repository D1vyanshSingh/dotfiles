
-- Docs: https://wiki.hypr.land/Configuring/Basics/Window-Rules/

hl.layer_rule({
    match = { namespace = "rofi" },
    blur = true,
    ignore_alpha = 0.15,
})

-- glass surfaces: the desktop wall, menubar and dock paint at low alpha and
-- rely on the compositor to blur the wallpaper behind them. ignore_alpha = 0
-- keeps the rounded corners blurred instead of hard-clipping them.
hl.layer_rule({ match = { namespace = "desktop-widgets-.*" }, blur = true, ignore_alpha = 0 })
hl.layer_rule({ match = { namespace = "quickshell-bar" }, blur = true, ignore_alpha = 0 })
hl.layer_rule({ match = { namespace = "quickshell-dock" }, blur = true, ignore_alpha = 0 })
hl.layer_rule({ match = { namespace = "calendar-app" }, blur = true, ignore_alpha = 0 })
hl.layer_rule({ match = { namespace = "datesheet-app" }, blur = true, ignore_alpha = 0 })
hl.layer_rule({ match = { namespace = "music-panel" }, blur = true, ignore_alpha = 0 })

-- Wispr Flow's dictation overlay is a big transparent window with a small pill
-- in it. Left alone, the compositor blurs the wallpaper across the whole
-- surface, so an empty blurred rectangle shows around the pill.
--
-- pin = true keeps the overlay (and its pill) on screen across every workspace,
-- instead of it living on whichever workspace it was spawned on. Pinning only
-- works for floating windows, so float is asserted alongside it.
hl.window_rule({
    name = "wispr-flow-overlay",
    match = { class = "^(wispr-flow)$" },
    float = true,
    pin = true,
    no_blur = true,
})

-- Opacity rules: 90% for all windows except fullscreen
hl.window_rule({
    match = { class = ".*" },
    opacity = "1.0 override",
})

hl.window_rule({
    match = { class = "kitty" },
    suppress_event = "maximize",
})

hl.window_rule({
    match = { class = ".*", fullscreen = true },
    opacity = "1.0 override",
})

hl.window_rule({
    name = "float-pavucontrol",
    match = { class = "^(pavucontrol)$" },
    float = true,
})

hl.window_rule({
    name = "float-nm-connection-editor",
    match = { class = "^(nm-connection-editor)$" },
    float = true,
})

hl.window_rule({
    name = "float-blueman-manager",
    match = { class = "^(blueman-manager)$" },
    float = true,
})

hl.window_rule({
    name = "float-open-file",
    match = { title = "^(Open File)$" },
    float = true,
})

hl.window_rule({
    name = "float-save-file",
    match = { title = "^(Save File)$" },
    float = true,
})
