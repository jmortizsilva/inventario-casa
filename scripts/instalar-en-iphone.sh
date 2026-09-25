#!/bin/zsh
# Compila la app, la instala en el iPhone emparejado (por cable o por Wi‑Fi) y
# la abre. Hay que lanzarlo desde Terminal, no desde una sesión en segundo
# plano: codesign necesita el llavero, y solo se desbloquea en la sesión
# gráfica.
set -e

cd "$(dirname "$0")/.."
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
xcrun devicectl device process launch --device "$dispositivo" com.jmortiz.inventario
