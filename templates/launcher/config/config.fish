# Termux Launcher — declarative fish config. Managed by home-manager: this file
# is a read-only symlink into the nix store. Edit the source instead
# (~/.config/nix-on-droid/config/config.fish) and `nix-on-droid switch`.
#
# YOUR OWN SETTINGS GO IN ~/.config/fish/conf.d/personal.fish — a normal
# writable file, no switch needed. Editor, aliases, sshd autostart and the
# ls/cd helpers all live there. Note fish loads conf.d/*.fish BEFORE this file.
#
# What stays here: only what the launcher itself needs — PATH to launcherctl,
# the wallpaper Material palette, and the themed prompt.

set -g fish_greeting ""

# Non-login shells (sshd, scripts) arrive without the profile on PATH.
if test -d "$HOME/.nix-profile/bin"; and not contains -- "$HOME/.nix-profile/bin" $PATH
    fish_add_path --prepend "$HOME/.nix-profile/bin"
end

set -gx TMPDIR "$HOME/.tmp"
mkdir -p "$TMPDIR"

set -q COLORTERM; or set -gx COLORTERM truecolor

fish_add_path "$HOME/.local/bin" "$HOME/.termux/bin"

# Where each package manager's global installs land. These live in $HOME rather
# than in the nix profile because the profile is a read-only store path that the
# next switch replaces: npm -g, go install and uv tool install all need a
# writable prefix that survives switches, rollbacks and garbage collection.
fish_add_path "$HOME/.npm-global/bin" "$HOME/go/bin"

# Nix edition: launcherctl/tai live in the proot /bin, which the generated
# PATH does not include. Append (not prepend) so nix binaries keep priority.
test -d /nix; and fish_add_path --append /bin

# Load wallpaper-generated Material colors when available. The launcher writes
# them to ~/.termux/material-colors.sh (and .properties as a fallback).
function __load_termux_material_colors
    set -l shell_colors "$HOME/.termux/material-colors.sh"
    set -l colors "$HOME/.termux/material-colors.properties"

    if test -r "$shell_colors"
        source "$shell_colors"
        return
    end

    test -r "$colors"; or return

    while read -l line
        set line (string trim -- "$line")
        string match -qr '^(#|$)' -- "$line"; and continue

        set -l pair (string split -m 1 '=' -- "$line")
        test (count $pair) -eq 2; or continue

        set -l key (string upper (string replace -a '-' '_' -- $pair[1]))
        set -gx TERMUX_MATERIAL_$key $pair[2]
    end < "$colors"
end

__load_termux_material_colors

# Theme changes rewrite the Material exports while existing shells keep their
# old palette. Refresh before each prompt so open shells adopt new colors.
set -g __termux_material_colors_signature ""
function __refresh_termux_material_colors --on-event fish_prompt
    set -l colors "$HOME/.termux/material-colors.sh"
    test -r "$colors"; or set colors "$HOME/.termux/material-colors.properties"
    test -r "$colors"; or return

    set -l signature (command stat -c '%Y:%s' "$colors" 2>/dev/null)
    test -n "$signature"; or return
    test "$signature" = "$__termux_material_colors_signature"; and return

    __load_termux_material_colors
    set -g __termux_material_colors_signature "$signature"
end

# Fallback palette so the prompt still renders in plain Termux or before the
# launcher has exported wallpaper colors.
set -q TERMUX_MATERIAL_ERROR; or set -gx TERMUX_MATERIAL_ERROR "#F2B8B5"
set -q TERMUX_MATERIAL_ERROR_CONTAINER; or set -gx TERMUX_MATERIAL_ERROR_CONTAINER "#8C1D18"
set -q TERMUX_MATERIAL_ON_PRIMARY; or set -gx TERMUX_MATERIAL_ON_PRIMARY "#003826"
set -q TERMUX_MATERIAL_ON_SECONDARY; or set -gx TERMUX_MATERIAL_ON_SECONDARY "#1E3529"
set -q TERMUX_MATERIAL_ON_SURFACE; or set -gx TERMUX_MATERIAL_ON_SURFACE "#DEE4DE"
set -q TERMUX_MATERIAL_ON_SURFACE_VARIANT; or set -gx TERMUX_MATERIAL_ON_SURFACE_VARIANT "#C0C9C0"
set -q TERMUX_MATERIAL_PRIMARY; or set -gx TERMUX_MATERIAL_PRIMARY "#8CD5B3"
set -q TERMUX_MATERIAL_SECONDARY; or set -gx TERMUX_MATERIAL_SECONDARY "#B3CCBE"
set -q TERMUX_MATERIAL_SURFACE; or set -gx TERMUX_MATERIAL_SURFACE "#0F1512"
set -q TERMUX_MATERIAL_SURFACE_CONTAINER_HIGHEST; or set -gx TERMUX_MATERIAL_SURFACE_CONTAINER_HIGHEST "#303632"
set -q TERMUX_MATERIAL_SURFACE_VARIANT; or set -gx TERMUX_MATERIAL_SURFACE_VARIANT "#404943"
set -q TERMUX_MATERIAL_TERTIARY; or set -gx TERMUX_MATERIAL_TERTIARY "#A5CCDF"
set -q TERMUX_MATERIAL_TERTIARY_CONTAINER; or set -gx TERMUX_MATERIAL_TERTIARY_CONTAINER "#234C5E"
set -q TERMUX_MATERIAL_ON_TERTIARY_CONTAINER; or set -gx TERMUX_MATERIAL_ON_TERTIARY_CONTAINER "#C1E8FB"
set -q TERMUX_MATERIAL_ON_ERROR_CONTAINER; or set -gx TERMUX_MATERIAL_ON_ERROR_CONTAINER "#F9DEDC"

