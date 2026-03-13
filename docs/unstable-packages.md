# Paquetes en su versión más reciente mediante `pkgs.unstable`

> **Escrito en**: Marzo 2026  
> **Objetivo**: Documentar el cambio que permite instalar paquetes desde `nixpkgs-unstable` fresco
> (siempre la última versión) dentro de hydenix, que por diseño usa un `nixpkgs` pinado.  
> **Caso de uso inicial**: `pkgs.unstable.antigravity-fhs` (Google Antigravity IDE)

---

## 1. El problema: hydenix usa nixpkgs pinado

### ¿Qué significa "nixpkgs pinado"?

En Nix/NixOS, cuando dices:

```nix
nixpkgs.url = "github:nixos/nixpkgs/95e96e8632c387dcf8c4223b8ab14a58936f8b10";
```

estás "pinando" (fijando) nixpkgs a un **commit específico** del repositorio de paquetes de NixOS.
Eso significa que **todos los paquetes** del sistema — Firefox, git, Python, etc. — provienen de
ese snapshot exacto de nixpkgs, tomado en un momento concreto del tiempo (en este caso, abril 2025).

### ¿Por qué hydenix hace esto?

Hydenix lo hace **deliberadamente** para garantizar **reproducibilidad y estabilidad**: si alguien
instala hydenix hoy o dentro de 6 meses, obtiene exactamente los mismos paquetes y versiones. Esto
evita regresiones inesperadas donde una actualización de nixpkgs rompe algo en el entorno HyDE.

Verás esto en `flake.nix` del repo:

```nix
# flake.nix (antes del cambio)
inputs = {
  # Hydenix's nixpkgs
  nixpkgs.url = "github:nixos/nixpkgs/95e96e8632c387dcf8c4223b8ab14a58936f8b10";
  ...
```

El commit `95e96e8` corresponde a **nixos-unstable de aproximadamente abril 2025**. Aunque la rama
se llama "unstable" (que en NixOS significa "la más reciente, con actualizaciones frecuentes"), al
pinarlo a un commit específico deja de ser "la más reciente" — se convierte en una fotografía fija.

### El problema concreto

Si quieres instalar un paquete que:
- No existía en abril 2025 (fue añadido a nixpkgs después), o
- Tiene una versión mucho más nueva en nixpkgs actual, o
- Necesitas la última versión por razones de funcionalidad/seguridad

...simplemente no puedes usar `pkgs.antigravity-fhs` porque `pkgs` apunta al snapshot antiguo.

---

## 2. La solución: un segundo `nixpkgs` "siempre fresco"

### La idea central

Nix Flakes permite declarar **múltiples inputs de nixpkgs**. No hay nada que te fuerce a usar solo
uno. La solución es añadir un segundo input que **nunca esté pinado** a un commit específico, sino
que siempre apunte a la punta de la rama `nixpkgs-unstable`:

```
nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable"
```

Aquí, `nixpkgs-unstable` (sin commit) hace que Nix resuelva al **commit más reciente** de esa rama
cada vez que ejecutes `nix flake update`. Esto te da siempre los paquetes más actuales.

### ¿Por qué no simplemente actualizar el nixpkgs principal?

Buena pregunta. La respuesta es: separación de responsabilidades.

- El `nixpkgs` principal de hydenix está pinado **a propósito** para que todo el entorno HyDE sea
  estable y reproducible. Actualizarlo requiere testing extenso porque puede romper cosas.
- `nixpkgs-unstable` adicional solo se usa para los paquetes que **tú eliges** instalar desde ahí.
  El resto del sistema sigue siendo estable.

Esto te da lo mejor de ambos mundos: **base estable + paquetes seleccionados siempre actuales**.

### El patrón: `pkgs.unstable`

Para hacer que los paquetes del segundo nixpkgs estén disponibles en tu configuración, los
exponemos como `pkgs.unstable` mediante el **overlay** de hydenix. Un overlay en Nix es una función
que extiende el conjunto de paquetes (`pkgs`) añadiendo o sobreescribiendo atributos.

Después del cambio, en cualquier módulo de NixOS puedes escribir:

