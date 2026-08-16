# Which toolkits this config installs. `setup-toolkits` edits this file; editing
# it by hand is equally fine — either way the change takes effect on the next
#
#   nix-on-droid switch --flake ~/.config/nix-on-droid
#
# Only the booleans are read (by home.nix, and by flake.nix for the fastfetch
# overlay). Comments and layout are yours; `setup-toolkits` rewrites the values
# in place and leaves everything else alone.
{
  # fish, oh-my-posh, eza, zoxide, yazi, fd, ripgrep, fzf.
  # The shipped fish config guards every block with `type -q`, so turning this
  # off degrades to a plain fish prompt instead of erroring — and fish itself
  # stays, because nix-on-droid.nix sets it as the login shell.
  shell = true;

  # fastfetch (with the animated GIF logo), timg, chafa — image output over the
  # kitty graphics protocol the launcher terminal implements natively.
  eyeCandy = true;

  # neovim plus what a distro's :checkhealth asks for on a fresh install
  # (tree-sitter CLI, fzf, lazygit, python3, imagemagick). Implies `build`:
  # treesitter compiles its grammars with a C compiler. `setup-nvim` installs
  # the config itself — nothing lands in ~/.config/nvim without asking.
  editor = true;

  # Base development toolchain: cc/c++, make, cmake, autotools, pkg-config,
  # binutils, archivers. Enough to configure-make-install an ordinary source
  # tree on the phone. Libraries to build *against* are per-project, and belong
  # in a `nix shell nixpkgs#zlib.dev` rather than in a global profile.
  build = true;

  # nodejs, npm, npx. Global installs (`npm install -g`) are redirected to
  # ~/.npm-global, so they survive switches, rollbacks and garbage collection.
  node = false;

  # go. `go install` writes to ~/go/bin, which stays on PATH across switches.
  go = false;

  # python3 with uv and uvx. `uv tool install` writes to ~/.local/bin.
  python = false;

  # Rebuild fastfetch with the kitty animation patch, so the GIF logo animates
  # instead of showing a single frame. Nothing prebuilt exists in the binary
  # cache for a patched fastfetch: budget ~20 minutes of on-device compiling
  # with the app in the foreground. The logo works either way — this only buys
  # the animation.
  animatedFastfetchLogo = false;
}
