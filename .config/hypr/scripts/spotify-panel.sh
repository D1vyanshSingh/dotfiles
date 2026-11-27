#!/usr/bin/env bash
# .config/hypr/scripts/spotify-panel.sh
#
# Super+Right: slide Spotify out of the left edge of the screen, the way
# Super+M pops the minimized windows out. Pressing it again puts it away.
#
# Spotify lives on its own "spotify" special workspace, so it never joins the
# tiling layout.
#
# Hyprland 0.56 evaluates dispatchers as Lua, so they look like this instead of
# the old "resizewindowpixel exact W H,address:0x..." strings.

set -u

ws="spotify"
inset=8   # matches general:gaps_out: keeps the panel off the screen edge

die() { echo "spotify-panel: $*" >&2; exit 1; }

# Dispatchers answer "ok"; anything else is reported but never aborts the
# script halfway, which would leave the window stuck off-screen.
dispatch() {
    local out
    out=$(hyprctl dispatch "$1" 2>&1)
    [[ -z $out || $out == ok ]] || echo "spotify-panel: $1 -> $out" >&2
}

# "address workspace floating" for the Spotify window, empty if closed
spotify_window() {
    hyprctl clients -j | jq -r '
        [.[] | select(.class | ascii_downcase == "spotify")][0] // empty
        | "\(.address) \(.workspace.name) \(.floating)"'
}

# --- panel geometry on the focused monitor --------------------------------
# reserved is what the bar and other exclusive surfaces take at each edge.
monitors=$(hyprctl monitors -j)
read -r mon_x mon_y mon_w mon_h res_l res_t res_r res_b <<<"$(
    jq -r '([.[] | select(.focused)][0] // .[0]) | "\(.x) \(.y) \(.width) \(.height) \(.reserved[0]) \(.reserved[1]) \(.reserved[2]) \(.reserved[3])"' <<<"$monitors")"
[[ -n ${mon_w:-} ]] || die "could not read the monitor geometry"
special_open=$(jq -r '([.[] | select(.focused)][0] // .[0]) | .specialWorkspace.name // ""' <<<"$monitors")

w=$(( (mon_w - res_l - res_r - 2 * inset) / 3 ))
h=$(( mon_h - res_t - res_b - 2 * inset ))
x=$(( mon_x + res_l + inset ))
y=$(( mon_y + res_t + inset ))

# --- put it away if it is already out -------------------------------------
if [[ $special_open == "special:$ws" ]]; then
    dispatch "hl.dsp.workspace.toggle_special('$ws')"
    exit 0
fi

# --- otherwise dock it on the left edge and show it ----------------------
win=$(spotify_window)

if [[ -z $win ]]; then
    setsid spotify >/dev/null 2>&1 &
    for _ in $(seq 1 40); do
        sleep 0.25
        win=$(spotify_window)
        [[ -n $win ]] && break
    done
    [[ -n $win ]] || die "Spotify did not open in time"
fi

read -r addr ws_name floating <<<"$win"

[[ $ws_name == "special:$ws" ]] ||
    dispatch "hl.dsp.window.move({ workspace = 'special:$ws', window = 'address:$addr' })"
[[ $floating == true ]] ||
    dispatch "hl.dsp.window.float({ action = 'toggle', window = 'address:$addr' })"

dispatch "hl.dsp.window.resize({ x = $w, y = $h, window = 'address:$addr' })"
dispatch "hl.dsp.window.move({ x = $x, y = $y, window = 'address:$addr' })"
dispatch "hl.dsp.workspace.toggle_special('$ws')"
