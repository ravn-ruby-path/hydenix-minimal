# Configuración de Helix Editor en el Repositorio `linuxmobile/shin`

De forma similar a la integración de Zed, este documento detalla cómo se instala, configura y gestiona **Helix** en el sistema NixOS, garantizando inmutabilidad, pureza funcional y un entorno libre de caídas derivadas de los clásicos problemas de directorios tipo FHS (Filesystem Hierarchy Standard).

## 1. ¿Cómo se instala Helix Editor?

Al igual que en la configuración de Zed, la instalación de Helix no consiste simplemente en el paquete oficial del sistema. Se compila con un *envoltorio* (wrapper) creado en tiempo de evaluación usando el poder de Nix (`runCommand` y `makeWrapper`).

En el archivo `home/editors/helix/default.nix`, podemos ver el núcleo de esta estrategia:

```nix
helixWithLSP = pkgs.runCommand "helix-with-lsp" {
  buildInputs = [pkgs.makeWrapper];
} ''
  mkdir -p $out/bin
  makeWrapper ${pkgs.helix}/bin/hx $out/bin/hx \
    --prefix PATH : ${lspBinPath}/bin
  # ... enlaces a otros binarios internos de Helix
'';
```

**Conclusión:** En vez de tener que ensuciar tu entorno por defecto, se construye el paquete `helixWithLSP` asegurando que cuando llames al intérprete con `hx`, en este viajen escondidas todas y cada una de las variables y repositorios de lenguaje para su ejecución limpia. Posteriormente se instala el paquete bajo nivel de sistema asigándolo a la directiva `users.users.linuxmobile.packages`.

### Nota para usuarios de Home Manager 💡
La configuración original del repositorio emplea la forma generalizada de NixOS a nivel de sistema (`users.users.<nombre>.packages`). Si gestionas tus dotfiles a través de **Home Manager**, operan los mismos principios pero en el entorno de tu propio usuario. Para aplicar este archivo bastará sustituir el modo de instalación del paquete `helixWithLSP` de esta manera:

```nix
# Reemplazar la de asignación a nivel de sistema NixOS:
users.users.tuUsuario.packages = [ helixWithLSP ];

# Por la asigación exclusiva de Home Manager:
home.packages = [ helixWithLSP ];
```
El resto de estructura y toda su funcionalidad (`(pkgs.formats.toml {}).generate`, rutas del XDG en `$HOME`, etc.) mantendrán su plena compatibilidad en Home Manager.

## 2. ¿Cómo se configura?

Helix funciona basado en estructuras TOML. Para que NixOS inyecte la configuración al editor dinámicamente, se hace uso de una utilidad nativa: `(pkgs.formats.toml {}).generate`, que se encarga de convertir y adaptar la evaluación pura del código Nix a en archivos de lectura para Helix. 

La orquestación ocurre en dos partes principales:

*   **`home/editors/helix/default.nix`**: Interviene en la capa principal (apariencia y uso). 
    *   Crea dinámicamente el archivo en `~/.config/helix/config.toml`. 
    *   Impone el tema (`noctalia`), habilita `true-color`, modo relativo de líneas y parámetros del `statusline`.
    *   Reescribe atajos de teclado clave (`keys.insert` y `keys.normal`) para asegurar navegación de estilo vim modificado y facilitar las transiciones entre ventanas o borrados veloces.

*   **`home/editors/helix/_languages.nix`**: Este módulo subyacente nutre el archivo `languages.toml`. Su misión principal es la integración y comportamiento de los motores internos de lenguaje.

## 3. ¿Cómo se instalan las herramientas, formatters y LSPs?

Es imperativo que el editor no dependa de repositorios en línea en el instante de su ejecución. Toda herramienta necesaria se compila de antemano. Todo empieza reuniendo los binarios usando la variable `lspPackages`:

```nix
lspPackages = with pkgs; [
  astro-language-server biome marksman nil tailwindcss-language-server vue-language-server
  alejandra oxfmt shfmt
];
```

Con una función parecida a la de Zed, usa `pkgs.buildEnv` para compactar estos paquetes en un entorno virtualizado local llamado `helix-lsp-env`. Dicha carpeta es sumada al inicio del comando de `hx` empleando la variable interna de bash `$PATH`.

## 4. Gestión dinámica dentro del `languages.toml` y elusión de la FHS

Helix requiere que se declaren tanto los servidores principales (LSPs) como el mecanismo a la hora de formatear código por lenguaje. En los dotfiles que no usan Nix, solemos ver esto como `command = "alejandra"`, asumiendo que el ordenador tiene a `alejandra` instalado en `/usr/bin/alejandra` (Entorno FHS clásico).

**La Solución Implementada en Nix:**
En `_languages.nix`, se evita cualquier ambigüedad resolviendo dependencias de la forma más determinista posible.

```nix
formatters = {
  alejandra = "${pkgs.alejandra}/bin/alejandra";
};
# ...
language = [
  {
    name = "nix";
    auto-format = true;
    formatter = {
      command = formatters.alejandra;
      args = ["-q"];
    };
    language-servers = ["nil"];
  }
];
```

Al interpolar las variables (con `${pkgs.paquete}`), Nix resuelve las rutas hacia la Tienda inmutable (`/nix/store/<hash>-alejandra/bin/alejandra`). 

**Este nivel de integración aporta 3 beneficios fundamentales a Helix:**
1.  **Imposible que falle el formateo**: El Linter o Formateador jamás va a fallar alegando que "no lo encontró en el sistema", ya que tiene su latitud y ubicación real.
2.  **No necesita FHS emulado**: En la ejecución de NixOS te ahorras todos los recursos pesados que acarrearía recrear los esqueletos FHS de Linux (`buildFHSUserEnv`); logrando máxima fluídez en el tecleo de comandos. 
3.  **Portabilidad instantánea**: Tu editor siempre está auto-contenido. Si clonas este repositorio en una máquina nueva, el editor nace pre-compilado con cada LSP instalado nativamente listo para su uso desde el segundo 0, sin requerir una conexión a Internet adicional tras construir con la Nix flake.
