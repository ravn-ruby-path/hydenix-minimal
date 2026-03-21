# Plan de Integración de Zed y Helix en Home Manager

Este documento detalla la estrategia para integrar **Zed Editor** y **Helix** en tus dotfiles gestionados por **Home Manager**, basándonos en el patrón determinista libre de FHS (Filesystem Hierarchy Standard) analizado en el repositorio `linuxmobile/shin`.

La idea central de este patrón es mantener la estructura modular idéntica a la de `shin` ([default.nix](file:///C:/Users/dev/Dropbox/ludus/hydenix-minimal/shin/home/editors/zed/default.nix) y [_settings.nix](file:///C:/Users/dev/Dropbox/ludus/hydenix-minimal/shin/home/editors/zed/_settings.nix) / [_languages.nix](file:///C:/Users/dev/Dropbox/ludus/hydenix-minimal/shin/home/editors/helix/_languages.nix)) para que puedas hacer comparaciones exactas (diff). La única diferencia significativa es el paso de `users.users.<nombre>.packages` a `home.packages`.

## Objetivo del Patrón
1. **Idéntica Arquitectura**: Archivos segregados para configuración global y utilidades de lenguaje.
2. **0 dependencias externas**: Al abrir el editor, no necesita descargar nada de internet.
3. **Determinismo**: Siempre usa la misma versión exacta del formateador/LSP provista por Nix.
4. **Inmutabilidad**: Las pre-evaluaciones dictan rutas absolutas en lugar de depender de `/usr/bin/`.

---

## Archivos Involucrados (Resumen de Impacto)

Para asegurar que al revisar en el futuro tengas claridad total, aquí está el desglose exacto de los archivos que se tocaron y los que se crearon desde cero dentro de tus dotfiles:

### 📝 Archivos Modificados (Existentes)
1. **`hydenix/modules/hm/editors.nix`**
   - *Cambio:* Se añadió la opción booleana para Helix (`helix = lib.mkOption {...}`) y se **eliminó** la descarga tradicional cruda de Zed (`pkgs.unstable.zed-editor`) para evitar dobles instalaciones.
2. **`hydenix/modules/hm/default.nix`**
   - *Cambio:* Se añadieron `./zed` y `./helix` a la lista de módulos a ser importados (`imports = [ ... ]`).
3. **`lib/config/home.nix`**
   - *Cambio:* Se agregó la línea `editors.helix = true;` para encender el interruptor de Helix a nivel de usuario (el de Zed ya estaba encendido).

### 🌟 Archivos Creados (Nuevos)
Las lógicas de los wrappers puristas y entornos deterministas se aislaron completamente en estos archivos modulares:
1. **`hydenix/modules/hm/zed/default.nix`** (Orquestador y Wrapper inyectando LSPs inestables).
2. **`hydenix/modules/hm/zed/_settings.nix`** (Asignación de rutas absolutas de Formatters y LSPs para Zed).
3. **`hydenix/modules/hm/helix/default.nix`** (Orquestador y Wrapper inyectando LSPs inestables para Helix).
4. **`hydenix/modules/hm/helix/_languages.nix`** (Resolución de lenguajes puros para Helix).
5. **`integracion/GUIA_AI_EDITORES.md`** (Instrucciones maestras creadas para mantener este estándar con VSCode, Cursor o Antigravity).
6. **`integracion/implementation_plan.md`** (Este mismo documento).

*Cualquier otro archivo `.nix` del sistema o de la carpeta de módulos ajenos a estos listados se mantuvo estrictamente intocable y seguro durante el proceso.*

---

## Proposed Changes

A continuación se plantean los módulos de Home Manager a crear. Deberías ubicarlos en una ruta análoga a la de `shin`, por ejemplo en tu carpeta de editores (`/modules/editors/zed/` y `/modules/editors/helix/`).

### [Módulo Zed Editor]

Se dividen las responsabilidades: [default.nix](file:///C:/Users/dev/Dropbox/ludus/hydenix-minimal/shin/home/editors/zed/default.nix) hace de orquestador y contenedor del paquete (usando `pkgs.symlinkJoin`), mientras que [_settings.nix](file:///C:/Users/dev/Dropbox/ludus/hydenix-minimal/shin/home/editors/zed/_settings.nix) declara los formatters y Language Servers puros.

#### [NEW] [zed/default.nix](file:///C:/Users/dev/Dropbox/ludus/hydenix-minimal/shin/home/editors/zed/default.nix) (Orquestador Base)
```nix
{ config, lib, pkgs, ... }:

let
  configFile = "zed/settings.json";
  
  # Importamos la configuración específica de lenguajes
  languageConfig = import ./_settings.nix { inherit pkgs lib; };
  
  # Fusionamos la configuración base con los lenguajes generados
  settingsJSON = builtins.toJSON (
    {
      telemetry.metrics = false;
      format_on_save = "on";
      # ... el resto de tu configuración global de apariencia (theme, ui_font_family, etc.)
    } // languageConfig
  );

  lspPackages = with pkgs; [
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
    paths = [ pkgs.zed-editor ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm -rf $out/bin
      mkdir -p $out/bin
      makeWrapper ${pkgs.zed-editor}/bin/zeditor $out/bin/zeditor \
        --prefix PATH : ${lspBinPath}/bin
      for bin in ${pkgs.zed-editor}/bin/*; do
        if [ "$(basename $bin)" != "zeditor" ]; then
          ln -s $bin $out/bin/$(basename $bin)
        fi
      done
    '';
  };

in {
  # Instalación usando Home Manager
  home.packages = [ zedWithLSP ];

  # Inyección pura de la configuración
  xdg.configFile."${configFile}" = {
    text = settingsJSON;
    mutable = true;
  };
}
```

#### [NEW] [zed/_settings.nix](file:///C:/Users/dev/Dropbox/ludus/hydenix-minimal/shin/home/editors/zed/_settings.nix) (Lógica de Lenguajes)
```nix
{ pkgs, ... }:

let
  formatters = {
    alejandra = "${pkgs.alejandra}/bin/alejandra";
    oxfmt = "${pkgs.oxfmt}/bin/oxfmt";
  };

  languageServers = {
    nil = "${pkgs.nil}/bin/nil";
  };

  # Helper function (idéntica a shin)
  mkExternalFormatter = command: args: {
    external = { inherit command; arguments = args; };
  };

in {
  languages = {
    Nix = {
      tab_size = 2;
      formatter = mkExternalFormatter formatters.alejandra [ "-q" ];
      format_on_save = "on";
      language_servers = [ "nil" ];
    };
    # ... Añade aquí el resto de lenguajes apuntando a resoluciones absolutas de la nix store
  };

  lsp = {
    nil = {
      binary = { path = languageServers.nil; };
      initialization_options = {
        formatting = {
          command = [ formatters.alejandra "-q" ];
        };
      };
    };
    # ... Añade aquí el resto de LSPs
  };
}
```

---

### [Módulo Helix Editor]

Idéntico a `shin`: se genera el archivo principal de configuración (`config.toml`) en el [default.nix](file:///C:/Users/dev/Dropbox/ludus/hydenix-minimal/shin/home/editors/zed/default.nix), el cual también se encarga de empaquetar `hx` mediante `pkgs.runCommand`. Por otra parte, [_languages.nix](file:///C:/Users/dev/Dropbox/ludus/hydenix-minimal/shin/home/editors/helix/_languages.nix) se ocupa en exclusiva de `languages.toml`.

#### [NEW] [helix/default.nix](file:///C:/Users/dev/Dropbox/ludus/hydenix-minimal/shin/home/editors/helix/default.nix) (Orquestador Base)
```nix
{ pkgs, ... }:

let
  configFile = "helix/config.toml";
  toTOML = (pkgs.formats.toml {}).generate;
  
  # Importamos y generamos la configuración pura de lenguajes
  languagesTOML = import ./_languages.nix { inherit pkgs; };

  lspPackages = with pkgs; [
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
    makeWrapper ${pkgs.helix}/bin/hx $out/bin/hx \
      --prefix PATH : ${lspBinPath}/bin

    for bin in ${pkgs.helix}/bin/*; do
      if [ "$(basename $bin)" != "hx" ]; then
        ln -s $bin $out/bin/$(basename $bin)
      fi
    done
  '';

in {
  # Instalación usando Home Manager
  home.packages = [ helixWithLSP ];

  # Generar settings base de Helix
  xdg.configFile."${configFile}".source = toTOML "config.toml" {
    theme = "noctalia";
    editor = {
      line-number = "relative";
      # ... el resto de tu configuración global pura
    };
  };

  xdg.configFile."helix/languages.toml".source = languagesTOML;
}
```

#### [NEW] [helix/_languages.nix](file:///C:/Users/dev/Dropbox/ludus/hydenix-minimal/shin/home/editors/helix/_languages.nix) (Lógica de Lenguajes)
```nix
{ pkgs, ... }:

let
  formatters = {
    alejandra = "${pkgs.alejandra}/bin/alejandra";
  };
  languageServers = {
    nil = "${pkgs.nil}/bin/nil";
  };
in
  (pkgs.formats.toml {}).generate "languages.toml" {
    language = [
      {
        name = "nix";
        auto-format = true;
        formatter = {
          command = formatters.alejandra;
          args = [ "-q" ];
        };
        language-servers = [ "nil" ];
      }
      # ... el resto de lenguajes definidos aquí
    ];

    language-server = {
      nil = {
        command = languageServers.nil;
        config.nil.formatting.command = [ formatters.alejandra "-q" ];
      };
      # ... el resto de lsps (command = ...)
    };
  }
```

---

## Verification Plan

### Automated Tests
*N/A - La mayoría de esto consiste en configuración del usuario. Se verificará comprobando que Home Manager corra apropiadamente.*

### Manual Verification
1. **Activar configuración de Home Manager:**
   Ejecutar `home-manager switch` para aplicar la configuración actual.
2. **Comparar Diff Visual:**
   Podrás comparar los dos archivos usando una herramienta de diff y verás que esencialmente usas la misma lógica subyacente de `shin`, solo que instalada eficientemente en contexto de usuario (`home.packages`).
3. **Comprobación Práctica:**
   Al usar Zed o Helix en `*.nix`, los respectivos formateadores (como `alejandra`) y LSPs (como `nil`) se iniciarán empleando las rutas hardcoded de la build de Nix.
