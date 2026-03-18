{ ... }:
{

  hydenix.hm = {
    enable = true;

    # ─── Text Editors & IDEs ───────────────────────────────────────────────
    # Configure which code editors and development tools to install
    
    editors.antigravity = true;     # Google Antigravity IDE (from nixpkgs-unstable)
    editors.cursor = true;          # Cursor AI-powered code editor
    editors.zed = true;             # Zed high-performance code editor
    editors.khanelivim = true;      # Khanelivim: Khaneliman's Neovim distro
    
    editors.claudeCode = true;      # Claude AI integration for VS Code
    editors.geminiCli = true;       # Google Gemini CLI tool
    editors.openCode = true;        # OpenCode IDE
    
    editors.workmux = true;         # Workmux terminal multiplexer
    editors.openSpec = true;        # OpenSpec tool

    git = {
      enable = true;
      name = "Roberto Flores";
      email = "25asab015@ujmd.edu.sv";
      githubCli = true;
      githubUser = "ravn-ruby-path";
      editor = "nvim";
      delta.enable = true;
      delta.sideBySide = true;
      lfs.enable = true;
      gpg.enable = true;
      gpg.signingKey = "DDA77282"; 
    };
    
    dropbox.enable = true;          # Enable Dropbox and appindicator
    dolphin.enable = true;          # Enable KDE Dolphin and plugins

    # Enable remote control for kitty (required by workmux)
    terminals.kitty.configText = ''
      allow_remote_control yes
      listen_on unix:@mykitty
    '';

    # ─── Theme Configuration ───────────────────────────────────────────────
    # Manage HyDE themes: select active theme and list installed themes
    
    theme = {
      enable = true;
      active = "BlueSky";           # Currently active theme
      themes = [                    # List of themes to install
        "BlueSky"
        "Catppuccin Latte"
        "Catppuccin-Macchiato"
        "Catppuccin Mocha"
        "Decay Green"
      ];
    };

    hyprland.animations = {
      enable = true;
      preset = "diablo-2";
    };
  };
}
