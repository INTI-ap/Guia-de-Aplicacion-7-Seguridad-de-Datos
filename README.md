# ManosSeguras — Semana 11: Seguridad de Datos en Reposo

Proyecto Flutter del **proyecto integrador** de **SIS048 – Desarrollo de Software II**
(Universidad Andina del Cusco, semestre 2026-II), correspondiente a la
**Unidad de Aprendizaje II: Arquitectura Limpia, Persistencia y Gestión de
Estado Avanzada**.

Esta entrega implementa la **Guía de Aplicación N.° 07 · Parte II**
(Semana 11) y continúa exactamente donde terminó la Semana 10:

| Temática del sílabo | Qué se implementa aquí |
|---|---|
| 2.2.4. Almacenamiento seguro (`flutter_secure_storage`) | `lib/data/seguro/` — puerto `AlmacenSeguro` + adaptador del plugin + doble de prueba. |
| 2.2.5. Guardado seguro de tokens de sesión | `GestorSesion`, `SesionRepository` y la pantalla `/sesion` con ciclo de vida completo del token. |
| Repaso 2.2.1–2.2.3 (Semana 10) | La tabla `preferencias` sigue existiendo: ahora se usa para **demostrar** por qué un dato sensible no debe ir allí. |
| Repaso 2.1.2–2.1.3 (Semana 8) | El dominio no importa `flutter_secure_storage`: se respeta la inversión de dependencias. |
| Repaso 2.1.5–2.1.7 (Semana 9) | El almacén y el repositorio se registran **contra sus interfaces** en `presentation/di.dart`. |

**Actividad de aprendizaje del sílabo:** *"Implementan el guardado seguro de
un token simulado"* — se cumple con un token emitido por el dispositivo
(`GeneradorTokenSimulado`), porque el backend real de autenticación llega en
la Unidad III (Firebase Auth, Semana 16).

---

## Los 5 retos de la Semana 11

Cada reto tiene su punto de partida en el código, marcado con
`TODO(reto-n)` y con el detalle en la guía de aplicación.

| Reto | Tema | Archivos de partida |
|---|---|---|
| 1 | Entidad de sesión, token y expiración | `domain/entidades/sesion.dart`, `test/domain/sesion_test.dart` |
| 2 | Almacén seguro: puerto, adaptador y dobles | `data/seguro/almacen_seguro*.dart` |
| 3 | Ciclo de vida de la sesión (iniciar, restaurar, cerrar) | `core/gestor_sesion.dart`, `presentation/di.dart` |
| 4 | Endurecimiento por plataforma (Keystore, Keychain, backup, registros) | `data/seguro/almacen_seguro_sistema.dart`, `docs/android/AndroidManifest.parche.xml` |
| 5 | Evidencia forense: texto plano en SQLite vs almacén seguro | `data/local/inspeccion_forense.dart`, `presentation/pantallas/pantalla_boveda.dart`, `test/data/sesion_insegura_test.dart` |

---

## Cómo ejecutarlo

```bash
flutter --version                   # verificado con Flutter 3.41.1 / Dart 3.11.0
flutter create .                    # genera las carpetas android/, ios/, web/…
flutter pub get
dart run build_runner build         # solo si modifica tablas o la schemaVersion
flutter run
```

> **Esta entrega no modifica el esquema de la base de datos.** No hay tablas
> nuevas ni cambios de `schemaVersion`: precisamente porque el token **no**
> se guarda en SQLite. Si su equipo ejecuta `build_runner`, el archivo
> `lib/data/local/manos_seguras_db.g.dart` debe quedar idéntico.

Para la demostración sin depender del llavero del equipo:

```bash
flutter run --dart-define=ALMACEN_EN_MEMORIA=true
```

### Requisitos de plataforma (verificados en la documentación del paquete)

| Plataforma | Requisito mínimo | Respaldo del secreto |
|---|---|---|
| Android | `minSdkVersion 24` | Android Keystore + AES-GCM con clave envuelta en RSA-OAEP |
| iOS | 13.0 | Keychain (`kSecAttrAccessible`) |
| macOS | 10.14 | Keychain (requiere *Keychain Sharing* en los entitlements) |
| Linux | `libsecret` de desarrollo y de ejecución + D-Bus | Secret Service (GNOME Keyring / KWallet) |
| Windows | C++ ATL de Visual Studio Build Tools | Almacén cifrado del plugin |
| Web | HTTPS o `localhost` | WebCrypto sobre `localStorage` (experimental) |

Además, en Android hay que **desactivar la copia de seguridad automática**;
el propio plugin advierte que, si no se hace, el descifrado falla con
`java.security.InvalidKeyException: Failed to unwrap key` al restaurar en un
dispositivo nuevo. El parche está en `docs/android/AndroidManifest.parche.xml`.

---

## Cómo verificarlo

```bash
flutter analyze --fatal-infos     # sin hallazgos
flutter test --reporter expanded  # dominio, datos, seguridad y widget
./scripts/verificar.sh            # las dos anteriores, en orden
```

Las pruebas **no necesitan Internet, ni emulador, ni llavero**: el almacén
seguro se sustituye por `AlmacenSeguroEnMemoria` y la base usa SQLite en
memoria (o un archivo temporal, en la prueba forense).

La prueba `test/data/sesion_insegura_test.dart` es la más importante de la
entrega: demuestra con bytes reales que el token guardado en la tabla
`preferencias` aparece en claro dentro de `manos_seguras.sqlite`, mientras
que el token guardado en el almacén seguro no aparece.

---

## Estructura del proyecto

