-- Keep only your personal env overrides here. Loaded after Omarchy's defaults,
-- so anything set below wins over default/hypr/envs.lua and default/hypr/nvidia.lua.

-- Point VA-API at the Intel iGPU, not the NVIDIA dGPU.
--
-- default/hypr/nvidia.lua sets LIBVA_DRIVER_NAME=nvidia on any NVIDIA machine
-- with GSP. That is wrong on this hybrid laptop: Chromium composites on the
-- Intel render node (renderD129) but is then told to decode on NVIDIA
-- (renderD128), and the cross-GPU dma-buf import fails with EGL_BAD_MATCH.
-- Result is black/green frames on H.264 sites and a hard freeze in Google Meet.
--
-- The NVIDIA VA-API shim is also decode-only: no VAEntrypointVideoProc and no
-- encode entrypoints at all. Intel's iHD has EncSlice, EncSliceLP and VideoProc.
-- Firefox is unaffected because nvidia-vaapi-driver is written against Firefox
-- and falls back to software decode cleanly.
--
-- See https://github.com/basecamp/omarchy/issues/4901
hl.env("LIBVA_DRIVER_NAME", "iHD")

-- Extra env variables (ported from the pre-quattro envs.conf).
hl.env("SDL_VIDEODRIVER", "wayland")
-- Keep Omasnap's timed preview (with Save As) instead of the --notify toast.
hl.env("OMASNAP_NOTIFY", "0")
hl.env("OMARCHY_SCREENSHOT_DIR", (os.getenv("HOME") or "") .. "/Pictures/Screenshots")
