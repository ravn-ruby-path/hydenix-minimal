# Configuración de Zed Editor en el Repositorio `linuxmobile/shin`

Este documento explica en detalle cómo se instala, configura y gestiona el editor **Zed** en esta configuración de NixOS, incluyendo cómo maneja sus dependencias, Language Servers (LSPs) y el dilema de los entornos FHS.

## 1. ¿Cómo se instala Zed Editor?

En lugar de instalar el paquete estándar de Zed, la configuración construye una instalación personalizada (un "wrapper" o envoltorio) utilizando el sistema de paquetes de Nix (`symlinkJoin` y `makeWrapper`).

En el archivo `home/editors/zed/default.nix`, podemos ver el bloque de instalación:

```nix
zedWithLSP = pkgs.symlinkJoin {
  name = "zed-with-lsp";
  paths = [pkgs.zed-editor];
  buildInputs = [pkgs.makeWrapper];
  postBuild = ''
    rm -rf $out/bin
    mkdir -p $out/bin
    makeWrapper ${pkgs.zed-editor}/bin/zeditor $out/bin/zeditor \
      --prefix PATH : ${lspBinPath}/bin
    # ... otros binarios enlazados
  '';
};
```

**Conclusión de la Instalación:** Zed se instala vinculando el paquete oficial de los repositorios de NixOS y reescribiendo el binario principal (`zeditor`) para inyectar un entorno (`lspBinPath`) que garantice que el editor siempre tenga acceso a las herramientas requeridas cuando se inicializa. Este paquete personalizado luego se añade a la lista de paquetes del usuario (Nivel de sistema): `users.users.linuxmobile.packages = [ zedWithLSP ];`.

### Nota para usuarios de Home Manager 💡
La configuración original del repositorio emplea `users.users.<nombre>.packages`, que es sintaxis exclusiva para la configuración de NixOS a nivel de sistema.
Si gestionas tus dotfiles y paquetes mediante **Home Manager**, la lógica es idéntica pero operando solo para tu propio alcance de usuario. Solo debes reemplazar la directiva final de la siguiente manera:

```nix
# Reemplazar la asignación en la configuración (Sintaxis NixOS System-level):
users.users.tuUsuario.packages = [ zedWithLSP ];

# Por la asignación correcta (Sintaxis Home Manager User-level):
home.packages = [ zedWithLSP ];
```
Todo el resto del archivo y la lógica (`makeWrapper`, `xdg.configFile`, etc.) funciona exactamente igual e interactúa de manera transparente con Home Manager.

## 2. ¿Cómo se configura?

La configuración es modular y se divide principalmente en dos archivos:

*   **`home/editors/zed/default.nix`**: Actúa como el orquestador. Aquí se define un enorme bloque `settingsJSON` que se inyecta directamente a la configuración `~/.config/zed/settings.json` mediante `xdg.configFile."zed/settings.json"`. Esta configuración domina el aspecto global del editor:
    *   **NodeJS Paths:** Indica a Zed exactamente de dónde sacar `node` y `npm` con rutas absolutas de la tienda de Nix (`${pkgs.nodejs}/bin/node`).
    *   **Diseño e Interfaz**: Usa pestañas minimalistas, desactiva características intrusivas, emplea tipografías muy específicas (`GT Pressura Mono Trial`, `Symbols Nerd Font`), y utiliza el tema `Noctalia` con iconos `Catppuccin Mocha`.
    *   **IA de Asistencia**: Configura un agente externo en `openrouter` bajo el modelo `mistralai/devstral-2512:free` para escritura, autocompletado y resúmenes guiados de código.

*   **`home/editors/zed/_settings.nix`**: Este archivo exporta toda la configuración para mapear LSPs (Language Server Protocols) y *formatters*. Se importa y fusiona (usando `//`) directamente con la configuración global de Zed mediante un modelo puro de Nix. Genera un objeto que luego Zed usa como fuente de verdad por lenguaje.

## 3. ¿Cómo se instalan las herramientas y utilidades?

A diferencia de la mayoría de usuarios de Zed (que dejan que el editor se conecte a Internet, baje un LSP y lo guarde en `~/.local/share/zed`), en esta configuración todo es determinista.

Se crea una lista de utilidades puras llamada `lspPackages`:
```nix
lspPackages = with pkgs; [
  # Language Server Protocol
  astro-language-server biome marksman nil tailwindcss-language-server vue-language-server
  # Formatters
  alejandra oxfmt shfmt
  # Dependencia Base
  nodejs
];
```

Con este array, se compila un entorno temporal (`pkgs.buildEnv`) denominado `zed-lsp-env`. Dicho entorno centraliza y empaqueta en una única carpeta `/bin/` el punto de entrada de cada una de estas herramientas provenientes de la vasta Nix Store.

En el archivo `_settings.nix`, este enfoque brilla. En lugar de configuraciones sueltas, se dictan explícitamente las rutas hacia los ejecutables que se van a usar según el lenguaje. Un ejemplo con Nix:
```nix
Nix = {
  tab_size = 2;
  formatter = mkExternalFormatter formatters.alejandra ["-q"];
  format_on_save = "on";
  language_servers = ["nil"];
};
```

## 4. ¿Cómo hace uso de entornos FHS (Arquitectura del Sistema de Archivos)?

Esta es la parte más avanzada del repositorio. **La respuesta corta es: No hace uso de un entorno FHS nativo o emulado explícitamente (tipo `buildFHSUserEnv`); de hecho, elude la necesidad de usar FHS inteligentemente.**

**El Problema:**
Habitualmente, cuando un editor de código se ejecuta nativamente en NixOS intenta descargar automáticamente binarios precompilados (para los servidores de lenguaje, línters, etc.). Estos binarios, porque asumen que tu equipo es un "Linux normal" (Ubuntu, Arch, etc.), buscan dependencias en rutas absolutas como `/lib64/ld-linux-x86-64.so.2` o `/usr/bin/bash`. (A estas rutas absolutas convencionales se las denomina entorno FHS). Como NixOS no tiene estas rutas por defecto (todo vive en la tienda `/nix/store/`), este mecanismo nativo de Zed fallaría fatalmente: los LSPs se descargarían pero no correrían de ningún modo.

**La Solución Adoptada por el Repositorio:**
En vez de envolver todo el editor de Zed en una jaula que falsea las rutas habituales de Linux (que ralentizaría un poco o ensuciaría el sistema), este entorno soluciona la necesidad de FHS desde su origen:

1.  **Inyección en PATH (`makeWrapper`)**: Al envolver la ejecución agregando las herramientas listadas en el apartado 3 a su propio `$PATH` invisible (`--prefix PATH`), evitamos que tengan que llamarse desde `/usr/bin/`.
2.  **Rutas Inmutables Absolutas**: En todo el archivo `_settings.nix` y en opciones de inicialización en la tienda, el autor pasa explícitamente la ruta directa desde el almacén inmutable `/nix/store/.../bin/volar`. Esto significa que Zed no necesita buscar nada: el intérprete sabe mágicamente dónde se encuentra la librería o ejecutable necesario.
3.  **Evitar el "Descargado Propio"**: Al tener todo proveído por sus propios *packages* gestionados por Nix (por ejemplo, asegurando NodeJS por si Zed lo llama), bloquea el problema de raíz, ya que nada en la ejecución es descargado durante el uso y por lo tanto, no choca con las faltas de librerías vinculadas dinámicamente.

En otras palabras, la configuración de Zed de este repositorio abraza totalmente el paradigma funcional *Nix Way* anulando brillantemente los vicios o necesidades de un entorno FHS convencional.