```nix
environment.systemPackages = [
  pkgs.unstable.antigravity-fhs   # versión más reciente de nixpkgs-unstable
  pkgs.unstable.cursor            # otro ejemplo para el futuro
  pkgs.firefox                    # versión del nixpkgs pinado de hydenix (igual que antes)
];
```

---

## 3. Archivos modificados y por qué

### 3.1 `flake.nix` — Declarar el nuevo input

**Ruta:** `/home/ravn/Work/hydenix/flake.nix`

Este es el punto de entrada de todo el flake. Aquí se declaran todas las **fuentes externas**
(inputs) que usa el proyecto: nixpkgs, home-manager, hyde, etc.

**Qué se añadió:**

```nix
inputs = {
  # Fresh nixpkgs-unstable — always latest, for cutting-edge packages (e.g. pkgs.unstable.antigravity-fhs)
  nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

  # Hydenix's nixpkgs (pinned for stability)  ← este ya existía
  nixpkgs.url = "github:nixos/nixpkgs/95e96e8632c387dcf8c4223b8ab14a58936f8b10";
  ...
```

**Por qué aquí:**  
En Nix Flakes, todo input externo debe declararse en `flake.nix`. Si no lo declaras aquí, los
módulos internos no pueden acceder a él. El nuevo input `nixpkgs-unstable` sin un hash/commit fijo
hará que Nix descargue el estado más reciente de esa rama al ejecutar `nix flake update`.

**Efecto en `flake.lock`:**  
Cuando Nix procesa el flake por primera vez después de añadir este input, actualiza `flake.lock`
añadiendo una entrada para `nixpkgs-unstable` con el commit más reciente en ese momento. Por ejemplo:

```
• Added input 'nixpkgs-unstable':
    'github:nixos/nixpkgs/75690239f08f885ca9b0267580101f60d10fbe62' (2026-03-11)
```

Ese commit en el lock garantiza que todos los que usen el repo obtengan la misma versión de
`nixpkgs-unstable` hasta que alguien ejecute `nix flake update nixpkgs-unstable` explícitamente.

---

### 3.2 `hydenix/sources/overlay.nix` — Exponer `pkgs.unstable`

**Ruta:** `/home/ravn/Work/hydenix/hydenix/sources/overlay.nix`

Este archivo define el **overlay principal de hydenix**. Un overlay en Nix es una función de la
forma `final: prev: { ... }` que añade o sobreescribe atributos en el conjunto de paquetes `pkgs`.

El overlay de hydenix ya existía y añadía paquetes propios del proyecto (hyde, hydectl, etc.).
Nosotros lo extendemos para añadir `pkgs.unstable`.

**Qué se añadió:**

```nix
{ inputs }:

final: prev:
let
  callPackage = prev.lib.callPackageWith (prev // packages // inputs);

  # ← NUEVO: construir un segundo conjunto de paquetes desde nixpkgs-unstable
  unstablePkgs = import inputs.nixpkgs-unstable {
    inherit (prev) system;       # usa la misma arquitectura (x86_64-linux, aarch64, etc.)
    config.allowUnfree = true;   # permitir software propietario (antigravity es propietario)
  };

  packages = {
    # ... paquetes preexistentes de hydenix ...

    # ← NUEVO: exponer unstablePkgs como pkgs.unstable
    # Ejemplo de uso: pkgs.unstable.antigravity-fhs
    unstable = unstablePkgs;
  };
in
packages
```

**Por qué `inherit (prev) system`:**  
`prev.system` es la arquitectura del sistema host (ej: `x86_64-linux`). Usamos la del sistema
que ya está configurado para que `pkgs.unstable` compile para la misma arquitectura que el resto.

**Por qué `config.allowUnfree = true`:**  
`antigravity-fhs` (y Cursor, y otros IDEs privativos) son software **unfree** (con licencia
propietaria). NixOS por defecto rechaza construir/descargar software unfree para proteger al usuario
de instalar cosas problemáticas sin saberlo. Al declarar `allowUnfree = true` en el nixpkgs-unstable
separado, le decimos a Nix que para ese subconjunto de paquetes está bien. El nixpkgs principal de
hydenix **ya tenía** esta opción habilitada en `nix.nix`, pero al crear un pkgs separado hay que
declararlo explícitamente de nuevo.

