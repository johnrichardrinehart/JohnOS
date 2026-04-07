{
  pkgs,
  lib,
  ...
}:
let
  ssdMount = "/mnt/nix-ssd";
  buildDir = "${ssdMount}/build";
  cacheDir = "${ssdMount}/nix-cache";
  ssdDevice = "/dev/disk/by-label/NIX_SSD";
  ssdUsers = [ "john" ];
  userList = lib.concatStringsSep "|" ssdUsers;
in
{
  systemd.services.nix-ssd-mount = {
    description = "Mount Nix SSD if available";
    wantedBy = [ "multi-user.target" ];
    before = [ "nix-daemon.service" ];
    after = [ "local-fs.target" ];
    path = [ pkgs.util-linux pkgs.coreutils pkgs.btrfs-progs pkgs.lvm2 ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "10s";
      ExecStop = pkgs.writeShellScript "nix-ssd-unmount" ''
        umount "${cacheDir}" 2>/dev/null || true
        umount "${buildDir}" 2>/dev/null || true
        umount "${ssdMount}" 2>/dev/null || true
        rm -f /run/nix/ssd.conf /run/nix/ssd.env
      '';
    };
    script = ''
      set -e

      echo "Attempting to activate LVM VG 'nas' in degraded mode..."
      vgchange -ay --activationmode degraded nas 2>/dev/null || true

      if [ ! -e "${ssdDevice}" ]; then
        echo "SSD device ${ssdDevice} not found"
        exit 1
      fi

      mkdir -p "${ssdMount}"

      if ! mount -t btrfs -o subvol=/,compress=zstd,noatime "${ssdDevice}" "${ssdMount}"; then
        echo "Failed to mount base volume"
        exit 1
      fi

      mkdir -p "${buildDir}" "${cacheDir}"

      if ! mount -t btrfs -o subvol=@build,compress=zstd,noatime "${ssdDevice}" "${buildDir}"; then
        echo "Failed to mount @build subvolume"
        exit 1
      fi

      if ! mount -t btrfs -o subvol=@cache,compress=zstd,noatime "${ssdDevice}" "${cacheDir}"; then
        echo "Failed to mount @cache subvolume"
        exit 1
      fi

      # This system leaves Nix's build-users-group unset, so the build
      # directory must be writable by the invoking user, not just nixbld.
      # Match the usual /build semantics: sticky + world-writable.
      chown root:root "${buildDir}"
      chmod 1777 "${buildDir}"

      chmod 0755 "${cacheDir}"
      ${lib.concatMapStringsSep "\n" (user: ''
        mkdir -p "${cacheDir}/${user}"
        chown ${user}:${user} "${cacheDir}/${user}"
        chmod 0755 "${cacheDir}/${user}"
      '') ssdUsers}

      mkdir -p /run/nix
      echo "build-dir = ${buildDir}" > /run/nix/ssd.conf
      echo "TMPDIR=${buildDir}" > /run/nix/ssd.env

      echo "SSD setup complete"
    '';
  };

  nix.extraOptions = ''
    !include /run/nix/ssd.conf
  '';

  systemd.services.nix-daemon = {
    after = [ "nix-ssd-mount.service" ];
    wants = [ "nix-ssd-mount.service" ];
    serviceConfig.EnvironmentFile = [ "-/run/nix/ssd.env" ];
  };

  environment.extraInit = ''
    if mountpoint -q "${ssdMount}" 2>/dev/null; then
      case "$USER" in
        ${userList})
          export NIX_CACHE_HOME="${cacheDir}/$USER"
          ;;
      esac
    fi
  '';
}
