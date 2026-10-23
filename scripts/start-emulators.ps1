$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
  $vitrinaJava = 'C:\Program Files\Android\Android Studio\jbr'
  if (Test-Path -LiteralPath "$vitrinaJava\bin\java.exe") {
    $env:JAVA_HOME = $vitrinaJava
    $env:PATH = "$vitrinaJava\bin;$env:PATH"
  }
}
firebase.cmd emulators:start --project demo-vitrina-local --only auth,firestore,functions,storage
