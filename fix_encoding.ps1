$archivos = @(
    'lib\services\baqueano_ia_service.dart',
    'lib\services\capacitacion_service.dart',
    'lib\services\gemini_service.dart',
    'lib\services\gemini_learner.dart',
    'lib\services\el_guia_engine.dart',
    'lib\widgets\guia_overlay.dart',
    'lib\screens\admin_guia_educador_screen.dart',
    'lib\services\truco_argentino_skill.dart'
)

foreach ($rel in $archivos) {
    $path = "c:\CapitanYA\capitan11.5.2026\$rel"
    if (Test-Path $path) {
        $txt = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
        $orig = $txt
        $txt = $txt -replace 'Ã±', 'ñ'
        $txt = $txt -replace 'Ã¡', 'á'
        $txt = $txt -replace 'Ã©', 'é'
        $txt = $txt -replace 'Ã­', 'í'
        $txt = $txt -replace 'Ã³', 'ó'
        $txt = $txt -replace 'Ãº', 'ú'
        $txt = $txt -replace 'Â¿', '¿'
        $txt = $txt -replace 'Â¡', '¡'
        $txt = $txt -replace 'Ã"', 'Ó'
        $txt = $txt -replace 'Ã', 'Á'
        if ($txt -ne $orig) {
            [System.IO.File]::WriteAllText($path, $txt, [System.Text.Encoding]::UTF8)
            Write-Host "Corregido: $rel"
        } else {
            Write-Host "Sin cambios: $rel"
        }
    }
}
Write-Host "Listo."
