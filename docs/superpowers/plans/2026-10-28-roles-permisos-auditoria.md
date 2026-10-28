# Roles, Permisos y Auditoría - Plan de Implementación

> **Para ejecutores agentes:** REQUIERE SUB-SKILL: Use superpowers:subagent-driven-development o superpowers:executing-plans para implementar este plan tarea por tarea. Los pasos usan sintaxis de checkbox (`- [ ]`) para seguimiento.

**Objetivo:** Implementar un sistema robusto de roles, permisos y auditoría con enfoque en seguridad. Características clave: 1) Todas las acciones se registran en auditoría, 2) Usuarios ven su propia auditoría, 3) Dueños pueden seleccionar "soy dueño" en registro, 4) Permisos validados servidor-side.

**Arquitectura:** Sistema de tres capas: 1) **Reglas Firestore** que permiten lectura de propia auditoría y definen acceso por rol, 2) **Cloud Functions** con validaciones servidor-side, registro de auditoría, y flujo de registro para dueños, 3) **Frontend Flutter** con opción de registro como dueño, auditoría personal visible, e indicadores de rol.

**Tech Stack:** Dart 3.13.5, Firebase (Auth, Firestore, Cloud Functions), Node.js 22

**Spec:** `docs/MODELO_Y_CONTRATOS.md` del proyecto (modelos, operaciones callable, permisos por rol)

## Restricciones Globales

- Autenticación: Solo usuarios registrados (no anónimos) pueden escribir datos
- Custom claims: El rol `admin` se verifica con custom claim `admin: true` de Firebase Auth
- Dueños: Verificados por campo `duenoId` en documento `negocios/{id}`
- Auditoría: Todas las operaciones callable (`enviarSolicitud`, `retirarSolicitud`, `resolverSolicitud`, `gestionEditorial`) deben registrarse
- Validaciones: Servidor es autoridad; cliente solo muestra/restringe UI

## Focus de Revisión

1. **Escalación de permisos:** Un usuario regular no debe poder elevarse a admin manipulando requests; solo servidor asigna custom claims
2. **Corrupción de auditoría:** Registros inmutables; usuarios solo ven SU propia auditoría, admin ve todos; nadie puede borrar
3. **Inyección de datos:** Cloud Functions validan TODOS los campos de entrada, especialmente en `registrarComoDueno`
4. **Registro como dueño:** Validación de información de negocio, verificación que no es duplicado, creación atómica de usuario+negocio
5. **Auditoría personal:** Usuario ve solo sus acciones (filtrada por `userId` en Firestore), admin ve todas

---

## Estructura de Archivos

**Modificar:**
- `firestore.rules` - Auditoría con lectura por usuario (propia) y admin (todas); mejoras de seguridad
- `lib/core/models.dart` - Agregar clases `UserRole` y `AuditLog`
- `lib/data/repository.dart` - Métodos para consultar auditoría personal
- `lib/data/firebase_repository.dart` - Implementar lectura de auditoría filtrada
- `lib/features/admin_page.dart` - Secciones de auditoría global y gestión
- `lib/features/account_pages.dart` - Mostrar rol actual, auditoría personal, opción registro como dueño
- `functions/domain.js` - Validaciones de roles y datos de negocio
- `functions/index.js` - Auditoría en operaciones, nueva callable `registrarComoDueno`

**Crear:**
- `lib/core/audit.dart` - Enums y modelos de auditoría
- `functions/audit.js` - Servicio centralizado de registro de auditoría
- `lib/features/owner_signup.dart` - Widget de registro como dueño de negocio
- `docs/ROLES_PERMISOS.md` - Documentación de roles, permisos y auditoría

---

## Tareas

### Tarea 1: Modelo de Roles y Auditoría (Dart)

**Archivos:**
- Crear: `lib/core/audit.dart`
- Modificar: `lib/core/models.dart`
- Prueba: Validaciones en `lib/core/models.dart`

**Interfaces:**
- Produce: Clases `UserRole`, `AuditAction`, `AuditLog` que el repositorio usará para modelar datos

- [ ] **Paso 1: Crear `lib/core/audit.dart` con enumeraciones de acciones y roles**

