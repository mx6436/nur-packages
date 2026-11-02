{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.clash-nyanpasu;

  clash-nyanpasu = pkgs.callPackage ../pkgs/clash-nyanpasu/package.nix { };

  user = config.users.users.${cfg.user} or { };
  home = toString (user.home or "/home/${cfg.user}");
  primaryGroup = user.group or "";

  dataDir = "${home}/.local/share/clash-nyanpasu";
  configDir = "${home}/.config/clash-nyanpasu";
  appDir = "${cfg.package}/bin";

  # service-manager 0.11 turns the label "moe.elaina.nyanpasu-service" into
  # "elaina-nyanpasu-service"; `nyanpasu-service status` probes that unit, so
  # the name must not change.
  serviceName = "elaina-nyanpasu-service";

  tmpfilesGroup = if primaryGroup == "" then "-" else primaryGroup;
in

{
  options.programs.clash-nyanpasu = {
    enable = lib.mkEnableOption "Clash Nyanpasu";

    package = lib.mkOption {
      type = lib.types.package;
      default = clash-nyanpasu;
      defaultText = lib.literalExpression "pkgs.clash-nyanpasu";
      description = "The clash-nyanpasu package to use.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      example = "alice";
      description = ''
        The desktop user whose configuration and data directories the
        privileged service manages.

        The default XDG directories `~/.config/clash-nyanpasu` and
        `~/.local/share/clash-nyanpasu` are used; custom `XDG_CONFIG_HOME`
        and `XDG_DATA_HOME` values are not supported.
      '';
    };

    serviceMode = lib.mkEnableOption "the privileged Nyanpasu service" // {
      description = ''
        Whether to run the privileged Nyanpasu service as a systemd unit.

        The service owns the core processes and is required for TUN mode. The
        user configured in {option}`programs.clash-nyanpasu.user` is added to
        the `nyanpasu` group so that the application can reach the service
        socket; log in again for the group change to take effect.
      '';
    };

    tunMode = lib.mkEnableOption "TUN mode support" // {
      description = ''
        Whether to relax reverse path filtering for TUN mode.

        The TUN device is created by the core, which only the privileged
        service runs with enough privileges, so this requires
        {option}`programs.clash-nyanpasu.serviceMode`.
      '';
    };

    autoStart = lib.mkEnableOption "Clash Nyanpasu auto launch";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      environment.systemPackages = [
        cfg.package
        (lib.mkIf cfg.autoStart (
          pkgs.makeAutostartItem {
            name = "clash-nyanpasu";
            package = cfg.package;
          }
        ))
      ];

      assertions = [
        {
          assertion = config.users.users ? ${cfg.user};
          message = "programs.clash-nyanpasu.user must name an existing user.";
        }
      ];
    })

    (lib.mkIf (cfg.enable && cfg.tunMode) {
      assertions = [
        {
          assertion = cfg.serviceMode;
          message = "programs.clash-nyanpasu.tunMode requires programs.clash-nyanpasu.serviceMode.";
        }
        {
          assertion =
            config.networking.firewall.checkReversePath != true
            && config.networking.firewall.checkReversePath != "strict";
          message = ''
            {option}`programs.clash-nyanpasu.tunMode` requires {option}`networking.firewall.checkReversePath`
            to be set to `false` or `"loose"`.
          '';
        }
      ];

      networking.firewall.checkReversePath = lib.mkDefault "loose";
    })

    (lib.mkIf (cfg.enable && cfg.serviceMode) {
      users.groups.nyanpasu = { };
      users.users.${cfg.user}.extraGroups = [ "nyanpasu" ];

      systemd.tmpfiles.rules = [
        "d ${configDir} 0700 ${cfg.user} ${tmpfilesGroup} -"
        "d ${dataDir} 0700 ${cfg.user} ${tmpfilesGroup} -"
      ];

      systemd.services.${serviceName} = {
        description = "Nyanpasu privileged service";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        path = [
          pkgs.coreutils
          pkgs.jq
        ];

        # The service refuses to start without a root-owned binding of the
        # user's data directory, which `install` normally writes. Derive it
        # from the `user` option instead of running the GUI's installer.
        preStart = ''
          data_dir="$(realpath -m ${lib.escapeShellArg dataDir})"
          printf '{"data_dir":%s,"owner":{"uid":%s,"gid":%s}}\n' \
            "$(jq -n --arg path "$data_dir" '$path')" \
            "$(id -u ${lib.escapeShellArg cfg.user})" \
            "$(id -g ${lib.escapeShellArg cfg.user})" \
            > /etc/nyanpasu-service/native-store-owner.json
          chown root:root /etc/nyanpasu-service/native-store-owner.json
          chmod 0600 /etc/nyanpasu-service/native-store-owner.json
        '';

        serviceConfig = {
          Type = "simple";
          ExecStart = "${lib.getExe' cfg.package "nyanpasu-service"} server --nyanpasu-data-dir ${lib.escapeShellArg dataDir} --nyanpasu-config-dir ${lib.escapeShellArg configDir} --nyanpasu-app-dir ${lib.escapeShellArg appDir} --service";
          Restart = "on-failure";
          RestartSec = 1;
          TimeoutStopSec = 20;
          StateDirectory = "nyanpasu-service";
          StateDirectoryMode = "0700";
          ConfigurationDirectory = "nyanpasu-service";
          ConfigurationDirectoryMode = "0700";
        };
      };
    })
  ];
}
