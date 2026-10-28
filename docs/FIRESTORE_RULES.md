# Reglas de Seguridad de Firestore - App Móvil PSF

## Descripción General

Las reglas de Firestore implementan control de acceso basado en roles (RBAC) con tres niveles:
- **Usuario Regular**: Acceso a contenido público
- **Dueño de Negocio**: Acceso a su propio negocio y contenido
- **Administrador**: Acceso completo a todo el sistema

## Funciones Auxiliares

```firestore
function signedIn() 
  → return request.auth != null && request.auth.token.firebase.sign_in_provider != 'anonymous'
  → Valida que el usuario esté autenticado (no anónimo)

function admin() 
  → return signedIn() && request.auth.token.get('admin', false) == true
  → Valida que el usuario sea administrador (custom claim)

function self(uid) 
  → return signedIn() && request.auth.uid == uid
  → Valida que el usuario sea el dueño del documento

function owner(id) 
  → return signedIn() && get(/databases/$(database)/documents/negocios/$(id)).data.duenoId == request.auth.uid
  → Valida que el usuario sea dueño del negocio

function ownAudit(userId) 
  → return signedIn() && resource.data.userId == userId && request.auth.uid == userId
  → Valida que el usuario sea dueño de su propio registro de auditoría
```

## Colecciones y Reglas de Acceso

### `/catalogo/{id}` - Catálogo de Negocios Publicados

```firestore
allow read: if resource.data.publicado == true || admin() || owner(id)
```

**Permisos:**
- **Lectura Pública**: Cualquier usuario autenticado puede leer catálogos publicados
- **Lectura Privada**: Dueño del negocio puede leer su propio catalogo (publicado o no)
- **Admin**: Puede leer todos

**Caso de uso**: Mostrar lista de negocios disponibles sin revelar borradores

---

### `/negocios/{id}` - Documentos de Negocio

```firestore
allow read: if admin() || (signedIn() && resource.data.duenoId == request.auth.uid)

match /versiones/{version} { 
  allow read: if admin() || owner(id)
}
```

**Permisos:**
- **Lectura**: Solo admin y dueño del negocio
- **Versiones**: Solo admin y dueño pueden ver historial de versiones

**Caso de uso**: Datos internos del negocio (no expuestos públicamente)

---

### `/categorias/{id}` - Categorías de Negocio

```firestore
allow read: if true
```

**Permisos:**
- **Lectura Pública**: Todos pueden leer (sin autenticación requerida)

**Caso de uso**: Llenar dropdowns sin necesidad de autenticación

---

### `/anuncios/{id}` - Anuncios Publicados

```firestore
allow read: if resource.data.publicado == true || admin()
```

**Permisos:**
- **Lectura Pública**: Solo anuncios publicados
- **Admin**: Puede ver todos (publicados y borradores)

**Caso de uso**: Feed de anuncios en la app

---

### `/boletines/{id}` - Boletines Administrativos

```firestore
allow read: if resource.data.publicado == true || admin()
```

**Permisos:**
- **Lectura Pública**: Solo boletines publicados
- **Admin**: Puede ver todos

**Caso de uso**: Comunicaciones de la plataforma

---

### `/novedades/{id}` - Feed de Novedades

```firestore
allow read: if signedIn()
```

**Permisos:**
- **Lectura Autenticada**: Solo usuarios registrados

**Caso de uso**: Timeline de eventos (nuevos negocios, anuncios aprobados)

---

### `/solicitudes/{id}` - Solicitudes Pendientes de Aprobación

```firestore
allow read: if admin() || (signedIn() && resource.data.solicitanteId == request.auth.uid)
```

**Permisos:**
- **Admin**: Ve todas las solicitudes
- **Usuario**: Ve solo sus propias solicitudes

**Caso de uso**: Panel de solicitudes para admin y usuario

---

### `/historial/{id}` - Historial de Solicitudes Resueltas

```firestore
allow read: if admin() || (signedIn() && resource.data.solicitanteId == request.auth.uid)
```

**Permisos:**
- **Admin**: Ve todo el historial
- **Usuario**: Ve solo sus propios registros

**Caso de uso**: Auditoría de cambios aprobados/rechazados

---

### `/usuarios/{uid}` - Perfil de Usuario

```firestore
allow read: if self(uid) || admin()

allow create: if self(uid) && request.resource.data.keys().hasOnly(['nombre'])
  && request.resource.data.nombre is string 
  && request.resource.data.nombre.size() > 0 
  && request.resource.data.nombre.size() <= 100

allow update: if self(uid) && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['nombre'])
  && request.resource.data.nombre is string 
  && request.resource.data.nombre.size() > 0 
  && request.resource.data.nombre.size() <= 100

match /favoritos/{id} {
  allow read, delete: if self(uid)
  allow create: if self(uid) 
    && request.resource.data.keys().hasOnly(['creado'])
    && request.resource.data.creado == request.time
    && get(/databases/$(database)/documents/catalogo/$(id)).data.publicado == true
}

match /notificaciones/{id} {
  allow read: if self(uid)
  allow update: if self(uid) 
    && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['leida'])
    && request.resource.data.leida is bool
}

match /lecturas/{id} {
  allow read: if self(uid)
  allow create, update: if self(uid) 
    && request.resource.data.keys().hasOnly(['leida']) 
    && request.resource.data.leida == true
}
```

