-- Extra autostart processes.

-- Chat apps, launched as a chain: each one starts only once the previous app's
-- window has actually opened. Fixed sleeps don't work -- on a cold boot the
-- apps map in an unpredictable order, and auto_group merges a new window into
-- whatever group happens to be focused at that moment, so they end up split.
-- window.open is event-driven, so the wait costs no CPU. Window rules in
-- windows.lua put the result on workspace 1 as one group.
local chat_apps = {
  { app = "org.telegram.desktop.desktop", class = "org.telegram.desktop" },
  { app = "com.rtosta.zapzap.desktop", class = "com.rtosta.zapzap" },
  { app = "viber.desktop", class = "viber" },
  { app = "discord.desktop", class = "discord", not_title = "Discord Updater" },
}

-- Starts inert. hyprctl reload re-runs this file, and a chain armed at load time
-- would re-arm too: the next window matching the first entry -- Telegram opening
-- a media viewer, say -- would look like startup and launch duplicate instances
-- of everything after it. Only a real Hyprland start arms it, below.
local pending = #chat_apps + 1

local function launch_pending()
  local entry = chat_apps[pending]
  if not entry then
    return
  end

  local launching = pending
  hl.exec_cmd(o.launch(entry.app))

  -- A crashed or never-mapping app would otherwise strand the whole chain.
  hl.timer(function()
    if pending == launching then
      pending = pending + 1
      launch_pending()
    end
  end, { timeout = 45000, type = "oneshot" })
end

hl.on("window.open", function(window)
  local entry = chat_apps[pending]
  if not entry or window.class ~= entry.class then
    return
  end

  -- Discord's updater window shares the class; waiting on it instead of the
  -- real window would advance the chain against the wrong window.
  if entry.not_title and window.title == entry.not_title then
    return
  end

  local is_first = pending == 1
  pending = pending + 1

  if is_first then
    launch_pending()
    return
  end

  -- Merge explicitly instead of trusting group.auto_group, which only absorbs
  -- into whatever group happens to be focused -- a coin flip during startup.
  -- The dispatcher acts on the active window, and the window isn't active yet
  -- when window.open fires, so defer a beat: the same one-shot deferral Omarchy
  -- uses in default/hypr/bindings/clipboard.lua. Launching the next app from
  -- inside the timer keeps the steps serialized.
  hl.timer(function()
    hl.dispatch(hl.dsp.window.move({ into_group = "l" }))
    launch_pending()
  end, { timeout = 300, type = "oneshot" })
end)

hl.on("hyprland.start", function()
  pending = 1
  launch_pending()
end)
