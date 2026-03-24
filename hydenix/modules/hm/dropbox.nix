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
    services.dropbox = {
      enable = true;
      path = "${pkgs.unstable.dropbox}/bin/dropbox";
    };

    home.packages = with pkgs; [
      # removed unstable.dropbox to avoid desktop file collision
    ] ++ lib.optionals cfg.appindicator [
      unstable.libappindicator-gtk3
    ];
  };
}