```dart
enum UserRole { user, owner, admin }

enum AuditAction {
  signIn,
  register,
  updateProfile,
  submitRequest,
  withdrawRequest,
  resolveRequest,
  editorialCategory,
  editorialBulletin,
  editorialBusiness,
  editorialAd,
  toggleFavorite,
  markReadNotification,
  uploadImage,
}

class AuditLog {
  final String id;
  final String userId;
  final String? userName;
  final AuditAction action;
  final String? targetId;
  final String? targetType; // 'request', 'business', 'user', etc
  final Map<String, dynamic>? changes;
  final String? result; // 'success', 'denied', 'error'
  final String? reason;
  final DateTime timestamp;

  AuditLog({
    required this.id,
    required this.userId,
    this.userName,
    required this.action,
    this.targetId,
    this.targetType,
    this.changes,
    this.result,
    this.reason,
    required this.timestamp,
  });
}
```

- [ ] **Paso 2: Agregar método auxiliar en `lib/core/models.dart` para determinar rol**

```dart
UserRole getUserRole(Account? account, {bool isOwner = false, List<String> ownedBusinesses = const []}) {
  if (account?.admin == true) return UserRole.admin;
  if (isOwner) return UserRole.owner;
  return UserRole.user;
}
```

- [ ] **Paso 3: Commit**

```bash
git add lib/core/audit.dart lib/core/models.dart
git commit -m "feat: agregar modelos de roles y auditoría"
```

---

### Tarea 2: Mejorar Reglas Firestore para Auditoría

**Archivos:**
- Modificar: `firestore.rules`

**Interfaces:**
- Consume: Estructura existente de usuarios, negocios, solicitudes
- Produce: Colección `auditoria` con lectura personal (propia) y admin (todas); escritura solo servidor

- [ ] **Paso 1: Agregar función `ownAudit()` y reglas para colección `auditoria` en `firestore.rules`**

En las reglas, agregar después de las funciones existentes:

```firestore
function ownAudit(userId) { return signedIn() && resource.data.userId == userId && request.auth.uid == userId; }

match /auditoria/{id} {
  allow read: if ownAudit(resource.data.userId) || admin();
  allow write: if false;
  allow delete: if false;
}

match /usuarios/{uid}/auditoria/{id} {
  allow read: if self(uid) || admin();
  allow write: if false;
}
```

- [ ] **Paso 2: Agregar restricción de lectura para `solicitudes` y `historial` (solo solicitante y admin)**

Verificar que las reglas existentes de `solicitudes` e `historial` restrinjan correctamente.

- [ ] **Paso 3: Commit**

```bash
git add firestore.rules
git commit -m "feat: agregar reglas firestore para auditoría con acceso personal y admin"
```

---

### Tarea 3: Cloud Function `registrarComoDueno` para Registro de Dueños

**Archivos:**
- Modificar: `functions/index.js`

**Interfaces:**
- Consume: Datos de usuario (nombre, email, contraseña) y datos de negocio (nombre, descripción, categoría, dirección, teléfono, horarios)
- Produce: Nueva callable `registrarComoDueno(data)` que crea usuario y negocio atómicamente

- [ ] **Paso 1: Agregar validaciones de datos de negocio a `functions/domain.js`**

Reutilizar función existente `businessData()` que ya valida campos de negocio.

- [ ] **Paso 2: Agregar callable `registrarComoDueno` a `functions/index.js`**

