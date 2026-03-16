{ ... }:
{

  hydenix.hm = {
    enable = true;

    # ─── Text Editors & IDEs ───────────────────────────────────────────────
    # Configure which code editors and development tools to install
    
    editors.antigravity = true;     # Google Antigravity IDE (from nixpkgs-unstable)
    editors.cursor = true;          # Cursor AI-powered code editor
    editors.zed = true;             # Zed high-performance code editor
    
    editors.claudeCode = true;      # Claude AI integration for VS Code
    editors.geminiCli = true;       # Google Gemini CLI tool
    editors.openCode = true;        # OpenCode IDE
    
    editors.workmux = true;         # Workmux terminal multiplexer
    editors.openSpec = true;        # OpenSpec tool

    git.githubCli = true;           # Enable GitHub CLI
    tools.tmux = true;              # Enable tmux terminal multiplexer

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
  };
}
