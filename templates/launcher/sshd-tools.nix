# sshd lifecycle commands for the nix edition. The server config is declarative
# (flags baked here, absolute store paths so sshd's re-exec requirement is always
# met); starting and stopping stay imperative and user-controlled. The host key is
# generated on first start under ~/.ssh/hostkeys — deliberately never in the store.
#
# Commands:
#   sshd-start [--quiet]   start if not running (idempotent)
#   sshd-stop              stop the pidfile-tracked instance
#   sshd-status            running state, port, autostart arming
#   sshd-autostart on|off  arm/disarm the interactive-session autostart hook
#                          (see config.fish; nothing starts unless armed)
#
# Port: 8023 by default — com.termux's sshd owns 8022 on the same device.
# Override by writing a port number to ~/.config/sshd/port.
{ pkgs }:
let
  runDir = "$HOME/.config/sshd";
  hostKey = "$HOME/.ssh/hostkeys/ssh_host_ed25519_key";
  sshd = "${pkgs.openssh}/bin/sshd";
  sshKeygen = "${pkgs.openssh}/bin/ssh-keygen";
in
[
  (pkgs.writeShellScriptBin "sshd-start" ''
    quiet=false
    [ "$1" = "--quiet" ] && quiet=true
    mkdir -p "${runDir}" "$HOME/.ssh/hostkeys"
    port="$(cat "${runDir}/port" 2>/dev/null || echo 8023)"

    if [ -f "${runDir}/pid" ] && kill -0 "$(cat "${runDir}/pid")" 2>/dev/null; then
      $quiet || echo "sshd already running (pid $(cat "${runDir}/pid"), port $port)"
      exit 0
    fi

    if [ ! -f "${hostKey}" ]; then
      $quiet || echo "generating host key..."
      ${sshKeygen} -t ed25519 -f "${hostKey}" -N "" >/dev/null
    fi

    # StrictModes off: Android home dir permissions never look canonical to sshd.
    # Redirect all stdio: the daemonized server otherwise keeps the caller's pty
    # open, which wedges piped/scripted invocations. Startup errors land in the log.
    ${sshd} -f /dev/null -p "$port" -h "${hostKey}" \
      -o "PidFile=${runDir}/pid" \
      -o UsePAM=no \
      -o PasswordAuthentication=no \
      -o StrictModes=no \
      < /dev/null >> "${runDir}/log" 2>&1
    rc=$?
    [ $rc -eq 0 ] || cat "${runDir}/log" >&2
    if [ $rc -eq 0 ]; then
      $quiet || echo "sshd listening on port $port"
    else
      echo "sshd failed to start (rc=$rc)" >&2
    fi
    exit $rc
  '')

  (pkgs.writeShellScriptBin "sshd-stop" ''
    if [ -f "${runDir}/pid" ] && kill -0 "$(cat "${runDir}/pid")" 2>/dev/null; then
      kill "$(cat "${runDir}/pid")" && echo "sshd stopped"
    else
      echo "sshd not running"
    fi
    rm -f "${runDir}/pid"
  '')

  (pkgs.writeShellScriptBin "sshd-status" ''
    port="$(cat "${runDir}/port" 2>/dev/null || echo 8023)"
    if [ -f "${runDir}/pid" ] && kill -0 "$(cat "${runDir}/pid")" 2>/dev/null; then
      echo "running (pid $(cat "${runDir}/pid"), port $port)"
    else
      echo "stopped (port $port when started)"
    fi
    if [ -e "${runDir}/autostart" ]; then
      echo "autostart: armed (new interactive sessions start it)"
    else
      echo "autostart: off"
    fi
  '')

  (pkgs.writeShellScriptBin "sshd-autostart" ''
    mkdir -p "${runDir}"
    case "$1" in
      on)  touch "${runDir}/autostart"; echo "autostart armed" ;;
      off) rm -f "${runDir}/autostart"; echo "autostart off" ;;
      *)   [ -e "${runDir}/autostart" ] && echo "autostart: armed" || echo "autostart: off"
           echo "usage: sshd-autostart on|off" ;;
    esac
  '')
]