**Por qué el overlay y no un `specialArgs`:**  
Hydenix ya pasa `inputs` al overlay (ver `nix.nix`), así que `inputs.nixpkgs-unstable` es accesible
ahí directamente. Usar el overlay es la forma más limpia porque hace que `pkgs.unstable` esté
disponible **automáticamente** en todos los módulos del sistema sin necesidad de pasarlo como
argumento especial a cada módulo.

---

### 3.3 `template/configuration.nix` — Documentación para usuarios

**Ruta:** `/home/ravn/Work/hydenix/template/configuration.nix`

Este archivo es la plantilla que los usuarios nuevos copian para crear su propia configuración
personal. No es la configuración del sistema que tú usas — es un **ejemplo comentado**.

**Qué se añadió (al final del archivo):**

```nix
  # ─── Cutting-edge packages via nixpkgs-unstable ────────────────────────────
  # Use pkgs.unstable.<name> to install packages at their latest version,
  # regardless of hydenix's pinned nixpkgs base.
  # To enable, uncomment the block below and add the packages you want:
  #
  # environment.systemPackages = [
  #   pkgs.unstable.antigravity-fhs  # Google Antigravity IDE (FHS-compatible)
  # ];
```

**Por qué aquí:**  
El template es lo primero que lee un usuario nuevo. Si esta capacidad no está documentada en la
plantilla, nadie sabrá que existe. El bloque está comentado para no instalar nada por defecto.

---

## 4. Cómo funciona todo junto (flujo completo)

```
flake.nix
  └── inputs.nixpkgs-unstable  ──→  github:nixos/nixpkgs (rama: nixpkgs-unstable, siempre fresca)
                                         │
                                         ▼
hydenix/sources/overlay.nix
  └── unstablePkgs = import inputs.nixpkgs-unstable { allowUnfree = true; }
  └── packages.unstable = unstablePkgs    ──→   pkgs.unstable disponible globalmente
                                                       │
                                                       ▼
hydenix/modules/system/nix.nix
  └── overlays = [ inputs.self.overlays.default ]  ←── aplica el overlay a toda la config
                                                       │
                                                       ▼
tu configuration.nix personal
  └── environment.systemPackages = [ pkgs.unstable.antigravity-fhs ]
```

El overlay se aplica en `nix.nix` dentro de `nixpkgs.pkgs = import inputs.nixpkgs { overlays = [...] }`.
Esto significa que el `pkgs` que reciben TODOS los módulos de NixOS ya incluye `pkgs.unstable`.

---

## 5. Verificación que se realizó

Después de aplicar los cambios, se verificó:

1. **`nix flake show`** — el flake es sintácticamente válido y Nix pudo resolverlo (exit 0).
2. **`flake.lock` actualizado** — Nix añadió automáticamente la entrada `nixpkgs-unstable`:
   - Commit: `75690239f08f885ca9b0267580101f60d10fbe62`
   - Fecha del commit: **11 de marzo 2026** (2 días antes de hacer este cambio)
3. **`nix eval github:NixOS/nixpkgs/75690239...#antigravity-fhs.name`** — confirmó que el paquete
   existe en ese commit y es versión **`antigravity-1.19.6`** ✅

---

## 6. Cómo agregar otro paquete en el futuro (ej: Cursor)

Si en el futuro quieres agregar Cursor (u otro paquete) en su versión más reciente, el proceso es:

### Paso 1: Verificar que el paquete existe en nixpkgs-unstable

```bash
# Buscar el nombre exacto del paquete
nix search nixpkgs/nixpkgs-unstable cursor

# O ver su información detallada
nix eval nixpkgs#cursor.name
```

