import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/fallos.dart';
import '../../core/gestor_sesion.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entidades/sesion.dart';
import '../../domain/servicios/generador_token.dart';
import '../di.dart';
import '../widgets/app_layout.dart';
import '../widgets/estados_vista.dart';

/// **Pantalla de inicio de sesión y estado del token** (Semana 11).
///
/// Actividad de aprendizaje del sílabo: *"Implementan el guardado seguro de
/// un token simulado"*. La pantalla hace visible todo el ciclo de vida:
///
///  1. se escriben las credenciales de un usuario del directorio simulado;
///  2. `GestorSesion` emite un token y lo entrega al repositorio;
///  3. el repositorio lo guarda en el almacén del sistema operativo
///     (Keystore, Keychain, libsecret…);
///  4. la tarjeta de estado muestra **solo la huella** del token, nunca su
///     valor;
///  5. al cerrar la aplicación y volver a abrirla, la sesión se restaura sin
///     volver a pedir credenciales (hasta que el token expire).
///
/// La pantalla es la evidencia visual que el informe debe capturar: la
/// tarjeta superior con la huella, el rol, el tiempo restante y el nombre
/// del mecanismo de protección de la plataforma.
class PantallaSesion extends StatefulWidget {
  const PantallaSesion({super.key});

  @override
  State<PantallaSesion> createState() => _PantallaSesionState();
}

class _PantallaSesionState extends State<PantallaSesion> {
  final GlobalKey<FormState> _formulario = GlobalKey<FormState>();
  final TextEditingController _documento = TextEditingController();
  final TextEditingController _clave = TextEditingController();
  bool _procesando = false;

