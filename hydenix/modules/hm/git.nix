{ pkgs, lib, config, ... }:

let
  cfg = config.hydenix.hm.git;
  
  # A helper to write git-setup.sh as a bash script package.
  gitSetupScript = pkgs.writeShellApplication {
    name = "git-setup";
    runtimeInputs = with pkgs; [ git gh gnupg coreutils gawk gnugrep openssh ];
    text = builtins.readFile ../../../git-setup.sh;
  };
in
{
  options.hydenix.hm.git = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.hydenix.hm.enable;
      description = "Enable git module";
    };

    # === User Identity ===
    name = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Git user name";
    };

    email = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Git user email";
    };
    
    githubUser = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Your GitHub username";
    };

    # === Tools ===
    githubCli = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable GitHub CLI";
    };
    
    editor = lib.mkOption {
      type = lib.types.str;
      default = "nvim";
      description = "Editor for commits and rebases";
    };

    browser = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Browser for opening GitHub links";
    };

    gitProtocol = lib.mkOption {
      type = lib.types.enum [ "https" "ssh" ];
      default = "https";
      description = "Protocol for Git operations";
    };

    lfs.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Git LFS for large files";
    };

    # === Enhancements ===
    delta = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Use delta as pager (pretty diffs)";
      };

      sideBySide = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Show side-by-side diffs";
      };
    };

    gpg = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Sign commits with GPG";
      };

      signingKey = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "GPG key ID for signing";
      };
    };

    extraAliases = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional git aliases";
    };

    ignorePatterns = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "*~"
        "*.swp"
        "*result*"
        ".direnv"
        "node_modules"
        ".DS_Store"
        "*.log"
      ];
      description = "Patterns to ignore globally";
    };
  };

  config = lib.mkIf cfg.enable {
    
    home.packages = [ gitSetupScript ] ++ lib.optionals cfg.lfs.enable [ pkgs.git-lfs ];
    
    home.sessionVariables = lib.mkIf cfg.githubCli (
      {
        GH_EDITOR = cfg.editor;
        GH_PAGER = "less -FR";
      }
      // lib.optionalAttrs (cfg.browser != "") {
        GH_BROWSER = cfg.browser;
      }
    );

    home.shellAliases = lib.mkIf cfg.githubCli {
      ghco = "gh pr checkout";
      ghpv = "gh pr view";
      ghrv = "gh repo view";
      ghis = "gh issue status";
    };

    programs.git = {
      enable = true;
      package = pkgs.git;

      ignores = cfg.ignorePatterns;

      signing = lib.mkIf cfg.gpg.enable {
        signByDefault = true;
        key = if cfg.gpg.signingKey != "" then cfg.gpg.signingKey else null;
      };

      lfs.enable = cfg.lfs.enable;

      settings = {
        user = {
          name = if cfg.name != "" then cfg.name else null;
          email = if cfg.email != "" then cfg.email else null;
        };
        
        alias = {
          st = "status";
          br = "branch";
          co = "checkout";
          d = "diff";
          ca = "commit -am";
          fuck = "commit --amend -m";
          pl = "!git pull origin \$(git rev-parse --abbrev-ref HEAD)";
          ps = "!git push origin \$(git rev-parse --abbrev-ref HEAD)";
          hist = ''log --pretty=format:"%Cgreen%h %Creset%cd %Cblue[%cn] %Creset%s%C(yellow)%d%C(reset)" --graph --date=relative --decorate --all'';
          llog = ''log --graph --name-status --pretty=format:"%C(red)%h %C(reset)(%cd) %C(green)%an %Creset%s %C(yellow)%d%Creset" --date=relative'';
          af = "!git add \$(git ls-files -m -o --exclude-standard | fzf -m)";
          df = "!git hist | peco | awk '{print $2}' | xargs -I {} git diff {}^ {}";
        } // cfg.extraAliases;

        core = {
          editor = cfg.editor;
          whitespace = "fix,-indent-with-non-tab,trailing-space,cr-at-eol";
        };
        init.defaultBranch = "main";
        pull.ff = "only";
        push = {
          autoSetupRemote = true;
          default = "current";
        };
        merge = {
          conflictstyle = "diff3";
          stat = true;
        };
        rebase = {
          autoSquash = true;
          autoStash = true;
        };
        diff.colorMoved = "default";
        rerere = {
          enabled = true;
          autoupdate = true;
        };
        github = lib.mkIf (cfg.githubUser != "") {
          user = cfg.githubUser;
        };
      } // lib.optionalAttrs (cfg.gitProtocol == "ssh") {
        "url \"git@github.com:\"".insteadOf = "https://github.com/";
      };
    };

    programs.delta = lib.mkIf cfg.delta.enable {
      enable = true;
      options = {
        features = "unobtrusive-line-numbers decorations";
        navigate = true;
        side-by-side = cfg.delta.sideBySide;
        true-color = "never";
        
        decorations = {
          commit-decoration-style = "bold grey box ul";
          file-decoration-style = "ul";
          file-style = "bold blue";
          hunk-header-decoration-style = "box";
        };
        
        unobtrusive-line-numbers = {
          line-numbers = true;
          line-numbers-left-format = "{nm:>4}│";
          line-numbers-left-style = "grey";
          line-numbers-right-format = "{np:>4}│";
          line-numbers-right-style = "grey";
        };
      };
    };

    programs.gh = lib.mkIf cfg.githubCli {
      enable = true;
      package = pkgs.unstable.gh;
    };
  };
}
