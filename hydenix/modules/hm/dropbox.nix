{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hydenix.hm.dropbox;
in
{
  options.hydenix.hm.dropbox = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.hydenix.hm.enable;
      description = "Enable dropbox module";
    };

    appindicator = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable appindicator for dropbox";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      unstable.dropbox
    ] ++ lib.optionals cfg.appindicator [
      unstable.libappindicator-gtk3
    ];
  };
}
