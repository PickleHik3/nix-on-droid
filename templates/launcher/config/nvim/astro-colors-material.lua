-- `:colorscheme material` — wallpaper-derived, via base16-nvim.
--
-- A real colors/ file rather than a one-shot setup() call, so AstroNvim can be told
-- `colorscheme = "material"` like any other theme, and re-applying it (after a
-- wallpaper change, or by hand) is just :colorscheme material.
local ok, palette = pcall(require, "launcher.material_palette")
if not ok then
  return
end

local built = palette.build()
if not built then
  return
end

require("base16-colorscheme").setup(built.base_16)
vim.o.background = built.type == "light" and "light" or "dark"

-- base16-nvim derives diagnostics from the base16 syntax slots, so DiagnosticError
-- comes out identical to base08 (variables, tags) and DiagnosticWarn identical to
-- base0E (keywords) — a warning then reads as a keyword. The palette's base_30
-- carries colours picked for exactly this: `red` is Material's ERROR role, pushed
-- apart in chroma when the wallpaper puts it on top of the syntax red. base46 uses
-- those directly; here they have to be applied by hand.
local d = built.base_30
local diagnostics = {
  Error = d.red,
  Warn = d.sun,
  Info = d.blue,
  Hint = d.teal,
  Ok = d.vibrant_green,
}
for level, colour in pairs(diagnostics) do
  vim.api.nvim_set_hl(0, "Diagnostic" .. level, { fg = colour })
  vim.api.nvim_set_hl(0, "DiagnosticVirtualText" .. level, { fg = colour })
  vim.api.nvim_set_hl(0, "DiagnosticFloating" .. level, { fg = colour })
  vim.api.nvim_set_hl(0, "DiagnosticSign" .. level, { fg = colour })
  vim.api.nvim_set_hl(0, "DiagnosticUnderline" .. level, { undercurl = true, sp = colour })
end

-- base16-nvim paints the standard groups, but AstroNvim's identity lives in groups
-- it never touches. Two families matter:
--
-- 1. Chrome. base16 sets StatusLine/TabLine from the base16 ramp, which is flat.
--    The Material surface roles give real layering (surface < container < high),
--    so the sidebar, tabline and statusline read as distinct planes.
-- 2. Mode colours. AstroNvim's setup_colors() resolves the mode indicator from
--    HeirlineNormal/Insert/Visual/Replace/Command/Terminal/Inactive highlight
--    groups (see _astroui_status.lua). base16 defines none of them, so it falls
--    back to lualine_mode(colors_name) -- no "material" lualine theme exists --
--    and then to AstroNvim's stock blue/green/purple. Defining them here is what
--    makes the statusline follow the wallpaper.
--
-- These are set from colors/material.lua rather than astroui's highlights.init so
-- ordering is guaranteed: heirline recomputes on ColorScheme, after this file runs.
local set = function(group, attrs) vim.api.nvim_set_hl(0, group, attrs) end
local accent = d.pmenu_bg -- Material PRIMARY

-- Chrome, on the Material surface ramp.
set("StatusLine", { fg = d.white, bg = d.statusline_bg })
set("StatusLineNC", { fg = d.grey_fg, bg = d.statusline_bg })
set("TabLine", { fg = d.grey_fg2, bg = d.darker_black })
set("TabLineFill", { bg = d.darker_black })
set("TabLineSel", { fg = d.white, bg = d.one_bg2 })
set("WinBar", { fg = d.grey_fg2, bg = d.black })
set("WinBarNC", { fg = d.grey, bg = d.black })
set("WinSeparator", { fg = d.line, bg = d.black })
set("Pmenu", { fg = d.white, bg = d.one_bg })
set("PmenuSel", { fg = d.black, bg = accent })
set("PmenuSbar", { bg = d.one_bg2 })
set("PmenuThumb", { bg = d.grey })
set("FloatBorder", { fg = d.line, bg = d.darker_black })
set("NormalFloat", { fg = d.white, bg = d.darker_black })
set("CursorLine", { bg = d.one_bg })
set("Visual", { bg = d.one_bg3 })

