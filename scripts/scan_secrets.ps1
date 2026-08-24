param([string]$Root = (Get-Location))

$ErrorActionPreference = 'Stop'
$patterns = @(
  @{ Name = 'Groq'; Regex = 'gsk_[A-Za-z0-9_-]{16,}' },
  @{ Name = 'Google API'; Regex = 'AIza[0-9A-Za-z_-]{20,}' },
  @{ Name = 'Private key'; Regex = '-----BEGIN (?:RSA )?PRIVATE KEY-----' },
  @{ Name = 'JWT'; Regex = 'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}' }
)
$exclude = @('!.git/**','!build/**','!.dart_tool/**','!public/**','!android/app/google-services.json')
$found = @()
foreach ($pattern in $patterns) {
  $matches = rg -l --hidden --glob $exclude --pcre2 $pattern.Regex $Root 2>$null
  foreach ($match in $matches) { $found += "[$($pattern.Name)] $match" }
}
# Los APK se analizan como binarios para detectar claves que hayan quedado
# incrustadas en artefactos locales; solo se informa el nombre del archivo.
foreach ($pattern in $patterns) {
  $matches = rg -a -l --pcre2 $pattern.Regex (Join-Path $Root '*.apk') 2>$null
  foreach ($match in $matches) { $found += "[$($pattern.Name)] $match" }
}
if ($found.Count -gt 0) {
  Write-Error ("Posibles secretos detectados (valores ocultos):`n" + ($found -join "`n"))
  exit 1
}
Write-Host 'Escaneo de secretos aprobado: no se detectaron patrones privados.'
exit 0
