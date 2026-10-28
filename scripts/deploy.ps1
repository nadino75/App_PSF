# Script de Despliegue - App Móvil PSF
# Uso: .\scripts\deploy.ps1

param(
    [string]$ProjectId = "app-movil-psf",
    [string]$Region = "us-central1"
)

Write-Host "[DEPLOY] Iniciando despliegue de App Movil PSF" -ForegroundColor Green
Write-Host "Proyecto: $ProjectId" -ForegroundColor Yellow
Write-Host ""

# Paso 1: Verificar Firebase CLI
Write-Host "[1] Verificando Firebase CLI..." -ForegroundColor Cyan
firebase --version
if (-not $?) {
    Write-Host "[ERROR] Firebase CLI no esta instalado. Instalalo con: npm install -g firebase-tools" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Firebase CLI esta disponible" -ForegroundColor Green
Write-Host ""

# Paso 2: Verificar autenticacion
Write-Host "[2] Verificando autenticacion..." -ForegroundColor Cyan
firebase projects:list --project=$ProjectId 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARN] No estas autenticado. Ejecutando: firebase login" -ForegroundColor Yellow
    firebase login
}
Write-Host "[OK] Autenticacion verificada" -ForegroundColor Green
Write-Host ""

# Paso 3: Desplegar Firestore Rules
Write-Host "[3] Desplegando reglas de Firestore..." -ForegroundColor Cyan
firebase deploy --only firestore:rules --project=$ProjectId
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Error al desplegar reglas" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Reglas de Firestore desplegadas" -ForegroundColor Green
Write-Host ""

# Paso 4: Desplegar Firestore Indexes
Write-Host "[4] Desplegando indices de Firestore..." -ForegroundColor Cyan
firebase deploy --only firestore:indexes --project=$ProjectId
if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARN] Advertencia al desplegar indices (puede ser normal)" -ForegroundColor Yellow
}
Write-Host "[OK] Indices de Firestore procesados" -ForegroundColor Green
Write-Host ""

# Paso 5: Desplegar Cloud Functions
Write-Host "[5] Instalando dependencias de Functions..." -ForegroundColor Cyan
npm --prefix functions ci
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Error al instalar dependencias" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Dependencias instaladas" -ForegroundColor Green
Write-Host ""

Write-Host "[6] Desplegando Cloud Functions..." -ForegroundColor Cyan
firebase deploy --only functions --project=$ProjectId --region=$Region
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Error al desplegar funciones" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Cloud Functions desplegadas" -ForegroundColor Green
Write-Host ""

# Paso 6: Desplegar Storage Rules
Write-Host "[7] Desplegando reglas de Storage..." -ForegroundColor Cyan
firebase deploy --only storage --project=$ProjectId
if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARN] Advertencia al desplegar Storage (crear bucket primero si falta)" -ForegroundColor Yellow
}
Write-Host "[OK] Reglas de Storage procesadas" -ForegroundColor Green
Write-Host ""

Write-Host "================================================" -ForegroundColor Green
Write-Host "[OK] DESPLIEGUE COMPLETADO!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""

Write-Host "[NEXT] PROXIMOS PASOS:" -ForegroundColor Yellow
Write-Host "1. Ve a Firebase Console: https://console.firebase.google.com" -ForegroundColor White
Write-Host "2. Selecciona proyecto: app-movil-psf" -ForegroundColor White
Write-Host "3. Habilita Autenticacion -> Email/Password" -ForegroundColor White
Write-Host "4. Crea bucket de Storage (si no existe)" -ForegroundColor White
Write-Host "5. Crea usuario admin en Cloud Shell:" -ForegroundColor White
Write-Host "   const admin = require('firebase-admin');" -ForegroundColor Gray
Write-Host "   admin.initializeApp();" -ForegroundColor Gray
Write-Host "   const user = await admin.auth().getUserByEmail('admin@appmovil.local');" -ForegroundColor Gray
Write-Host "   await admin.auth().setCustomUserClaims(user.uid, { admin: true });" -ForegroundColor Gray
Write-Host "6. Ejecuta pruebas en la app" -ForegroundColor White
Write-Host ""

Write-Host "[URLS] URLs utiles:" -ForegroundColor Cyan
Write-Host "Firebase Console: https://console.firebase.google.com/project/app-movil-psf" -ForegroundColor White
Write-Host "Cloud Functions: https://console.cloud.google.com/functions/list?project=app-movil-psf" -ForegroundColor White
Write-Host "Firestore: https://console.firebase.google.com/project/app-movil-psf/firestore" -ForegroundColor White
Write-Host ""

Write-Host "[READY] Listo para pruebas!" -ForegroundColor Green
