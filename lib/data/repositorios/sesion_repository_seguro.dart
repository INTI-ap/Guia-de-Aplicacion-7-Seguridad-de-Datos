import '../../domain/entidades/sesion.dart';
import '../../domain/repositorios/sesion_repository.dart';
import '../seguro/almacen_seguro.dart';

/// **Implementación segura del repositorio de sesión** (Semana 11).
///
/// Traduce el contrato del dominio a operaciones sobre cualquier
/// [AlmacenSeguro]: en la aplicación real, el adaptador de
/// `flutter_secure_storage`; en las pruebas, el almacén en memoria.
///
/// ## Qué guarda y qué no
///
/// | Dato | ¿Va al almacén seguro? | Motivo |
/// |---|---|---|
/// | Token de sesión | **Sí** | Permite actuar en nombre del usuario |
/// | Documento y nombre | **Sí** | Son datos personales (PII) |
/// | Rol | **Sí** | Viaja junto con la identidad |
/// | Preferencia de tema | No (SQLite) | No es sensible; se consulta sin cifrar |
/// | Auditorías y oportunidades | No (SQLite) | Datos operativos; su protección depende del cifrado del dispositivo |
///
/// Esa tabla, con la justificación de cada decisión, es uno de los
/// entregables del informe técnico.
class SesionRepositorySeguro implements SesionRepository {
  SesionRepositorySeguro(this._almacen);

  /// Clave única bajo la que vive la sesión.
  ///
  /// Se elige un nombre con punto (`sesion.activa`) siguiendo la convención
  /// de las preferencias de la Semana 10.
  static const String claveSesion = 'sesion.activa';

  /// Clave que usa el experimento forense de la bóveda para su token B.
  ///
  /// Es **distinta** de [claveSesion] para que el experimento no pise la
  /// sesión activa ni deje al [GestorSesion] con un estado desactualizado.
  static const String claveExperimento = 'experimento.token_b';

  final AlmacenSeguro _almacen;

  @override
  Future<void> guardar(Sesion sesion) {
    return _almacen.escribir(claveSesion, sesion.serializar());
  }

  @override
  Future<Sesion?> leer() async {
    final String? crudo = await _almacen.leer(claveSesion);
    if (crudo == null || crudo.isEmpty) return null;
    return Sesion.desdeAlmacen(crudo);
  }

  @override
  Future<bool> haySesionActiva() async {
    final Sesion? sesion = await leer();
    if (sesion == null) return false;

    // Una sesión expirada no se conserva: si el token ya no sirve, el
    // almacén se limpia en el mismo instante en que se detecta. Dejar un
    // token vencido guardado es basura que además amplía la superficie de
    // ataque (MASWE-0024: datos accesibles después del cierre de sesión).
    if (!sesion.activaEn(DateTime.now())) {
      await cerrar();
      return false;
    }
    return true;
  }

  @override
  Future<void> cerrar() => _almacen.eliminar(claveSesion);

  /// Guarda el token del experimento forense bajo [claveExperimento].
  ///
  /// El experimento de la bóveda necesita escribir en el almacén seguro para
  /// demostrar que su token **no** aparece en el archivo SQLite. Si usara
  /// [claveSesion], estaría sobrescribiendo la sesión activa y dejaría al
  /// [GestorSesion] con un estado desactualizado.
  Future<void> guardarExperimento(Sesion sesion) {
    return _almacen.escribir(claveExperimento, sesion.serializar());
  }

  /// Limpia la clave del experimento forense sin tocar la sesión activa.
  Future<void> cerrarExperimento() => _almacen.eliminar(claveExperimento);

  /// Descripción del mecanismo de protección, para la pantalla de
  /// diagnóstico. Delega en el almacén para no duplicar la lógica de
  /// plataformas.
  String get mecanismoDeProteccion => _almacen.mecanismo;
}
