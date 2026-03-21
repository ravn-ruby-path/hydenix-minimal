# Guía de Integración de Editores (Home Manager / Nix)
**Documentación para futuras IAs (VSCode, Cursor, Antigravity, etc.)**

Este documento detalla el patrón exacto que se utilizó para integrar **Zed** y **Helix** en la configuración de **Home Manager** de este repositorio (basado en el patrón *free-FHS* de `linuxmobile/shin`). 

El objetivo es **servir de contexto estricto** para que futuras inteligencias artificiales puedan replicar esta lógica impecablemente con otros IDEs complejos (como **VSCode**, **Cursor**, **Antigravity**, etc.) sin romper el sistema, sin depender del FHS tradicional y manteniendo compatibilidad para *diffs* con el repositorio original.

---

## 1. El Problema a Resolver
Editores y entornos de desarrollo nativos asumen que viven en distribuciones Linux convencionales (con directorios estándar como `/usr/bin/` y `/lib64/`). En NixOS esto causa fallos masivos cuando los LSPs u otras herramientas descargan binarios dinámicos de internet, ya que no hallan sus rutas absolutas. 

La solución no es encerrar los editores en entornos `buildFHSUserEnv` que son ineficientes. La solución es **envolver (wrap) el binario del editor**, forzándolo a encontrar las herramientas puras extraídas de la Nix Store.

## 2. Archivos Clave Modificados y Creados

### A. Modificación del Core de Opciones
Archivo: `hydenix/modules/hm/editors.nix`
- **Paso 1 (Crear Interruptor):** Se debe declarar un "Toggle" booleano para el nuevo editor dentro del esquema general (eg. `helix = lib.mkOption { type = lib.types.bool; ... }`). Esto le enseña a `home.nix` a reconocer el comando `editors.helix = true`.
- **Paso 2 (Prevención de Choques):** **CRÍTICO:** Si el editor ya existía como una instalación básica y cruda dentro del array principal de `home.packages` (ejemplo previo: `(lib.mkIf cfg.zed pkgs.unstable.zed-editor)`), la IA debe ELIMINAR esa línea *por completo*. La instalación se delega en exclusiva al submódulo que construirá el Wrapper. Si mantienes las dos líneas, se intentará instalar dos veces y chocarán en el ecosistema.

### B. Módulos Específicos por Editor
Archivos: `hydenix/modules/hm/<editor>/default.nix` y `_settings.nix` (o similar).
- **Importación en el Árbol:** Todo submódulo nuevo en `hydenix/modules/hm/<editor>` debe forzosamente registrarse en la lista de `imports` en `hydenix/modules/hm/default.nix`.
- **Estructura Dual Exacta a shin:** 
  1. Un archivo `default.nix` construye el "Wrapper" del editor inyectándole un `$PATH` virtual. También empuja la configuración final usando generadores u objetos de Nix (`xdg.configFile."ruta_del_editor/config.json".source = ...`).
  2. Un archivo secundario (ej. `_settings.nix` o `_languages.nix`) que contenga lógica de programación purísima para generar los sub-ajustes declarativos con variables inmutables de la Store.

## 3. Código y Metodología Paso a Paso (El Patrón Wrapper)

### Paso 1: Dependencias `unstable` centralizadas
Se utilizan las dependencias provenientes del paquete **`pkgs.unstable`** para LSPs, Formatters y los editores principales. Esto asegura características punteras de código. 

```nix
# Dentro del default.nix del editor
lspPackages = with pkgs.unstable; [
  astro-language-server biome marksman nil tailwindcss-language-server
  alejandra oxfmt shfmt nodejs
];

lspBinPath = pkgs.buildEnv {
  name = "editor-lsp-env";
  paths = lspPackages;
  pathsToLink = [ "/bin" ];
};
```

### Paso 2: El Wrapper (symlinkJoin / runCommand)
Usamos envolturas (`makeWrapper`) para alterar el ejecutable real sin intervenir globalmente el sistema operativo.

