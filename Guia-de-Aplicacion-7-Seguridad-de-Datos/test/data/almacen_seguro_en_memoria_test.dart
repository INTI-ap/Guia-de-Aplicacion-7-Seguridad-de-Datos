import 'package:flutter_test/flutter_test.dart';
import 'package:manos_seguras/core/fallos.dart';
import 'package:manos_seguras/data/seguro/almacen_seguro_en_memoria.dart';

void main() {
  test(
    'sobrescribe, cuenta escrituras y conserva aislamiento del mapa inicial',
    () async {
      final inicial = {'sesion.activa': 'a'};
      final almacen = AlmacenSeguroEnMemoria(datosIniciales: inicial);
      inicial['sesion.activa'] = 'externo';
      expect(await almacen.leer('sesion.activa'), 'a');
      await almacen.escribir('sesion.activa', 'b');
      await almacen.escribir('sesion.activa', 'c');
      expect(almacen.escriturasRealizadas, 2);
      expect(await almacen.claves(), {'sesion.activa'});
      expect(await almacen.leer('sesion.activa'), 'c');
      await almacen.eliminar('sesion.activa');
      expect(await almacen.contiene('sesion.activa'), isFalse);
    },
  );
  test('claves no permiten modificar el almacén y limpiar lo vacía', () async {
    final almacen = AlmacenSeguroEnMemoria(datosIniciales: {'a': 'secreto'});
    final claves = await almacen.claves();
    expect(() => claves.add('b'), throwsUnsupportedError);
    await almacen.limpiar();
    expect(await almacen.claves(), isEmpty);
  });
  test('el doble de fallo rechaza todas las operaciones', () async {
    final almacen = AlmacenSeguroEnMemoria.queFalla('bloqueado');
    for (final operacion in <Future<Object?> Function()>[
      () => almacen.escribir('a', 'b'),
      () => almacen.leer('a'),
      () => almacen.contiene('a'),
      () => almacen.eliminar('a'),
      almacen.claves,
      almacen.limpiar,
    ]) {
      expect(operacion, throwsA(isA<FalloSeguridad>()));
    }
  });
}
