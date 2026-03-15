{ pkgs, lib, config, ... }:

let
  cfg = config.hydenix.hm.git;
in
{

  options.hydenix.hm.git = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.hydenix.hm.enable;
      description = "Enable git module";
    };

    name = lib.mkOption {
      default = false;
      description = "Git user name";
    };

    email = lib.mkOption {
      default = false;
      description = "Git user email";
    };

    githubCli = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable GitHub CLI";
    };
  };

  config = lib.mkIf cfg.enable {

    programs.git = {
      enable = true;
      settings = {
        user.name = cfg.name;
        user.email = cfg.email;
        init.defaultBranch = "main";
        pull.rebase = false;
      };
    };

    programs.gh = {
      enable = cfg.githubCli;
      package = pkgs.unstable.gh;
    };
  };
}