Para editores con muchos binarios auxiliares compartidos (como *Zed/VSCode/Cursor*), utiliza **`symlinkJoin`**.
```nix
editorWithLSP = pkgs.symlinkJoin {
  name = "editor-with-lsp";
  paths = [ pkgs.unstable.paquete-del-editor ]; # Paquete inestable base
  buildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    rm -rf $out/bin
    mkdir -p $out/bin
    
    # Envolver el binario maestro
    makeWrapper ${pkgs.unstable.paquete-del-editor}/bin/ejecutable $out/bin/ejecutable \
      --prefix PATH : ${lspBinPath}/bin
      
    # Reconectar sub-binarios
    for bin in ${pkgs.unstable.paquete-del-editor}/bin/*; do
      if [ "$(basename $bin)" != "ejecutable" ]; then
        ln -s $bin $out/bin/$(basename $bin)
      fi
    done
  '';
};
```

### Paso 3: Configuración con Rutas Absolutas (El Módulo Secundario)
Las llamadas a LSPs en la configuración del editor no apuntan al nombre abstracto del comando (como `"command": "alejandra"`). Tienen que resolver en su lugar su ruta evaluada exacta.

```nix
# Dentro del _settings.nix
{ pkgs, ... }:
let
  formatters = {
    alejandra = "${pkgs.unstable.alejandra}/bin/alejandra";
  };
  languageServers = {
    nil = "${pkgs.unstable.nil}/bin/nil";
  };
in {
  # Inyección pura a ser interpretada en JSON/TOML por el orquestador
  languages = {
    Nix = {
      formatter = { command = formatters.alejandra; };
    };
  };
}
```

## 4. Checklists para la IA Futura 🤖
Cuando se te encomiende agregar VSCode, Cursor o Antigravity a este entorno en un futuro requerimiento, **toda IA debe cumplir el siguiente checklist riguroso:**

- [ ] ¿Modifiqué `hydenix/modules/hm/editors.nix` añadiendo una bandera o validando que exista y retiré su compilación bruta si estaba?
- [ ] ¿Incluí `hydenix/modules/hm/<nuevo-editor>` en el array de `imports` de `hydenix/modules/hm/default.nix`?
- [ ] ¿El nuevo ejecutable está envuelto con un `pkgs.buildEnv` que contiene sus LSPs mediante `symlinkJoin` y `--prefix PATH`?
- [ ] ¿Todas y cada una de las variables o referencias a un compilador, LSP o utilería web (ejs. TypeScript/Bioma/Nil) se realizan vía `${pkgs.unstable.x}/bin/y` para sortear problemas de FHS local?
- [ ] ¿Usaste condicionales estrictos de Home Manager (`config = lib.mkIf cfg.editor { ... }`) y lo instalaste vía `home.packages = [ wrapperPackage ]`?

**⚠️ Notas Adicionales:** 
Si el editor es una bifurcación de Electron de los mismos repositorios de VSCode (como Cursor), ten cuidado extra al encontrar el archivo o script interno que necesita de ser envuelto, podrías necesitar leer el derivation crudo de la *nixpkgs* para replicarlo de manera exitosa.

---

## 5. Técnica Avanzada: Coexistencia para Pruebas A/B (Aislamiento de Entornos)
Si el usuario desea comparar el rendimiento de una instalación tradicional (FHS, sujeta a errores de entorno) versus la instalación pura forzada por este patrón Wrapper (por ej., para evaluar **Cursor**), Nix permite que ambos convivan intactos al mismo tiempo *sin chocar*.

Para indicarle a la IA futura cómo lograr este modo de prueba A/B:

1. **Mantén el Toggle Original e inventa uno nuevo:**
   En `editors.nix` no borres la vieja línea de ejecución, más bien crea dos opciones booleanas (ej. `cursor-legacy = true` y `cursor-pure = true`).
2. **Renombra el ejecutable final del Wrapper:**
   Dentro de tu nuevo archivo `hm/<editor>/default.nix`, al usar `makeWrapper`, cambia intencionalmente el nombre de salida del binario para que no haga colisión con la versión estándar.
   *Ejemplo Práctico:*
   ```bash
   # En lugar de sobreescribirlo:
   makeWrapper ''${pkgs.unstable.cursor}/bin/cursor $out/bin/cursor
   
   # Crea un alias/ejecutable alternativo puro:
   makeWrapper ''${pkgs.unstable.cursor}/bin/cursor $out/bin/cursor-pure \
     --prefix PATH : ''${lspBinPath}/bin
   ```
De esta forma, el usuario en su terminal podrá escribir `cursor .` para lanzar la versión estándar sucia, y `cursor-pure .` para lanzar la nueva arquitectura inmutable basada en nuestro Wrapper. Ambas existirán en aislamiento dentro del contenedor `/nix/store/`.