```javascript
exports.registrarComoDueno = onCall(async (request) => {
  // Rechazar usuarios autenticados (solo nuevos usuarios)
  D.requireThat(!request.auth || request.auth.token.firebase?.sign_in_provider === 'anonymous',
    'already-authenticated', 'Ya estás registrado.');

  const email = D.text(request.data.email, 'email', 254);
  const password = D.text(request.data.password, 'password', 128);
  const nombre = D.text(request.data.nombre, 'nombre', 100);
  const negocioData = D.businessData(request.data.negocio);

  // Validar email único en Firestore
  const existingUser = await db.collection('usuarios')
    .where('email', '==', email)
    .limit(1)
    .get();
  D.requireThat(existingUser.empty, 'already-exists', 'Este correo ya está registrado.');

  // Crear usuario en Firebase Auth
  const userRecord = await admin.auth().createUser({
    email,
    password,
    displayName: nombre,
  });

  // Crear documento de usuario y negocio en transacción
  const negocioId = db.collection('negocios').doc().id;
  await db.runTransaction(async tx => {
    // Usuario
    tx.set(db.collection('usuarios').doc(userRecord.uid), {
      nombre,
      email,
      dueno: true,
      creado: FieldValue.serverTimestamp(),
    });

    // Negocio
    tx.set(db.collection('negocios').doc(negocioId), {
      duenoId: userRecord.uid,
      publicado: false,
      versionId: negocioId,
      creado: FieldValue.serverTimestamp(),
    });

    // Catálogo
    tx.set(db.collection('catalogo').doc(negocioId), {
      ...negocioData,
      publicado: false,
      creado: FieldValue.serverTimestamp(),
    });

    // Versión inicial
    tx.set(db.collection('negocios').doc(negocioId).collection('versiones').doc(negocioId), {
      ...negocioData,
      creado: FieldValue.serverTimestamp(),
    });
  });

  return { uid: userRecord.uid, negocioId };
});
```

Nota: Esta función se llamará desde el cliente ANTES de autenticarse. No requiere `admin()` porque crea al usuario.

- [ ] **Paso 3: Commit**

```bash
git add functions/index.js
git commit -m "feat: agregar callable registrarComoDueno para registro de dueños de negocio"
```

---

### Tarea 4: Servicio de Auditoría en Cloud Functions

**Archivos:**
- Crear: `functions/audit.js`
- Modificar: `functions/index.js`

**Interfaces:**
- Produce: Función `logAudit(db, userId, action, targetId, targetType, changes, result, reason)` que crea documento en colección `auditoria`

- [ ] **Paso 1: Crear `functions/audit.js` con servicio centralizado**

```javascript
const { FieldValue } = require('firebase-admin/firestore');

const AuditAction = {
  SIGN_IN: 'signIn',
  REGISTER: 'register',
  UPDATE_PROFILE: 'updateProfile',
  SUBMIT_REQUEST: 'submitRequest',
  WITHDRAW_REQUEST: 'withdrawRequest',
  RESOLVE_REQUEST: 'resolveRequest',
  EDITORIAL_CATEGORY: 'editorialCategory',
  EDITORIAL_BULLETIN: 'editorialBulletin',
  EDITORIAL_BUSINESS: 'editorialBusiness',
  EDITORIAL_AD: 'editorialAd',
  TOGGLE_FAVORITE: 'toggleFavorite',
  UPLOAD_IMAGE: 'uploadImage',
};

const AuditResult = {
  SUCCESS: 'success',
  DENIED: 'denied',
  ERROR: 'error',
};

async function logAudit(db, userId, action, targetId = null, targetType = null, changes = null, result = AuditResult.SUCCESS, reason = null) {
  const auditLog = {
    userId,
    action,
    targetId,
    targetType,
    changes,
    result,
    reason,
    creado: FieldValue.serverTimestamp(),
  };

  try {
    await db.collection('auditoria').add(auditLog);
  } catch (error) {
    console.error('Error logging audit:', error);
    // No lanzar error; auditoría fallida no debe romper la operación
  }
}

module.exports = { logAudit, AuditAction, AuditResult };
```

- [ ] **Paso 2: Importar y usar auditoría en `functions/index.js`**

En la cabecera de `functions/index.js`:
```javascript
const { logAudit, AuditAction, AuditResult } = require('./audit');
```

- [ ] **Paso 3: Agregar auditoría a `enviarSolicitud`**

Después de la transacción exitosa (antes del `return { id }`):
```javascript
await logAudit(db, auth.uid, AuditAction.SUBMIT_REQUEST, id, 'request', 
  { tipo, negocioId }, AuditResult.SUCCESS);
```

- [ ] **Paso 4: Agregar auditoría a `retirarSolicitud`**

Después de la transacción exitosa:
```javascript
await logAudit(db, auth.uid, AuditAction.WITHDRAW_REQUEST, D.identifier(data.id), 'request', null, AuditResult.SUCCESS);
```

- [ ] **Paso 5: Agregar auditoría a `resolverSolicitud`**

