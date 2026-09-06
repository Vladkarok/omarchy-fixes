-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Personal bindings load after Omarchy's defaults. Always unbind first so
-- these choices continue to win if a future update claims the same keys.
local function rebind(keys, description, dispatcher, options)
  hl.unbind(keys)
  o.bind(keys, description, dispatcher, options)
end

-- Launch Last War through its desktop entry.
rebind("SUPER + SHIFT + L", "Last War", { launch = "gtk-launch LastWar" })

-- Replace Omarchy's ChatGPT web app binding with the native desktop app.
rebind("SUPER + SHIFT + A", "ChatGPT Desktop", { launch = "gtk-launch chatgpt" })

-- Replace Omarchy's HEY Calendar web app binding with Claude Desktop.
rebind("SUPER + SHIFT + C", "Claude Desktop", { launch = "gtk-launch com.anthropic.Claude" })

-- Don't lock the screen when the lid closes. Omarchy's default runs
-- omarchy-system-lid-close, which locks (unless an external monitor is
-- attached) and then reconciles displays. Keep only the display half, so the
-- internal panel still turns off instead of running under a shut lid.
rebind("switch:on:Lid Switch", nil, "omarchy-hyprland-monitor-clamshell", { locked = true })

-- Use emote instead of Omarchy's built-in picker. The built-in one pastes the
-- emoji into the focused window with Shift+Insert and deliberately wipes the
-- clipboard afterwards; emote leaves it on the clipboard and has recents and
-- categories. The built-in picker is still reachable via
-- `omarchy-shell shell toggle omarchy.emojis`.
rebind("SUPER + CTRL + E", "Emojis", { launch = "emote" })

-- Reorder tabs inside a group. Omarchy binds only focus movement within a
-- group (SUPER + CTRL + arrows), so mirror it with SHIFT for moving the window
-- itself.
rebind("SUPER + CTRL + SHIFT + LEFT", "Move window left in group", hl.dsp.group.move_window({ forward = false }))
rebind("SUPER + CTRL + SHIFT + RIGHT", "Move window right in group", hl.dsp.group.move_window({ forward = true }))

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Let RDP/VM guests receive compositor shortcuts such as Alt+Tab.
rebind("SUPER + F12", "Guest shortcut passthrough", hl.dsp.submap("passthrough"))
hl.define_submap("passthrough", function()
  hl.bind("SUPER + F12", hl.dsp.submap("reset"), { description = "Exit guest shortcut passthrough" })
end)
