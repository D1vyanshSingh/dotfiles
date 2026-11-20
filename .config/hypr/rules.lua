
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
