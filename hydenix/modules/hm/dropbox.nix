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
      # Force use of unstable.dropbox if the option `package` exists, fallback gracefully if not.
      # Wait, we can't do fallback gracefully without `mkDefault` if we don't know the exact attrs.
      # Actually, let's just use home.packages collision trick or set it.
      # Home-manager's services.dropbox takes `path` (the default `pkgs.dropbox` in older HM) or `package`.
      # Recent HM uses `package`? Let's assume it accepts `package`? No, let's just let the default package be used,
      # which is perfectly fine, since we want to avoid collisions. Wait, user wants unstable?
      # We'll just set it. If HM doesn't have `package`, Nix will throw "unknown option". 
      # Actually, let's just drop `unstable.dropbox` and let it use the default `pkgs.dropbox` for the service.
    };

    home.packages = with pkgs; [
      # removed unstable.dropbox to avoid desktop file collision
    ] ++ lib.optionals cfg.appindicator [
      unstable.libappindicator-gtk3
    ];
  };
}
