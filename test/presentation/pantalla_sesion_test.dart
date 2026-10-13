import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manos_seguras/core/gestor_sesion.dart';
import 'package:manos_seguras/data/repositorios/sesion_repository_seguro.dart';
import 'package:manos_seguras/data/seguro/almacen_seguro.dart';
import 'package:manos_seguras/data/seguro/almacen_seguro_en_memoria.dart';
import 'package:manos_seguras/domain/entidades/sesion.dart';
import 'package:manos_seguras/domain/repositorios/sesion_repository.dart';
import 'package:manos_seguras/domain/servicios/generador_token.dart';
import 'package:manos_seguras/presentation/di.dart';
import 'package:manos_seguras/presentation/pantallas/pantalla_sesion.dart';

void main() {
  late AlmacenSeguroEnMemoria almacen;

  setUp(() {
    almacen = AlmacenSeguroEnMemoria();
    getIt
      ..registerSingleton<AlmacenSeguro>(almacen)
      ..registerSingleton<SesionRepository>(
        SesionRepositorySeguro(almacen),
      )
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
  });

  tearDown(() async {
    if (getIt.isRegistered<GestorSesion>()) {
      getIt<GestorSesion>().detenerVigilanciaExpiracion();
    }
    await getIt.reset();
  });

  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: PantallaSesion()));
    await tester.pumpAndSettle();
  }

  testWidgets('sin sesión, la pantalla invita a iniciarla',
      (WidgetTester tester) async {
    await abrir(tester);

    expect(find.text('Sin sesión iniciada'), findsOneWidget);
    expect(find.text('Sesión activa'), findsNothing);
    expect(find.textContaining('almacén del sistema'), findsOneWidget);
  });

  testWidgets('con credenciales correctas la sesión queda activa',
      (WidgetTester tester) async {
    await abrir(tester);
    await tester.enterText(find.byType(TextFormField).first, '40123456');
    await tester.enterText(find.byType(TextFormField).last, 'higiene2026');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Sesión activa'), findsOneWidget);
    expect(find.text('Rosa Quispe Huamán'), findsOneWidget);
    expect(find.text('****3456'), findsOneWidget);
    expect(find.textContaining('Token vigente'), findsOneWidget);
    expect(find.textContaining('expira en'), findsOneWidget);

    getIt<GestorSesion>().detenerVigilanciaExpiracion();
  });

  testWidgets('con credenciales incorrectas no se crea ninguna sesión',
      (WidgetTester tester) async {
    await abrir(tester);
    await tester.enterText(find.byType(TextFormField).first, '40123456');
    await tester.enterText(find.byType(TextFormField).last, 'clave-equivocada');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Sin sesión iniciada'), findsOneWidget);
    expect(find.text('Documento o clave incorrectos.'), findsOneWidget);
    expect(await almacen.claves(), isEmpty);
  });

  testWidgets('el valor del token NO se muestra en la pantalla',
      (WidgetTester tester) async {
    await abrir(tester);
    await tester.enterText(find.byType(TextFormField).first, '40123456');
    await tester.enterText(find.byType(TextFormField).last, 'higiene2026');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar sesión'));
    await tester.pumpAndSettle();

    final Sesion? sesion = await getIt<SesionRepository>().leer();
    expect(sesion, isNotNull);

    expect(find.textContaining(sesion!.token.valor), findsNothing);
    expect(find.text(sesion.token.valor), findsNothing);
    expect(find.textContaining(sesion.token.huella), findsOneWidget);

    getIt<GestorSesion>().detenerVigilanciaExpiracion();
  });

  testWidgets('cerrar sesión vacía el almacén seguro',
      (WidgetTester tester) async {
    await abrir(tester);
    await tester.enterText(find.byType(TextFormField).first, '40123456');
    await tester.enterText(find.byType(TextFormField).last, 'higiene2026');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar sesión'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Cerrar sesión y borrar el token'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sin sesión iniciada'), findsOneWidget);
    expect(await almacen.claves(), isEmpty);
    expect(await getIt<SesionRepository>().leer(), isNull);
  });

  testWidgets('la sesión se restaura al volver a abrir la aplicación',
      (WidgetTester tester) async {
    await abrir(tester);
    await tester.enterText(find.byType(TextFormField).first, '40123456');
    await tester.enterText(find.byType(TextFormField).last, 'higiene2026');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Sesión activa'), findsOneWidget);

    final GestorSesion gestorNuevo = GestorSesion(
      repositorio: getIt<SesionRepository>(),
      generador: getIt<GeneradorTokenSimulado>(),
      directorio: getIt<DirectorioUsuariosSimulado>(),
    );

    await gestorNuevo.restaurar();

    expect(gestorNuevo.value, isNotNull);
    expect(gestorNuevo.value!.nombre, 'Rosa Quispe Huamán');
    expect(gestorNuevo.value!.documento, '40123456');

    gestorNuevo.dispose();
    getIt<GestorSesion>().detenerVigilanciaExpiracion();
  });
}
