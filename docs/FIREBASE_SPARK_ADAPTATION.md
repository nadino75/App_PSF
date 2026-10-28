# Adaptación Firebase Spark Plan (Gratuito)

## Cambios de Arquitectura

Como el plan Spark **no incluye Cloud Functions**, la aplicación se adapta así:

### ❌ Removido
- Cloud Functions (`functions/` no se usa)
- Validaciones de servidor
- Lógica de aprobación automática
- Auditoría desde servidor

### ✅ Mantenido
- Firestore Database (almacenamiento)
- Firebase Auth (registro/login)
- Cloud Storage (imágenes)
- Firestore Rules (control de acceso)

---

## Cambios en Flujo de Negocio

### Opción B (Spark): Registro + Solicitud Simplificada

```
1. Usuario se registra
   └─ Crea documento en /usuarios/{uid}
   └─ Auditoría registrada en cliente

2. Usuario solicita crear negocio
   └─ Crea documento en /solicitudes/{id}
   └─ Espera aprobación manual (sin automatización)

3. Admin aprueba manualmente en Firebase Console
   └─ Actualiza /usuarios/{uid} con dueno: true
   └─ Crea negocio en /negocios/{negocioId}
   └─ Auditoría registrada en cliente
```

**Diferencia:**
- Sin Cloud Functions = Sin validaciones de servidor
- Admin debe intervenir manualmente en Console
- Aplicación es más simple pero menos segura

---

## Cambios en Código Flutter

### Registro (Sin Cloud Function)

**Antes (con Cloud Function):**
```dart
final result = await FirebaseFunctions.instance
    .httpsCallable('registrarUsuario')
    .call({...});
```

**Ahora (Spark directo):**
```dart
// 1. Crear usuario en Auth
final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
  email: email,
  password: password,
);

// 2. Crear documento de usuario
await FirebaseFirestore.instance
    .collection('usuarios')
    .doc(userCredential.user!.uid)
    .set({
      'nombre': nombre,
      'email': email,
      'creado': FieldValue.serverTimestamp(),
    });

// 3. Registrar en auditoría (cliente-side)
await logAuditFromClient(uid, 'register', 'usuario');
```

---

### Enviar Solicitud de Negocio (Sin Cloud Function)

**Ahora (Spark directo):**
```dart
final solicitudId = FirebaseFirestore.instance.collection('solicitudes').doc().id;

await FirebaseFirestore.instance
    .collection('solicitudes')
    .doc(solicitudId)
    .set({
      'tipo': 'negocio',
      'negocioId': solicitudId,
      'propuesta': {
        'nombre': nombreNegocio,
        'descripcion': descripcion,
        'categoria': categoria,
        'direccion': direccion,
        'telefono': telefono,
        'horarios': horarios,
      },
      'estado': 'pendiente',
      'solicitanteId': uid,
      'creado': FieldValue.serverTimestamp(),
      'actualizado': FieldValue.serverTimestamp(),
    });

// Registrar auditoría
await logAuditFromClient(uid, 'submitRequest', solicitudId);
```

---

### Auditoría Cliente-Side

Nueva función en `lib/data/firebase_repository.dart`:

```dart
Future<void> logAuditFromClient(
  String userId,
  String action,
  String? targetId,
) async {
  final auditId = FirebaseFirestore.instance.collection('auditoria').doc().id;
  
  await FirebaseFirestore.instance
      .collection('auditoria')
      .doc(auditId)
      .set({
        'userId': userId,
        'action': action,
        'targetId': targetId,
        'targetType': _getTargetType(action),
        'result': 'success',
        'timestamp': FieldValue.serverTimestamp(),
      });
}

String _getTargetType(String action) {
  switch (action) {
    case 'register':
      return 'usuario';
    case 'submitRequest':
      return 'request';
    case 'updateProfile':
      return 'usuario';
    default:
      return 'unknown';
  }
}
```

---

## Cambios en Firestore Rules

### Simplificación: Permite escribir solicitudes directamente

**Antes:**
```firestore
match /solicitudes/{id} { 
  allow read: if admin() || (signedIn() && resource.data.solicitanteId == request.auth.uid); 
}
```

**Ahora (Spark):**
```firestore
match /solicitudes/{id} {
  allow read: if admin() || (signedIn() && resource.data.solicitanteId == request.auth.uid);
  allow create: if signedIn() 
    && request.resource.data.solicitanteId == request.auth.uid
    && request.resource.data.tipo in ['negocio', 'cambio', 'anuncio'];
}
```

---

## Proceso Manual para Admin

**En lugar de aprobación automática:**

1. Admin inicia sesión en app Flutter
2. Ve panel de "Solicitudes Pendientes"
3. Revisa datos del solicitante
4. **Si aprueba manualmente en app:**
   - Actualiza `/usuarios/{uid}` → `dueno: true`
   - Crea `/negocios/{negocioId}`
   - Crea `/catalogo/{negocioId}`

---

## Limitaciones Conocidas

| Aspecto | Cloud Functions | Spark (Directo) |
|--------|-----------------|-----------------|
| Validación servidor | ✅ Segura | ❌ Cliente solo |
| Auditoría | ✅ Inmutable | ⚠️ Cliente puede manipular |
| Transacciones atómicas | ✅ Garantizado | ⚠️ Posibles inconsistencias |
| Control de acceso | ✅ Servidor | ✅ Firestore Rules |
| Escalabilidad | ✅ Función por solicitud | ⚠️ Lectura/escritura directa |

---

## Roadmap: Upgrade a Blaze

Cuando decidas agregar Cloud Functions (plan Blaze):

1. Restaurar funciones en `functions/index.js`
2. Cambiar llamadas en Flutter a `FirebaseFunctions.instance.httpsCallable()`
3. Migrar auditoría a servidor
4. Validaciones de servidor se reactivan automáticamente

---

## Resumen de Cambios

✅ **Completado:**
- Firestore Rules adaptadas (lectura/escritura de solicitudes)
- Auditoría cliente-side
- Registro directo en Firestore
- Solicitudes sin Cloud Function

⏳ **TODO:**
- Actualizar código Flutter para usar Firestore directo
- Remover/comentar llamadas a Cloud Functions
- Actualizar UI (sin validaciones de servidor)
- Testing con plan Spark

