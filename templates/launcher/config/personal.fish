# ~/.config/fish/conf.d/personal.fish — YOUR file. Writable, edit freely, takes
# effect in the next shell (`exec fish`). Nothing here needs a nix switch.
#
# Copied here once, on first activation. It is never overwritten afterwards, so
# your edits are safe across switches. Delete it and switch again to get a fresh
# copy. The launcher's own settings live in ~/.config/fish/config.fish, which is
# read-only on purpose — see the comment at the top of it.
#
# Load order: fish reads conf.d/*.fish (alphabetically) BEFORE config.fish. So
# PATH additions from the launcher config are not in place yet when this runs —
# hence the guard below. Anything you want to override in config.fish must go in
# a function or an event handler, not a bare `set`.

# Profile on PATH early, so the tools below are findable from here.
if test -d "$HOME/.nix-profile/bin"; and not contains -- "$HOME/.nix-profile/bin" $PATH
    fish_add_path --prepend "$HOME/.nix-profile/bin"
end

set -q EDITOR; or set -gx EDITOR nvim
set -q VISUAL; or set -gx VISUAL $EDITOR

## ---------------------------------------------------------------------------
## sshd — off unless you arm it with `sshd-autostart on`
## ---------------------------------------------------------------------------
if status is-interactive
    if test -e ~/.config/sshd/autostart; and type -q sshd-start
        sshd-start --quiet
    end
end

## ---------------------------------------------------------------------------
## ls / cd helpers. Remove the block if you prefer plain ls and cd.
## ---------------------------------------------------------------------------
if status is-interactive
    if type -q eza
        function ls
            command eza --group-directories-first --icons=auto $argv
        end

        function l
            command eza --group-directories-first --icons=auto $argv
        end

        function la
            command eza --all --group-directories-first --icons=auto $argv
        end

        function ll
            command eza --long --all --header --git --group-directories-first --icons=auto $argv
        end

        function lt
            command eza --tree --level=2 --group-directories-first --icons=auto $argv
        end
    end

    # zoxide powers cd; the wrapper also lists the destination after moving.
    if type -q zoxide
        zoxide init --cmd cd fish | source

        functions --erase cd
        function cd --wraps=__zoxide_z
            __zoxide_z $argv
            and ls
        end
    else
        function cd --wraps=cd
            builtin cd $argv
            and ls
        end
    end
end

# yazi helper: exit yazi into the directory it was viewing.
function y
    set -l tmp (mktemp -t "yazi-cwd.XXXXXX")

    command yazi $argv --cwd-file="$tmp"

    if read -l cwd <"$tmp"; and test "$cwd" != "$PWD"; and test -d "$cwd"
        builtin cd -- "$cwd"
    end

    rm -f -- "$tmp"
end

## ---------------------------------------------------------------------------
## Nix shortcuts. Uncomment what you want.
## ---------------------------------------------------------------------------
#
#   abbr -a nxe 'nvim ~/.config/nix-on-droid/home.nix'          # edit the package list
#   abbr -a nxs 'nix-on-droid switch --flake ~/.config/nix-on-droid'
#   abbr -a nxb 'nix-on-droid build --flake ~/.config/nix-on-droid'   # dry build, no activation
#   abbr -a nxr 'nix-on-droid rollback'                         # undo the last switch
#   abbr -a nxl 'nix-on-droid list-generations'
#   abbr -a nxu 'nix flake update --flake ~/.config/nix-on-droid'     # bump ALL pinned versions
#   abbr -a nxun 'nix flake update nixpkgs --flake ~/.config/nix-on-droid'  # bump nixpkgs only
#   abbr -a nxg 'nix-collect-garbage -d'                        # reclaim disk, drops rollbacks
#   abbr -a nxq 'nix search nixpkgs'                            # nxq ripgrep
#
# Update habit that avoids surprise on-device compiles: bump the pins, check
# what it would do, then switch.
#
#   nix flake update && nix-on-droid build --flake . && nix-on-droid switch --flake .

## ---------------------------------------------------------------------------
## General shortcuts. Abbreviations expand as you type, so history stays useful.
## ---------------------------------------------------------------------------
#
#   abbr -a cc clear
#   abbr -a ee exit
#   abbr -a cdd 'cd ..'
#   abbr -a nn nvim
#   abbr -a py python
#   abbr -a gitc 'git clone'
#   abbr -a fishy 'nvim ~/.config/fish/conf.d/personal.fish'   # edit this file
#   abbr -a termuxy 'nvim ~/.termux/termux.properties'         # terminal settings
#   abbr -a rfish 'exec fish'                                  # reload fish
#   abbr -a rr termux-reload-settings                          # reload ~/.termux configs
#
# Functions are for anything with logic (see `y` above). Bind one to a key:
#
#   function __git_status
#       git status
#       commandline -f repaint
#   end
#   bind \eg __git_status
#
# API keys and other secrets belong in a file you never share:
#
#   test -r ~/.config/fish/secrets.fish; and source ~/.config/fish/secrets.fish
