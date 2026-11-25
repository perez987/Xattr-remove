#!/bin/bash
# Desinstala la Acción rápida "Eliminar atributo de cuarentena"
WF="$HOME/Library/Services/Eliminar cuarentena.workflow"
rm -rf "$WF"
/System/Library/CoreServices/pbs -flush 2>/dev/null || true
echo "Eliminado: $WF"
