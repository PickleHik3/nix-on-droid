# Package-set overrides. Applied from flake.nix, and only when
# `animatedFastfetchLogo = true` in toolkits.nix — everything here has to be
# built on the phone, so it stays opt-in.
final: prev: {
  # fastfetch with the kitty animation-frames patch: the patch decodes GIF
  # frames through ImageMagick's CoalesceImages, transmits them with the kitty
  # animation protocol, and places the logo through Unicode placeholders
  # (U=1) — both of which the launcher terminal implements. Stock fastfetch
  # shows the first frame and nothing else.
  fastfetch = prev.fastfetch.overrideAttrs (old: {
    version = "2.67.0";
    src = final.fetchFromGitHub {
      owner = "fastfetch-cli";
      repo = "fastfetch";
      tag = "2.67.0";
      hash = "sha256-IwptETUR3mDVxF7IkBwRMHVqbh8Wl39uiVl6yxXiJmw=";
    };
    patches = (old.patches or [ ]) ++ [ ./fastfetch-kitty-animation.patch ];
    # gcc spawning `as` is flaky under proot at high -j; build serially.
    enableParallelBuilding = false;
  });
}
