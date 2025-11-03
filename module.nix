{ config, pkgs, lib, ... }: {
  options.podman-nixos = {
    name = lib.mkOption {
      type = lib.types.str;
      description = "image name";
      default = "nixos";
    };
    tag = lib.mkOption {
      type = lib.types.str;
      description = "image tag";
      default = "latest";
    };
    image = lib.mkOption {
      type = lib.types.path;
      description = "image";
    };
  };
  config = {
    system.activationScripts.specialfs = lib.mkForce "";
    boot = {
      isContainer = true;
      loader.initScript.enable = true;
      postBootCommands = ''
        if [ -f /nix-path-registration ]; then
          ${config.nix.package}/bin/nix-store --load-db < /nix-path-registration && rm /nix-path-registration
        fi
        ${config.nix.package}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
      '';
    };
    systemd.mounts = [ {
      enable = false;
      where = "/sys/kernel/debug";
    } {
      enable = false;
      where = "/sys/kernel/tracing";
    } {
      enable = false;
      where = "/run/wrappers";
    } ];
    systemd.services.suid-sgid-wrappers = {
      # remove /run/wrappers
      unitConfig.RequiresMountsFor = lib.mkForce [ "/nix/store" ];
      preStart = "mkdir -p /run/wrappers";
    };
    networking.useDHCP = false;

    podman-nixos.image = let
      toplevel = config.system.build.toplevel;
      info = pkgs.closureInfo { rootPaths = [ toplevel ]; };
    in pkgs.dockerTools.buildImage {
      inherit (config.podman-nixos) name tag;
      config.Cmd = [ "/sbin/init" ];
      copyToRoot = pkgs.runCommand "root" {} ''
        mkdir -p $out/{nix-support,sbin}
        echo ${toplevel} > $out/nix-support/propagated-build-inputs
        cp ${toplevel}/init $out/sbin/init
        cp ${info}/registration $out/nix-path-registration
      '';
    };
  };
}