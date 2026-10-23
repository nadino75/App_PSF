# Modelo y contratos de Vitrina Local

El catálogo público se separa de la propiedad y las propuestas privadas. Los clientes nunca escriben directamente publicaciones, roles, solicitudes, historial ni decisiones; las funciones validan identidad, propiedad y datos.

| Colección | Contenido | Acceso |
| --- | --- | --- |
| `usuarios/{uid}` | Nombre y marca `dueno` derivada por el servidor | Propio usuario; solo puede editar nombre |
| `usuarios/{uid}/favoritos/{negocioId}` | Fecha de guardado | Propio usuario |
| `usuarios/{uid}/notificaciones/{solicitudId}` | Decisión, texto y estado leído | Propio usuario; solo cambia leído |
| `usuarios/{uid}/lecturas/{novedadId}` | Lectura de avisos públicos | Propio usuario |
| `negocios/{id}` | Dueño, estado y versión vigente | Dueño y administrador |
| `negocios/{id}/versiones/{solicitudId}` | Copia de cada versión aprobada | Dueño y administrador |
| `catalogo/{id}` | Nombre, descripción, categoría, dirección, zona, teléfono, horarios, imágenes, publicado | Público cuando publicado; dueño y administrador |
| `solicitudes/{id}` | Tipo, negocio, solicitante, propuesta, estado, anteriorId, decisión, fechas | Solicitante y administrador |
| `pendientes/{negocioId}_{tipo}` | Bloqueo transaccional de envío pendiente | Solo servidor |
| `categorias/{id}` | Nombre, activa | Lectura pública; escritura del servidor |
| `anuncios/{id}` | Título, descripción, negocio, vencimiento, publicado | Público cuando publicado |
| `boletines/{id}` | Título, contenido, publicado | Público cuando publicado |
| `historial/{solicitudId}` | Decisión, revisor, motivo, fecha y solicitante | Solicitante y administrador |
| `novedades/{id}` | Avisos compartidos de publicación | Usuarios registrados |

El administrador se verifica mediante el custom claim `admin: true` de Authentication. El perfil no concede privilegios. Ser dueño se verifica por `negocios.duenoId` en cada operación.

## Operaciones callable

Todas residen en `us-central1`. El cliente mantiene el mismo identificador durante un reintento de envío. Los errores se comunican como códigos HttpsError y no se muestra éxito antes de recibir confirmación.

| Función | Entrada principal | Efecto |
| --- | --- | --- |
| `enviarSolicitud` | id, tipo negocio/cambio/anuncio, negocioId, propuesta, borrador, anteriorId | Valida campos y dueño. Guarda borrador o crea pendiente y bloqueo. |
| `retirarSolicitud` | id | Solo el solicitante retira una pendiente y libera el bloqueo. |
| `resolverSolicitud` | id, aprobar, motivo | Solo admin. Transacción: publica, resuelve, registra historial y notifica. |
| `gestionEditorial` | id, tipo y campos | Solo admin. Categorías, boletines, publicación de negocios y baja de anuncios. |

La corrección de una solicitud rechazada o retirada crea un nuevo envío con `anteriorId`. Un borrador conserva su ID. La información mínima es obligatoria también para guardar borradores. Solo puede existir una solicitud pendiente por negocio y tipo; en particular, un único cambio pendiente por negocio. Las solicitudes resueltas no pueden resolverse nuevamente.

Las imágenes se cargan en rutas inmutables `usuarios/{uid}/{id}`. Máximo 5 MB por imagen, JPEG/PNG/WebP y seis imágenes. Se guardan URLs con token de descarga: son enlaces compartibles y no deben contener información sensible. El archivo no se puede sustituir ni borrar desde el cliente después de cargado. La primera imagen actúa como portada; logo y color de acento son ampliaciones pendientes. No existe limpieza automática de archivos huérfanos.

Los anuncios vencidos dejan de mostrarse en las pantallas públicas por fecha. El vencimiento no equivale a borrar ni hacer secreto el documento. Al despublicar un negocio se despublican también sus anuncios. Volver a publicar el negocio no reactiva sus anuncios.

Los avisos de decisiones y publicaciones se guardan en la misma transacción/batch que el cambio: nunca existe un aviso de una operación fallida. La bandeja combina avisos personales con las últimas 100 novedades públicas y guarda las lecturas por usuario.

## Límites de esta base

El catálogo se filtra en memoria; un catálogo grande requerirá paginación y búsqueda de servidor. Las categorías inactivas dejan de estar disponibles en nuevos formularios, aunque negocios antiguos siguen visibles en Todos. Las funciones administrativas usan el SDK Admin y todas sus invariantes deben mantenerse en el servidor. El mapa integrado, enlaces públicos de ficha, borrado definitivo y edición de diseño no están implementados.

Referencias de implementación: [funciones callable](https://firebase.google.com/docs/functions/callable), [transacciones Firestore](https://firebase.google.com/docs/firestore/manage-data/transactions), [pruebas de reglas](https://firebase.google.com/docs/rules/unit-tests).
