$url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co'
$key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw'
$headers = @{
    'apikey' = $key
    'Authorization' = "Bearer $key"
}

# Fetch OpenAPI spec to inspect tables
$openapi = Invoke-RestMethod -Uri "$url/rest/v1/?apikey=$key" -Headers $headers -Method GET

Write-Host "=== Columns for public.notificaciones ==="
$openapi.definitions.notificaciones.properties.PSObject.Properties | ForEach-Object {
    Write-Host "$($_.Name) : $($_.Value.type) (format: $($_.Value.format))"
}

Write-Host "`n=== Columns for public.notificaciones_globales ==="
$openapi.definitions.notificaciones_globales.properties.PSObject.Properties | ForEach-Object {
    Write-Host "$($_.Name) : $($_.Value.type) (format: $($_.Value.format))"
}