Si necesitas saber el nombre exacto del paquete (a veces no es obvio), también puedes buscar en
[search.nixos.org](https://search.nixos.org/packages?channel=unstable) seleccionando el canal
"unstable".

### Paso 2: Actualizr nixpkgs-unstable al último commit (opcional)

Si quieres asegurarte de tener la versión más reciente del paquete:

```bash
cd /home/ravn/Work/hydenix
nix flake update nixpkgs-unstable
```

Esto actualiza **solo** el input `nixpkgs-unstable` en `flake.lock` sin tocar nada más.

> ⚠️ **No ejecutes `nix flake update` sin argumentos** a menos que quieras actualizar también
> el nixpkgs pinado de hydenix, home-manager, etc. Usa siempre el nombre del input específico.

### Paso 3: Agregar el paquete en tu `configuration.nix` personal

En tu archivo de configuración personal (el que tienes en `/etc/nixos/` o equivalente):

```nix
environment.systemPackages = [
  pkgs.unstable.cursor           # Cursor IDE, siempre en su versión más reciente
  pkgs.unstable.antigravity-fhs  # Google Antigravity IDE
  # pkgs.firefox                 # esto viene del nixpkgs pinado de hydenix
];
```

### Paso 4: Aplicar los cambios

```bash
sudo nixos-rebuild switch --flake /ruta/a/tu/config#tu-hostname
```

### Caso especial: el paquete necesita `allowUnfree` adicional

Si obtienes un error como:
```
error: Package 'cursor-...' has an unfree license, refusing to evaluate.
```

No deberías verlo con la configuración actual porque ya incluimos `allowUnfree = true` en
`unstablePkgs`. Pero si por alguna razón apareciera, también puedes añadir en tu config personal:

```nix
nixpkgs.config.allowUnfree = true;
```

### Caso especial: el paquete no existe en nixpkgs-unstable

Si el paquete no está en nixpkgs, tienes dos opciones:

**A) Usar un flake externo del paquete** (si existe):  
Muchos proyectos publican sus propios flakes. Por ejemplo:
```nix
# En flake.nix inputs:
cursor-nix.url = "github:author/cursor-nix";

# En overlay.nix packages:
cursor = inputs.cursor-nix.packages.${prev.stdenv.hostPlatform.system}.default;

# En tu configuration.nix:
environment.systemPackages = [ pkgs.cursor ];
```

**B) Escribir tu propia derivación en `hydenix/sources/`**:  
El repo ya tiene ejemplos como `pokego.nix`, `hyde-gallery.nix`. Puedes seguir el mismo patrón
para empaquetar lo que necesites.

---

## 7. Referencia rápida

| Tarea | Comando / Lugar |
|---|---|
| Ver versión actual de un paquete en unstable | `nix eval nixpkgs#<paquete>.version` |
| Buscar paquetes en unstable | [search.nixos.org](https://search.nixos.org) → channel: unstable |
| Actualizar solo nixpkgs-unstable | `nix flake update nixpkgs-unstable` (desde el repo) |
| Instalar un paquete reciente | `pkgs.unstable.<nombre>` en `environment.systemPackages` |
| Ver qué commit tiene nixpkgs-unstable | `nix flake metadata \| grep nixpkgs-unstable` |
| Ver cuándo fue ese commit | buscar el hash en `github.com/NixOS/nixpkgs/commit/<hash>` |

---

## 8. Archivos clave del repo para entender el sistema de overlays

Si en el futuro necesitas entender cómo está armado todo:

| Archivo | Propósito |
|---|---|
| [`flake.nix`](../flake.nix) | Punto de entrada. Declara todos los inputs externos. |
| [`hydenix/sources/overlay.nix`](../hydenix/sources/overlay.nix) | Define `pkgs.unstable` y otros paquetes custom. |
| [`hydenix/modules/system/nix.nix`](../hydenix/modules/system/nix.nix) | Aplica el overlay al pkgs global del sistema. |
| [`hydenix/modules/system/system.nix`](../hydenix/modules/system/system.nix) | Lista de paquetes base del sistema (los del nixpkgs pinado). |
| [`template/configuration.nix`](../template/configuration.nix) | Plantilla de configuración personal para usuarios nuevos. |
| [`flake.lock`](../flake.lock) | Hashes exactos de todos los inputs. Garantiza reproducibilidad. |
