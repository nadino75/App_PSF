# Roles, Permisos y Auditoría - App Móvil PSF

## Roles de Usuario

### Usuario Regular
- Puede registrarse y crear cuenta
- Puede explorar catálogo público
- Puede crear solicitudes de nuevo negocio
- Puede ver sus propias notificaciones y su auditoría personal
- Puede marcar favoritos
- **NO puede**: Resolver solicitudes, editar negocios ajenos, ver auditoría de otros

### Dueño de Negocio
- Todas las capacidades de usuario regular
- Puede editar su propio negocio
- Puede enviar cambios a su negocio (solicitud de cambio)
- Puede proponer anuncios para su negocio
- Puede registrarse directamente como dueño al crear cuenta (opción en signup)
- **NO puede**: Resolver solicitudes, acceder a auditoría global

### Administrador
- Todas las capacidades de dueño
- Puede resolver solicitudes (aprobar/rechazar)
- Puede crear y editar categorías
- Puede crear y publicar boletines
- Puede publicar/despublicar negocios
- Puede bajar anuncios
- Puede ver auditoría global de todos los usuarios
- Verificado con custom claim `admin: true` en Firebase Auth

## Matriz de Permisos

| Acción | Usuario | Dueño | Admin |
|--------|---------|-------|-------|
| Leer catálogo público | ✓ | ✓ | ✓ |
| Ver su propia auditoría | ✓ | ✓ | ✓ |
| Ver auditoría global | ✗ | ✗ | ✓ |
| Registrarse | ✓ | ✓ | ✓ |
| Crear negocio (solicitud) | ✓ | ✓ | ✓ |
| Editar propio negocio | ✗ | ✓ | ✓ |
| Editar negocio ajeno | ✗ | ✗ | ✓ |
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

## Flujo de Registro como Dueño

1. Usuario toca "Registrarse como dueño" en signup
2. Se abre formulario extendido con:
   - Datos de persona: nombre, email, contraseña
   - Datos de negocio: nombre, descripción, categoría, dirección, teléfono, horarios
3. Cloud Function `registrarComoDueno` valida y crea atómicamente:
   - Cuenta de usuario en Firebase Auth
   - Documento de usuario con `dueno: true`
   - Documento de negocio asignado al usuario
   - Entrada en catálogo
   - Versión inicial del negocio
4. Usuario es auto-autenticado inmediatamente
5. Se registra la acción en auditoría

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

## Cloud Functions Relevantes

- `registrarComoDueno(email, password, nombre, negocio)` - Registro de dueño
- `enviarSolicitud(id, tipo, negocioId, propuesta)` - Envío de solicitud
- `resolverSolicitud(id, aprobar, motivo)` - Resolución de solicitud (admin)
- `gestionEditorial(id, tipo, campos)` - Gestión de categorías, boletines, etc (admin)

Todas registran auditoría al completarse exitosamente.

## Consideraciones de Seguridad

1. **Servidor es autoridad**: Cloud Functions validan todos los permisos
2. **Custom claims**: Admin se verifica por custom claim, no por datos en Firestore
3. **Validaciones transaccionales**: Operaciones batch son atómicas
4. **Tokens expirados**: Cambios en custom claims aplican en nuevo login
5. **Auditoría a prueba de falsificación**: Timestamps y IDs del servidor
