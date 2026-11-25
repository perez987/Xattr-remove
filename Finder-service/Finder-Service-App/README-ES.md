# Remove-quarantine: servicio del Finder en una app mínima

*[English version](README.md)*

App de macOS sin ventana ni icono en el Dock, independiente de Xattr-remove. Solo sirve para ofrecer el servicio **Eliminar cuarentena** (*Remove quarantine* en inglés) en el menú contextual del Finder. Al ser un servicio declarado por una aplicación (como "Nueva ventana de Terminal en la carpeta"), aparece en la **raíz** del menú contextual y no dentro de *Acciones rápidas*.

## Qué hace

- Para cada elemento seleccionado (archivo, carpeta, `.app`, `.dmg`, `.pkg`) elimina **solo** el atributo `com.apple.quarantine`, también dentro de carpetas y bundles. Equivale a `xattr -dr com.apple.quarantine`.
- Usa `removexattr()` con `XATTR_NOFOLLOW`, así que no sigue enlaces simbólicos.
- No muestra ningún mensaje. Si el atributo no está, no hace nada.
- macOS la abre en segundo plano al usar el servicio y se cierra sola 2 segundos después.
- No usa sandbox, porque el sandbox bloquea `removexattr()`.
- El nombre del servicio está traducido: **Remove quarantine** (inglés, por defecto) y **Eliminar cuarentena** (español).

## Requisitos

- macOS 13 o posterior.
- Xcode o las Command Line Tools (para `swiftc`, `lipo` y `codesign`).

## Instalación

```bash
cd Finder-Service-App
./install.sh
```

El script hace lo siguiente:

1. Compila la app universal (Apple Silicon e Intel) en `build/`.
2. La copia a `~/Applications/Remove-quarantine.app`.
3. La registra en LaunchServices y la abre una vez para que macOS lea el servicio. Se cierra sola a los 10 segundos.
4. Refresca el caché de servicios y reinicia el Finder.

Después, comprueba que **Eliminar cuarentena** está marcado en *Ajustes del Sistema → Teclado → Atajos de teclado → Servicios → Archivos y carpetas*.

## Firma y notarización para otros usuarios

Con la firma ad hoc la app funciona en tu Mac. En otro Mac, Gatekeeper la bloquea la primera vez y obliga a autorizarla en *Ajustes del Sistema → Privacidad y seguridad*. Para evitarlo, firma la app con el certificado **Developer ID Application** y notarízala con Apple. El certificado *Apple Development* solo sirve para desarrollo, no para distribuir.

**1. Credenciales de notarización (solo una vez).** Necesitas una contraseña específica de app, que se crea en appleid.apple.com, y tu Team ID:

```bash
xcrun notarytool store-credentials "notary-profile" --apple-id "tu@correo.com" --team-id "TEAMID"
```

**2. Compilar y firmar.** `build.sh` busca en el llavero la primera identidad *Developer ID Application* y firma con runtime endurecido (*hardened runtime*) y sello de tiempo. Si no encuentra ninguna, firma ad hoc. Para elegir la identidad a mano:

```bash
./build.sh
# o bien
SIGN_IDENTITY="Developer ID Application: Nombre (TEAMID)" ./build.sh
```

**3. Notarizar, grapar el ticket y empaquetar:**

```bash
./notarize.sh
```

El resultado es `build/Remove-quarantine.zip`, listo para distribuir.

**Lo que hace el otro usuario:**

1. Descomprime el zip y mueve `Remove-quarantine.app` a `/Applications` o a `~/Applications`.
2. La abre una vez. No aparece ningún aviso de Gatekeeper; la app se cierra sola a los 10 segundos y deja registrado el servicio.
3. Comprueba que el servicio está marcado en *Ajustes del Sistema → Teclado → Atajos de teclado → Servicios → Archivos y carpetas*.

## Recompilar tras cambiar el código

```bash
./build.sh && ./install.sh
```

## Desinstalación

```bash
./uninstall.sh
```

## Archivos

| Archivo | Función |
|---|---|
| `Sources/main.swift` | Proveedor del servicio (`removeQuarantine:userData:error:`) y cierre automático |
| `Info.plist` | `LSUIElement` (sin Dock), icono, idiomas y declaración `NSServices` |
| `Resources/<idioma>.lproj/ServicesMenu.strings` | Nombre del servicio traducido (`en`, `es`) |
| `AppIcon.png` | Icono de 1024×1024; `build.sh` lo convierte en `AppIcon.icns` |
| `build.sh` | Compilación con `swiftc`, icono, idiomas y firma (Developer ID o ad hoc) |
| `notarize.sh` | Notarización, grapado del ticket y zip para distribuir |
| `install.sh` / `uninstall.sh` | Instalación y registro del servicio, y su eliminación |

## Añadir un idioma

Crea `Resources/<código>.lproj/ServicesMenu.strings` con el nombre traducido, añade el código a `CFBundleLocalizations` en `Info.plist` y vuelve a compilar:

```
"Remove quarantine" = "<nombre traducido>";
```
