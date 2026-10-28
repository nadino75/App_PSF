# Guía de Despliegue - App Móvil PSF

## Requisitos Previos

- ✅ Firebase CLI instalado (`firebase --version`)
- ✅ Proyecto creado en [Firebase Console](https://console.firebase.google.com)
- ✅ Acceso a credenciales de Firebase
- ✅ Node.js 22+ para Cloud Functions

## Paso 1: Autenticación Firebase

```bash
# Login en Firebase
firebase login

# Verificar proyecto actual
firebase projects:list
```

## Paso 2: Configuración de Proyecto

El proyecto está configurado para usar **app-movil-PSF**. Verifica:

```bash
# Ver configuración actual
cat .firebaserc

# Debe mostrar:
{
  "projects": {
    "default": "app-movil-PSF"
  }
}
```

## Paso 3: Actualizar IDs de Aplicación

> **IMPORTANTE:** Obtén estos valores de Firebase Console → Configuración del proyecto

Edita `firebase.json` y actualiza:

```json
{
  "flutter": {
    "platforms": {
      "android": {
        "default": {
          "projectId": "app-movil-PSF",
          "appId": "1:YOUR_NUMBER:android:YOUR_APP_ID",  // ← REEMPLAZAR
          "fileOutput": "android/app/google-services.json"
        }
      },
      "dart": {
        "lib/firebase_options.dart": {
          "projectId": "app-movil-PSF",
          "configurations": {
            "android": "1:YOUR_NUMBER:android:YOUR_APP_ID",  // ← REEMPLAZAR
            "web": "1:YOUR_NUMBER:web:YOUR_APP_ID",          // ← REEMPLAZAR
            "windows": "1:YOUR_NUMBER:web:YOUR_APP_ID"       // ← REEMPLAZAR
          }
        }
      }
    }
  }
}
```

## Paso 4: Generar Firebase Options

```bash
# Generar archivos de configuración
flutterfire configure --project=app-movil-PSF --platforms=android,web,windows,ios

# Esto actualiza lib/firebase_options.dart automáticamente
```

## Paso 5: Desplegar Firestore

```bash
# Validar reglas
firebase firestore:rules test

# Desplegar reglas
firebase deploy --only firestore:rules

# Desplegar índices
firebase deploy --only firestore:indexes
```

## Paso 6: Desplegar Cloud Functions

```bash
# Instalar dependencias (si no está hecho)
npm --prefix functions ci

# Desplegar funciones
firebase deploy --only functions

# Ver logs
firebase functions:log
```

## Paso 7: Desplegar Storage Rules

```bash
firebase deploy --only storage
```

## Paso 8: Crear Usuario Admin (Una sola vez)

```bash
# Opción 1: Firebase CLI
firebase auth:create-user \
  --email admin@appmovil.local \
  --password "AdminPassword123!" \
  --display-name "Administrador"

# Opción 2: Cloud Shell en Firebase Console (recomendado)
# Ve a: Firebase Console → Cloud Functions → Cloud Shell

# Ejecuta este script Node.js:
const admin = require('firebase-admin');
admin.initializeApp();

async function makeAdmin(email) {
  const user = await admin.auth().getUserByEmail(email);
  await admin.auth().setCustomUserClaims(user.uid, { admin: true });
  console.log(`✅ ${email} ahora es administrador`);
}

makeAdmin('admin@appmovil.local');
```

## Paso 9: Habilitar Autenticación en Firebase

En Firebase Console:

1. **Autenticación → Sign-in method**
   - Email/Contraseña: ✅ Habilitado
   - Anónimo: ❌ Deshabilitado (para seguridad)

2. **Firestore Database**
   - Modo: Nativo
   - Ubicación: Cercana a tus usuarios

3. **Cloud Storage**
   - Crear bucket: `app-movil-psf.appspot.com`
   - Reglas: Deploy con `firebase deploy --only storage`

## Paso 10: Verificar Despliegue

```bash
# Ver estado de despliegue
firebase deploy:log

# Verificar Firestore
firebase firestore:indexes:list

# Verificar Functions
firebase functions:list

# Verificar Storage
firebase storage:rules:get
```

## Pruebas Post-Despliegue

### Test 1: Registro de Usuario Normal

```bash
# En Emulador o en la app
1. Abre la app
2. Toca "Crear cuenta"
3. Email: test@appmovil.local
4. Contraseña: Test123!
5. Toca "Registrarse"

✅ Esperado: Usuario creado, auto-login, sin errores
```

### Test 2: Registro como Dueño

```bash
1. Abre la app
2. Toca "¿Eres dueño de negocio?"
3. Completa formulario con:
   - Nombre: Test User
   - Email: owner@appmovil.local
   - Contraseña: Owner123!
   - Nombre negocio: Mi Negocio
   - Categoría: Gastronomía
   - Dirección: Calle Principal 123
   - Teléfono: +591 70000000
   - Horarios: Lunes a viernes 9-18

✅ Esperado:
   - Usuario + Negocio creados
   - Auto-login como dueño
   - Aparece "Mi Actividad" en perfil
```

### Test 3: Auditoría

```bash
1. Login como admin@appmovil.local
2. Ve a la sección de Administración
3. Toca "Auditoría"

✅ Esperado:
   - Ves registros de signIn, register, resolverSolicitud
   - Cada registro muestra usuario, acción, timestamp
   - No puedes eliminar registros
```

### Test 4: Permisos

```bash
1. Login como usuario normal
2. Intenta ver "Auditoría global" → ❌ Acceso denegado
3. Ve a "Mi actividad" → ✅ Ves tus propias acciones
4. Logout
5. Login como admin → ✅ Ves auditoría global
```

## Rollback (Si algo falla)

```bash
# Revertir a versión anterior de reglas
firebase firestore:rules:get > rules_backup.txt
firebase firestore:rules:rollback  # Vuelve a última versión estable

# Revertir Cloud Functions
firebase functions:delete resolverSolicitud --region=us-central1
firebase functions:delete enviarSolicitud --region=us-central1
firebase functions:delete retirarSolicitud --region=us-central1
firebase functions:delete gestionEditorial --region=us-central1
firebase functions:delete registrarComoDueno --region=us-central1
```

## Monitoreo Post-Despliegue

### En Firebase Console

1. **Functions → Logs**: Monitorear errores
2. **Firestore → Data**: Verificar colección `auditoria`
3. **Authentication**: Ver usuarios registrados
4. **Storage**: Verificar bucket de imágenes

### En la App

- ✅ Cargas sin errores de Firebase
- ✅ Signup funciona normalmente
- ✅ Login es rápido
- ✅ Auditoría se registra sin demoras

## Comandos Útiles

```bash
# Ver estado actual
firebase status

# Desplegar todo
firebase deploy

# Desplegar solo funciones
firebase deploy --only functions

# Ver logs en vivo
firebase functions:log --limit=50

# Listar usuarios (en Cloud Shell)
firebase auth:list --project app-movil-PSF

# Eliminar usuario
firebase auth:delete USER_UID --project app-movil-PSF
```

## Troubleshooting

### Error: "Project not found"
```bash
firebase use app-movil-PSF
firebase deploy
```

### Error: "Permission denied on /auditoria"
- Verifica que `firestore.rules` está desplegada
- Ejecuta: `firebase firestore:rules:test`

### Error: "Cloud Function deployment failed"
```bash
# Verificar dependencias
npm --prefix functions list

# Reinstalar
npm --prefix functions ci

# Redeploy
firebase deploy --only functions
```

### Admin no puede ver auditoría global
- Verifica que el custom claim `admin: true` está asignado
- En Cloud Shell:
  ```javascript
  const user = await admin.auth().getUser('USER_UID');
  console.log(user.customClaims); // Debe mostrar {admin: true}
  ```

## Próximos Pasos

1. ✅ Desplegar reglas Firestore
2. ✅ Desplegar Cloud Functions
3. ✅ Crear usuario admin
4. ✅ Ejecutar pruebas
5. 📱 Compilar APK para Android
6. 🌐 Desplegar web a hosting
7. 📊 Monitorear métricas

## Soporte

- [Firebase Documentation](https://firebase.google.com/docs)
- [Flutter Firebase Docs](https://firebase.flutter.dev)
- [Cloud Functions Guide](https://cloud.google.com/functions/docs)
