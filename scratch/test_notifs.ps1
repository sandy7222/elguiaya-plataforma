$url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co'
$key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw'
$headers = @{
    'apikey' = $key
    'Authorization' = "Bearer $key"
    'Content-Type' = 'application/json'
}

Write-Host "--- Querying tables ---"
try {
    $res1 = Invoke-RestMethod -Uri "$url/rest/v1/notificaciones?limit=1" -Headers $headers -Method GET
    Write-Host "notificaciones table exists. Count returned: $($res1.Count)"
} catch {
    Write-Host "Error notificaciones: $_"
}

try {
    $res2 = Invoke-RestMethod -Uri "$url/rest/v1/notificaciones_globales?limit=1" -Headers $headers -Method GET
    Write-Host "notificaciones_globales table exists. Count returned: $($res2.Count)"
} catch {
    Write-Host "Error notificaciones_globales: $_"
}
