# ArchConfigs

Personal Arch Linux / Hyprland configuration.

## Dashboard

The dashboard is implemented with Quickshell/QML and is opened from Hyprland with:

```text
SUPER + M
```

Main files:

```text
hypr/hyprland.lua
hypr/scripts/dashboard.sh
quickshell/dashboard/shell.qml
quickshell/dashboard/scripts/dashboard-data.sh
scripts/install-dashboard-assets.sh
```

### Dependencies

Install the required packages:

```bash
sudo pacman -S quickshell curl jq playerctl libpulse pipewire-pulse inter-font
```

Optional, depending on your GPU/audio setup:

```bash
sudo pacman -S nvidia-utils
```

### Pulling config directly into ~/.config

This repository is intended to be used from `~/.config`, so updates can be applied with:

```bash
cd ~/.config
git pull
```

### Debugging dashboard startup

Run manually:

```bash
bash ~/.config/hypr/scripts/dashboard.sh
```

Check logs:

```bash
cat /tmp/qs-dashboard.log
cat /tmp/qs-dashboard-assets.log
```

Check data output:

```bash
bash ~/.config/quickshell/dashboard/scripts/dashboard-data.sh | jq
```

If the dashboard opens but data is empty, verify these tools:

```bash
command -v qs
command -v playerctl
command -v pactl
command -v curl
command -v jq
```