Después de la transacción exitosa:
```javascript
const resultLog = {
  solicitudId: id,
  aprobada: data.aprobar,
  motivo: data.motivo,
};
await logAudit(db, auth.uid, AuditAction.RESOLVE_REQUEST, id, 'request', resultLog, AuditResult.SUCCESS);
```

- [ ] **Paso 6: Agregar auditoría a `gestionEditorial`**

Después de ejecutar la operación:
```javascript
const changeLog = { tipo: data.tipo, id };
if (data.tipo === 'categoria') changeLog.nombre = data.nombre;
if (data.tipo === 'boletin') changeLog.titulo = data.titulo;
if (data.tipo === 'negocio') changeLog.publicado = data.publicado;
if (data.tipo === 'anuncio') changeLog.id = id;

await logAudit(db, auth.uid, `editorial${data.tipo.charAt(0).toUpperCase() + data.tipo.slice(1)}`, id, data.tipo, changeLog, AuditResult.SUCCESS);
```

- [ ] **Paso 7: Commit**

```bash
git add functions/audit.js functions/index.js
git commit -m "feat: agregar servicio de auditoría centralizado en Cloud Functions"
```

---

### Tarea 5: Mejoras a Domain.js para Validaciones de Roles

**Archivos:**
- Modificar: `functions/domain.js`

**Interfaces:**
- Consume: Estructura de `auth.token` de Firebase
- Produce: Funciones `isAdmin(auth)`, `isOwner(auth, ownerId)`, `validateUserRole(auth, requiredRole)`

- [ ] **Paso 1: Agregar validaciones de roles a `functions/domain.js`**

```javascript
function isAdmin(auth) {
  return auth && auth.token && auth.token.admin === true;
}

function isOwner(auth, ownerId) {
  return auth && auth.uid === ownerId;
}

function validateUserRole(auth, requiredRole) {
  // requiredRole puede ser 'user', 'owner', 'admin'
  if (requiredRole === 'admin') return isAdmin(auth);
  if (requiredRole === 'owner') return isOwner(auth, auth.uid); // Owner check debe hacerse con negocio específico
  return !!auth; // 'user' solo requiere autenticación
}

module.exports = {
  isAdmin,
  isOwner,
  validateUserRole,
  // ... exportar también las funciones existentes
};
```

- [ ] **Paso 2: Actualizar `index.js` para usar `isAdmin` de domain en lugar de función local**

Reemplazar:
```javascript
const admin = auth => D.requireThat(auth.token.admin === true, 'permission-denied', 'Se requiere un administrador.');
```

Con:
```javascript
const requireAdmin = auth => D.requireThat(D.isAdmin(auth), 'permission-denied', 'Se requiere un administrador.');
```

Y actualizar llamadas de `admin(auth)` a `requireAdmin(auth)`.

- [ ] **Paso 3: Commit**

```bash
git add functions/domain.js functions/index.js
git commit -m "feat: agregar validaciones de roles centralizadas en domain.js"
```

---

### Tarea 6: Backend Flutter - Repository y Firebase Repository

**Archivos:**
- Modificar: `lib/data/repository.dart`
- Modificar: `lib/data/firebase_repository.dart`

**Interfaces:**
- Consume: Modelos `Account`, `Item`, `AuditLog` de core
- Produce: Métodos `fetchAuditLogs()` (todas las auditorías para admin) y `fetchMyAuditLogs()` (auditoría personal)

- [ ] **Paso 1: Agregar métodos abstractos a `lib/data/repository.dart`**

```dart
abstract class AppRepository extends ChangeNotifier {
  // ... métodos existentes ...
  
  List<AuditLog> auditLogs = [];
  List<AuditLog> myAuditLogs = [];
  
  Future<List<AuditLog>> fetchAuditLogs(); // Admin: todas las auditorías
  Future<List<AuditLog>> fetchMyAuditLogs(); // Usuario: sus propias acciones
}
```

- [ ] **Paso 2: Implementar `fetchAuditLogs()` en `lib/data/firebase_repository.dart` (admin solo)**

Cargar todas las auditorías de la colección `auditoria` ordenadas por timestamp descendente, limitadas a últimas 100.

- [ ] **Paso 3: Implementar `fetchMyAuditLogs()` en `lib/data/firebase_repository.dart` (para todos)**

