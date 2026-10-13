#!/usr/bin/env bash
#
# Verificación completa del proyecto de la Semana 11.
#
#   ./scripts/verificar.sh
#
# El script reproduce exactamente lo que ejecuta el pipeline de GitHub Actions
# definido en ../.github/workflows/flutter-semana11.yml, para que el estudiante
# pueda comprobarlo antes de hacer commit.
#
# Novedad de la Semana 11: el paso 5 ejecuta, además de toda la batería de
# pruebas, la prueba forense que demuestra con bytes reales que el token
# guardado en la tabla `preferencias` queda expuesto en el archivo SQLite
# mientras que el guardado en el almacén seguro no aparece.

set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> 1/5  Versiones"
flutter --version

echo "==> 2/5  Dependencias"
flutter pub get

echo "==> 3/5  Código generado por drift"
# No hay tablas nuevas en la Semana 11: el token NO se guarda en SQLite.
# Este paso debe dejar lib/data/local/manos_seguras_db.g.dart sin cambios.
dart run build_runner build

echo "==> 4/5  Análisis estático"
flutter analyze --fatal-infos

echo "==> 5/5  Pruebas (incluye la evidencia forense del Reto 5)"
flutter test --reporter expanded

echo
echo "Verificación completada sin errores."
echo "Evidencia forense generada por: test/data/sesion_insegura_test.dart"