# Keep the prompt near the bottom of the screen after clearing.
function __move_cursor_to_bottom
    if type -q tput
        set -l lines (tput lines 2>/dev/null)

        if string match -rq '^[0-9]+$' -- "$lines"; and test "$lines" -gt 1
            command tput cup (math "$lines - 2") 0 2>/dev/null
        end
    end
end

function clear
    command clear
    __move_cursor_to_bottom
end

if status is-interactive
    # Mention the Neovim chooser once, only while no config exists. Not a prompt:
    # a question on every new shell would be worse than no question at all.
    set -l __tl_config_home (test -n "$XDG_CONFIG_HOME"; and echo "$XDG_CONFIG_HOME"; or echo "$HOME/.config")

    # Same idea for the toolkit checklist: said once, on the first shell after
    # the template's first switch, then never again.
    if type -q setup-toolkits; and not test -e "$__tl_config_home/.setup-toolkits-hinted"
        echo "Pick what this environment installs — 'setup-toolkits' (shell, editor, build tools, node, go, python)."
        touch "$__tl_config_home/.setup-toolkits-hinted"
    end

    if type -q setup-nvim; and not test -e "$__tl_config_home/nvim"; and not test -e "$__tl_config_home/.setup-nvim-hinted"
        echo "Neovim has no config yet — run 'setup-nvim' to pick one (NvChad, LazyVim, kickstart, or stock)."
        touch "$__tl_config_home/.setup-nvim-hinted"
    end

    # Saving a .nix file changes nothing on its own — a switch is what builds and
    # activates it. "I edited it and nothing happened" is this edition's classic
    # first hour, so compare the flake's files against the profile symlink, whose
    # mtime is the last switch. Store paths all carry a 1970 mtime, hence `stat`
    # on the link itself rather than test -nt, which would follow it and always
    # fire. Says nothing when the profile is missing or stat is unavailable.
    set -l __tl_profile /nix/var/nix/profiles/nix-on-droid
    set -l __tl_flake (test -n "$NIX_ON_DROID_FLAKE_DIR"; and echo "$NIX_ON_DROID_FLAKE_DIR"; or echo "$__tl_config_home/nix-on-droid")
    if type -q stat; and test -L "$__tl_profile"; and test -d "$__tl_flake"
        set -l __tl_switched (stat -c %Y "$__tl_profile" 2>/dev/null)
        if string match -rq '^[0-9]+$' -- "$__tl_switched"
            for __tl_file in $__tl_flake/*.nix
                set -l __tl_edited (stat -c %Y "$__tl_file" 2>/dev/null)
                if string match -rq '^[0-9]+$' -- "$__tl_edited"; and test "$__tl_edited" -gt "$__tl_switched"
                    echo "$__tl_flake has changes that are not applied yet — run: nix-on-droid switch --flake $__tl_flake"
                    break
                end
            end
        end
    end
    set -e __tl_profile
    set -e __tl_flake
    set -e __tl_config_home

    function fish_greeting
        command clear
        __move_cursor_to_bottom
    end

    # Oh My Posh prompt, after the Material colors are sourced. The compact
    # Aliens-derived theme follows the launcher's Material palette;
    # termux-launcher is the fuller alternate theme.
    if type -q oh-my-posh
        set -l omp_theme "$HOME/.config/ohmyposh/aliens-material.omp.json"
        test -f "$omp_theme"; or set omp_theme "$HOME/.config/ohmyposh/termux-launcher.omp.json"

        if test -f "$omp_theme"
            oh-my-posh --config "$omp_theme" init fish | source
        end
    end
end
