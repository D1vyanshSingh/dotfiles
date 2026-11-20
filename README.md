<div align="center">

## Hyprland Setup by 43pr メ

A clean and simple Hyprland setup focused on practical keybinds, productivity, and easy to customize.

![Hyprland](https://img.shields.io/badge/Hyprland-0.56.2-8b9aaf?style=for-the-badge&labelColor=101418)
![GitHub repo size](https://img.shields.io/github/repo-size/43PR/dotfiles?style=for-the-badge&labelColor=101418&color=8b9aaf)
[![Discord](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fdiscord.com%2Fapi%2Finvites%2FHQwU9SzHj%3Fwith_counts%3Dtrue&query=%24.approximate_member_count&style=for-the-badge&logo=discord&logoColor=ffffff&label=discord&labelColor=101418&color=7289a8)](https://discord.gg/HQwU9SzHj)
[![YouTube](https://img.shields.io/badge/youtube-subscribe-b05a63?style=for-the-badge&logo=youtube&logoColor=ffffff&labelColor=101418)](https://www.youtube.com/@43PR2)
[![Ko-Fi donate](https://img.shields.io/badge/donate-kofi?style=for-the-badge&logo=ko-fi&logoColor=ffffff&label=ko-fi&labelColor=101418&color=9a6570)](https://ko-fi.com/43pr)

### **[Features](#features)  -  [Keybinds](#most-used-keybinds)  -  [Installation](#installation) -  [Updating](#updating)**

</div>

**v1.2.0**

<img width="1920" height="1080" alt="v1 2 0" src="https://github.com/user-attachments/assets/3b4857bc-285a-473a-924c-be89dab714b9" />

<img width="1920" height="1080" alt="1791338767" src="https://github.com/user-attachments/assets/d2b9999a-9939-410d-9980-11e97b448d78" />

Wallpapers: https://wallhaven.cc/user/43pr

## Features

- **Top bar** - Customizing options, vertical bar, styles, calendar, controls for volume and media playback.
- **Settings Menu** — System, network, bluetooth, display, audio, storage, themes, and more.
- **Wallpaper picker & Dynamic Colors** — Custom wallpaper selector with automatic wallpaper-based color generation.
- **Preset Themes** — Default Monochrome, Nord, Tokyo Night, etc, and easily create your own. 
- **App Launcher** — **Rofi** Application search, clipboard history, and opacity control.
- **Zsh + Starship** — Customizable shell with autosuggestions and history.
- **Customizable Power Menu** —  Custom power menu. 
- **Notes / To do** —  Custom quick Notes/To-do. 
- **Hyprlock** — Custom lock screen.
- **Spotify + Spicetify** — Custom theme based on **text - darkthemer**, (modified).
- **Custom Scripts** — Scripts for workflow and system management.

> All programs: [packages.txt](packages.txt)

### Wallpaper Selector

Just made some tweaks to it. Give it some love: [hyprquickpaper](https://github.com/iamsurjog/hyprquickpaper)

## Most used keybinds

> **You can modify keybinds using HyprMod**

| Keybind                 | Action                    |
| -----------             | ------------------------- |
| `Super + T`             | Terminal                  |
| `Super + Q`             | Close active window       |
| `Super`                 | Application launcher      |
| `Super + Space`         | Toggle floating window    |
| `Super + F`             | Toggle fullscreen         |
| `Super + 1, 2, 3..`     | Change workspaces         |
| `Super + Shift + 1, 2..`| Move window to workspace  |
| `Super + E`             | File manager              |
| `Super + B`             | Browser (Firefox)         |
| `Super + Shift + B`     | Chrome                    |
| `Super + V`             | Clipboard history         |
| `Super + S`             | Second launcher           |
| `Super + I`             | Settings menu             |
| `Super + W`             | Wallpaper selector        |
| `Super + O`             | Switch opacity            |
| `Super + Tab`           | Lock screen               |
| `Alt + Tab`             | Switch window (alt-tab)   |
| `Super + Shift + M`     | Minimize window           |
| `Super + M`             | Show minimized windows    |
| `Super + Grave`         | Logout menu               |
| `Super + Shift + W`     | Toggle bar                |
| `Super + Mouse wheel`   | Zoom in/out               |
| `Super + C`             | Notes/To-do               |
| `Super + N`             | Notifications             |
| `Super + G`             | Calendar                  |
| `Delete`                | Screenshot fullscreen     |
| `SHIFT + Delete`        | Screenshot area select    |

> [!note]
> **Move and resize windows with Super + left/right mouse drag.**
> To close most quickshell apps just click outside or Esc key.
> All keybinds: [.config/hypr/keybinds.lua](.config/hypr/keybinds.lua)

---
## Restoring this setup on another machine

This repository is the customized copy of the 43PR setup — the Quickshell bar, dock, desktop wall and shelf, the bluetooth agent, the systemd user units and the current theme palette are all here. Cloning it and running the installer rebuilds the setup on a fresh Arch-based install:

```bash
sudo pacman -S git

git clone git@github.com:D1vyanshSingh/dotfiles.git
mv dotfiles ~/dotfiles
cd ~/dotfiles && chmod +x install.sh && ./install.sh
```

On the new machine, authenticate first: either add a fresh SSH key to the GitHub account, or clone over HTTPS with a personal access token. Keep the clone where you put it — `install.sh` symlinks `~/.config` into the repository, so moving or deleting it breaks every link.

To save later changes from a machine that already has the repo, commit and run `git push backup main` (`origin` still points at upstream 43PR, for pulling their future updates). Runtime state — todo list, shelf contents, bar layout, notification history — lives in `~/.config/quickshell/state/` and is deliberately git-ignored, so it stays machine-local.

---
## Installation 

**READ ALL**

Should work for Arch, Manjaro, EndeavourOS, CachyOS, etc. 

This is mainly intended for a clean installation (existing configuration files that are being replaced will be backed up automatically).

**First install git then use the next command and continue the installation until it's finished**

```bash
sudo pacman -S git   
```

```bash
git clone https://github.com/43PR/dotfiles.git
cd dotfiles
chmod +x install.sh
./install.sh
```

After the installation finishes log out and back in.

> [!important]
> **Do not move or delete the dotfiles repository after installation.**
>
> This setup uses **symbolic links (symlinks)** that point to files inside the cloned repository. If you move or delete the repository, those symlinks will break.
>
> If you relocate the repository, simply run:
>
> ```bash
> ./install.sh
> ```
>
> The installer will automatically update the existing symlinks to point to the new location.

---
## Updating

Pull the latest changes, then run the updater from inside the repository:

```bash
git pull
./update.sh
```

Other options: `--dry-run` (preview changes), `--skip-packages`, `--skip-theme`.

Dotfiles are symlinked so, `git pull` updates your live configs directly.

You can check the reminders printed at the end of the run.

> [!tip]
> If any Quickshell (`.qml`) files changed in the pull, run:
>
> ```bash
> ./update.sh --restart-shell
> ```
>
> to restart Quickshell automatically.

> [!note]
> 
> Custom-gpu parts are specific to my hardware.
>
> For issues with the wallpaper picker, you can clear the cache from the Storage page in Settings.


