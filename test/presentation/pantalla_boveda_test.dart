import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manos_seguras/core/gestor_sesion.dart';
import 'package:manos_seguras/data/local/conexion.dart';
import 'package:manos_seguras/data/local/daos/preferencias_dao.dart';
import 'package:manos_seguras/data/local/manos_seguras_db.dart';
import 'package:manos_seguras/data/repositorios/sesion_repository_seguro.dart';
import 'package:manos_seguras/data/seguro/almacen_seguro.dart';
import 'package:manos_seguras/data/seguro/almacen_seguro_en_memoria.dart';
import 'package:manos_seguras/domain/repositorios/sesion_repository.dart';
import 'package:manos_seguras/domain/servicios/generador_token.dart';
import 'package:manos_seguras/presentation/di.dart';
import 'package:manos_seguras/presentation/pantallas/pantalla_boveda.dart';
import 'package:path/path.dart' as p;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AlmacenSeguroEnMemoria almacen;
  late ManosSegurasDb base;
  late Directory directorioDocumentos;
  late String rutaDeLaBase;

  setUp(() async {
    directorioDocumentos = Directory(
      p.join(
        Directory.systemTemp.path,
        'manos_seguras_boveda_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    if (directorioDocumentos.existsSync()) {
      directorioDocumentos.deleteSync(recursive: true);
    }
    directorioDocumentos.createSync(recursive: true);
    rutaDeLaBase = p.join(directorioDocumentos.path, 'manos_seguras.sqlite');
    if (File(rutaDeLaBase).existsSync()) {
      File(rutaDeLaBase).deleteSync();
    }

    almacen = AlmacenSeguroEnMemoria();
    base = abrirBaseDeDatosDeArchivo(rutaDeLaBase);
    final preferencias = DriftPreferenciasDao(base);
    getIt
      ..registerSingleton<AlmacenSeguro>(almacen)
      ..registerSingleton<SesionRepository>(
        SesionRepositorySeguro(almacen),
      )
      ..registerSingleton<PreferenciasDao>(preferencias)
      ..registerSingleton<GeneradorTokenSimulado>(GeneradorTokenSimulado())
      ..registerSingleton<DirectorioUsuariosSimulado>(
        DirectorioUsuariosSimulado(),
      )
      ..registerSingleton<GestorSesion>(
        GestorSesion(
          repositorio: getIt<SesionRepository>(),
          generador: getIt<GeneradorTokenSimulado>(),
          directorio: getIt<DirectorioUsuariosSimulado>(),
        ),
      );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall llamada) async {
        if (llamada.method == 'getApplicationDocumentsDirectory') {
          return directorioDocumentos.path;
        }
        return null;
      },
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (getIt.isRegistered<GestorSesion>()) {
      getIt<GestorSesion>().detenerVigilanciaExpiracion();
    }
    await getIt.reset();
    try {
      await base.close();
    } catch (_) {}
    if (directorioDocumentos.existsSync()) {
      try {
        directorioDocumentos.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: PantallaBoveda()));
    await tester.pumpAndSettle();
  }

  testWidgets('la bóveda muestra el mecanismo y las claves del almacén',
      (WidgetTester tester) async {
    await abrir(tester);

    expect(find.text('Bóveda y evidencia'), findsOneWidget);
    expect(find.text('Ejecutar experimento forense'), findsOneWidget);
    expect(find.text('Limpiar ambos almacenes'), findsOneWidget);
  });

  testWidgets('el experimento forense no interfiere con la sesión activa',
      (WidgetTester tester) async {
    final GestorSesion gestor = getIt<GestorSesion>();
    await gestor.iniciarSesion(
      documento: '40123456',
      clave: 'higiene2026',
    );
    expect(gestor.value, isNotNull);
    final String sesionAntes = await almacen.leer(
      SesionRepositorySeguro.claveSesion,
    ) ??
        '';

    await abrir(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Ejecutar experimento forense'));
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();

    expect(gestor.value, isNotNull);
    expect(gestor.value!.nombre, 'Rosa Quispe Huamán');
    expect(
      await almacen.leer(SesionRepositorySeguro.claveSesion),
      equals(sesionAntes),
    );
    expect(
      await almacen.claves(),
      contains(SesionRepositorySeguro.claveExperimento),
    );

    await tester.tap(find.text('Limpiar ambos almacenes'));
    await tester.pumpAndSettle();

    expect(
      await almacen.claves(),
      isNot(contains(SesionRepositorySeguro.claveExperimento)),
    );
    expect(
      await almacen.leer(SesionRepositorySeguro.claveSesion),
      equals(sesionAntes),
    );
    expect(gestor.value, isNotNull);
    expect(gestor.value!.nombre, 'Rosa Quispe Huamán');

    gestor.detenerVigilanciaExpiracion();
  });

  testWidgets('repetir el experimento no falla y limpia correctamente',
      (WidgetTester tester) async {
    await abrir(tester);

    await tester.runAsync(() async {
      await tester.tap(find.text('Ejecutar experimento forense'));
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.text('Ejecutar experimento forense'));
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();

    expect(
      await almacen.claves(),
      contains(SesionRepositorySeguro.claveExperimento),
    );
    expect(find.text('Resultados del experimento'), findsOneWidget);

    await tester.tap(find.text('Limpiar ambos almacenes'));
    await tester.pumpAndSettle();

    expect(
      await almacen.claves(),
      isNot(contains(SesionRepositorySeguro.claveExperimento)),
    );
    expect(find.text('Resultados del experimento'), findsNothing);
  });
}
