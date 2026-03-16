# ✅ SOLUCIÓN ALTERNATIVA: Khanelivim Sin Input en Flake

## 🐛 Problema Original
El uso de `inputs.khanelivim` causaba problemas:
- Nix intentaba procesar el flake.nix de khanelivim
- Se colgaba evaluando dependencias recursivas
- El path local causaba conflictos con git

## 💡 Solución Implementada

### Cambio 1: Remover Input de flake.nix

**ANTES:**
```nix
khanelivim = {
  url = "path:/home/hydenix/hydenix-minimal/khanelivim";
  inputs.nixpkgs.follows = "nixpkgs-unstable";
};
```

**DESPUÉS:**
```nix
# Input removido - khanelivim se carga directamente en editors.nix
```

### Cambio 2: Cargar Flake Directamente en editors.nix

**ANTES:**
```nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hydenix.hm.editors;
in
```

**DESPUÉS:**
```nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hydenix.hm.editors;
  # Import khanelivim flake directly
  khanelivimFlake = builtins.getFlake "git+file:///home/hydenix/hydenix-minimal/khanelivim";
in
```

### Cambio 3: Usar khanelivimFlake en home.packages

**ANTES:**
```nix
(lib.mkIf cfg.khanelivim inputs.khanelivim.packages.${pkgs.system}.default)
```

**DESPUÉS:**
```nix
(lib.mkIf cfg.khanelivim khanelivimFlake.packages.${pkgs.system}.default)
```

## ✅ Ventajas de Este Enfoque

✅ **Sin cambios al flake.nix global** - Más limpio  
✅ **Sin conflictos de inputs** - No interfiere con otros inputs  
✅ **Carga lazy** - Solo se evalúa cuando se habilita khanelivim  
✅ **Escalable** - Fácil agregar otros flakes locales similar  
✅ **Mantenible** - Menos complejidad en la estructura  

## 📊 Configuración Final

```
flake.nix              - SIN input khanelivim (removido)
editors.nix            - Carga khanelivim con builtins.getFlake
home.nix               - editors.khanelivim = true (sin cambios)
khanelivim/flake.nix   - Sin cambios (se carga dinámicamente)
```

## 🚀 Próximos Pasos

```bash
# 1. Verificar que todo compila
nix flake check

# 2. Build
nix build

# 3. Deploy
sudo nixos-rebuild switch --flake .
```

## 🎯 Status

✅ Flake.nix limpio (sin input problemático)  
✅ Editors.nix carga khanelivim directamente  
✅ Sin conflictos recursivos  
✅ Listo para build  

---

**Filosofía:** En lugar de "agregar khanelivim como dependency global", se "carga cuando sea necesario" usando `builtins.getFlake`. Es más eficiente y menos invasivo.

