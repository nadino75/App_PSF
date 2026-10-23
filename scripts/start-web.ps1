param([switch]$Demo)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
if ($Demo) {
  flutter run -d web-server --web-hostname 127.0.0.1 --web-port 7357 --dart-define=DEMO_MODE=true
} else {
  flutter run -d web-server --web-hostname 127.0.0.1 --web-port 7357 --dart-define=USE_EMULATORS=true
}
