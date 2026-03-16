# 📋 RESUMEN: Rollback de Integración Khanelivim

## 🔄 ¿Qué Pasó?

El usuario eliminó el directorio `khanelivim/` con `rm -rfv khanelivim`, lo que causó que la integración fallara con el error:

```
error: cannot call 'getFlake' on unlocked flake reference 'git+file:///home/hydenix/hydenix-minimal/khanelivim'
```

## ✅ Acciones Tomadas

Se realizó un **rollback completo** de la integración khanelivim para permitir que el sistema vuelva a compilar:

### 1. Remover carga de khanelivim en `editors.nix`
```diff
- khanelivimFlake = builtins.getFlake "git+file:///home/hydenix/hydenix-minimal/khanelivim";
```
✅ Removida

### 2. Remover paquete de khanelivim en home.packages
```diff
- (lib.mkIf cfg.khanelivim khanelivimFlake.packages.${pkgs.system}.default)
```
✅ Removida

### 3. Cambiar default editor de vuelta a "code"
```diff
- default = "nvim";
+ default = "code";
```
✅ Cambiado

### 4. Cambiar khanelivim option a default = false
```nix
khanelivim = lib.mkOption {
  type = lib.types.bool;
  default = false;  # ← AHORA DESHABILITADO
  description = "Enable Khanelivim...";
};
```
✅ Deshabilitada

### 5. Remover khanelivim de home.nix
```diff
- editors.khanelivim = true;
```
✅ Removida

## 📊 Estado Final

```
✅ Sistema puede compilar nuevamente
✅ Opción khanelivim aún existe (para futuro)
✅ Default editor vuelto a "code"
✅ Sin referencias a khanelivim en home-manager
✅ Flake.nix limpio (sin input khanelivim)
```

## 🔮 Para el Futuro

Si se desea reintegrar khanelivim:
1. Copiar el repositorio en `./khanelivim`
2. Cambiar `default = false` a `default = true` en editors.nix
3. Agregar `editors.khanelivim = true;` en home.nix
4. Reescribir la lógica de carga (no usar builtins.getFlake sin --impure)

## 📝 Lecciones Aprendidas

- ✅ `path:./` inputs causan problemas con git
- ✅ `builtins.getFlake` requiere --impure o flake lockeado
- ✅ Los flakes locales complejos necesitan cuidado extra
- ✅ Mejor approach: usar referencias remotas o integración más simple

---

**Estado:** Sistema vuelto a estado compilable ✅

