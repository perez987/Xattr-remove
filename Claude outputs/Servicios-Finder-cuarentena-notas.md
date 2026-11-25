# Notas: servicios del Finder para eliminar la cuarentena

Resumen de lo aprendido al crear un servicio del Finder independiente de Xattr-remove para eliminar el atributo `com.apple.quarantine`.

---

## 1. Las tres formas probadas

| Forma | Dónde aparece en el menú contextual | Carpeta del repositorio |
|---|---|---|
| Servicio de la app **Xattr-remove** (`NSServices` en su `Info.plist`) | Raíz del menú, o submenú *Servicios* si hay muchos | `Xcode-project/` |
| **Acción rápida** de Automator (`.workflow`) | Submenú *Acciones rápidas* | `Finder-QuickAction/` |
| App mínima **Remove-quarantine** (servicio declarado por una app) | **Raíz del menú** | `Finder-Service-App/` |

**Por qué cambia la posición:**

- Los servicios que declara una aplicación en su `Info.plist`, como "Nueva ventana de Terminal en la carpeta", salen en la raíz del menú contextual.
- Los workflows de Automator salen en *Acciones rápidas*. Si se desactivan como Acción rápida en *Ajustes → Extensiones → Finder*, desaparecen del menú contextual y solo quedan en **Finder → Servicios**, en la barra de menús. No hay ningún ajuste del `.workflow` que los saque a la raíz.
- Si hay más de 4 o 5 servicios activos para la selección, el Finder los agrupa todos en un submenú **Servicios**.

---

## 2. `xattr -c` frente a `xattr -d`

| Comando | Efecto |
|---|---|
| `xattr -cr <ruta>` | Borra **todos** los atributos extendidos, de forma recursiva: etiquetas de color, comentarios del Finder, `kMDItemWhereFroms`, etc. |
| `xattr -dr com.apple.quarantine <ruta>` | Borra **solo** la cuarentena, de forma recursiva. **Es el que conviene usar.** |

Equivalente en código: `removexattr(path, "com.apple.quarantine", XATTR_NOFOLLOW)`. Devuelve `ENOATTR` si el atributo no existe, y en ese caso se puede ignorar.

---

## 3. Acción rápida con Automator

Lo más fiable es crearla desde Automator. Un `.workflow` escrito a mano puede no ser aceptado por macOS.

1. En Automator, elige *Archivo → Nuevo → Acción rápida*.
2. Configura: *El flujo de trabajo recibe* **archivos o carpetas** en **Finder.app**.
3. Añade la acción **Ejecutar script de shell**, con *Shell* `/bin/bash` y *Pasar datos de entrada* **como argumentos**.
4. Pega este script:

   ```bash
   for f in "$@"; do
       /usr/bin/xattr -dr com.apple.quarantine "$f" 2>/dev/null
   done
   exit 0
   ```

5. Guárdala con ⌘S. Se guarda en `~/Library/Services/<nombre>.workflow`.

Se activa y desactiva en dos sitios:

- *Ajustes del Sistema → General → Ítems de inicio y extensiones → Finder*, que controla el submenú *Acciones rápidas*.
- *Ajustes del Sistema → Teclado → Atajos de teclado → Servicios → Archivos y carpetas*, que controla *Finder → Servicios*.

Para probar un workflow desde Terminal:

```bash
touch /tmp/t.txt && xattr -w com.apple.quarantine "0000;00000000;Safari;" /tmp/t.txt
automator -i /tmp/t.txt ~/Library/Services/"<nombre>.workflow"
xattr -l /tmp/t.txt   # no debería mostrar nada
```

---

## 4. Quitar el servicio de la app Xattr-remove

No es un archivo aparte: está en el `Info.plist` de la app, y macOS lo registra para **cada copia** de la app que encuentra, incluidas las compiladas por Xcode en DerivedData.

- **Solo ocultarlo:** desmárcalo en *Atajos de teclado → Servicios → Archivos y carpetas*.
- **Eliminarlo del todo:**

```bash
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

# Copias registradas
$LSREG -dump | grep -i "path:.*Xattr-remove.app" | sort -u

# Darlas de baja
$LSREG -u "/Applications/Xattr-remove.app"
$LSREG -u ~/Library/Developer/Xcode/DerivedData/Xattr-remove-*/Build/Products/*/Xattr-remove.app

# Opcional: borrar los builds de Xcode
rm -rf ~/Library/Developer/Xcode/DerivedData/Xattr-remove-*

/System/Library/CoreServices/pbs -flush; /System/Library/CoreServices/pbs -update
killall Finder
```

Para que no vuelva a registrarse, hay que quitar el bloque `NSServices` del `Info.plist` y recompilar. Si no, reaparece en cuanto la app se abre.

---

## 5. Diagnóstico cuando un servicio no aparece

1. **¿Está instalado?** Comprueba `ls ~/Library/Services/` (workflows) o `~/Applications` (apps).
2. **¿Lo ve el sistema?**

   ```bash
   /System/Library/CoreServices/pbs -dump | grep -i -A3 "<nombre>"
   ```

3. **¿Aparece en *Finder → Servicios*,** en la barra de menús, con un archivo seleccionado? Si sale ahí, el servicio funciona y el problema es solo dónde lo coloca el menú contextual.
4. **Haz clic derecho sobre un archivo o carpeta,** no sobre el espacio vacío de la ventana.
5. **Desactiva servicios que no uses,** para que el Finder no los agrupe en el submenú *Servicios*.
6. **Refresca el caché:** `pbs -flush; pbs -update; killall Finder`. Si no basta, **cierra sesión y vuelve a entrar**.

Archivos de caché de servicios:

```
~/Library/Caches/com.apple.ServicesMenu.Services.plist
~/Library/Caches/com.apple.nsservicescache.plist
```