Cargar auditorías donde `userId == account.uid` desde la colección `auditoria`, limitado a últimas 50.

- [ ] **Paso 4: Implementar ambos en `lib/data/demo_repository.dart`**

Retornar listas vacías (modo demo no tiene auditoría).

- [ ] **Paso 5: Commit**

```bash
git add lib/data/repository.dart lib/data/firebase_repository.dart lib/data/demo_repository.dart
git commit -m "feat: agregar métodos para consultar auditoría personal y global"
```

---

### Tarea 7: UI - Indicadores de Rol en Account Pages

**Archivos:**
- Modificar: `lib/features/account_pages.dart`

**Interfaces:**
- Consume: `Account` con campo `admin`, repositorio para determinar si es owner
- Produce: UI mejorada mostrando rol actual

- [ ] **Paso 1: Modificar la sección de perfil en `account_pages.dart` para mostrar rol actual**

Agregary un widget que muestre:
```dart
class RoleIndicator extends StatelessWidget {
  final Account account;
  final bool isOwner;

  const RoleIndicator({
    required this.account,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    final role = account.admin 
      ? 'Administrador' 
      : isOwner 
        ? 'Dueño de negocio' 
        : 'Usuario';
    
    final color = account.admin 
      ? Colors.red 
      : isOwner 
        ? Colors.orange 
        : Colors.blue;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(account.admin ? Icons.security : isOwner ? Icons.store : Icons.person, color: color),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tu rol:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(role, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Paso 2: Integrar `RoleIndicator` en la UI principal de perfil**

En el build de account page, después del nombre mostrar:
```dart
RoleIndicator(
  account: repository.account!,
  isOwner: repository.owned.isNotEmpty,
)
```

- [ ] **Paso 3: Commit**

```bash
git add lib/features/account_pages.dart
git commit -m "feat: agregar indicador de rol en página de perfil"
```

---

### Tarea 8: UI - Panel de Auditoría en Admin Page y Auditoría Personal en Account

**Archivos:**
- Modificar: `lib/features/admin_page.dart`
- Modificar: `lib/features/account_pages.dart`

**Interfaces:**
- Consume: `repository.auditLogs`, `repository.myAuditLogs`, métodos `fetchAuditLogs()` y `fetchMyAuditLogs()`
- Produce: Sección "Auditoría global" en admin page, sección "Mi actividad" en account page

- [ ] **Paso 1: Agregar sección "Auditoría" en admin page**

Cargar todas las auditorías con `fetchAuditLogs()`, mostrar en ListView con user, acción, timestamp, resultado.

- [ ] **Paso 2: Agregar sección "Mi actividad" en account page**

Cargar propias auditorías con `fetchMyAuditLogs()`, mostrar últimas 20 acciones en una lista simple.

- [ ] **Paso 3: Crear widget auxiliar `AuditLogTile()` reutilizable**

Widget que muestra una auditoría con icono de resultado, acción y timestamp.

- [ ] **Paso 4: Commit**

```bash
git add lib/features/admin_page.dart lib/features/account_pages.dart
git commit -m "feat: agregar secciones de auditoría en admin y actividad personal en account"
```

---

### Tarea 9: UI - Widget de Registro como Dueño de Negocio

**Archivos:**
- Crear: `lib/features/owner_signup.dart`
- Modificar: `lib/features/account_pages.dart` (agregar acceso al widget de signup)

**Interfaces:**
- Consume: Cloud Function `registrarComoDueno`, modelo `Item` para negocio
- Produce: Widget `OwnerSignupDialog` que guía el registro de dueño con datos de negocio

- [ ] **Paso 1: Crear `lib/features/owner_signup.dart` con formulario de registro**

Form con campos:
- Nombre de persona
- Email
- Contraseña (confirmar)
- Nombre del negocio
- Descripción
- Categoría (selector)
- Dirección
- Teléfono
- Horarios

- [ ] **Paso 2: Agregar validaciones de campos**

Usar validadores existentes: `requiredText()`, `validEmail()`, `validPhone()`.

- [ ] **Paso 3: Implementar envío a Cloud Function `registrarComoDueno`**

```dart
final result = await FirebaseFunctions.instance
    .httpsCallable('registrarComoDueno')
    .call({
      'nombre': nombreController.text,
      'email': emailController.text,
      'password': passwordController.text,
      'negocio': {
        'nombre': negocioNombreController.text,
        'descripcion': descripcionController.text,
        'categoria': categoriaSeleccionada,
        'direccion': direccionController.text,
        'telefono': telefonoController.text,
        'horarios': horariosController.text,
        'imagenes': [],
      },
    });
