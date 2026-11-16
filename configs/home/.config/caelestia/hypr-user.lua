-- Real PC (RTX 5060 Ti) - copy to ~/.config/caelestia/hypr-user.lua
-- The VM's graphics workarounds (LIBGL_ALWAYS_SOFTWARE, XWAYLAND_NO_GLAMOR) are NOT needed here.

-- Keyboard: English + Thai. Switch with Super+Space (same shortcut as Windows).
hl.config({
    input = {
        kb_layout  = "us,th",
        kb_options = "grp:win_space_toggle",

        -- Mouse: no acceleration (like Windows with "Enhance pointer precision" off),
        -- a little slower. sensitivity goes -1.0 .. 1.0; with "flat", -0.1 = 90% speed.
        accel_profile = "flat",
        sensitivity   = -0.1,
    },
})

-- NVIDIA (Hyprland wiki "Nvidia" page): hardware video decoding + the right GLX library.
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")
