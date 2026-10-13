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

/// **Pruebas de widget de la pantalla de sesión** (Semana 11).
///
/// Comprueban dos cosas que no se pueden verificar en una prueba de dominio:
///
///  1. el flujo completo funciona desde la interfaz (escribir credenciales,
///     iniciar sesión, ver el estado, cerrar sesión);
///  2. **el valor del token nunca llega a la pantalla**, que es la regla de
///     manejo del dato sensible más fácil de romper sin darse cuenta (basta
///     con un `Text(sesion.token.valor)` "para depurar").
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
    await getIt.reset();
  });

  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: PantallaSesion()));
    await tester.pumpAndSettle();
  }

  Future<void> iniciarSesion(
    WidgetTester tester, {
    String documento = '40123456',
    String clave = 'higiene2026',
  }) async {
    await tester.enterText(find.byType(TextFormField).first, documento);
    await tester.enterText(find.byType(TextFormField).last, clave);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar sesión'));
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
    await iniciarSesion(tester);

    expect(find.text('Sesión activa'), findsOneWidget);
    expect(find.text('Rosa Quispe Huamán'), findsOneWidget);
    // El documento se muestra enmascarado.
    expect(find.text('****3456'), findsOneWidget);
    expect(find.textContaining('Token vigente'), findsOneWidget);
    // El dato del token se resume como "huella … · expira en …"; se busca el
    // sufijo para no confundirlo con el texto de la nota de seguridad.
    expect(find.textContaining('expira en'), findsOneWidget);
  });

  testWidgets('con credenciales incorrectas no se crea ninguna sesión',
      (WidgetTester tester) async {
    await abrir(tester);
    await iniciarSesion(tester, clave: 'clave-equivocada');

    expect(find.text('Sin sesión iniciada'), findsOneWidget);
    expect(find.text('Documento o clave incorrectos.'), findsOneWidget);
    expect(await almacen.claves(), isEmpty);
  });

  testWidgets('el valor del token NO se muestra en la pantalla',
      (WidgetTester tester) async {
    await abrir(tester);
    await iniciarSesion(tester);

    // La prueba conoce el token porque puede leerlo del repositorio…
    final Sesion? sesion = await getIt<SesionRepository>().leer();
    expect(sesion, isNotNull);

    // …y comprueba que en el árbol de widgets no aparece por ningún lado.
    expect(find.textContaining(sesion!.token.valor), findsNothing);
    expect(find.text(sesion.token.valor), findsNothing);
    // Solo se publica la huella.
    expect(find.textContaining(sesion.token.huella), findsOneWidget);
  });

  testWidgets('cerrar sesión vacía el almacén seguro',
      (WidgetTester tester) async {
    await abrir(tester);
    await iniciarSesion(tester);

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
    await iniciarSesion(tester);

    // Simula el reinicio: el gestor vuelve a leer el almacén seguro.
    await getIt<GestorSesion>().cerrarSesion();
    await getIt<GestorSesion>().restaurar();
    await tester.pumpAndSettle();

    // Al cerrar sesión el token se borró, así que no hay nada que restaurar…
    expect(find.text('Sin sesión iniciada'), findsOneWidget);

    // …y si se vuelve a iniciar, el gestor recupera la sesión del almacén.
    await iniciarSesion(tester);
    final Sesion? enAlmacen = await getIt<SesionRepository>().leer();
    await getIt<GestorSesion>().restaurar();
    await tester.pumpAndSettle();

    expect(enAlmacen, isNotNull);
    expect(find.text('Sesión activa'), findsOneWidget);
  });
}