```

Luego auto-loguearse con email/password recibidos.

- [ ] **Paso 4: Agregar opción en signup de account_pages**

Botón "¿Eres dueño de negocio?" que abre el dialog de `OwnerSignupDialog`.

- [ ] **Paso 5: Commit**

```bash
git add lib/features/owner_signup.dart lib/features/account_pages.dart
git commit -m "feat: agregar widget de registro como dueño de negocio"
```

---

### Tarea 10: Documentación de Roles y Permisos

**Archivos:**
- Crear: `docs/ROLES_PERMISOS.md`

**Interfaces:**
- Produce: Documentación clara de roles, permisos, auditoría y flujo de registro de dueños

- [ ] **Paso 1: Crear `docs/ROLES_PERMISOS.md`**

```markdown
# Roles, Permisos y Auditoría

## Roles de Usuario

### Usuario Regular
- Puede registrarse y crear cuenta
- Puede explorar catálogo público
- Puede crear solicitudes de nuevo negocio
- Puede ver sus propias notificaciones y auditoría personal
- Puede marcar favoritos
- **NO puede**: Resolver solicitudes, editar negocios ajenos, ver auditoría de otros

### Dueño de Negocio
- Todas las capacidades de usuario regular
- Puede editar su propio negocio
- Puede enviar cambios a su negocio
- Puede proponer anuncios para su negocio
- Puede seleccionar "Soy dueño" durante el registro (crea negocio automáticamente)
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
| Crear negocio (registro) | ✓ | ✓ (automático) | ✓ |
| Editar propio negocio | ✗ | ✓ | ✓ |
| Resolver solicitudes | ✗ | ✗ | ✓ |
| Editar categorías | ✗ | ✗ | ✓ |

## Auditoría

Se registran las siguientes acciones:

- `register` - Registro de usuario (incluyendo registro como dueño)
- `signIn` - Inicio de sesión
- `submitRequest` - Envío de solicitud (nuevo negocio, cambio, anuncio)
- `withdrawRequest` - Retiro de solicitud
- `resolveRequest` - Resolución de solicitud
- `editorialCategory` - Cambio en categoría
- `editorialBulletin` - Publicación de boletín
- `editorialBusiness` - Cambio de publicación de negocio
- `editorialAd` - Bajada de anuncio

Cada usuario ve su propia auditoría. Administradores ven todas.

## Flujo de Registro como Dueño

1. Usuario en signup puede elegir "¿Eres dueño de negocio?"
2. Se abre formulario extendido con datos de persona y negocio
3. Cloud Function `registrarComoDueno` crea:
   - Cuenta de usuario en Firebase Auth
   - Documento de usuario con `dueno: true`
   - Documento de negocio asignado al usuario
   - Entrada en catálogo
   - Versión inicial del negocio
4. Usuario es auto-autenticado inmediatamente
5. Se registra en auditoría
```

- [ ] **Paso 2: Commit**

```bash
git add docs/ROLES_PERMISOS.md
git commit -m "docs: agregar documentación de roles, permisos, auditoría y registro de dueños"
```

---

## Verificaciones de Seguridad

Después de completar todas las tareas, verificar:

- [ ] Las reglas Firestore deniegan escritura a usuarios no-servidor en `auditoria`
- [ ] Cloud Functions validan `admin` con `auth.token.admin === true`, nunca confiando en cliente
- [ ] Auditoría se registra para TODAS las operaciones callable, incluso las denegadas
- [ ] El campo `userId` en auditoría es `auth.uid` del servidor, no del cliente
- [ ] Los custom claims (cambiar a admin) aplican inmediatamente sin refresco manual
- [ ] No hay forma de borrar registros de auditoría desde el cliente
- [ ] La UI muestra correctamente el rol cuando hay múltiples roles (ej: admin que es dueño)

