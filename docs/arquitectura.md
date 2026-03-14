# Arquitectura de Hydenix — Guía Completa

> **¿Qué es Hydenix?**
> Hydenix es una configuración NixOS + Home Manager que convierte HyDE (Hyprland Desktop Environment, originalmente para Arch Linux) en un sistema declarativo, reproducible y extensible basado en Nix. En vez de scripts de instalación, todo es código Nix.

---

## Tabla de Contenidos

1. [Visión General de la Arquitectura](#1-visión-general-de-la-arquitectura)
2. [El Punto de Entrada: `flake.nix`](#2-el-punto-de-entrada-flakenix)
3. [El Sistema de Overlays: `hydenix/sources/overlay.nix`](#3-el-sistema-de-overlays-hydenixsourcesoverlaynix)
4. [La Derivación de HyDE: `hydenix/sources/hyde.nix`](#4-la-derivación-de-hyde-hydenixsourceshydenix)
5. [El Sistema de Temas](#5-el-sistema-de-temas)
   - 5.1 [`hydenix/sources/themes/default.nix`](#51-hydenixsourcesthemesdefaultnix)
   - 5.2 [`hydenix/sources/themes/utils/mkTheme.nix`](#52-hydenixsourcesthemesutilsmkthemenix)
   - 5.3 [Un archivo de tema individual](#53-un-archivo-de-tema-individual)
6. [Módulos del Sistema NixOS](#6-módulos-del-sistema-nixos)
   - 6.1 [`hydenix/modules/system/default.nix`](#61-hydenixmodulyssystemdefaultnix)
   - 6.2 [`system/system.nix`](#62-systemsystemnix)
   - 6.3 [`system/boot.nix`](#63-systembootnix)
   - 6.4 [`system/sddm.nix`](#64-systemsddmnix)
   - 6.5 [Otros módulos del sistema](#65-otros-módulos-del-sistema)
7. [Módulos de Home Manager (hm)](#7-módulos-de-home-manager-hm)
   - 7.1 [`hydenix/modules/hm/default.nix`](#71-hydenixmoduleshmmdefaultnix)
   - 7.2 [`hm/mutable.nix` — El corazón de los archivos mutables](#72-hmmutablenix--el-corazón-de-los-archivos-mutables)
   - 7.3 [`hm/hyde.nix` — Instalación de HyDE](#73-hmhydenix--instalación-de-hyde)
   - 7.4 [`hm/theme.nix` — Gestión de Temas](#74-hmthemenix--gestión-de-temas)
   - 7.5 [`hm/hyprland/` — Configuración de Hyprland](#75-hmhyprland--configuración-de-hyprland)
   - 7.6 [`hm/shell.nix` — Shell del usuario](#76-hmshellnix--shell-del-usuario)
   - 7.7 [`hm/waybar.nix` — Barra del sistema](#77-hmwaybarnix--barra-del-sistema)
   - 7.8 [Otros módulos hm](#78-otros-módulos-hm)
8. [La Capa `lib/`](#8-la-capa-lib)
   - 8.1 [`lib/config/`](#81-libconfig)
   - 8.2 [`lib/dev-shell.nix`](#82-libdev-shellnix)
   - 8.3 [`lib/hyde-update/`](#83-libhyde-update)
   - 8.4 [`lib/vms/`](#84-libvms)
9. [La Plantilla para Usuarios: `template/`](#9-la-plantilla-para-usuarios-template)
10. [Archivos Raíz de Configuración](#10-archivos-raíz-de-configuración)
11. [El Flujo Completo: De Flake a Escritorio](#11-el-flujo-completo-de-flake-a-escritorio)
12. [Cómo Extender Hydenix](#12-cómo-extender-hydenix)

---

## 1. Visión General de la Arquitectura

```
hydenix/
├── flake.nix                   ← Punto de entrada. Define inputs, outputs, módulos y paquetes.
├── flake.lock                  ← Versiones fijadas de todos los inputs.
│
├── hydenix/                    ← Código core de hydenix
│   ├── modules/
│   │   ├── hm/                 ← Módulos de Home Manager (configuración del usuario)
│   │   └── system/             ← Módulos NixOS (configuración del sistema)
│   └── sources/                ← Derivaciones Nix (paquetes custom)
│       ├── overlay.nix         ← Expone todos los paquetes custom al sistema de pkgs
│       ├── hyde.nix            ← Empaqueta el repo HyDE-Project/HyDE
│       ├── themes/             ← 59 temas, cada uno como derivación Nix
│       └── ...                 ← Otros paquetes: cursores, iconos, pokego, etc.
│
├── lib/                        ← Utilidades internas del flake
│   ├── config/                 ← Configuración NixOS "real" de hydenix
│   ├── dev-shell.nix           ← Entorno de desarrollo del proyecto
│   ├── hyde-update/            ← Script/herramienta para updater HyDE
│   └── vms/                    ← Configuraciones de VMs para testing
│
├── template/                   ← Plantilla para que usuarios creen su propio flake
│   ├── flake.nix
│   ├── configuration.nix
│   ├── hardware-configuration.nix
│   └── modules/
│       ├── hm/                 ← Módulos hm del usuario
│       └── system/             ← Módulos system del usuario
│
└── docs/                       ← Documentación (aquí estás)
```

La arquitectura tiene **tres capas**:

| Capa | Responsabilidad | Tecnología Nix |
|------|----------------|----------------|
| **Sources** | Empaquetar el código HyDE y assets | `stdenv.mkDerivation` |
| **Modules/System** | Configurar el sistema operativo | `nixosModules` |
| **Modules/hm** | Configurar el entorno del usuario | `homeModules` |

---

## 2. El Punto de Entrada: `flake.nix`

**Archivo:** [`flake.nix`](file:///c:/Users/Rob/hydenix/flake.nix)

Este es el archivo más importante del repositorio. Define todo lo que Nix necesita saber.

### Inputs (Dependencias externas)

```nix
inputs = {
  nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable"; # Paquetes siempre frescos
  nixpkgs.url = "github:nixos/nixpkgs/95e96e8...";               # Pinned para estabilidad
  home-manager = { ... inputs.nixpkgs.follows = "nixpkgs"; };    # HM sigue el nixpkgs de hydenix
  nixos-hardware.url = "...";                                      # Módulos de hardware
  nix-index-database = { ... };                                    # Para el comando comma (,)
  hyde = { url = "github:HyDE-Project/HyDE/be97b8b..."; flake = false; }; # El código HyDE, pinned
  hyq.url = "github:richen604/hyprquery";                         # Query de hyprland
  hydectl.url = "github:richen604/hydectl";                       # CLI de HyDE
  hyde-ipc.url = "github:richen604/hyde-ipc";                     # IPC de HyDE
  hyde-config.url = "github:richen604/hyde-config";               # Servicio config parser
};
```

**Punto clave:** El repo `HyDE-Project/HyDE` está **pinned a un commit específico** (`be97b8b4...`). Esto es intencional: hydenix controla cuándo actualizar HyDE para garantizar que los patches aplicados en `hyde.nix` sigan siendo compatibles.

### Outputs (Lo que el flake expone)

```nix
outputs = { ... }@inputs: {
  # Módulos reutilizables (la API pública de hydenix)
  homeModules.default  = import ./hydenix/modules/hm;      # Módulo hm
  nixosModules.default = import ./hydenix/modules/system;  # Módulo system
  overlays.default     = import ./hydenix/sources/overlay.nix { inherit inputs; };

  # Plantilla para nuevos usuarios
  templates.default = { path = ./template; ... };

  # Configuración NixOS completa (la instalación de desarrollo/referencia)
  nixosConfigurations.default = defaultConfig;

  # Paquetes construibles directamente
  packages.${system} = {
    default  = vmConfig.config.system.build.vm;  # VM de prueba
    demo-vm  = demoVmConfig.config.system.build.vm;
    hyde-update = ...;  # Herramienta de actualización
    hyq      = inputs.hyq.packages.${system}.default;
    hydectl  = inputs.hydectl.packages.${system}.default;
    hyde-config = inputs.hyde-config.packages.${system}.default;
  };

  # CI checks
  checks.${system} = { hyq = ...; hydectl = ...; hyde-config = ...; };

  # Entorno de desarrollo
  devShells.${system}.default = import ./lib/dev-shell.nix { inherit inputs; };

  # Lib pública para que usuarios construyan VMs de su config
  lib.vmConfig = import ./lib/vms/nixos-vm.nix;
}
```

---

## 3. El Sistema de Overlays: `hydenix/sources/overlay.nix`

**Archivo:** [`hydenix/sources/overlay.nix`](file:///c:/Users/Rob/hydenix/hydenix/sources/overlay.nix)

Un **overlay** en Nix es una función que extiende el conjunto de paquetes (`pkgs`). Todo lo que hydenix necesita y que no existe en nixpkgs se define aquí.

```nix
{ inputs }:
final: prev:
let
  callPackage = prev.lib.callPackageWith (prev // packages // inputs);

  # nixpkgs-unstable siempre frescos, accesible como pkgs.unstable.<nombre>
  unstablePkgs = import inputs.nixpkgs-unstable {
    inherit (prev) system;
    config.allowUnfree = true;
  };

  packages = {
    hyde-gallery          = callPackage ./hyde-gallery.nix { };
    pokego                = callPackage ./pokego.nix { };
    python-pyamdgpuinfo   = callPackage ./python-pyamdgpuinfo.nix { };
    Tela-circle-dracula   = callPackage ./Tela-circle-dracula.nix { };
    Bibata-Modern-Ice     = callPackage ./Bibata-Modern-Ice.nix { };
    hyde                  = callPackage ./hyde.nix { inherit inputs; };
    hydenix-themes        = callPackage ./themes/default.nix { };
    hyq                   = inputs.hyq.packages.${prev.stdenv...}.default;
    hydectl               = inputs.hydectl.packages.${...}.default;
    hyde-ipc              = inputs.hyde-ipc.packages.${...}.default;
    hyde-config           = inputs.hyde-config.packages.${...}.default;
    unstable              = unstablePkgs;  # pkgs.unstable.cualquierPaquete
  };
in packages
```

**Cómo funciona:** Este overlay se registra en `lib/config/default.nix` al instanciar `nixpkgs`. A partir de ese momento, en cualquier módulo puedes escribir `pkgs.hyde`, `pkgs.hydenix-themes`, `pkgs.unstable.otroPaquete`, etc.

---

## 4. La Derivación de HyDE: `hydenix/sources/hyde.nix`

**Archivo:** [`hydenix/sources/hyde.nix`](file:///c:/Users/Rob/hydenix/hydenix/sources/hyde.nix)

Esta es una de las derivaciones más complejas del proyecto. Toma el código fuente de `HyDE-Project/HyDE` y lo adapta para NixOS.

```nix
{ pkgs, inputs }:
pkgs.stdenv.mkDerivation {
  name = "hyde-modified";
  src = inputs.hyde;  # El repo HyDE completo como fuente

  buildPhase = ''
    # 1. Eliminar binarios externos que vienen en HyDE (se reemplazan por las versiones Nix)
    rm -rf Configs/.local/lib/hyde/resetxdgportal.sh
    rm -rf Configs/.local/bin/hydectl
    rm -rf Configs/.local/bin/hyde-ipc
    rm -rf Configs/.local/lib/hyde/hyde-config
    rm -rf Configs/.local/lib/hyde/hyq

    # 2. Aplicar patches de compatibilidad NixOS:
    # En NixOS los binarios tienen wrappers con el sufijo "-wrapped"
    find . -type f | xargs sed -i 's/killall waybar/killall .waybar-wrapped/g'
    find . -type f | xargs sed -i 's/killall dunst/killall .dunst-wrapped/g'
    find . -type f | xargs sed -i 's/killall kitty/killall .kitty-wrapped/g'

    # 3. Corregir comandos find para seguir symlinks (patrón Nix store)
    find . -type f -executable | xargs sed -i 's/find "/find -L "/g'

    # 4. Fix para temas gtk4
    sed -i '187,190d' Configs/.local/lib/hyde/theme.switch.sh

    # 5. Construir assets (fuentes, extensión VSCode, temas GRUB, iconos, GTK)
    mkdir -p $out/share/fonts/truetype
    tar xzf ./Source/arcs/Font_*.tar.gz -C $out/share/fonts/truetype/
    # ... etc
  '';

  installPhase = ''
    mkdir -p $out
    cp -r . $out
  '';
}
```

**Lo que esta derivación produce (`pkgs.hyde`):**
- `$out/Configs/` — todos los dotfiles de HyDE (zsh, hyprland, waybar, etc.)
- `$out/.local/lib/hyde/` — scripts de HyDE (theme.switch.sh, etc.)
- `$out/share/fonts/` — fuentes extraídas de los archives
- `$out/share/grub/themes/` — temas GRUB (Retroboot, Pochita)
- `$out/share/icons/` — iconos Wallbash
- `$out/share/themes/` — tema GTK Wallbash

---

## 5. El Sistema de Temas

### 5.1 `hydenix/sources/themes/default.nix`

**Archivo:** [`hydenix/sources/themes/default.nix`](file:///c:/Users/Rob/hydenix/hydenix/sources/themes/default.nix)

Este archivo es un **registro** que mapea nombres de temas a derivaciones Nix:

```nix
{ pkgs }:
let
  mkTheme = import ./utils/mkTheme.nix { inherit pkgs; };
  callTheme = file: import file { inherit pkgs mkTheme; };
in {
  "Catppuccin Mocha" = callTheme ./Catppuccin-Mocha.nix;
  "Catppuccin Latte" = callTheme ./Catppuccin-Latte.nix;
  "Dracula"          = callTheme ./Dracula.nix;
  "Tokyo Night"      = callTheme ./Tokyo-Night.nix;
  # ... 59 temas en total
}
```

El resultado (`pkgs.hydenix-themes`) es un **attrset** donde cada clave es el nombre del tema y cada valor es su derivación. Esto permite en `theme.nix` hacer: `pkgs.hydenix-themes.${"Catppuccin Mocha"}`.

### 5.2 `hydenix/sources/themes/utils/mkTheme.nix`

**Archivo:** [`hydenix/sources/themes/utils/mkTheme.nix`](file:///c:/Users/Rob/hydenix/hydenix/sources/themes/utils/mkTheme.nix)

La función constructora de temas. Recibe `{ name, src, meta }` y devuelve una derivación que:

1. Copia los configs HyDE del tema a `$out/share/hyde/themes/<name>/`
2. Extrae el tema GTK (si existe) a `$out/share/themes/`
3. Extrae iconos (si existen) a `$out/share/icons/`
4. Extrae cursores (si existen) a `$out/share/icons/`
5. Extrae fuentes (si existen) a `$out/share/fonts/`

Maneja correctamente el problema de symlinks rotos en el Nix store, y respeta la estructura de archivos esperada por HyDE.

### 5.3 Un archivo de tema individual

**Ejemplo:** `hydenix/sources/themes/Catppuccin-Mocha.nix`

```nix
{ pkgs, mkTheme }:
mkTheme {
  name = "Catppuccin Mocha";
  src = pkgs.fetchFromGitHub {
    owner = "HyDE-Project";
    repo  = "hyde-gallery";
    rev   = "abc123...";
    sha256 = "sha256-...";
  };
  meta = {
    description = "Catppuccin Mocha theme for HyDE";
    homepage = "...";
    priority = 100;
  };
}
```

Cada tema descarga su propio repositorio de `hyde-gallery` con un hash fijo — **total reproducibilidad**.

---

## 6. Módulos del Sistema NixOS

### 6.1 `hydenix/modules/system/default.nix`

**Archivo:** [`hydenix/modules/system/default.nix`](file:///c:/Users/Rob/hydenix/hydenix/modules/system/default.nix)

El **punto de entrada** para todos los módulos de sistema. Importa todos los submódulos y define las opciones globales del namespace `hydenix`:

```nix
{ lib, config, ... }:
let cfg = config.hydenix;
in {
  imports = [
    ./audio.nix    # PipeWire, audio
    ./boot.nix     # bootloader, kernel
    ./hardware.nix # GPU, OpenGL
    ./network.nix  # NetworkManager
    ./nix.nix      # configuración de Nix/nixpkgs
    ./sddm.nix     # display manager
    ./system.nix   # paquetes core, Hyprland, Bluetooth
    ./gaming.nix   # Steam, gamemode
  ];

  options.hydenix = {
    enable   = lib.mkEnableOption "Enable Hydenix modules globally";
    hostname = lib.mkOption { type = lib.types.str; };
    timezone = lib.mkOption { type = lib.types.str; };
    locale   = lib.mkOption { type = lib.types.str; };
  };

  config = {
    hydenix.enable = lib.mkDefault false;

    # Validaciones: si hydenix está activo, estas opciones son obligatorias
    assertions = lib.mkIf cfg.enable [
      { assertion = cfg.hostname != ""; message = "hydenix.hostname must be set"; }
      { assertion = cfg.timezone != ""; }
      { assertion = cfg.locale != "";   }
    ];

    # Aplica las opciones cuando hydenix está activo
    time.timeZone        = lib.mkIf cfg.enable cfg.timezone;
    i18n.defaultLocale   = lib.mkIf cfg.enable cfg.locale;
    networking.hostName  = lib.mkIf cfg.enable cfg.hostname;

    system.stateVersion = "25.05";
  };
}
```

**Patrón importante:** Cada módulo usa la misma convención:
1. Lee su propia porción de config: `cfg = config.hydenix.something`
2. Define opciones bajo `options.hydenix.something`
3. Aplica la config **solo si** `cfg.enable` es `true` (`lib.mkIf cfg.enable`)

### 6.2 `system/system.nix`

El módulo más denso. Instala y configura el núcleo del sistema:

- **Paquetes esenciales:** `parallel`, `jq`, `imagemagick`, `wl-clipboard`, `cliphist`, `cava`, `fzf`, `polkit_gnome`, `dbus`, `xwayland`, etc.
- **Hyprland:** `programs.hyprland.enable = true` con soporte UWSM
- **Bluetooth:** habilitado con soporte Media
- **Servicios:** `dbus`, `upower`, `openssh`, `libinput`
- **Seguridad:** `polkit`, `pam`, `rtkit`
- **Portales XDG:** `xdg-desktop-portal-hyprland` + `xdg-desktop-portal-gtk`
- **Variable de entorno:** `NIXOS_OZONE_WL=1` para Electron/Chrome nativo Wayland

### 6.3 `system/boot.nix`

Gestiona el bootloader con opciones configurables:

```nix
options.hydenix.boot = {
  useSystemdBoot = lib.mkOption { type = lib.types.bool; default = true; };
  grubTheme      = lib.mkOption { type = lib.types.enum ["Retroboot" "Pochita"]; };
  grubExtraConfig = lib.mkOption { ... };
  kernelPackages  = lib.mkOption { default = pkgs.linuxPackages_zen; };
};
```

- Por defecto usa `systemd-boot`. Si `useSystemdBoot = false`, configura GRUB con el tema seleccionado (extraído de `pkgs.hyde`).
- El kernel por defecto es `linux-zen`, optimizado para escritorio.

### 6.4 `system/sddm.nix`

Configura el display manager:
- Usa el tema `sddm-astronaut-theme`
- Modo Wayland habilitado
- Cursor `Bibata-Modern-Ice` (tamaño 24)
- HiDPI habilitado
- Sesión por defecto: `hyprland.desktop`

### 6.5 Otros módulos del sistema

| Archivo | Qué configura |
|---------|--------------|
| `audio.nix` | PipeWire + wireplumber, soporte Bluetooth audio |
| `hardware.nix` | OpenGL/Vulkan, soporte GPU |
| `network.nix` | NetworkManager, resolución DNS |
| `nix.nix` | Experimental features, caché binario, flakes, auto-optimize |
| `gaming.nix` | Steam, gamemode, proton |

---

## 7. Módulos de Home Manager (hm)

### 7.1 `hydenix/modules/hm/default.nix`

**Archivo:** [`hydenix/modules/hm/default.nix`](file:///c:/Users/Rob/hydenix/hydenix/modules/hm/default.nix)

El punto de entrada del módulo hm. Importa todos los submódulos y define el toggle global:

```nix
{ lib, ... }:
{
  imports = [
    ./mutable.nix      # Infraestructura para archivos mutables
    ./comma.nix        # Herramienta comma (,command)
    ./dolphin.nix      # File manager KDE
    ./editors.nix      # VSCode, nvim, etc.
    ./fastfetch.nix    # Fastfetch config
    ./firefox.nix      # Firefox
    ./gtk.nix          # Tema GTK
    ./git.nix          # Git
    ./hyde.nix         # HyDE core + dotfiles
    ./hyprland         # Hyprland (subdirectorio complejo)
    ./lockscreen.nix   # Hyprlock
    ./notifications.nix # Dunst/Swaync
    ./qt.nix           # Tema Qt
    ./rofi.nix         # Lanzador de apps
    ./screenshots.nix  # Grim/slurp
    ./shell.nix        # zsh/fish/bash + prompt
    ./social.nix       # Discord, etc.
    ./spotify.nix      # Spotify
    ./swww.nix         # Wallpaper daemon
    ./terminals.nix    # Kitty
    ./theme.nix        # Sistema de temas HyDE
    ./uwsm.nix         # Universal Wayland Session Manager
    ./waybar.nix       # Barra del sistema
    ./wlogout.nix      # Pantalla de logout
    ./xdg.nix          # XDG dirs + asociaciones
  ];

  options.hydenix.hm = {
    enable = lib.mkEnableOption "Enable Hydenix home-manager modules globally";
  };

  config = {
    hydenix.hm.enable = lib.mkDefault false;
    home.stateVersion = "25.05";
    programs.home-manager.enable = true;
  };
}
```

Cada módulo hm tiene su propia opción `hydenix.hm.<modulo>.enable` que por defecto hereda el valor de `hydenix.hm.enable`.

### 7.2 `hm/mutable.nix` — El corazón de los archivos mutables

**Archivo:** [`hydenix/modules/hm/mutable.nix`](file:///c:/Users/Rob/hydenix/hydenix/modules/hm/mutable.nix)

Este módulo resuelve un problema fundamental: **HyDE modifica sus propios archivos de config en tiempo de ejecución** (wallbash genera colores, el theme switcher escribe en disco). Pero home-manager por defecto crea **symlinks de solo lectura** al Nix store.

**Solución:** Agrega la opción `mutable = true` a `home.file`, `xdg.configFile` y `xdg.dataFile`:

```nix
options.home.file = lib.types.attrsOf (lib.types.submodule {
  options.mutable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Copia el archivo en lugar de symlink. Permite modificaciones en runtime.";
  };
});
```

Y una **activation action** (`mutableGeneration`) que se ejecuta **después** de `linkGeneration`. Para cada archivo marcado como `mutable = true`:
1. Lo copia con `cp`, eliminando el symlink/archivo existente (`--remove-destination`)
2. Si es un directorio, lo copia recursivamente
3. Detecta si el archivo es ejecutable/script y le añade permisos `u+wx`

**Uso en otros módulos:**
```nix
home.file.".config/hyde/config.toml" = {
  source = "${pkgs.hyde}/Configs/.config/hyde/config.toml";
  force = true;
  mutable = true;  # HyDE puede modificar este archivo en runtime
};
```

### 7.3 `hm/hyde.nix` — Instalación de HyDE

**Archivo:** [`hydenix/modules/hm/hyde.nix`](file:///c:/Users/Rob/hydenix/hydenix/modules/hm/hyde.nix)

Este módulo instala la capa de usuario de HyDE. Cuando `hydenix.hm.hyde.enable = true`:

**Paquetes instalados:**
```nix
home.packages = with pkgs; [
  hyde              # El core de HyDE (pkgs.hyde del overlay)
  Bibata-Modern-Ice # Cursor theme
  Tela-circle-dracula # Icon theme
  kdePackages.kconfig
  wf-recorder
  python-pyamdgpuinfo
  hyq hydectl hyde-ipc hyde-config
];
```

**Variables de sesión:**
```nix
home.sessionVariables = {
  HYPRLAND_CONFIG = "${config.xdg.dataHome}/hypr/hyprland.conf";
};
```

**Archivos desplegados (dotfiles de HyDE):**
- `.config/hyde/wallbash/` — scripts de wallbash (mutable)
- `.local/lib/hyde/` — scripts core de HyDE (mutable)
- `.local/share/hyde/` — datos compartidos de HyDE (mutable)
- `.local/share/waybar/` — layouts, módulos, estilos de waybar
- `.local/share/wallbash/` — templates de wallbash (mutable)
- `.config/MangoHud/MangoHud.conf` — overlay de GPU para gaming
- `.local/binary/hyde-shell` — wrapper de `hyde-shell` con PYTHONPATH correcto
- Servicios systemd: `hyde-config.service`, `hyde-ipc.service`

**Activation action:** crea el archivo `.config/cava/config` en el primer boot (cava falla si no existe).

### 7.4 `hm/theme.nix` — Gestión de Temas

**Archivo:** [`hydenix/modules/hm/theme.nix`](file:///c:/Users/Rob/hydenix/hydenix/modules/hm/theme.nix)

El módulo de temas resuelve la instalación y activación de temas HyDE en NixOS.

**Opciones:**
```nix
options.hydenix.hm.theme = {
  enable = ...;
  active = lib.mkOption {
    type = lib.types.str;
    default = "Catppuccin Mocha";
    description = "Tema activo";
  };
  themes = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = ["Catppuccin Mocha" "Catppuccin Latte"];
    description = "Lista de temas disponibles para instalar";
  };
};
```

**Cómo funciona la instalación:**
```nix
# Crea un paquete combinado con todos los temas seleccionados
home.packages = [
  (pkgs.symlinkJoin {
    name = "hydenix-themes";
    paths = map findThemeByName availableThemes;  # filtra los que no existen
  })
];

# Crea symlinks individuales en ~/.config/hyde/themes/<nombre>/
home.file.".config/hyde/themes/${theme.name}" = {
  source = "${theme.pkg}/share/hyde/themes/${theme.name}";
  force = true; recursive = true; mutable = true;
};
```

**Activación del tema — proceso en dos fases:**

Fase 1 (activation action — antes de `graphical.target`):
```bash
# Ejecuta el switcher de temas de HyDE directamente
$HOME/.local/lib/hyde/theme.switch.sh -s "Catppuccin Mocha"
```

Fase 2 (servicios systemd — después de `graphical.target` y `dbus.service`):
- **`setThemeDconf.service`**: aplica settings de Qt/GTK via dconf
- **`setTheme.service`**: re-ejecuta el theme switch completo (necesario porque dconf requiere una sesión activa)

Este diseño en dos fases garantiza que el tema se aplique correctamente tanto en el primer boot como en rebuilds posteriores.

### 7.5 `hm/hyprland/` — Configuración de Hyprland

**Directorio:** [`hydenix/modules/hm/hyprland/`](file:///c:/Users/Rob/hydenix/hydenix/modules/hm/hyprland/)

El módulo más complejo del proyecto. Está dividido en múltiples archivos:

| Archivo | Propósito |
|---------|-----------|
| `default.nix` | Punto de entrada, importa todos, instala `hyprutils`, `hyprpicker`, `hyprcursor` |
| `options.nix` | **Define todas las opciones del módulo** (ver abajo) |
| `assertions.nix` | Validaciones declarativas de la configuración |
| `animations.nix` | Gestión de presets de animación |
| `shaders.nix` | Gestión de shaders GLSL para Hyprland |
| `workflows.nix` | Perfiles de flujo de trabajo (gaming, editing, etc.) |
| `hypridle.nix` | Configuración del demonio de inactividad |
| `keybindings.nix` | Atajos de teclado |
| `windowrules.nix` | Reglas de ventanas |
| `nvidia.nix` | Variables de entorno y tweaks para NVIDIA |
| `monitors.nix` | Configuración de monitores |

**Opciones principales** (de `options.nix`):

```nix
options.hydenix.hm.hyprland = {
  enable      = ...;
  extraConfig = ...; # se añade a userprefs.conf
  overrideMain = ...; # reemplaza hyprland.conf completamente (poder total)

  animations = {
    enable = true;
    preset = "standard"; # "LimeFrenzy", "classic", "diablo-1", "fast", ...
    extraConfig = "";
    overrides = {};  # override por nombre de preset
  };

  shaders = {
    active   = "disable"; # "blue-light-filter", "grayscale", "oled", "wallbash", ...
    overrides = {};
  };

  workflows = {
    active   = "default"; # "editing", "gaming", "powersaver", "snappy"
    overrides = {};
  };

  hypridle = { enable = true; extraConfig = ""; overrideConfig = null; };
  keybindings = { enable = true; extraConfig = ""; overrideConfig = null; };
  windowrules = { enable = true; extraConfig = ""; overrideConfig = null; };
  nvidia   = { enable = false; extraConfig = ""; overrideConfig = null; };
  pyprland = { enable = true; extraConfig = "";  overrideConfig = null; };
  monitors = { enable = true; overrideConfig = null; };
};
```

**Archivos que gestiona `default.nix`:**
- `.config/hypr/hyprland.conf` — config principal (de HyDE, o el `overrideMain` del usuario)
- `.config/hypr/userprefs.conf` — extras del usuario (vía `extraConfig`)
- `.local/share/hypr/` — assets compartidos de hyprland
- Crea los directorios de temas/animaciones/shaders/workflows en la activation action

### 7.6 `hm/shell.nix` — Shell del usuario

**Archivo:** [`hydenix/modules/hm/shell.nix`](file:///c:/Users/Rob/hydenix/hydenix/modules/hm/shell.nix)

Configura el shell del usuario con muchas opciones:

```nix
options.hydenix.hm.shell = {
  enable = ...;
  zsh = {
    enable = true; # zsh por defecto
    plugins = ["sudo"]; # plugins oh-my-zsh
    configText = ""; # texto libre para añadir a .zshrc
  };
  bash     = { enable = false; };
  fish     = { enable = false; };
  p10k     = { enable = false; }; # Powerlevel10k
  starship = { enable = true; };  # Starship prompt (por defecto)
  pokego   = { enable = false; }; # Arte ASCII de Pokémon al abrir terminal
  fastfetch = { enable = true; }; # Fastfetch al abrir terminal
};
```

Para **zsh** configura:
- `oh-my-zsh` con plugins configurables
- `autosuggestions` y `syntaxHighlighting`
- Aliases: `c` (clear), `vc` (code), `..`, `...`, etc.
- Funciones cargadas desde `~/.config/zsh/{functions,completions}/`
- Completions de HyDE (`hydectl`, `hyde-shell`, `fzf`)

Para **fish** implementa la config de HyDE usando home-manager nativo, con integración fzf, starship y los mismos aliases.

Los dotfiles de zsh/fish se sirven desde `pkgs.hyde/Configs/`.

### 7.7 `hm/waybar.nix` — Barra del sistema

**Archivo:** [`hydenix/modules/hm/waybar.nix`](file:///c:/Users/Rob/hydenix/hydenix/modules/hm/waybar.nix)

Configura la barra del sistema Waybar con toda su complejidad:

```nix
options.hydenix.hm.waybar = {
  enable    = ...;
  waybar.enable = true;
  userStyle = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = "CSS personalizado para user-style.css";
  };
};
```

**Archivos desplegados:**
- `.config/waybar/modules/` — módulos de waybar (de HyDE)
- `.config/waybar/layouts/` — layouts disponibles
- `.config/waybar/includes/includes.json` — generado por Nix con los paths XDG correctos
- `.config/waybar/user-style.css` — CSS custom del usuario
- `.config/waybar/style.css` — CSS principal (importa wallbash colors, theme.css, user-style.css)

El archivo `includes.json` es notable: referencia **todos los módulos** posibles de waybar usando `${config.xdg.configHome}` resuelto en tiempo de build. Esto garantiza que los paths absolutos sean correctos independientemente del usuario.

**Paquetes instalados:** `waybar`, `playerctl`, `python3.withPackages(pygobject3)`, `lm_sensors`, `power-profiles-daemon`.

### 7.8 Otros módulos hm

| Módulo | Qué hace |
|--------|----------|
| `gtk.nix` | Configura el tema GTK (via home-manager gtk module), establece fuente y cursor |
| `qt.nix` | Configura Qt para usar el tema activo compatible con Wayland |
| `xdg.nix` | Configura XDG dirs, mimeapps, associaciones de archivos |
| `terminals.nix` | Kitty: config de HyDE para el terminal, opciones de fuente |
| `rofi.nix` | Rofi como lanzador de apps, config de HyDE |
| `lockscreen.nix` | Hyprlock: pantalla de bloqueo, config de HyDE |
| `notifications.nix` | Dunst o Swaync para notificaciones |
| `screenshots.nix` | Grim + slurp para capturas de pantalla |
| `dolphin.nix` | Configuración del file manager KDE Dolphin |
| `editors.nix` | VSCode con extensión wallbash, neovim |
| `fastfetch.nix` | Config de fastfetch con preset de HyDE |
| `firefox.nix` | Firefox con políticas |
| `git.nix` | Configuración básica de git |
| `social.nix` | Discord, etc. |
| `spotify.nix` | Spotify |
| `swww.nix` | swww como daemon de wallpaper |
| `uwsm.nix` | Universal Wayland Session Manager |
| `wlogout.nix` | Pantalla de logout estilizada |
| `comma.nix` | El comando `,` para ejecutar paquetes sin instalar |

---

## 8. La Capa `lib/`

### 8.1 `lib/config/`

**Archivos:** [`lib/config/default.nix`](file:///c:/Users/Rob/hydenix/lib/config/default.nix), `configuration.nix`, `home.nix`

`default.nix` es el punto que instancia la configuración NixOS completa del repositorio (la config de referencia/desarrollo):

```nix
{ inputs, ... }:
let
  system = "x86_64-linux";
  pkgs = import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
    overlays = [ inputs.self.overlays.default ]; # ← Aquí se conectan los paquetes custom
  };
in
inputs.nixpkgs.lib.nixosSystem {
  inherit system pkgs;
  specialArgs = { inherit inputs; };
  modules = [ ./configuration.nix ];
}
```

`configuration.nix` es comparable a la config de un usuario real: importa `nixosModules.default`, `homeModules.default`, y configura las opciones de hydenix.

### 8.2 `lib/dev-shell.nix`

Entorno de desarrollo con herramientas para contribuir al proyecto (`nixfmt`, `statix`, etc.). Se accede con `nix develop`.

### 8.3 `lib/hyde-update/`

Un paquete con un script (`run.sh`) que ayuda a actualizar el commit de HyDE en `flake.nix` y verificar compatibilidad. Se expone como `packages.hyde-update`.

### 8.4 `lib/vms/`

Dos configuraciones de VM:

- **`nixos-vm.nix`**: Envuelve una `nixosConfiguration` existente (la del usuario) para poder probarla como VM con `nix run .#default`. Muy útil para probar cambios antes de aplicarlos al sistema real.
- **`demo-vm.nix`**: Una VM de demostración independiente. Se usa para generar videos de demostración.

La función `lib.vmConfig` se expone en el flake para que **los usuarios** puedan usarla para crear VMs de su propia config:

```nix
# En el template/flake.nix del usuario:
vmConfig = inputs.hydenix.lib.vmConfig {
  inherit inputs;
  nixosConfiguration = hydenixConfig;
};
packages."x86_64-linux".vm = vmConfig.config.system.build.vm;
```

---

## 9. La Plantilla para Usuarios: `template/`

**Directorio:** [`template/`](file:///c:/Users/Rob/hydenix/template/)

La plantilla es lo que un usuario nuevo copia para crear su propio config. Se instala con:

```bash
nix flake init -t github:richen604/hydenix
```

### `template/flake.nix`

```nix
{
  inputs = {
    nixpkgs.follows = "hydenix/nixpkgs"; # Hereda el nixpkgs de hydenix (estabilidad)
    hydenix.url = "github:richen604/hydenix";
    nixos-hardware.url = "...";
  };

  outputs = { ... }@inputs: let
    hydenixConfig = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./configuration.nix ];
    };
    # La VM usa la función pública lib.vmConfig de hydenix
    vmConfig = inputs.hydenix.lib.vmConfig { inherit inputs; nixosConfiguration = hydenixConfig; };
  in {
    nixosConfigurations.hydenix = hydenixConfig;
    packages."x86_64-linux".vm = vmConfig.config.system.build.vm;
  };
}
```

### `template/configuration.nix`

El archivo que el usuario edita. Sus pasos son:

1. Importar los módulos de hydenix: `inputs.hydenix.nixosModules.default` y `inputs.hydenix.homeModules.default`
2. Importar hardware opcional de `nixos-hardware`
3. Configurar home-manager con su usuario
4. Establecer `hydenix.enable = true` y los campos obligatorios (hostname, timezone, locale)
5. Personalizar opciones adicionales

---

## 10. Archivos Raíz de Configuración

| Archivo | Propósito |
|---------|-----------|
| `flake.lock` | Hashes y versiones de todos los inputs. No editar manualmente. |
| `.commitlintrc.json` | Estilo de commits (Conventional Commits) |
| `.releaserc.json` | Configuración de semantic-release para el CHANGELOG |
| `CHANGELOG.md` | Historial de cambios generado automáticamente |
| `TODO.md` | Issues abiertos y trabajo en progreso interno |
| `.envrc` | `use flake` para direnv — activa el devShell automáticamente |
| `.gitignore` | Ignora `result/`, `.direnv/` |
| `package.json` | Solo para semantic-release (no es un proyecto Node.js) |
| `comando-maestro-para-rebuild.sh` | Script rápido de rebuild del sistema |
| `docs/unstable-packages.md` | Lista de paquetes disponibles en nixpkgs-unstable |

---

## 11. El Flujo Completo: De Flake a Escritorio

```
nix rebuild switch (en la máquina del usuario)
      │
      ▼
template/flake.nix
  └─ Instancia nixosSystem con inputs
      │
      ▼
lib/config/default.nix (o template/configuration.nix)
  ├─ Crea pkgs con overlays.default aplicado
  │    └─ overlay.nix añade: hyde, hydenix-themes, pokego, etc.
  │
  └─ Pasa modules = [configuration.nix]
      │
      ▼
configuration.nix del usuario
  ├─ nixosModules.default      → hydenix/modules/system/default.nix
  │    ├─ system.nix           → instala hyprland, bluetooth, portales XDG
  │    ├─ boot.nix             → configura bootloader y kernel zen
  │    ├─ sddm.nix             → configura display manager
  │    ├─ audio.nix            → PipeWire
  │    └─ ...
  │
  └─ homeModules.default       → hydenix/modules/hm/default.nix
       ├─ mutable.nix          → infraestructura de archivos mutables
       ├─ hyde.nix             → despliega dotfiles core de HyDE
       ├─ theme.nix            → instala temas seleccionados + activa el tema
       ├─ hyprland/            → config de Hyprland (principal + userprefs)
       ├─ shell.nix            → configura zsh/fish + starship
       ├─ waybar.nix           → configura waybar con módulos
       └─ ... (resto de módulos)
            │
            ▼
     home-manager apply
       ├─ linkGeneration          → crea symlinks inmutables en ~/
       ├─ mutableFileGeneration   → copia archivos mutables (reemplazando symlinks)
       ├─ createCavaConfig        → crea ~/.config/cava/config
       ├─ createHyprConfigs       → crea dirs de animaciones/shaders/workflows
       └─ setTheme               → ejecuta theme.switch.sh -s "Catppuccin Mocha"
            │
            ▼ (después de graphical.target)
       systemd user services
         ├─ setThemeDconf.service → aplica dconf settings
         ├─ setTheme.service      → re-aplica tema completo
         ├─ hyde-config.service   → parser de config de HyDE
         └─ hyde-ipc.service      → IPC de HyDE
```

---

## 12. Cómo Extender Hydenix

### Agregar un nuevo paquete custom

1. Crear `hydenix/sources/mi-paquete.nix`:
```nix
{ pkgs }:
pkgs.stdenv.mkDerivation {
  name = "mi-paquete";
  src = pkgs.fetchFromGitHub { ... };
  installPhase = ''mkdir -p $out/bin; cp mi-script $out/bin/'';
}
```

2. Registrarlo en `overlay.nix`:
```nix
packages = {
  # ... existentes ...
  mi-paquete = callPackage ./mi-paquete.nix { };
};
```

3. Usarlo en cualquier módulo:
```nix
home.packages = [ pkgs.mi-paquete ];
```

### Agregar un nuevo tema

1. Crear `hydenix/sources/themes/Mi-Tema.nix`:
```nix
{ pkgs, mkTheme }:
mkTheme {
  name = "Mi Tema";
  src = pkgs.fetchFromGitHub {
    owner = "HyDE-Project"; repo = "hyde-gallery";
    rev = "commit-hash"; sha256 = "sha256-...";
  };
  meta = { description = "Mi tema custom"; homepage = "..."; priority = 100; };
}
```

2. Registrarlo en `themes/default.nix`:
```nix
"Mi Tema" = callTheme ./Mi-Tema.nix;
```

3. Usarlo en tu config:
```nix
hydenix.hm.theme = {
  themes = ["Catppuccin Mocha" "Mi Tema"];
  active = "Mi Tema";
};
```

### Agregar un nuevo módulo hm

1. Crear `hydenix/modules/hm/mi-app.nix`:
```nix
{ config, lib, pkgs, ... }:
let cfg = config.hydenix.hm.miApp;
in {
  options.hydenix.hm.miApp = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.hydenix.hm.enable;
      description = "Enable mi-app";
    };
    # otras opciones...
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.mi-app ];
    home.file.".config/mi-app/config" = {
      source = ./mi-app-config;
    };
  };
}
```

2. Importarlo en `hm/default.nix`:
```nix
imports = [
  # ... existentes ...
  ./mi-app.nix
];
```

### Personalizar la config de Hyprland sin modificar el source

En tu `template/modules/hm/default.nix`:
```nix
hydenix.hm.hyprland = {
  # Añadir config sin tocar hyprland.conf
  extraConfig = ''
    bind = SUPER, T, exec, alacritty
    decoration {
      rounding = 15
    }
  '';

  # Usar un preset de animación diferente
  animations.preset = "fast";

  # Activar un shader
  shaders.active = "blue-light-filter";

  # Configurar NVIDIA si aplica
  nvidia.enable = true;
};
```

### Usar paquetes de nixpkgs-unstable

Gracias al overlay, puedes usar paquetes de nixpkgs-unstable en cualquier módulo:
```nix
home.packages = [
  pkgs.unstable.helix  # Editor siempre en la versión más nueva
];

# O en systemPackages:
environment.systemPackages = [
  pkgs.unstable.firefox
];
```

### Añadir CSS custom a Waybar

```nix
hydenix.hm.waybar.userStyle = ''
  window#waybar {
    background-color: rgba(0, 0, 0, 0.5);
  }
  .modules-right {
    font-size: 14px;
  }
'';
```

### Extender el shell ZSH

```nix
hydenix.hm.shell.zsh = {
  enable = true;
  plugins = ["sudo" "git" "docker"];
  configText = ''
    # Tu config personalizada de zsh
    export MY_VAR="valor"
    alias gs="git status"
    source ~/.config/zsh/my-custom.zsh
  '';
};
```

---

*Generado automáticamente analizando el código fuente del repositorio hydenix.*
*Última actualización: 2026-03-13*
