# Copyright (c) 2019-2024, see AUTHORS. Licensed under MIT License, see LICENSE.

{ runCommand, nixDirectory, prootTermux, bash, pkgs, config, initialPackageInfo }:

runCommand "bootstrap" { } ''
  mkdir --parents $out/{.l2s,bin,dev/shm,etc,root,tmp,usr/{bin,lib}}
  mkdir --parents $out/nix/var/nix/{profiles,gcroots}/per-user/nix-on-droid

  cp --recursive ${nixDirectory}/store $out/nix/store
  # $out/nix/var already exists (per-user dirs above), so copying the
  # directory itself would nest it as nix/var/var and ship the store
  # database where nix never finds it — every shipped path then counts
  # as invalid and first boot only works if all of them are substitutable.
  cp --recursive ${nixDirectory}/var/. $out/nix/var/
  chmod --recursive u+w $out/nix

  ln --symbolic ${initialPackageInfo.bash}/bin/sh $out/bin/sh

  install -D -m 0755 ${prootTermux}/bin/proot-static $out/bin/proot-static

  cp ${config.environment.files.login} $out/bin/login
  cp ${config.environment.files.loginInner} $out/usr/lib/login-inner

  ${bash}/bin/bash ${../modules/environment/etc/setup-etc.sh} $out/etc ${config.build.activationPackage}/etc

  cp --dereference --recursive $out/etc/static $out/etc/.static.tmp
  rm $out/etc/static
  mv $out/etc/.static.tmp $out/etc/static

  find $out -executable -type f | sed s@^$out/@@ > $out/EXECUTABLES.txt

  find $out -type l | while read -r LINK; do
    LNK=''${LINK#$out/}
    TGT=$(readlink "$LINK")
    echo "$TGT←$LNK" >> $out/SYMLINKS.txt
    rm "$LINK"
  done
''