**Permisos:**

#### Perfil Principal
- **Lectura**: Solo el usuario y admin
- **Creación**: Solo el usuario, campo `nombre` obligatorio (1-100 caracteres)
- **Actualización**: Solo campo `nombre`, mismo usuario

#### Favoritos
- **Lectura**: Solo el usuario
- **Creación**: Solo para negocios publicados, timestamp del servidor
- **Eliminación**: Solo el usuario

#### Notificaciones
- **Lectura**: Solo el usuario
- **Actualización**: Solo campo `leida` (booleano)

#### Lecturas (Boletines leídos)
- **Lectura**: Solo el usuario
- **Creación/Actualización**: Solo campo `leida: true`

**Caso de uso**: Perfil privado, favoritos, notificaciones personales

---

### `/auditoria/{id}` - Registro de Auditoría (INMUTABLE)

```firestore
allow read: if ownAudit(resource.data.userId) || admin()
allow write: if false
allow delete: if false
```

**Permisos:**
- **Lectura**: Solo el usuario (sus propias acciones) o admin (todas)
- **Escritura**: PROHIBIDA para usuarios (solo Cloud Functions)
- **Eliminación**: PROHIBIDA permanentemente

**Caso de uso**: Auditoría a prueba de falsificación

---

### Catch-all - Denegación Total

```firestore
match /{document=**} { 
  allow read, write: if false 
}
```

**Permisos**: Cualquier colección no explícitamente permitida es **denegada**

**Caso de uso**: Seguridad por defecto (permitir explícitamente, no denegar implícitamente)

---

## Matriz de Acceso por Rol

| Colección | Usuario Regular | Dueño de Negocio | Admin |
|-----------|-----------------|------------------|-------|
| `/catalogo` | Leer publicados | Leer todos los suyos | Leer todos |
| `/negocios` | ✗ | Leer propio | Leer todos |
| `/negocios/*/versiones` | ✗ | Ver historial propio | Ver todo |
| `/categorias` | Leer | Leer | Leer |
| `/anuncios` | Leer publicados | Leer suyos | Leer todos |
| `/boletines` | Leer publicados | Leer publicados | Leer todos |
| `/novedades` | Leer | Leer | Leer |
| `/solicitudes` | Ver propias | Ver propias | Ver todas |
| `/historial` | Ver propio | Ver propio | Ver todo |
| `/usuarios/{uid}` | Leer propio | Leer propio | Leer todos |
| `/usuarios/*/favoritos` | Crear, leer, eliminar propios | Crear, leer, eliminar propios | ✗ |
| `/usuarios/*/notificaciones` | Leer, actualizar propias | Leer, actualizar propias | ✗ |
| `/auditoria` | Leer propia | Leer propia | Leer todas |

---

## Patrones de Seguridad Implementados

### 1. Validación de Timestamps
```firestore
request.resource.data.creado == request.time
```
Solo permite timestamps de servidor, no del cliente

### 2. Validación de Strings
```firestore
request.resource.data.nombre is string 
&& request.resource.data.nombre.size() > 0 
&& request.resource.data.nombre.size() <= 100
```
Valida tipo, longitud mínima y máxima

### 3. Validación de Campos Específicos
```firestore
request.resource.data.keys().hasOnly(['nombre'])
```
Solo permite ciertos campos, rechaza campos desconocidos

### 4. Validación de Cambios Parciales
```firestore
request.resource.data.diff(resource.data).affectedKeys().hasOnly(['leida'])
```
Solo permite actualizar ciertos campos, rechaza cambios a otros

### 5. Lectura de Documentos Relacionados
```firestore
get(/databases/$(database)/documents/catalogo/$(id)).data.publicado == true
```
Valida condiciones en documentos relacionados antes de permitir

### 6. Auditoría Inmutable
```firestore
allow write: if false
allow delete: if false
```
Previene falsificación de registros de auditoría

---

## Testing de Reglas

Para verificar que las reglas funcionan correctamente:

```bash
# Ejecutar tests de reglas
firebase firestore:rules:test

# Desplegar reglas
firebase deploy --only firestore:rules
```

---

## Notas de Seguridad

1. **Admin se valida por custom claim**, no por dato en Firestore
2. **Timestamps del servidor**, nunca del cliente
3. **Auditoría inmutable** - no se puede eliminar ni modificar
4. **Seguridad por defecto** - denegar todo, permitir explícitamente
5. **Validación en servidor** - Cloud Functions validan antes de escribir
6. **Índices** - creados automáticamente según firestore.indexes.json

---

## Referencias

- [Firestore Security Rules Documentation](https://firebase.google.com/docs/firestore/security/start)
- [Custom Claims en Firebase Auth](https://firebase.google.com/docs/auth/admin/custom-claims)
- [Best Practices para Seguridad](https://firebase.google.com/docs/firestore/security/best-practices)
