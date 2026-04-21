# Hyprland Waybar Widgets

Small Waybar widgets that solve gaps in the stock modules, with a bias toward Hyprland setups.

Current widgets:

- `keyboard-layout.sh` - reliable keyboard layout indicator for Hyprland
- `cpu-status.py` - CPU hover widget with per-core load, temperatures, session peaks, and short load graphs

Config snippets:

- `examples/memory-builtin.jsonc` - icon-only built-in Waybar memory module with tooltip details
- `examples/memory-builtin.css` - warning / critical colors for the built-in memory module

## Keyboard Layout Widget

A reliable keyboard layout indicator for [Waybar](https://github.com/Alexays/Waybar) on [Hyprland](https://hyprland.org/) that works around the known IPC parsing bugs in the built-in `hyprland/language` module.

### Why this exists

Waybar ships a built-in `hyprland/language` module, but it has documented failure modes:

1. Device names with special characters can break IPC event parsing.
2. The configured `keyboard-name` may not be the device that actually emits the layout event.
3. The upstream Hyprland event format is ambiguous and has not been changed.

Related issues:

- [Waybar #4340](https://github.com/Alexays/Waybar/issues/4340)
- [Waybar #2544](https://github.com/Alexays/Waybar/issues/2544)
- [Waybar #4229](https://github.com/Alexays/Waybar/issues/4229)
- [Waybar #4301](https://github.com/Alexays/Waybar/issues/4301)
- [Hyprland #6298](https://github.com/hyprwm/Hyprland/issues/6298)
- [Omarchy Discussion #111](https://github.com/basecamp/omarchy/discussions/111)

### Dependencies

- `hyprctl`
- `jq`
- `socat`

```bash
# Arch Linux
sudo pacman -S jq socat

# Debian/Ubuntu
sudo apt install jq socat

# Fedora
sudo dnf install jq socat
```

### Install

1. Find the keyboard device name:

```bash
hyprctl devices -j | jq -r '.keyboards[] | .name'
```

2. Copy the script:

```bash
mkdir -p ~/.config/waybar/scripts
cp keyboard-layout.sh ~/.config/waybar/scripts/
chmod +x ~/.config/waybar/scripts/keyboard-layout.sh
```

3. Add the module to Waybar:

```jsonc
"modules-right": [
    "custom/language"
],

"custom/language": {
    "exec": "~/.config/waybar/scripts/keyboard-layout.sh <YOUR_KEYBOARD_NAME>",
    "return-type": "json",
    "on-click": "hyprctl switchxkblayout all next"
},
```

4. Optional CSS:

```css
#custom-language {
    margin-right: 15px;
}

#custom-language.en {
    color: #89b4fa;
}

#custom-language.ua {
    color: #f9e2af;
}
```

### How it works

The script listens for `activelayout` IPC events only as a trigger, then reads the actual keyboard state from `hyprctl devices -j`. That avoids brittle parsing of the raw socket payload and keeps the widget reliable even with odd device names.

## CPU Hover Widget

A Waybar CPU icon widget with a detailed hover tooltip:

- total CPU load
- per-core load
- per-core temperature when exposed by the kernel
- highest temperature seen in the current boot session
- 10-sample load sparklines for total and per-core activity

### Dependencies

- `python3`

The script reads `/proc/stat`, `/sys/class/hwmon`, and `/sys/class/thermal` directly. No external Python packages are required.

### Install

1. Copy the script:

```bash
mkdir -p ~/.config/waybar/scripts
cp cpu-status.py ~/.config/waybar/scripts/
chmod +x ~/.config/waybar/scripts/cpu-status.py
```

2. Replace the stock `cpu` module with a custom one:

```jsonc
"modules-right": [
    "custom/cpu"
],

"custom/cpu": {
    "exec": "python3 ~/.config/waybar/scripts/cpu-status.py",
    "return-type": "json",
    "interval": 1,
    "tooltip": true
},
```

3. Optional CSS for temperature-based color states:

```css
#custom-cpu.warm {
    color: #d79921;
}

#custom-cpu.hot {
    color: #fe8019;
}

#custom-cpu.critical {
    color: #fb4934;
}
```

4. Reload Waybar:

```bash
pkill -USR2 waybar
```

### Notes

- On many Intel CPUs, temperature sensors are exposed per physical core, not per logical thread. In that case sibling threads share the same temperature reading.
- The `peak` value is session-tracked by the script. It is not a firmware or hardware lifetime maximum.
- The mini graph is CPU load history, not temperature history.

## Built-in Memory Widget

If you do not need a custom RAM history graph yet, Waybar's built-in `memory` module is enough for a clean icon-only widget with a useful tooltip.

Files:

- `examples/memory-builtin.jsonc`
- `examples/memory-builtin.css`

Recommended behavior:

- show only the memory icon in the bar
- show percentage and used / total GiB on hover
- keep color changes with `warning` / `critical` states

Example tooltip output:

```text
43%
12.7G / 31.1G
```

## Tested On

- Hyprland 0.54.1
- Waybar 0.15.0
- Arch Linux

## License

MIT
