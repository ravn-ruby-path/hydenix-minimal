{ config, lib, pkgs, ... }:

let
  configFile = "zed/settings.json";
  
  # Importamos la configuración específica de lenguajes
  languageConfig = import ./_settings.nix { inherit pkgs lib; };
  
  # Fusionamos la configuración base con los lenguajes generados
  settingsJSON = builtins.toJSON (
    {
      telemetry = {
        diagnostics = false;
        metrics = false;
      };
      format_on_save = "on";
      ui_font_size = 15;
      buffer_font_size = 14;
      theme = {
        mode = "system";
        light = "One Light";
        dark = "One Dark";
      };
    } // languageConfig
  );

  lspPackages = with pkgs.unstable; [
    astro-language-server biome marksman nil tailwindcss-language-server vue-language-server
    alejandra oxfmt shfmt nodejs
  ];

  lspBinPath = pkgs.buildEnv {
    name = "zed-lsp-env";
    paths = lspPackages;
    pathsToLink = [ "/bin" ];
  };

  zedWithLSP = pkgs.symlinkJoin {
    name = "zed-with-lsp";
    paths = [ pkgs.unstable.zed-editor ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm -rf $out/bin
      mkdir -p $out/bin
      makeWrapper ${pkgs.unstable.zed-editor}/bin/zeditor $out/bin/zeditor \
        --prefix PATH : ${lspBinPath}/bin
      for bin in ${pkgs.unstable.zed-editor}/bin/*; do
        if [ "$(basename $bin)" != "zeditor" ]; then
          ln -s $bin $out/bin/$(basename $bin)
        fi
      done
    '';
  };

  cfg = config.hydenix.hm.editors;

in {
  config = lib.mkIf cfg.zed {
    home.packages = [ zedWithLSP ];

    xdg.configFile."${configFile}" = {
      text = settingsJSON;
      mutable = true;
    };
  };
}
