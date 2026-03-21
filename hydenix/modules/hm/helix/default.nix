{ config, lib, pkgs, ... }:

let
  configFile = "helix/config.toml";
  toTOML = (pkgs.formats.toml {}).generate;
  
  languagesTOML = import ./_languages.nix { inherit pkgs; };

  lspPackages = with pkgs.unstable; [
    astro-language-server biome marksman nil tailwindcss-language-server vue-language-server
    alejandra oxfmt shfmt
  ];

  lspBinPath = pkgs.buildEnv {
    name = "helix-lsp-env";
    paths = lspPackages;
    pathsToLink = [ "/bin" ];
  };

  helixWithLSP = pkgs.runCommand "helix-with-lsp" {
    buildInputs = [ pkgs.makeWrapper ];
  } ''
    mkdir -p $out/bin
    makeWrapper ${pkgs.unstable.helix}/bin/hx $out/bin/hx \
      --prefix PATH : ${lspBinPath}/bin

    for bin in ${pkgs.unstable.helix}/bin/*; do
      if [ "$(basename $bin)" != "hx" ]; then
        ln -s $bin $out/bin/$(basename $bin)
      fi
    done
  '';

  cfg = config.hydenix.hm.editors;

in {
  config = lib.mkIf cfg.helix {
    home.packages = [ helixWithLSP ];

    xdg.configFile."${configFile}".source = toTOML "config.toml" {
      theme = "noctalia";
      editor = {
        line-number = "relative";
        cursorline = true;
        bufferline = "multiple";
        color-modes = true;
        true-color = true;
      };
    };

    xdg.configFile."helix/languages.toml".source = languagesTOML;
  };
}
