-- Wallpaper-derived colourscheme for AstroNvim.
--
-- AstroNvim has no base46, so the palette drives base16-nvim instead: it maps
-- base00..base0F across every highlight group including treesitter captures, and
-- lua/launcher/material_palette.lua already computes that table with the contrast
-- floor, the diagnostic separation and the greyscale fallback applied.
--
-- The theme itself lives in colors/material.lua so AstroNvim can select it by name.
return {
  { "RRethy/base16-nvim", lazy = false, priority = 1000 },

  {
    "AstroNvim/astroui",
    opts = { colorscheme = "material" },
  },

  -- Retint an open editor when the launcher rewrites the palette.
  {
    "AstroNvim/astrocore",
    opts = function(_, opts)
      local watcher, pending = vim.uv.new_fs_event(), false
      if watcher then
        watcher:start(os.getenv "HOME" .. "/.termux/material-colors.sh", {}, function()
          if pending then
            return
          end
          pending = true
          -- Debounced: the palette is rewritten in a few syscalls and fs_event
          -- reports each one.
          vim.defer_fn(function()
            pending = false
            package.loaded["launcher.material_palette"] = nil
            pcall(vim.cmd.colorscheme, "material")
          end, 250)
        end)
      end
      return opts
    end,
  },
}
