-- Change the default Omarchy look'n'feel.

-- Tighter gaps between windows and screen edges.
hl.config({
  general = {
    gaps_in = 0,
    gaps_out = 0,
  },
})

-- Tighter groupbar too: no wallpaper strip between the tabs and the window,
-- and minimal spacing between the tabs themselves. Tabs are opaque chips so
-- the wallpaper only shows in the gaps -- that's what marks the borders.
hl.config({
  group = {
    groupbar = {
      indicator_gap = 0,
      gaps_in = 3,
      col = {
        active = "rgba(404040ee)",
        inactive = "rgba(000000b3)",
      },
    },
  },
})

-- Don't let a window on another workspace yank the view over when it asks for
-- attention (Omarchy defaults this to true). Without it, closing a window can
-- hand focus to whatever requested activation last and jump workspaces --
-- e.g. relaunching the Last War launcher on workspace 5 lands you on 3.
-- This was in the old looknfeel.conf and was lost in the .conf -> .lua migration.
hl.config({
  misc = {
    focus_on_activate = false,
  },
})

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
-- hl.config({
--   general = {
--     -- No gaps between windows or borders.
--     gaps_in = 0,
--     gaps_out = 0,
--     border_size = 0,
--
--     -- Change to niri-like side-scrolling layout.
--     layout = "scrolling",
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
-- hl.config({
--   decoration = {
--     -- Use round window corners.
--     rounding = 8,
--
--     -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
--     dim_inactive = true,
--     dim_strength = 0.15,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     -- Avoid overly wide single-window layouts on wide screens.
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- hl.config({
--   scrolling = {
--     -- See only one column per screen instead of two.
--     column_width = 0.97,
--   },
-- })

-- Keep the pointer visible. Omarchy hides it on any key press (compositor
-- binds included) and over Remmina's XWayland window mouse motion does not
-- bring it back, so its OK/Cancel panels had an invisible cursor.
hl.config({
  cursor = {
    hide_on_key_press = false,
  },
})
