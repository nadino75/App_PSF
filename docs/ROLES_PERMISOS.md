# Roles, Permisos y Auditoría - App Móvil PSF

## Roles de Usuario

### Usuario Regular
- Puede registrarse y crear cuenta
- Puede explorar catálogo público y ver anuncios
- Puede marcar favoritos
- Puede ver sus propias notificaciones y su auditoría personal
- **PUEDE**: Enviar solicitud para crear su propio negocio (espera aprobación admin)
- **NO puede**: Crear negocio sin aprobación, resolver solicitudes, ver auditoría global
- **Rol**: Observador de catálogo, anuncios y solicitante de propiedad

### Dueño de Negocio
- **Se obtiene por**: Aprobación de solicitud de creación de negocio por admin
- Puede editar su propio negocio (mediante solicitudes de cambio)
- Puede enviar cambios a su negocio para aprobación
- Puede crear anuncios para su negocio
- Puede ver anuncios y catálogo público
- Puede ver sus propias notificaciones y auditoría personal
- **NO puede**: Resolver solicitudes, editar negocios ajenos, ver auditoría global, crear otros negocios

### Administrador
- Todas las capacidades de dueño
- Puede resolver solicitudes (aprobar/rechazar)
- Puede crear y editar categorías
- Puede crear y publicar boletines
- Puede publicar/despublicar negocios
- Puede bajar anuncios
- Puede ver auditoría global de todos los usuarios
- Verificado con custom claim `admin: true` en Firebase Auth

## Diferencia Clave: Usuario vs Dueño (OPCIÓN B - Solicitud)

```
┌─────────────────────────────────────────────────────────┐
│ USUARIO REGULAR (TODOS comienzan aquí)                  │
├─────────────────────────────────────────────────────────┤
│ • Ve catálogo público                                   │
│ • Ve anuncios                                           │
│ • Marca favoritos                                       │
│ • Recibe notificaciones                                 │
│ • PUEDE solicitar crear su negocio                      │
│ • Espera aprobación del admin                           │
└─────────────────────────────────────────────────────────┘
                            ↓
                    Envía solicitud de NEGOCIO
                    (con datos del negocio)
                            ↓
┌─────────────────────────────────────────────────────────┐
│ DUEÑO DE NEGOCIO (Después de aprobación)                │
├─────────────────────────────────────────────────────────┤
│ • Posee UN negocio (creado por admin al aprobar)        │
│ • Puede actualizar datos del negocio                    │
│ • Puede publicar anuncios                               │
│ • Espera aprobación del admin para cambios              │
│ • Ve catálogo y anuncios también                        │
│ • NO puede crear más negocios                           │
│ • NO puede aprobar solicitudes                          │
└─────────────────────────────────────────────────────────┘
```

**Flujo de Registro (OPCIÓN B):**
1. Todos se registran como USUARIOS normales
2. Usuario que quiere negocio envía "Solicitud de negocio"
3. Admin aprueba → Usuario pasa a ser DUEÑO + negocio creado

## Matriz de Permisos

| Acción | Usuario | Dueño | Admin |
|--------|---------|-------|-------|
| Leer catálogo público | ✓ | ✓ | ✓ |
| Ver anuncios | ✓ | ✓ | ✓ |
| Ver su propia auditoría | ✓ | ✓ | ✓ |
| Ver auditoría global | ✗ | ✗ | ✓ |
| Registrarse | ✓ | ✓ | ✓ |
| **Solicitar crear negocio** | **✓ (espera aprobación)** | **✓** | ✓ |
| **Crear negocio** | **✗ (solo aprobado)** | **✓ (por aprobación)** | ✓ |
| Editar propio negocio | ✗ | ✓ | ✓ |
| Enviar cambios a negocio | ✗ | ✓ | ✓ |
| Crear anuncios para negocio | ✗ | ✓ | ✓ |
| Resolver solicitudes | ✗ | ✗ | ✓ |
| Editar categorías | ✗ | ✗ | ✓ |
| Crear/publicar boletines | ✗ | ✗ | ✓ |

## Auditoría

Se registran las siguientes acciones en Firestore (`/auditoria/{id}`):

