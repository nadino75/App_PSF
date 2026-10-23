# Vitrina Local

Aplicación Flutter para Android y vista web local. Incluye exploración pública, cuentas, solicitudes de negocios, cambios moderados, anuncios, boletines, favoritos, notificaciones y administración. La implementación parte del plan suministrado del 22 de octubre de 2026.

## Inicio rápido sin servicios

```powershell
flutter pub get
.\scripts\start-web.ps1 -Demo
```

Abre http://127.0.0.1:7357. El modo DEMO_MODE usa datos ficticios en memoria: se pierden al cerrar o reiniciar la app. No requiere Firebase ni envía correos. Permite recorrer los distintos roles y crear cuentas temporales. Las imágenes se agregan mediante una URL HTTPS en este modo.

## Inicio con Firebase local

Requisitos: Flutter compatible con Dart 3.13.5, Node 22 recomendado para Functions, Firebase CLI y Java. El equipo de desarrollo tiene Node 24; las pruebas locales también se ejecutaron con esa versión. Para Android se requiere el SDK y JDK de Android Studio.

Instala dependencias:

```powershell
flutter pub get
npm.cmd --prefix functions ci
```

En una terminal inicia los emuladores:

```powershell
.\scripts\start-emulators.ps1
```

En otra terminal prepara cuentas/categorías y ejecuta la web:

```powershell
.\scripts\seed-local.ps1
.\scripts\start-web.ps1
```

El proyecto emulado es siempre `demo-vitrina-local`. Los scripts de preparación y pruebas rechazan ejecutarse si no hay variables de emulador. La configuración remota existente `psf-publinfo001` se conserva, pero no fue desplegada ni modificada.

| Cuenta local | Correo | Contraseña |
| --- | --- | --- |
| Dueño | dueno@vitrina.local | Demo123! |
| Administrador | admin@vitrina.local | Demo123! |
| Otra cuenta | otro@vitrina.local | Demo123! |

Estas cuentas solo existen en los emuladores y en la demostración en memoria. La interfaz de emuladores está en http://127.0.0.1:4000. Sus datos se pierden cuando se detienen sin exportarlos; el script de preparación puede ejecutarse de nuevo.

Para un emulador Android:

```powershell
flutter run -d <id-del-dispositivo> --dart-define=USE_EMULATORS=true --dart-define=EMULATOR_HOST=10.0.2.2
```

Para Android sin Firebase:

```powershell
flutter run -d <id-del-dispositivo> --dart-define=DEMO_MODE=true
flutter build apk --debug --dart-define=DEMO_MODE=true
```

El APK de demostración está en `build/app/outputs/flutter-apk/app-debug.apk`. Usa firma de depuración y datos en memoria. No se ha probado la instalación en un teléfono físico y no es un paquete para tienda.

## Verificación

```powershell
flutter analyze
flutter test
npm.cmd --prefix functions test
# Con los emuladores encendidos:
.\scripts\test-backend.ps1
```

Las pruebas cubren lectura pública filtrada, denegación de acceso ajeno, escalamiento de permisos, idempotencia del envío, revisión concurrente, corrección, retiro, conservación de versiones, avisos, anuncios y reglas de imágenes. Las pruebas de widgets comprueban catálogo y acceso en una pantalla estrecha.

Para compilar una web conectada a los emuladores:

```powershell
flutter build web --dart-define=USE_EMULATORS=true --no-web-resources-cdn
```

Sirve `build/web` con un servidor HTTP local. No abras `index.html` como un archivo. El servidor final de esta sesión utiliza http://127.0.0.1:7358 cuando está activo.

## Estructura

- `lib/core`: modelos y validaciones compartidas.
- `lib/data`: contrato de repositorio, Firebase y demostración.
- `lib/features`: catálogo, cuenta, editor, administración y componentes.
- `functions`: validaciones y operaciones privilegiadas transaccionales.
- `firestore.rules`, `storage.rules`, `firestore.indexes.json`: permisos e índices.
- `docs/MODELO_Y_CONTRATOS.md`: colecciones, contratos y límites.
- `docs/VERIFICACION.md`: alcance comprobado y pendientes.
- `archive`: copia del código y reglas anteriores, excluida de la app.

## Activación del entorno remoto

Antes de usar el arranque predeterminado contra `psf-publinfo001`, deben habilitarse Email/Password en Authentication, Firestore, Storage y Cloud Functions. Revisar los requisitos de facturación de los servicios. Crear un administrador mediante Firebase Admin SDK en un entorno de confianza con el claim `admin: true`; nunca editar el perfil desde el cliente para conceder roles. Volver a iniciar sesión después de asignar el claim.

Revisar y desplegar las reglas, índices y funciones juntos. Una vez decidida la activación, el comando es:

```powershell
firebase deploy --project psf-publinfo001 --only firestore,storage,functions
```

Ese despliegue **no se ejecutó** durante esta implementación. Las colecciones antiguas `comercios`, `boletines` y `anuncios` no se migran automáticamente. Los documentos antiguos que carezcan de `publicado: true` no aparecen en la nueva app. Antes de sustituir reglas remotas, respaldar los datos y planificar su revisión y migración; no marcar contenido antiguo como aprobado sin revisarlo.

La ubicación abre Google Maps mediante un enlace. El widget de mapa con marcador requiere trabajo adicional y configuración de API. También quedan pendientes logo/color personalizados, limpieza de imágenes huérfanas, enlaces públicos por ficha, eliminación definitiva, contenido institucional y pruebas de dispositivo real. La baja habitual ya funciona por despublicación. Push, chat, reseñas y tienda de aplicaciones están fuera de esta primera base.

En Windows se deshabilitó `kotlin.incremental` porque la caché de paquetes está en C: y el proyecto en G:, lo que ocasionaba errores de rutas relativas durante la compilación. Gradle usa un máximo de dos workers para reducir consumo de memoria.
