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

    # Override the broken dropbox-start script containing "run: command not found"
    # and disable the HOME override which forces dropbox into ~/.dropbox-hm
    systemd.user.services.dropbox = {
      Service = {
        ExecStart = lib.mkForce "${pkgs.unstable.dropbox}/bin/dropbox start";
        Environment = lib.mkForce [ "DISPLAY=" ];
        PIDFile = lib.mkForce "%h/.dropbox/dropbox.pid";
      };
    };

    home.packages = with pkgs; [
      # removed unstable.dropbox to avoid desktop file collision
    ] ++ lib.optionals cfg.appindicator [
      unstable.libappindicator-gtk3
    ];
  };
}