- `signIn` - Inicio de sesión
- `register` - Registro de usuario (incluyendo registro como dueño)
- `updateProfile` - Cambio de nombre
- `submitRequest` - Envío de solicitud (nuevo negocio, cambio, anuncio)
- `withdrawRequest` - Retiro de solicitud pendiente
- `resolveRequest` - Resolución de solicitud (aprobada/rechazada)
- `editorialCategory` - Cambio en categoría
- `editorialBulletin` - Publicación de boletín
- `editorialBusiness` - Cambio de publicación de negocio
- `editorialAd` - Bajada de anuncio
- `uploadImage` - Carga de imagen
- `toggleFavorite` - Marcar/desmarcar favorito

### Acceso a Auditoría

- **Usuarios**: Ven solo sus propias acciones (filtradas por userId en Firestore)
- **Administradores**: Ven todas las auditorías del sistema

### Características de Seguridad

- Auditoría inmutable: No puede ser eliminada por usuarios finales
- Timestamps del servidor: Todos registran hora del servidor, no del cliente
- Validación servidor-side: Cloud Functions registran antes de confirmar operación
- Reglas Firestore: Lectura restringida a usuario dueño o admin

## Flujo para Obtener Propiedad de Negocio (OPCIÓN B)

### Paso 1: Registro como Usuario Normal
1. Usuario completa formulario de registro:
   - Email
   - Contraseña
   - Nombre
2. Cloud Function `registrarUsuario`:
   - Crea cuenta en Firebase Auth
   - Crea documento de usuario (sin `dueno: true`)
3. Usuario es auto-autenticado
4. Se registra "register" en auditoría

### Paso 2: Solicitud de Creación de Negocio
1. Usuario autenticado toca "Crear mi negocio"
2. Completa formulario con:
   - Nombre del negocio
   - Descripción
   - Categoría
   - Dirección
   - Teléfono
   - Horarios
3. Cloud Function `enviarSolicitud` con `tipo: "negocio"`:
   - Valida que el usuario no tenga negocio ya
   - Crea documento de solicitud con estado "pendiente"
   - Se registra "submitRequest" en auditoría

### Paso 3: Aprobación por Admin
1. Admin ve solicitud pendiente
2. Revisa datos del negocio propuesto
3. Toca "Aprobar"
4. Cloud Function `resolverSolicitud` con `aprobar: true`:
   - Crea negocio en `/negocios/{negocioId}`
   - Crea entrada en catálogo
   - Crea versión inicial
   - **Marca usuario con `dueno: true`**
   - Marca solicitud como "aprobada"
   - Se registra "resolveRequest" en auditoría

### Resultado
- Usuario ahora es DUEÑO
- Negocio está publicado en catálogo
- Usuario recibe notificación de aprobación

## Reglas de Firestore - Resumen

```firestore
# Lectura de catálogo público
match /catalogo/{id} { 
  allow read: if publicado || admin() || owner(id); 
}

# Negocios: solo dueño y admin
match /negocios/{id} { 
  allow read: if admin() || (autenticado && duenoId == uid); 
}

# Auditoría: lectura personal o admin
match /auditoria/{id} { 
  allow read: if (uid == userId) || admin(); 
  allow write: if false;  # Solo servidor
  allow delete: if false; # Nunca se borra
}
```

## Cloud Functions Relevantes (OPCIÓN B)

- `registrarUsuario(email, password, nombre)` - Registro de usuario regular
- `enviarSolicitud(id, tipo, negocioId, propuesta)` - Envío de solicitud
  - `tipo: "negocio"` → Solicitud para crear negocio
  - `tipo: "cambio"` → Cambios a negocio existente
  - `tipo: "anuncio"` → Nuevo anuncio para negocio
- `resolverSolicitud(id, aprobar, motivo)` - Resolución de solicitud (admin)
  - Al aprobar tipo "negocio": Crea negocios/, catalogo/, versiones/ y marca usuario como dueno
- `gestionEditorial(id, tipo, campos)` - Gestión de categorías, boletines, etc (admin)

Todas registran auditoría al completarse exitosamente.

## Consideraciones de Seguridad

1. **Servidor es autoridad**: Cloud Functions validan todos los permisos
2. **Custom claims**: Admin se verifica por custom claim, no por datos en Firestore
3. **Validaciones transaccionales**: Operaciones batch son atómicas
4. **Tokens expirados**: Cambios en custom claims aplican en nuevo login
5. **Auditoría a prueba de falsificación**: Timestamps y IDs del servidor
