# Acción rápida del Finder: Eliminar atributo de cuarentena

Acción rápida de Automator, que añade al menú contextual del Finder la opción **Acciones rápidas → Eliminar cuarentena**.

Para cada archivo, carpeta, app, `.dmg` o `.pkg` seleccionado ejecuta:

```bash
/usr/bin/xattr -dr com.apple.quarantine "<elemento>"
```

Solo elimina el atributo `com.apple.quarantine` (también dentro de carpetas y bundles `.app`). Los demás atributos extendidos, como etiquetas o comentarios del Finder, se conservan. No muestra ningún mensaje: si el atributo existe lo quita y, si no, no hace nada.

## Instalación

**Opción A, con el script:**
```bash
cd Finder-QuickAction
./install.sh
```

**Opción B, a mano:** haz doble clic en `Eliminar cuarentena.workflow` y acepta **Instalar**. También puedes copiarlo a `~/Library/Services/`.

Si no aparece en el menú:

- Actívalo en **Ajustes del Sistema → Teclado → Funciones rápidas de teclado → Servicios** (sección *Archivos y carpetas*)
- Limpia la caché con:

```bash
/System/Library/CoreServices/pbs -flush; /System/Library/CoreServices/pbs -update
killall Finder
```

## Desinstalación

```bash
./uninstall.sh
```
