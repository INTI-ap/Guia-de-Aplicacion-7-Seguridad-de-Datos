import 'package:flutter/foundation.dart';

import '../data/repositorios/sesion_repository_seguro.dart';
import '../domain/entidades/sesion.dart';
import '../domain/repositorios/sesion_repository.dart';
import '../domain/servicios/generador_token.dart';
import 'fallos.dart';

/// **Estado de la sesión a nivel de aplicación** (Semana 11).
///
/// Cumple el mismo papel que `TemaApp` (Semana 10): es un `ValueNotifier`
/// que la capa de presentación observa con `ValueListenableBuilder`. Cuando
/// la sesión cambia —se inicia, se restaura o se cierra— todas las pantallas
/// que lo escuchan se reconstruyen solas, sin `setState` repartido por todo
/// el proyecto.
///
/// ## El ciclo de vida completo
///
/// ```
///  iniciarSesion()   credenciales → token simulado → guardar (Keystore/Keychain)
///        │
///  restaurar()       lee del almacén seguro; si el token expiró, cierra sesión
///        │
///  cerrarSesion()    elimina la clave del almacén seguro
/// ```
///
/// Decisiones de diseño que el informe debe justificar:
///
///  1. **El token no se expone.** [descripcionToken] devuelve solo la huella y
///     el tiempo restante. Ni la interfaz ni los registros de depuración
///     (`debugPrint`, MASWE-0005) ven nunca el valor completo.
///  2. **La sesión no vive en memoria más de lo necesario.** Al cerrar
///     sesión se borra el almacén **y** se pone `value = null`, para que
///     ninguna pantalla conserve una referencia utilizable.
///  3. **Fallo explícito.** Si el almacén del sistema falla, se propaga
///     [FalloSeguridad]; no se degrada en silencio a "guardar en texto plano".
///     Un respaldo inseguro silencioso sería peor que un error visible.
class GestorSesion extends ValueNotifier<Sesion?> {
  GestorSesion({
    required SesionRepository repositorio,
    GeneradorTokenSimulado? generador,
    DirectorioUsuariosSimulado? directorio,
  })  : _repositorio = repositorio,
        _generador = generador ?? GeneradorTokenSimulado(),
        _directorio = directorio ?? DirectorioUsuariosSimulado(),
        super(null);

  final SesionRepository _repositorio;
  final GeneradorTokenSimulado _generador;
  final DirectorioUsuariosSimulado _directorio;

  /// `true` si hay una sesión con token vigente en memoria.
  bool get haySesionActiva => value != null && value!.activaEn(DateTime.now());

  /// Nombre del mecanismo que protege el token en esta plataforma.
  String get mecanismoDeProteccion {
    final SesionRepository repositorio = _repositorio;
    return repositorio is SesionRepositorySeguro
        ? repositorio.mecanismoDeProteccion
        : 'Almacén sin cifrado (implementación de laboratorio)';
  }

  /// **Restaura la sesión** al arrancar la aplicación.
  ///
  /// Se llama una sola vez, desde `main()`. Si el almacén no responde, la
  /// aplicación **no** debe impedir el arranque: se registra el problema y se
  /// continúa sin sesión (mismo criterio que `TemaApp.cargarDesdeDisco`). Si
  /// lo que falla es el contenido guardado (formato desconocido), tampoco se
  /// rompe: se limpia el almacén y se pide autenticarse otra vez.
  Future<void> restaurar() async {
    try {
      final Sesion? guardada = await _repositorio.leer();
      if (guardada == null) {
        value = null;
        return;
      }
      if (!guardada.activaEn(DateTime.now())) {
        // Token vencido: cerrar es la única respuesta correcta.
        await _repositorio.cerrar();
        value = null;
        return;
      }
      value = guardada;
    } on FalloDeValidacion catch (error) {
      debugPrint('La sesión guardada no es legible, se descarta: '
          '${error.mensaje}');
      await _repositorio.cerrar();
      value = null;
    } on FalloSeguridad catch (error) {
      debugPrint('El almacén seguro no está disponible: ${error.mensaje}');
      value = null;
    }
  }

  /// **Inicia sesión**: verifica credenciales, emite un token simulado y lo
  /// guarda en el almacén seguro.
  ///
  /// Devuelve la sesión creada. Lanza [FalloDeAutenticacion] si las
  /// credenciales no coinciden y [FalloSeguridad] si el guardado falla.
  /// En este último caso la sesión **no** queda activa en memoria: es
  /// preferible pedir de nuevo el inicio de sesión que dejar al usuario
  /// trabajando con una sesión que no sobrevivirá al cierre de la aplicación.
  Future<Sesion> iniciarSesion({
    required String documento,
    required String clave,
    DateTime? ahora,
  }) async {
    final UsuarioSimulado? usuario = _directorio.autenticar(
      documento: documento,
      clave: clave,
    );
    if (usuario == null) {
      throw const FalloDeAutenticacion();
    }

    final Sesion nueva = Sesion(
      documento: usuario.documento,
      nombre: usuario.nombre,
      rol: usuario.rol,
      token: _generador.emitir(ahora: ahora),
    );

    await _repositorio.guardar(nueva);
    value = nueva;
    return nueva;
  }

  /// **Cierra sesión** de forma completa: borra el dato del almacén seguro y
  /// la referencia en memoria.
  Future<void> cerrarSesion() async {
    await _repositorio.cerrar();
    value = null;
  }

  /// Texto listo para la interfaz con la información **no sensible** de la
  /// sesión: huella del token y tiempo restante.
  String? get descripcionToken {
    final Sesion? sesion = value;
    if (sesion == null) return null;
    final Duration restante = sesion.token.restanteEn(DateTime.now());
    final String horas = restante.inHours.toString().padLeft(2, '0');
    final String minutos = (restante.inMinutes % 60).toString().padLeft(2, '0');
    return 'huella ${sesion.token.huella} · expira en ${horas}h ${minutos}m';
  }

  /// `true` si el token sigue siendo válido pero está por expirar.
  bool get porExpirar {
    final Sesion? sesion = value;
    return sesion != null && sesion.token.porExpirarEn(DateTime.now());
  }
}
