# Verificación de Vitrina Local

Fecha: 23 de octubre de 2026. Plataforma acordada: Android y vista web local.

## Resultado

Se convirtió la base inicial de publicación directa y sesión anónima en una aplicación modular con recorrido público, cuentas, dueño y administración. El código anterior quedó preservado en `archive`. La carpeta original no contenía repositorio Git; no se creó un remoto ni se publicaron cambios en servicios externos.

La aplicación se ejecuta contra Firebase Emulator Suite y también tiene un modo de demostración independiente en memoria. La web compiló y se abrió en el navegador; se comprobó visualmente el catálogo y se inició sesión con el dueño local. El APK Android de demostración compiló con firma de depuración.

## Alcance implementado

| Área | Estado |
| --- | --- |
| Autenticación | Registro, acceso, cierre, recuperación mediante Firebase, edición de nombre y navegación por rol. El envío real de correos no se verificó. |
| Exploración | Catálogo público filtrado, búsqueda, categorías, ficha, horarios, galería, anuncios y boletines. |
| Contacto | Acciones de llamada, WhatsApp, ubicación externa y copia de la ficha para compartir. Requieren aplicaciones compatibles; no se probaron en teléfono físico. |
| Favoritos | Separados por usuario; protegidos por reglas. |
| Solicitudes | Borrador con campos mínimos, envío, retiro, seguimiento, rechazo con motivo y corrección mediante nuevo envío relacionado. |
| Dueño | Gestión de varios negocios, cambios pendientes separados de la versión publicada, imágenes y solicitudes de anuncios. |
| Administración | Revisión y comparación, aprobación/rechazo, categorías, boletines, despublicación de negocios y anuncios, historial. |
| Avisos | Decisiones personales y novedades de publicación con estado de lectura. |
| Backend | Funciones callable, transacciones, bloqueos de pendientes, IDs idempotentes, roles por claims y comprobación de propiedad. |
| Infraestructura local | Reglas Firestore/Storage, índices, emuladores, datos iniciales y scripts PowerShell. |

## Comprobaciones ejecutadas

- `flutter analyze`: sin incidencias después de las correcciones.
- `flutter test`: cuatro pruebas aprobadas. Incluyen el flujo de solicitud/revisión, propiedad/favoritos, vencimiento/validaciones y navegación/acceso en 390 × 844.
- `npm --prefix functions test`: cuatro pruebas unitarias de datos, decisiones, vencimiento e identificadores aprobadas.
- Integración Firebase: permisos públicos/privados; prohibición de ascenso de rol; envío repetido; dos revisores concurrentes; conservación de la versión aprobada; rechazo, retiro y corrección; historial y avisos; anuncios y despublicación; boletines; imágenes del propio usuario, tipo, tamaño y prohibición de reemplazo.
- `flutter build apk --debug --dart-define=DEMO_MODE=true`: APK generado, 159.405.017 bytes. SHA-256: `1DDA3A0642BF7B86A8AC44D4DA31BEB18BAF5844A504208C03A9BE23C57C95B4`.
- `flutter build web --dart-define=USE_EMULATORS=true --no-web-resources-cdn`: compilación final generada. El manifiesto web se actualizó después para reflejar el nombre y colores del proyecto.
- Inspección visual web: inicio, acceso y cuenta del dueño; captura en `screenshots/vitrina-local.png`.

La primera prueba móvil detectó un desbordamiento en el encabezado, corregido con texto flexible. La compilación Android requirió deshabilitar la caché incremental Kotlin por la separación entre los discos C: y G:. La primera ronda de pruebas de imágenes detectó reemplazo de archivos y se corrigió exigiendo `resource == null`. Un arranque lento del emulador durante la compilación motivó un límite de espera explícito en las pruebas HTTP.

## Pendientes para una entrega de producción

1. Activar y verificar los servicios del proyecto remoto, revisar su facturación, asignar el primer administrador mediante un entorno de confianza y desplegar reglas/índices/funciones juntos.
2. Respaldar y planificar la migración de las colecciones antiguas. No se modificaron datos remotos ni se supuso aprobación de contenido existente.
3. Instalar y probar en un dispositivo Android real: teclado, fotos, enlaces externos, red intermitente, retorno desde segundo plano y navegación completa. Preparar identificador de aplicación definitivo y firma de distribución.
4. Integrar el mapa con marcador si se mantiene el requisito de Google Maps embebido. Actualmente funciona el enlace externo por dirección; no hay clave de Maps configurada.
5. Completar las ampliaciones opcionales del plan: logo y color de acento, enlaces públicos individuales, eliminación definitiva administrativa, limpieza de archivos huérfanos y página institucional cuando se aporte su contenido.
6. Para un catálogo grande, introducir paginación, búsqueda en servidor y límites operativos. El MVP carga el catálogo para filtrar localmente; no se evaluó carga masiva ni costes de producción.

No se afirma que el calendario de cuatro semanas esté íntegramente completado: se dejó una base funcional amplia con flujo principal probado en local. Los avisos push, reseñas, chat y publicación en tiendas siguen fuera del alcance inicial definido en el plan.

## Fuentes de la revisión

- Documento facilitado: `C:/Users/Usuario/Downloads/Plan_de_implementacion_Vitrina_Local.docx`.
- Código y configuración existentes en esta carpeta antes de la implementación, preservados parcialmente en `archive`.
- Documentación oficial: [funciones callable](https://firebase.google.com/docs/functions/callable), [transacciones](https://firebase.google.com/docs/firestore/manage-data/transactions) y [pruebas de reglas](https://firebase.google.com/docs/rules/unit-tests).
