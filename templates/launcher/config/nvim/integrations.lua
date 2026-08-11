-- Termux Launcher integrations for Neovim. Installed by `setup-nvim` and required
-- from whichever config you chose, so it works the same under NvChad, LazyVim,
-- kickstart, or a stock config.
--
-- Nothing here depends on a plugin. Delete the require line in your config to
-- opt out, or copy the bits you want and drop the rest.

-- Clipboard through OSC 52. The launcher terminal decodes the escape sequence and
-- hands the text to the Android clipboard, so yanks reach other apps with no helper
-- tool -- and the Nix edition has no termux-clipboard-set at all. The terminal never
-- answers clipboard *queries* (reading it back would let anything that can write to
-- your terminal steal what you last copied), so paste reads Neovim's own register
-- rather than blocking on a reply that never arrives. Paste from Android with the
-- terminal's own paste action.
local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
if ok then
  vim.g.clipboard = {
    name = "OSC 52",
    copy = {
      ["+"] = osc52.copy "+",
      ["*"] = osc52.copy "*",
    },
    paste = {
      ["+"] = function()
        return vim.split(vim.fn.getreg '"', "\n")
      end,
      ["*"] = function()
        return vim.split(vim.fn.getreg '"', "\n")
      end,
    },
  }
  vim.opt.clipboard = "unnamedplus"
end

-- Wrap long lines instead of scrolling them off a phone-width screen: break at word
-- boundaries, keep the wrapped part at the original indent, and mark continuations
-- so a wrapped line is not mistaken for a real one.
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.opt.showbreak = "↪ "

-- Distros and filetype plugins set wrap per window after this file runs, so
-- re-assert it on every new window rather than only at startup.
vim.api.nvim_create_autocmd({ "BufWinEnter", "WinNew" }, {
  group = vim.api.nvim_create_augroup("launcher_wrap", { clear = true }),
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
  end,
})

-- Retint when the launcher rewrites its wallpaper palette. Only meaningful for a
-- base46 theme (NvChad) built from that palette; harmless everywhere else.
local has_base46 = pcall(require, "base46")
if has_base46 then
  local palette_ok, palette = pcall(require, "launcher.material_palette")
  if palette_ok then
    palette.watch()
  end
end

-- Report what the generated theme decided: contrast ratios, whether the greyscale
-- fallback kicked in, the launcher's contrast level. `:MaterialThemeInfo`
vim.api.nvim_create_user_command("MaterialThemeInfo", function()
  local palette_ok, palette = pcall(require, "launcher.material_palette")
  if not palette_ok then
    vim.notify("launcher.material_palette is not installed", vim.log.levels.WARN)
    return
  end
  palette.build() -- populates vim.g.material_theme_info
  print(vim.inspect(vim.g.material_theme_info))
end, { desc = "Show how the wallpaper-derived theme was built" })
