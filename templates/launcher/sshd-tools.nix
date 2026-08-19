# sshd lifecycle commands for the nix edition. The server config is declarative
# (flags baked here, absolute store paths so sshd's re-exec requirement is always
# met); starting and stopping stay imperative and user-controlled. The host key is
# generated on first start under ~/.ssh/hostkeys — deliberately never in the store.
#
# Commands:
#   sshd-start [--quiet]   start if not running (idempotent)
#   sshd-stop              stop the running instance
#   sshd-status            running state, port, autostart arming
#   sshd-autostart on|off  arm/disarm the interactive-session autostart hook
#                          (see config.fish; nothing starts unless armed)
#
# Port: 8023 by default — com.termux's sshd owns 8022 on the same device.
# Override by writing a port number to ~/.config/sshd/port.
#
# Liveness is probed on the port itself (connect + read the SSH banner), not
# inferred from the pidfile: pidfiles go stale across proot sessions, and an
# sshd orphaned by its proot tracer keeps the port open without ever answering.
{ pkgs }:
let
  runDir = "$HOME/.config/sshd";
  hostKey = "$HOME/.ssh/hostkeys/ssh_host_ed25519_key";
  # These scripts run under whatever shell the user happens to be in, and the base
  # environment ships neither coreutils nor grep, so an unqualified `grep` or `tr`
  # is simply absent right after a first switch. Put what they need on PATH instead
  # of absolutising every call, and keep the inherited PATH behind it so `nix` and
  # `nix-on-droid` still resolve.
  toolPath = ''
    export PATH="${pkgs.lib.makeBinPath [ pkgs.coreutils pkgs.gnugrep ]}:$PATH"
  '';

  sshd = "${pkgs.openssh}/bin/sshd";
  sshKeygen = "${pkgs.openssh}/bin/ssh-keygen";

  # probe <port>: exit 0 = answering (banner seen), 1 = port open but mute
  # (wedged/foreign), 2 = nothing reachable. The outer timeout is load-bearing:
  # bash's /dev/tcp connect blocks forever when the SYN is dropped instead of
  # refused, and read -t only bounds the banner wait, not the connect.
  probeSnippet = ''
    probe() {
      ${pkgs.coreutils}/bin/timeout 4 ${pkgs.bash}/bin/bash -c '
        exec 3<>"/dev/tcp/127.0.0.1/$0" || exit 2
        banner=""
        IFS= read -r -t 3 banner <&3
        case "$banner" in
          SSH-*) exit 0 ;;
          *)     exit 1 ;;
        esac
      ' "$1" 2>/dev/null
      rc=$?
      [ "$rc" -eq 124 ] && rc=2
      return $rc
    }
  '';

  # find_sshd_pids: real kernel pids of our sshd instances, found by the baked
  # host-key path in the command line. The [k] class keeps the scanner's own
  # grep from matching itself.
  findPidsSnippet = ''
    find_sshd_pids() {
      for d in /proc/[0-9]*; do
        if tr '\0' ' ' < "$d/cmdline" 2>/dev/null | grep -q "hostkeys/ssh_host_ed25519_ke[y]"; then
          echo "''${d#/proc/}"
        fi
      done
    }
  '';
in
[
  (pkgs.writeShellScriptBin "sshd-start" ''
    ${toolPath}
    ${probeSnippet}
    quiet=false
    [ "$1" = "--quiet" ] && quiet=true
    mkdir -p "${runDir}" "$HOME/.ssh/hostkeys"
    port="$(cat "${runDir}/port" 2>/dev/null || echo 8023)"

    probe "$port"
    case $? in
      0) $quiet || echo "sshd already running (port $port)"; exit 0 ;;
      1) echo "port $port is open but not answering ssh — a wedged sshd or another service." >&2
         echo "run sshd-stop first (it also cleans up orphaned instances)." >&2
         exit 1 ;;
    esac

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
    ${toolPath}
    ${findPidsSnippet}
    stopped=false
    if [ -f "${runDir}/pid" ] && kill -0 "$(cat "${runDir}/pid")" 2>/dev/null; then
      kill "$(cat "${runDir}/pid")" 2>/dev/null && stopped=true
    fi
    # Pidfile-less leftovers: instances whose pidfile went stale, or that were
    # orphaned by a dead proot tracer and still squat on the port.
    for pid in $(find_sshd_pids); do
      kill "$pid" 2>/dev/null && stopped=true
    done
    rm -f "${runDir}/pid"
    $stopped && echo "sshd stopped" || echo "sshd not running"
  '')

  (pkgs.writeShellScriptBin "sshd-status" ''
    ${toolPath}
    ${probeSnippet}
    port="$(cat "${runDir}/port" 2>/dev/null || echo 8023)"
    probe "$port"
    case $? in
      0) if [ -f "${runDir}/pid" ] && kill -0 "$(cat "${runDir}/pid")" 2>/dev/null; then
           echo "running (pid $(cat "${runDir}/pid"), port $port)"
         else
           echo "running (port $port; pidfile stale)"
         fi ;;
      1) echo "wedged: port $port accepts connections but never answers ssh." ;;
      2) echo "stopped (port $port when started)" ;;
    esac
    if [ -e "${runDir}/autostart" ]; then
      echo "autostart: armed (new interactive sessions start it)"
    else
      echo "autostart: off"
    fi
  '')

  (pkgs.writeShellScriptBin "sshd-autostart" ''
    ${toolPath}
    mkdir -p "${runDir}"
    case "$1" in
      on)  touch "${runDir}/autostart"; echo "autostart armed" ;;
      off) rm -f "${runDir}/autostart"; echo "autostart off" ;;
      *)   [ -e "${runDir}/autostart" ] && echo "autostart: armed" || echo "autostart: off"
           echo "usage: sshd-autostart on|off" ;;
    esac
  '')
]
