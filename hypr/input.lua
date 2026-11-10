-- Keep only your personal input overrides here. Uncommented settings below
-- replace Omarchy's defaults.

-- Turn off mouse acceleration (default: adaptive) and slow the pointer down.
-- sensitivity runs -1.0 to 1.0, 0 is Omarchy's default.
hl.config({
  input = {
    accel_profile = "flat",
    sensitivity = -0.3,
  },
})

-- Layout toggles on Alt+Shift; Compose is on Caps Lock.
--
-- Do not move the layout toggle to Caps Lock (`grp:caps_toggle`). That was
-- tried between 2026-08-28 and 2026-09-03 and it silently broke layout
-- switching for every app behind fcitx5 — Telegram and WhatsApp typed Latin
-- while every indicator correctly reported Ukrainian. Reverting to
-- `grp:alt_shift_toggle` fixed it immediately, with no change to fcitx5.
-- `compose:caps` was collateral damage of the same edit, so Compose was gone
-- for those six days too.
--
-- XKB carries at most FOUR groups. A fifth layout in this list is not an
-- error you will see: libxkbcommon drops it with one line on stderr
-- ("Unrecognized RMLVO layout ... was ignored") and compiles the rest, so the
-- layout is simply absent while the config still names it. Four is the
-- budget; spend it deliberately.
hl.config({
  input = {
    kb_layout = "us,ua",
    kb_options = "compose:caps,grp:alt_shift_toggle",
  },
})

-- Keyboard layout and options.
-- See https://wiki.hypr.land/Configuring/Basics/Variables/#input
-- hl.config({
--   input = {
--     -- Use multiple keyboard layouts and switch between them with Left Alt + Right Alt.
--     kb_layout = "us,dk,eu",
--     kb_options = "compose:caps,shift:both_capslock_cancel,grp:alts_toggle",
--
--     -- Use a specific keyboard variant if needed (e.g. intl for international keyboards).
--     kb_variant = "intl",
--
--     -- Change speed of keyboard repeat.
--     repeat_rate = 40,
--     repeat_delay = 250,
--
--     -- Start with numlock on by default.
--     numlock_by_default = true,
--
--     -- Increase sensitivity for mouse/trackpad (default: 0).
--    sensitivity = 0.25,
--
--     -- Turn off mouse acceleration (default: adaptive).
--     accel_profile = "flat",
--
--     touchpad = {
--       -- Use natural (inverse) scrolling.
--       natural_scroll = true,
--
--       -- Use two-finger clicks for right-click instead of lower-right corner.
--       clickfinger_behavior = true,
--
--       -- Control the speed of your scrolling.
--       scroll_factor = 0.4,
--
--       -- Enable the touchpad while typing.
--       disable_while_typing = false,
--
--       -- Left-click-and-drag with three fingers.
--       drag_3fg = 1,
--     },
--   },
-- })

-- App-specific touchpad scroll speeds.
-- o.window("(Alacritty|kitty|foot)", { scroll_touchpad = 1.5 })
-- o.window("com.mitchellh.ghostty", { scroll_touchpad = 0.2 })

-- Enable touchpad gestures for changing workspaces.
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/
-- hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Enable touchpad gestures for moving focus (helpful on scrolling layout).
-- hl.gesture({ fingers = 3, direction = "left", action = function() hl.dispatch(hl.dsp.focus({ direction = "l" })) end })
-- hl.gesture({ fingers = 3, direction = "right", action = function() hl.dispatch(hl.dsp.focus({ direction = "r" })) end })