-- Sidebar and pickers. Setting a group that a plugin never uses is harmless, so
-- both neo-tree and the snacks picker are covered without probing which is active.
for group, attrs in pairs {
  NeoTreeNormal = { fg = d.white, bg = d.darker_black },
  NeoTreeNormalNC = { fg = d.grey_fg2, bg = d.darker_black },
  NeoTreeEndOfBuffer = { fg = d.darker_black, bg = d.darker_black },
  NeoTreeWinSeparator = { fg = d.darker_black, bg = d.darker_black },
  NeoTreeRootName = { fg = accent, bold = true },
  NeoTreeDirectoryIcon = { fg = accent },
  NeoTreeGitModified = { fg = d.yellow },
  TelescopeNormal = { fg = d.white, bg = d.darker_black },
  TelescopeBorder = { fg = d.line, bg = d.darker_black },
  TelescopePromptTitle = { fg = d.black, bg = accent, bold = true },
  TelescopeSelection = { bg = d.one_bg2 },
  SnacksPicker = { fg = d.white, bg = d.darker_black },
  SnacksPickerBorder = { fg = d.line, bg = d.darker_black },
  SnacksPickerTitle = { fg = d.black, bg = accent, bold = true },
  SnacksPickerListCursorLine = { bg = d.one_bg2 },
  SnacksDashboardHeader = { fg = accent },
  SnacksDashboardIcon = { fg = d.blue },
} do
  set(group, attrs)
end

-- Git signs, and the statusline segments derived from them. Without these,
-- setup_colors() falls back to hardcoded onedark values (git_added "#98c379").
set("GitSignsAdd", { fg = d.green })
set("GitSignsChange", { fg = d.yellow })
set("GitSignsDelete", { fg = d.red })
set("GitSignsAddNr", { fg = d.green })
set("GitSignsChangeNr", { fg = d.yellow })
set("GitSignsDeleteNr", { fg = d.red })
set("DiffAdd", { fg = d.green, bg = d.one_bg })
set("DiffChange", { fg = d.yellow, bg = d.one_bg })
set("DiffDelete", { fg = d.red, bg = d.one_bg })
set("NvimEnvironmentName", { fg = d.orange })

-- Mode indicator, the piece that looked stock.
set("HeirlineNormal", { bg = accent })
set("HeirlineInsert", { bg = d.green })
set("HeirlineVisual", { bg = d.purple })
set("HeirlineReplace", { bg = d.red })
set("HeirlineCommand", { bg = d.yellow })
set("HeirlineTerminal", { bg = d.teal })
set("HeirlineInactive", { bg = d.grey })

-- :terminal inside nvim on the same 16 colours the shell uses.
local ansi = {
  built.base_16.base00, built.base_16.base08, built.base_16.base0B, built.base_16.base0A,
  built.base_16.base0D, built.base_16.base0E, built.base_16.base0C, built.base_16.base05,
  d.grey_fg2, d.baby_pink, d.vibrant_green, d.sun,
  d.nord_blue, d.dark_purple, d.teal, built.base_16.base06,
}
for i, colour in ipairs(ansi) do
  vim.g["terminal_color_" .. (i - 1)] = colour
end

-- Transparency. A terminal cell has no alpha channel, so this is on/off here: bg
-- "NONE" makes nvim inherit the terminal's own background, and *that* is where the
-- degree comes from -- the launcher's terminal/surface opacity slider. Set
-- vim.g.material_transparent = true before the colourscheme loads, or toggle it
-- live with :MaterialTransparent.
--
-- Deliberately selective: the buffer area goes transparent so the wallpaper shows
-- through, while statusline, sidebar, floats and pickers keep solid backgrounds.
-- Fully transparent chrome is where legibility falls apart -- those surfaces carry
-- small, dense text over whatever happens to be behind them.
local function apply_transparency(on)
  local groups = {
    "Normal", "NormalNC", "SignColumn", "EndOfBuffer", "LineNr", "CursorLineNr",
    "FoldColumn", "NonText", "MsgArea", "VertSplit",
  }
  for _, group in ipairs(groups) do
    local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
    -- Opaque means opaque: set the background explicitly rather than leaving it
    -- unset. Unset merely inherits Normal, which looks identical but reports as
    -- NONE and would go transparent again if Normal ever did.
    hl.bg = on and "NONE" or built.base_16.base00
    vim.api.nvim_set_hl(0, group, hl)
  end
  set("WinSeparator", { fg = d.line, bg = on and "NONE" or d.black })
  -- Floats blend against the buffer behind them; the popup menu likewise. Modest
  -- values only: past ~20 the text starts fighting whatever is underneath.
  vim.o.winblend = on and 10 or 0
  vim.o.pumblend = on and 10 or 0
end

apply_transparency(vim.g.material_transparent == true)

vim.api.nvim_create_user_command("MaterialTransparent", function(cmd)
  local arg = cmd.args ~= "" and cmd.args or nil
  local on
  if arg == "on" then
    on = true
  elseif arg == "off" then
    on = false
  else
    on = not (vim.g.material_transparent == true)
  end
  vim.g.material_transparent = on
  vim.cmd.colorscheme "material"
  print("material: transparency " .. (on and "on" or "off"))
end, { nargs = "?", complete = function() return { "on", "off" } end,
       desc = "Toggle transparent background (inherits the terminal's opacity)" })

vim.g.colors_name = "material"
