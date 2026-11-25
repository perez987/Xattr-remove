# Quitar el servicio de Xattr-remove y diagnosticar la Acción rápida

## 1. Quitar el servicio de la app Xattr-remove

El servicio "Remove quarantine (Xattr-remove)" no es un archivo aparte: está declarado en el `Info.plist` de la app (`NSServices`). macOS lo registra para **cada copia** de la app que encuentra, y eso incluye las que compila Xcode en DerivedData.

- **Solo ocultarlo:** desactívalo en *Ajustes del Sistema → Teclado → Funciones rápidas de teclado → Servicios → Archivos y carpetas*.
- **Eliminarlo del todo:** tienes que dar de baja todas las copias registradas.

```bash
# Ver qué copias de la app tiene registradas el sistema
$/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -dump | grep -i "path:.*Xattr-remove.app" | sort -u

# Dar de baja cada ruta que aparezca (ejemplo)
$/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "/Applications/Xattr-remove.app"
$/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u ~/Library/Developer/Xcode/DerivedData/Xattr-remove-*/Build/Products/*/Xattr-remove.app

# Opcional: borrar los builds de Xcode para que no se vuelva a registrar
rm -rf ~/Library/Developer/Xcode/DerivedData/Xattr-remove-*

/System/Library/CoreServices/pbs -flush; /System/Library/CoreServices/pbs -update
killall Finder
```

Si quieres seguir usando la app pero sin el servicio, hay que quitar el bloque `NSServices` del archivo `Info.plist` y recompilarla. Si no, en cuanto se vuelva a abrir, macOS lo registra otra vez.

## 2. La nueva Acción rápida no aparece

Compruébalo en este orden:

1. **¿Se instaló?** Con `ls ~/Library/Services/` debería salir `Eliminar cuarentena.workflow`.
2. **¿La ve el sistema?** Con `/System/Library/CoreServices/pbs -dump | grep -i cuarentena`:
   - Si sale, el servicio está registrado pero desactivado. Actívalo en *Ajustes → Teclado → Funciones rápidas de teclado → Servicios*, y también en *Ajustes → General → Ítems de inicio y extensiones → Finder* (Acciones rápidas).
   - Si no sale, macOS no ha aceptado el workflow, seguramente porque estaba escrito a mano.
3. **¿El workflow es válido?** Prueba a ejecutarlo directamente:

   ```bash
   touch /tmp/t.txt && xattr -w com.apple.quarantine "0000;00000000;Safari;" /tmp/t.txt
   xattr -l /tmp/t.txt
   # com.apple.quarantine: 0000;00000000;Safari;
   automator -i /tmp/t.txt ~/Library/Services/"Remove-quarantine.workflow"
   xattr -l /tmp/t.txt
   # 
   ```

### Crear la Acción rápida desde Automator (lo más fiable)

1. Abre Automator, elige *Archivo → Nuevo → Acción rápida*.
2. Arriba, configura: *El flujo de trabajo recibe* **archivos o carpetas** en **Finder.app**.
3. Arrastra la acción **Ejecutar script de shell**. Elige *Shell*: `/bin/bash` y *Pasar datos de entrada*: **como argumentos**.
4. Pega este script:

   ```bash
   for f in "$@"; do
       /usr/bin/xattr -dr com.apple.quarantine "$f" 2>/dev/null
   done
   exit 0
   ```

5. Guárdala con ⌘S como **Eliminar cuarentena**. Automator la guarda en `~/Library/Services` y aparece al momento.
