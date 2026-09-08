# Xattr-remove: eliminar `com.apple.quarantine`

![Platform](https://img.shields.io/badge/macOS-13.5+-orange.svg)
![Swift](https://img.shields.io/badge/Swift-5+-green.svg)
![Xcode](https://img.shields.io/badge/Xcode-15-blue.svg)

Aplicación SwiftUI para macOS que elimina el atributo extendido `com.apple.quarantine` de los archivos descargados de Internet. Funciona aceptando archivos mediante arrastrar y soltar sobre la ventana de la aplicación.

|  |
|:----|
| ![Main](Images/Main-window-es.png) |

### Eliminación del atributo de cuarentena

Esta aplicación se diseña para una tarea principal: eliminar rápida y fácilmente `com.apple.quarantine` de los archivos descargados de Internet para que puedan abrirse en macOS sin problemas con Gatekeeper.

### Firmar digitalmente la aplicación (opcional)

También puede aplicar una firma digital *ad-hoc* a la aplicación y al paquete Sparkle, sustituyendo su certificado por el del usuario de la máquina actual.
Esto resulta especialmente útil si, al intentar ejecutar la aplicación por primera vez, incluso después de eliminar el atributo `com.apple.quarantine`, se cierra inesperadamente con un error relacionado con Sparkle.
Esta opción equivale a ejecutar estos comandos:

```bash
 codesign --force --deep --sign - \
  <App-name>.app/Contents/Frameworks/Sparkle.framework

 codesign --force --deep --sign - \
  <App-name>.app
```

**Nota**: Esto no es necesario ni recomendable con aplicaciones firmadas digitalmente con un Apple Developer ID.

### Detección de la arquitectura (complemento)

Si el archivo arrastrado a la ventana es una `.app`, un ejecutable de macOS o una librería, Xattr-remove ejecuta `lipo -archs` sobre el archivo. El resultado (arquitectura/s del archivo) se muestra en la ventana principal durante el procesamiento y se añade al mensaje que informa al usuario. La arquitectura puede ser `Intel y Silicon`, `Sólo Intel` o `Sólo Silicon`. Si arrastras varios archivos a la vez, no se muestra información sobre la arquitectura, ya que sería ambigua. Los archivos que no son binarios (documentos de texto, scripts, etc.) no devuelven nada y no aparece información sobre la arquitectura.

| Capturas de pantalla |
|:----|
| ![Alert](Images/1file+arch-es.png) |
| ![Alert](Images/1file-es.png) |

## Funcionalidades

- Xattr-remove está certificado por Apple y no presenta problemas con Gatekeeper en la primera ejecución 
- Permite arrastrar archivos sobre la ventana de la aplicación para eliminar el atributo de cuarentena
- Casilla de selección opcional para volver a firmar la aplicación (Sparkle primero, aplicación después) ademas de eliminar el atributo `quarantine`
- Información sobre las arquitecturas detectadas si se trata de un archivo binario de macOS
- Desarrollada con Swift y SwiftUI
- Manejo de errores (tanto si el atributo existe como si no)
- Compatible con todos los tipos de archivo
- Sistema de idiomas con selector y 5 idiomas (alemán, ingles, francés, italiano y español)
   - Selector de idioma: `Idioma` > `Elegir idioma` en la barra de menús o mediante el teclado `⌘ + L`

## Compilación con Xcode

Abre `Xattr-remove.xcodeproj` en Xcode y compila el proyecto. La aplicación requiere macOS 13.0 o posterior.

## Uso

1. Lanza la aplicación para abrir la ventana principal
2. Arrastra y suelta archivos descargados de Internet sobre la ventana de la aplicación
3. El atributo de cuarentena, si existe, se elimina automáticamente
4. (Opcional) Antes de arrastrar los archivos, activa la la casilla para volver a firmar la aplicación y ejecutar `codesign`
5. El usuario recibe alertas informativas
6. La aplicación se cierra automáticamente 5 segundos después de mostrar la alerta excepto en casos de error

**Nota:** Los archivos deben soltarse sobre la ventana de la aplicación. Hacerlos sobre el icono de la aplicación en Finder o Dock es difícil de implementar debido a las restricciones de macOS Gatekeeper con ejecutables en cuarentena.

## Requerimientos

- macOS 13.0 o posterior (para ejecutar)
- Xcode 15.0 o posterior (para compilar)

## Créditos

Basado en:

- [https://github.com/rcsiko/xattr-editor](https://github.com/rcsiko/xattr-editor)
- [https://github.com/perez987/Xattr-Editor](https://github.com/perez987/Xattr-Editor)
- [https://github.com/jozefizso/swift-xattr](https://github.com/jozefizso/swift-xattr)
- [https://github.com/overbuilt/foundation-xattr](https://github.com/overbuilt/foundation-xattr)
- [https://github.com/abra-code/XattrApp](https://github.com/abra-code/XattrApp)
