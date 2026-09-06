-- Personal window rules. Omarchy's defaults load first, these override them.

-- Keep the focused window fully opaque, leave Omarchy's slight fade on the rest.
-- Same tag rule the default sets at the end of default/hypr/windows.lua, so it
-- has to be restated here to win; the pair is "<active> <inactive>".
o.window({ tag = "default-opacity" }, { opacity = "1 0.96" })

-- Chat apps all live on workspace 1 as one tabbed group: "set" opens each as a
-- group, and Hyprland's group.auto_group (on by default) merges the next one
-- into the focused group instead of tiling it beside.
local chat_apps = {
  [[^(discord|vesktop|webcord)$]],
  [[^(org\.telegram\.desktop|telegram-desktop|TelegramDesktop)$]],
  [[^(com\.rtosta\.zapzap)$]],
  [[^(Viber|viber)$]],
}

-- No "silent": auto_group only merges into the *focused* group, so each app has
-- to take focus as it maps or it starts a group of its own. autostart.lua staggers
-- the launches so they map in order and land in one group.
-- "tile" is load-bearing, not decoration: these apps map transient splash/login
-- windows under the same class, and a floating one joining the group drags the
-- whole group floating -- which is how they ended up as small floating windows.
for _, class in ipairs(chat_apps) do
  o.window(class, { workspace = "1", group = "set", float = false })
end

-- Discord's updater is a separate 320x370 window under the same class, and it
-- maps floating. Left alone it groups with the main window and drags the whole
-- group floating. Same shape of problem as Telegram's media viewer below.
o.window({
  class = [[^(discord|vesktop|webcord)$]],
  title = [[^(Discord Updater)$]],
}, {
  group = "override barred",
  float = true,
})

-- emote hides itself the moment it loses focus. With input.follow_mouse = 1,
-- merely sliding the pointer off the popup hands focus to the window
-- underneath and kills it mid-search, so pin focus for as long as it is open.
-- Esc and picking an emoji still close it.
o.window([[^(emote)$]], { stay_focused = true, center = true })

-- Last War on workspace 5. Its auxiliary window has an empty title and belongs
-- with xclicker on workspace 15.
--
-- "float = false" is load-bearing: the game maps floating at a small size in the
-- top-left corner and otherwise has to be tiled by hand with SUPER + T. This is
-- the "tile on" rule that the windows.conf -> windows.lua migration dropped.
o.window({ title = [[^(Last War-Survival Game)$]] }, { workspace = "5 silent", float = false })
o.window({ class = [[^(steam_proton)$]], title = [[Last War]] }, { workspace = "5 silent", float = false })

-- The vendor launcher (Rust/Iced) maps before the game and respawns while it
-- runs, so pin it to workspace 5 rather than letting it land on whatever
-- workspace happens to be focused. Deliberately left floating: tiling it would
-- split workspace 5 with the game.
o.window({ class = [[^(steam_proton)$]], title = [[^(Launcher - Iced)$]] }, { workspace = "5 silent", float = true })

o.window({ class = [[^(xclicker)$]] }, { workspace = "15 silent" })
o.window({ class = [[^(steam_proton)$]], title = [[^$]] }, { workspace = "15 silent" })

-- Telegram's image viewer is a separate window with the SAME class as the chat
-- window, so it inherits the group rule above and hijacks the group: fullscreen
-- a picture, close it, and the surviving member is stuck fullscreen. Float it
-- instead and bar it from grouping. Matched by title, so this stops working if
-- the Telegram UI language changes away from English.
o.window({
  class = [[^(org\.telegram\.desktop|telegram-desktop|TelegramDesktop)$]],
  title = [[^(Media viewer)$]],
}, {
  group = "override barred",
  float = true,
  -- Absolute pixels: percentage sizes are silently ignored here. 1440x900 is
  -- 90% of this display's 1600x1000 logical area, so it needs adjusting for a
  -- differently sized monitor.
  size = "1440 900",
  center = true,
})
