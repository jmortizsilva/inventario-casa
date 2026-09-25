#!/bin/zsh
# Compila la app, la instala en el iPhone emparejado (por cable o por Wi‑Fi) y
# la abre. Sirve también por SSH.
#
# El certificado de desarrollo está en el llavero guardalo-firma, no en el de
# inicio de sesión (ver docs/FIRMA-SIN-PANTALLA.md de Guardar Enlaces). Se
# abre aquí, en la misma sesión que compila, y se pone en la lista de llaveros:
# desbloquearlo antes en otra orden no basta, y codesign falla con
# errSecInternalComponent.
set -e

cd "$(dirname "$0")/.."

llavero=~/Library/Keychains/guardalo-firma.keychain-db
security unlock-keychain -p "$(cat ~/.appstoreconnect/llavero-firma.txt)" "$llavero"
security list-keychains -d user -s "$llavero" ~/Library/Keychains/login.keychain-db

equipo="S92QZXCW54"
salida="/tmp/inventario-iphone"

# Primer iPhone físico emparejado que aparezca.
dispositivo=$(xcrun devicectl list devices 2>/dev/null \
  | awk '/physical/ && /available|connected/ { for (i = 1; i <= NF; i++) if ($i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$/) { print $i; exit } }')

if [[ -z "$dispositivo" ]]; then
  echo "No encuentro ningún iPhone emparejado. Comprueba que está desbloqueado y en la misma red."
  exit 1
fi

echo "Compilando para $dispositivo…"
xcodebuild -project InventarioCasa.xcodeproj -scheme InventarioCasa -configuration Debug \
  -destination "id=$dispositivo" -derivedDataPath "$salida" \
  DEVELOPMENT_TEAM="$equipo" CODE_SIGN_STYLE=Automatic build -quiet

echo "Instalando…"
xcrun devicectl device install app --device "$dispositivo" \
  "$salida/Build/Products/Debug-iphoneos/InventarioCasa.app"

echo "Abriendo…"
# Con el iPhone bloqueado no se puede abrir, pero la app ya está instalada.
xcrun devicectl device process launch --device "$dispositivo" com.jmortiz.inventario >/dev/null 2>&1 \
  && echo "Instalada y abierta." \
  || echo "Instalada. No se ha podido abrir: el iPhone está bloqueado."
