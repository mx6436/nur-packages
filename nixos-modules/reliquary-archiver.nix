{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.reliquary-archiver;
in

{
  options.programs.reliquary-archiver = {
    enable = lib.mkEnableOption "reliquary-archiver";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.reliquary-archiver;
      defaultText = lib.literalExpression "pkgs.reliquary-archiver";
      description = "The reliquary-archiver package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    security.wrappers.reliquary-archiver = {
      owner = "root";
      group = "root";
      capabilities = "cap_net_raw+ep";
      source = "${lib.getExe cfg.package}";
    };
  };
}
