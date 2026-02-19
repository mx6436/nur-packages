{
  config,
  lib,
  pkgs,
  natfrp-service ? pkgs.callPackage ../pkgs/natfrp-service/package.nix { },
  ...
}:

let
  cfg = config.services.natfrp;
in

{
  options.services.natfrp = {
    enable = lib.mkEnableOption "natfrp service";

    package = lib.mkOption {
      type = lib.types.package;
      default = natfrp-service;
      defaultText = lib.literalExpression "pkgs.callPackage ../pkgs/natfrp-service/package.nix { }";
      description = "The natfrp-service package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.natfrp = {
      enable = true;
      description = "SakuraFrp Launcher";

      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/natfrp-service --daemon";

        TimeoutStopSec = "20";
        Restart = "on-failure";
        RestartSec = "5s";

        DynamicUser = "true";
        StateDirectory = "natfrp";
        Environment = "NATFRP_SERVICE_WD=%S/natfrp";
      };
    };
  };
}
