
$files = Get-ChildItem -Path "lib" -Filter *.dart -Recurse
foreach ($file in $files) {
    Write-Host "Procesando: $($file.FullName)"
    $content = Get-Content $file.FullName -Raw
    
    # 1. Reemplazar CachedNetworkImage por Image.network
    $content = $content -replace "CachedNetworkImage\(", "Image.network("
    $content = $content -replace "imageUrl:", ""
    
    # 2. Reemplazar Image.file por Image.network(file.path)
    # Nota: Esto es una simplificación, pero funciona para la mayoría de nuestros casos
    $content = $content -replace "Image\.file\((.*?)\)", "Image.network(`$1.path)"
    
    Set-Content $file.FullName $content -NoNewline
}
Write-Host "✅ Limpieza completada con éxito."
