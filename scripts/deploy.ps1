# Script de Despliegue - App Móvil PSF
# Uso: .\scripts\deploy.ps1

param(
    [string]$ProjectId = "app-movil-psf",
    [string]$Region = "us-central1"
)

Write-Host "🚀 Iniciando despliegue de App Móvil PSF" -ForegroundColor Green
Write-Host "Proyecto: $ProjectId" -ForegroundColor Yellow
Write-Host ""

# Paso 1: Verificar Firebase CLI
Write-Host "1️⃣  Verificando Firebase CLI..." -ForegroundColor Cyan
firebase --version
if (-not $?) {
    Write-Host "❌ Firebase CLI no está instalado. Instálalo con: npm install -g firebase-tools" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Firebase CLI está disponible" -ForegroundColor Green
Write-Host ""

# Paso 2: Verificar autenticación
Write-Host "2️⃣  Verificando autenticación..." -ForegroundColor Cyan
firebase projects:list --project=$ProjectId 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  No estás autenticado. Ejecutando: firebase login" -ForegroundColor Yellow
    firebase login
}
Write-Host "✅ Autenticación verificada" -ForegroundColor Green
Write-Host ""

# Paso 3: Desplegar Firestore Rules
Write-Host "3️⃣  Desplegando reglas de Firestore..." -ForegroundColor Cyan
firebase deploy --only firestore:rules --project=$ProjectId
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Error al desplegar reglas" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Reglas de Firestore desplegadas" -ForegroundColor Green
Write-Host ""

# Paso 4: Desplegar Firestore Indexes
Write-Host "4️⃣  Desplegando índices de Firestore..." -ForegroundColor Cyan
firebase deploy --only firestore:indexes --project=$ProjectId
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  Advertencia al desplegar índices (puede ser normal)" -ForegroundColor Yellow
}
Write-Host "✅ Índices de Firestore procesados" -ForegroundColor Green
Write-Host ""

# Paso 5: Desplegar Cloud Functions
Write-Host "5️⃣  Instalando dependencias de Functions..." -ForegroundColor Cyan
npm --prefix functions ci
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Error al instalar dependencias" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Dependencias instaladas" -ForegroundColor Green
Write-Host ""

Write-Host "6️⃣  Desplegando Cloud Functions..." -ForegroundColor Cyan
firebase deploy --only functions --project=$ProjectId --region=$Region
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Error al desplegar funciones" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Cloud Functions desplegadas" -ForegroundColor Green
Write-Host ""

# Paso 6: Desplegar Storage Rules
Write-Host "7️⃣  Desplegando reglas de Storage..." -ForegroundColor Cyan
firebase deploy --only storage --project=$ProjectId
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  Advertencia al desplegar Storage (crear bucket primero si falta)" -ForegroundColor Yellow
}
Write-Host "✅ Reglas de Storage procesadas" -ForegroundColor Green
Write-Host ""

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "✅ ¡DESPLIEGUE COMPLETADO!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host ""

Write-Host "📋 PRÓXIMOS PASOS:" -ForegroundColor Yellow
Write-Host "1. Ve a Firebase Console: https://console.firebase.google.com" -ForegroundColor White
Write-Host "2. Selecciona proyecto: app-movil-psf" -ForegroundColor White
Write-Host "3. Habilita Autenticación → Email/Password" -ForegroundColor White
Write-Host "4. Crea bucket de Storage (si no existe)" -ForegroundColor White
Write-Host "5. Crea usuario admin en Cloud Shell:" -ForegroundColor White
Write-Host "   const admin = require('firebase-admin');" -ForegroundColor Gray
Write-Host "   admin.initializeApp();" -ForegroundColor Gray
Write-Host "   const user = await admin.auth().getUserByEmail('admin@appmovil.local');" -ForegroundColor Gray
Write-Host "   await admin.auth().setCustomUserClaims(user.uid, { admin: true });" -ForegroundColor Gray
Write-Host "6. Ejecuta pruebas en la app" -ForegroundColor White
Write-Host ""

Write-Host "🔗 URLs útiles:" -ForegroundColor Cyan
Write-Host "Firebase Console: https://console.firebase.google.com/project/app-movil-psf" -ForegroundColor White
Write-Host "Cloud Functions: https://console.cloud.google.com/functions/list?project=app-movil-psf" -ForegroundColor White
Write-Host "Firestore: https://console.firebase.google.com/project/app-movil-psf/firestore" -ForegroundColor White
Write-Host ""

Write-Host "✨ ¡Listo para pruebas!" -ForegroundColor Green