---

## 6. App mínima Remove-quarantine (`Finder-Service-App/`)

### Diseño

- Es una app AppKit sin ventana y sin icono en el Dock (`LSUIElement = true`), sin sandbox, para macOS 13 o posterior. Se compila como binario universal (arm64 y x86_64).
- Declara un único servicio en `NSServices`:
  - `NSMessage = removeQuarantine`, que llama al método `removeQuarantine(_:userData:error:)`.
  - `NSPortName = Remove-quarantine`, que **debe coincidir con el nombre de la app**.
  - `NSSendFileTypes = public.item`.
  - `NSRequiredContext = {}`.
- Lee las URL del pasteboard y aplica `removexattr` con `XATTR_NOFOLLOW` de forma recursiva, incluidos los archivos ocultos y el contenido de los bundles.
- Se cierra sola: 2 segundos después de usar el servicio, o 10 segundos después de abrirla a mano. macOS la vuelve a lanzar cuando se usa el servicio.
- Identificador del bundle: `yo.remove-quarantine`. Región de desarrollo: `en`.

### Archivos

| Archivo | Función |
|---|---|
| `Sources/main.swift` | Proveedor del servicio y cierre automático |
| `Info.plist` | `LSUIElement`, icono, `CFBundleLocalizations` y `NSServices` |
| `Resources/<idioma>.lproj/ServicesMenu.strings` | Nombre del servicio traducido |
| `AppIcon.png` | Icono de 1024×1024, que se convierte en `.icns` al compilar |
| `build.sh` | `swiftc` para cada arquitectura, `lipo`, icono, idiomas y firma |
| `notarize.sh` | Notarización, grapado del ticket y zip para distribuir |
| `install.sh` / `uninstall.sh` | Instalar y registrar el servicio en `~/Applications`, y quitarlo |
| `README.md` / `README-ES.md` | Documentación en inglés y en español |

### Uso

```bash
cd Finder-Service-App
./build.sh && ./install.sh     # compilar e instalar
./uninstall.sh                 # desinstalar
```

### Icono

`build.sh` genera `AppIcon.icns` a partir de `AppIcon.png` con `sips` (tamaños de 16 a 1024 px, con sus @2x) e `iconutil`, y `CFBundleIconFile = AppIcon`. Si el Finder no muestra el icono nuevo:

```bash
touch ~/Applications/Remove-quarantine.app && killall Finder Dock
```

### Traducciones del nombre del servicio

El nombre por defecto está en el `Info.plist` (`NSMenuItem → default = "Remove quarantine"`). Las traducciones van en `Resources/<código>.lproj/ServicesMenu.strings`:

```
"Remove quarantine" = "Eliminar cuarentena";
```

Para añadir un idioma, crea su `.lproj`, añade el código a `CFBundleLocalizations` y recompila.

---

## 7. Firma y notarización para distribuir

- Con la firma **ad hoc** (`codesign --sign -`), la app solo sirve en tu Mac. En otros, Gatekeeper pide autorizarla en *Privacidad y seguridad*.
- **Developer ID Application** + **notarización** hacen que se abra sin avisos.
- El certificado **Apple Development** no sirve para distribuir.
- La app no necesita entitlements: el runtime endurecido no bloquea `removexattr()`.

### Credenciales de notarización (solo una vez)

```bash
xcrun notarytool store-credentials "notary-profile" --apple-id "tu@correo.com" --team-id "TEAMID"
```

Pide una contraseña específica de app, que se crea en appleid.apple.com.

### Cada versión

```bash
./build.sh        # firma con el primer "Developer ID Application" del llavero; si no hay, ad hoc
# o con una identidad concreta:
SIGN_IDENTITY="Developer ID Application: Nombre (TEAMID)" ./build.sh

./notarize.sh     # envía a Apple, espera, grapa el ticket, verifica y crea build/Remove-quarantine.zip
```

Los pasos internos son:

```bash
codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" App.app
ditto -c -k --keepParent App.app App.zip
xcrun notarytool submit App.zip --keychain-profile notary-profile --wait
xcrun stapler staple App.app
spctl --assess --type execute --verbose=2 App.app
```

Si la notarización falla, el motivo se ve con:

```bash
xcrun notarytool log <id> --keychain-profile notary-profile
```

### Lo que hace el otro usuario

1. Descomprime el zip y mueve la app a `/Applications` o a `~/Applications`.
2. La abre una vez. La app se cierra sola y deja el servicio registrado.
3. Comprueba que **Remove quarantine** está activado en *Atajos de teclado → Servicios*.

> Al cambiar el identificador del bundle, macOS trata la app como nueva. Puede quedar una entrada repetida en *Servicios*; desmárcala o cierra sesión y vuelve a entrar.

---

## 8. Comandos útiles

```bash
# Añadir y ver la cuarentena (pruebas)
xattr -w com.apple.quarantine "0000;00000000;Safari;" archivo
xattr -l archivo

# Quitar solo la cuarentena
xattr -dr com.apple.quarantine archivo_o_carpeta

# Caché de servicios
/System/Library/CoreServices/pbs -flush; /System/Library/CoreServices/pbs -update
/System/Library/CoreServices/pbs -dump | grep -i -A3 "nombre"

# LaunchServices
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
$LSREG -dump | grep -i "path:.*NombreApp.app"
$LSREG -f /ruta/App.app     # registrar
$LSREG -u /ruta/App.app     # dar de baja

# Firma
security find-identity -v -p codesigning
codesign -dv --verbose=2 App.app
codesign --verify --strict --verbose=2 App.app

# Arquitecturas de un binario
lipo -archs App.app/Contents/MacOS/App

killall Finder
```
