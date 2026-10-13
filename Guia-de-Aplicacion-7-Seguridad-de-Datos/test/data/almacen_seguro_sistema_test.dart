import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manos_seguras/core/fallos.dart';
import 'package:manos_seguras/data/seguro/almacen_seguro_sistema.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const canal = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final mensajero =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late AlmacenSeguroSistema almacen;
  late Map<String, String> datos;
  late List<MethodCall> llamadas;

  setUp(() {
    almacen = AlmacenSeguroSistema();
    datos = {};
    llamadas = [];
    mensajero.setMockMethodCallHandler(canal, (llamada) async {
      llamadas.add(llamada);
      final argumentos = Map<String, dynamic>.from(llamada.arguments as Map);
      final clave = argumentos['key'] as String?;
      switch (llamada.method) {
        case 'write':
          datos[clave!] = argumentos['value'] as String;
          return null;
        case 'read':
          return datos[clave];
        case 'containsKey':
          return datos.containsKey(clave);
        case 'delete':
          datos.remove(clave);
          return null;
        case 'readAll':
          return Map<String, String>.from(datos);
        case 'deleteAll':
          datos.clear();
          return null;
        default:
          throw MissingPluginException();
      }
    });
  });
  tearDown(() => mensajero.setMockMethodCallHandler(canal, null));

  test(
    'escribe, lee, enumera y elimina sin exponer valores en claves',
    () async {
      await almacen.escribir('sesion.activa', 'secreto_de_prueba');
      expect(await almacen.leer('sesion.activa'), 'secreto_de_prueba');
      expect(await almacen.contiene('sesion.activa'), isTrue);
      expect(await almacen.claves(), {'sesion.activa'});
      await almacen.eliminar('sesion.activa');
      expect(await almacen.leer('sesion.activa'), isNull);
      await almacen.escribir('laboratorio', 'otro');
      await almacen.limpiar();
      expect(await almacen.claves(), isEmpty);
    },
  );

  test('envía opciones Android endurecidas en cada operación', () async {
    await almacen.escribir('sesion.activa', 'secreto');
    final argumentos = Map<String, dynamic>.from(
      llamadas.single.arguments as Map,
    );
    final opciones = Map<String, dynamic>.from(argumentos['options'] as Map);
    expect(opciones['resetOnError'], 'false');
    expect(opciones['storageNamespace'], 'manos_seguras_sesion');
    expect(opciones['preferencesKeyPrefix'], 'manos_seguras');
  });

  final operaciones = <String, Future<Object?> Function(AlmacenSeguroSistema)>{
    'escribir': (a) => a.escribir('sesion.activa', 'secreto'),
    'leer': (a) => a.leer('sesion.activa'),
    'contiene': (a) => a.contiene('sesion.activa'),
    'eliminar': (a) => a.eliminar('sesion.activa'),
    'claves': (a) => a.claves(),
    'limpiar': (a) => a.limpiar(),
  };
  for (final entrada in operaciones.entries) {
    test(
      '${entrada.key}: traduce el error sin publicar su contenido sensible',
      () async {
        mensajero.setMockMethodCallHandler(canal, (_) async {
          throw PlatformException(
            code: 'secreto_codigo',
            message: 'token_secreto',
          );
        });
        try {
          await entrada.value(almacen);
          fail('Debió producir FalloSeguridad');
        } on FalloSeguridad catch (fallo) {
          expect(fallo.toString(), isNot(contains('token_secreto')));
          expect(fallo.toString(), isNot(contains('secreto_codigo')));
          expect(fallo.causa, isA<PlatformException>());
        }
      },
    );
    test('${entrada.key}: plugin ausente produce FalloSeguridad', () async {
      mensajero.setMockMethodCallHandler(
        canal,
        (_) async => throw MissingPluginException(),
      );
      expect(() => entrada.value(almacen), throwsA(isA<FalloSeguridad>()));
    });
  }
}
