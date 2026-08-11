-- Wallpaper-derived base46 theme, installed as lua/themes/material.lua by
-- `setup-nvim`. All the work is in lua/launcher/material_palette.lua.
--
-- Falls back to onedark's tables when no palette file exists yet — plain Termux, or
-- before the launcher has exported wallpaper colours — so the colourscheme is never
-- broken, just static.
local built = require("launcher.material_palette").build()
local M = built or require "base46.themes.onedark"

M = require("base46").override_theme(M, "material")

return M
