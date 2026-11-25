#!/bin/bash
# Instala la Acción rápida "Eliminar atributo de cuarentena" en ~/Library/Services
set -e
cd "$(dirname "$0")"
WF="Eliminar cuarentena.workflow"
DEST="$HOME/Library/Services"
mkdir -p "$DEST"
rm -rf "$DEST/$WF"
cp -R "$WF" "$DEST/"
/usr/bin/xattr -dr com.apple.quarantine "$DEST/$WF" 2>/dev/null || true
/System/Library/CoreServices/pbs -flush 2>/dev/null || true
/System/Library/CoreServices/pbs -update 2>/dev/null || true
echo "Instalado en: $DEST/$WF"
echo "Si no aparece en el menú contextual: Ajustes del Sistema > Teclado > Funciones rápidas de teclado > Servicios (actívalo) o reinicia el Finder (killall Finder)."
