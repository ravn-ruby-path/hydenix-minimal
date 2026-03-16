{ config, lib, pkgs, ... }:

let
  cfg = config.hydenix.hm.tools;
in
{
  options.hydenix.hm.tools = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.hydenix.hm.enable;
      description = "Enable tools module";
    };

    tmux = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable tmux terminal multiplexer";
    };
    
    # Add future tools here
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      (lib.mkIf cfg.tmux pkgs.unstable.tmux)
    ];
  };
}