  @override
  void dispose() {
    _documento.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (!(_formulario.currentState?.validate() ?? false)) return;

    setState(() => _procesando = true);
    final GestorSesion gestor = getIt<GestorSesion>();
    try {
      final Sesion sesion = await gestor.iniciarSesion(
        documento: _documento.text,
        clave: _clave.text,
      );
      if (!mounted) return;
      _clave.clear();
      _avisar('Sesión iniciada para ${sesion.nombre}.');
    } on Fallo catch (fallo) {
      if (!mounted) return;
      _avisar(fallo.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _cerrarSesion() async {
    setState(() => _procesando = true);
    final GestorSesion gestor = getIt<GestorSesion>();
    try {
      await gestor.cerrarSesion();
      if (!mounted) return;
      _avisar('Sesión cerrada y token eliminado del almacén seguro.');
    } on Fallo catch (fallo) {
      if (!mounted) return;
      _avisar(fallo.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  void _avisar(String mensaje, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: error ? AppColors.alerta : AppColors.exito,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final GestorSesion gestor = getIt<GestorSesion>();

    return Scaffold(
      appBar: AppBar(title: const Text('Sesión y token seguro')),
      body: SingleChildScrollView(
        child: AppLayout(
          child: ValueListenableBuilder<Sesion?>(
            valueListenable: gestor,
            builder: (BuildContext context, Sesion? sesion, Widget? _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const TituloSeccion(
                    'Estado de la sesión',
                    icono: Icons.verified_user_outlined,
                  ),
                  _TarjetaEstado(
                    sesion: sesion,
                    mecanismo: gestor.mecanismoDeProteccion,
                    descripcionToken: gestor.descripcionToken,
                    porExpirar: gestor.porExpirar,
                  ),
                  if (sesion == null) ...<Widget>[
                    const SizedBox(height: 8),
                    const TituloSeccion(
                      'Iniciar sesión',
                      icono: Icons.login,
                    ),
                    _formularioInicio(),
                  ] else ...<Widget>[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _procesando ? null : _cerrarSesion,
                        icon: const Icon(Icons.logout),
                        label: const Text('Cerrar sesión y borrar el token'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => context.go('/boveda'),
                        icon: const Icon(Icons.science_outlined),
                        label: const Text(
                          'Ver bóveda y evidencia forense (Reto 5)',
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('Volver al inicio'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const TituloSeccion(
                    'Directorio simulado del laboratorio',
                    icono: Icons.badge_outlined,
                  ),
                  _TarjetaUsuarios(
                    usuarios: getIt<DirectorioUsuariosSimulado>().usuarios,
                    alElegir: (UsuarioSimulado usuario) {
                      setState(() => _documento.text = usuario.documento);
                    },
                  ),
                  const SizedBox(height: 8),
                  const _NotaSeguridad(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _formularioInicio() {
    return TarjetaBase(
      child: Form(
        key: _formulario,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: _documento,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Documento (DNI)',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (String? valor) {
                final String texto = (valor ?? '').trim();
                if (texto.isEmpty) return 'Escriba el número de documento.';
                if (texto.length < 8) {
                  return 'El documento debe tener al menos 8 dígitos.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clave,
              obscureText: true,
              // Evita que el teclado "aprenda" la clave y la ofrezca como
              // sugerencia en el teclado del dispositivo.
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Clave',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (String? valor) => (valor ?? '').isEmpty
                  ? 'Escriba la clave del directorio simulado.'
                  : null,
              onFieldSubmitted: (_) => _iniciarSesion(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _procesando ? null : _iniciarSesion,
                icon: _procesando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.key_outlined),
                label: Text(
                  _procesando ? 'Guardando en el almacén seguro…' : 'Iniciar sesión',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta con el estado de la sesión y los datos **no sensibles** del token.
class _TarjetaEstado extends StatelessWidget {
  const _TarjetaEstado({
    required this.sesion,
    required this.mecanismo,
    required this.descripcionToken,
    required this.porExpirar,
  });

  final Sesion? sesion;
  final String mecanismo;
  final String? descripcionToken;
  final bool porExpirar;

  @override
  Widget build(BuildContext context) {
    final Sesion? actual = sesion;

    return TarjetaBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                actual == null ? Icons.lock_open : Icons.lock,
                color: actual == null ? AppColors.textSecondary : AppColors.navy,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  actual == null ? 'Sin sesión iniciada' : 'Sesión activa',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.navy,
                  ),
                ),
              ),
              if (actual != null)
                InsigniaOrigen(
                  etiqueta: porExpirar ? 'Por expirar' : 'Token vigente',
                  esRemoto: !porExpirar,
                  icono: porExpirar ? Icons.timer_outlined : Icons.check_circle,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (actual == null)
            const Text(
              'No hay ningún token guardado en el almacén del sistema. '
              'Inicie sesión para generarlo.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            )
          else ...<Widget>[
            _Dato('Usuario', actual.nombre),
            _Dato('Documento', actual.documentoEnmascarado),
            _Dato('Rol', actual.rol.etiqueta),
            _Dato('Token', descripcionToken ?? '—'),
            _Dato('Protección', mecanismo),
          ],
        ],
      ),
    );
  }
}

/// Tarjeta con los usuarios del directorio simulado (solo laboratorio).
class _TarjetaUsuarios extends StatelessWidget {
  const _TarjetaUsuarios({required this.usuarios, required this.alElegir});

  final List<UsuarioSimulado> usuarios;
  final ValueChanged<UsuarioSimulado> alElegir;

  @override
  Widget build(BuildContext context) {
    return TarjetaBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Usuarios de práctica (el docente los entrega en clase). '
            'Pulse uno para rellenar el documento:',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ...usuarios.map(
            (UsuarioSimulado usuario) => InkWell(
              onTap: () => alElegir(usuario),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.person_pin_circle_outlined,
                        size: 18, color: AppColors.navy),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${usuario.documento} · ${usuario.nombre}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      usuario.rol.etiqueta,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Recordatorio de las reglas de manejo del token.
class _NotaSeguridad extends StatelessWidget {
  const _NotaSeguridad();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.aviso.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.aviso.withValues(alpha: 0.35)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.gpp_maybe_outlined, color: AppColors.aviso, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Regla del proyecto: el valor del token nunca se imprime en '
              'pantalla, ni en registros de depuración, ni en el informe. '
              'Solo se publica su huella (8 dígitos hexadecimales) y su '
              'fecha de expiración.',
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila `etiqueta: valor` reutilizada por las tarjetas de esta pantalla.
class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              etiqueta,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