```
lib/
├── main.dart                        Arranque: DI + tema + restauración de la sesión
├── router/app_router.dart           Rutas, incluidas /sesion y /boveda
├── core/
│   ├── fallos.dart                  + FalloSeguridad y FalloDeAutenticacion
│   ├── gestor_sesion.dart           ← NUEVO (S11): estado de la sesión
│   ├── tema_app.dart                Preferencia de tema persistida en SQLite
│   └── theme/app_theme.dart         Tema institucional claro/oscuro
├── domain/
│   ├── entidades/sesion.dart        ← NUEVO (S11): Sesion, TokenSesion, RolUsuario
│   ├── repositorios/
│   │   ├── sesion_repository.dart   ← NUEVO (S11): contrato del repositorio
│   │   ├── auditoria_repository.dart
│   │   └── indicador_repository.dart
│   ├── servicios/
│   │   ├── generador_token.dart     ← NUEVO (S11): tokens y usuarios simulados
│   │   └── calculadora_adherencia.dart
│   └── entidades/…                  (sin cambios respecto de la Semana 10)
├── data/
│   ├── seguro/                      ← NUEVO (S11)
│   │   ├── almacen_seguro.dart              puerto (interfaz)
│   │   ├── almacen_seguro_sistema.dart      adaptador de flutter_secure_storage
│   │   └── almacen_seguro_en_memoria.dart   doble de prueba
│   ├── local/
│   │   ├── inspeccion_forense.dart  ← NUEVO (S11): búsqueda en bytes del .sqlite
│   │   ├── tablas/ daos/ …          (sin cambios respecto de la Semana 10)
│   ├── repositorios/
│   │   ├── sesion_repository_seguro.dart     ← NUEVO (S11)
│   │   ├── sesion_repository_inseguro.dart   ← NUEVO (S11, ANTIPATRÓN de laboratorio)
│   │   └── …                        (sin cambios respecto de la Semana 10)
└── presentation/
    ├── di.dart                      Grafo get_it: + AlmacenSeguro, SesionRepository…
    ├── pantallas/
    │   ├── pantalla_sesion.dart     ← NUEVO (S11): inicio de sesión y estado
    │   ├── pantalla_boveda.dart     ← NUEVO (S11): evidencia forense
    │   └── …                        (sin cambios respecto de la Semana 10)
    └── widgets/                     AppLayout, TarjetaBase, estados
docs/
└── android/AndroidManifest.parche.xml   Parche de backup para Android (Reto 4)
```

---

## Qué dato va a cada almacén (y por qué)

| Dato | Almacén | Justificación |
|---|---|---|
| Token de sesión | **Almacén seguro** | Permite actuar en nombre del usuario; un robo equivale a suplantación. |
| Documento y nombre del observador | **Almacén seguro** | Son datos personales (PII); no deben vincularse a las auditorías desde una copia del `.sqlite`. |
| Preferencia de tema | SQLite (`preferencias`) | No es sensible y se consulta en cada arranque. |
| Auditorías y oportunidades | SQLite | Datos operativos del instrumento MINSA; su confidencialidad se apoya en el cifrado del dispositivo. |
| Credenciales (clave) | **En ningún lado** | Se verifican contra el servidor; la aplicación nunca las almacena. |

---

## La regla de oro del token

1. El valor del token **nunca** se imprime en pantalla (solo su huella de 8
   dígitos hexadecimales y su expiración).
2. El valor del token **nunca** se escribe con `print` ni `debugPrint`
   (debilidad MASWE-0005 de OWASP).
3. El valor del token **no** aparece en el informe técnico: si una captura lo
   muestra, debe censurarse.
4. La única excepción es la pantalla `/boveda`, que lo enseña **censurado por
   omisión** y solo con tokens simulados de laboratorio.

---

## Entrega

1. **Repositorio en GitHub** con este proyecto y `README.md` completo.
2. **Informe técnico** según la estructura entregada por el docente
   (`../guia/Semana11_Estructura_Informe_Tecnico.docx`), incluyendo la matriz
   de datos sensibles, los controles aplicados y las evidencias.
3. **Capturas o video** que evidencien: la pantalla `/sesion` con la sesión
   activa (token censurado), el cierre de sesión, y el resultado del
   experimento forense de `/boveda`.
4. **Salida de `flutter test`** con la prueba forense incluida.

## Nota sobre el uso de IA generativa

Se permite y recomienda usar asistentes de código para comprender errores y
explorar alternativas. En la revisión se pedirá modificar en vivo un fragmento
del código entregado: **código que el estudiante no puede explicar se califica
como no presentado**.

## Referencias principales

- Android Developers. (2025, 30 de julio). *Security* [Notas de la versión de
  Jetpack]. https://developer.android.com/jetpack/androidx/releases/security
- Apple Inc. (2026). *Restricting keychain item accessibility*. Apple
  Developer Documentation.
  https://developer.apple.com/documentation/security/restricting-keychain-item-accessibility
- Lodderstedt, T., Bradley, J., Labunets, A., & Fett, D. (2025). *Best current
  practice for OAuth 2.0 security* (RFC 9700, BCP 240). Internet Engineering
  Task Force. https://doi.org/10.17487/RFC9700
- OWASP Foundation. (s. f.). *MASVS-STORAGE-1: The app securely stores
  sensitive data*. OWASP Mobile Application Security.
  https://mas.owasp.org/MASVS/controls/MASVS-STORAGE-1/
- Steenbakker, J. (2026). *flutter_secure_storage* (Versión 11.2.0) [Paquete de
  Flutter]. pub.dev. https://pub.dev/packages/flutter_secure_storage
