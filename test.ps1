# test.ps1
Write-Host "🧪 TEST RAPIDE ZERO TRUST" -ForegroundColor Blue

# 1. Vérifier les services
Write-Host "`n1. Services:" -ForegroundColor Yellow
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 2. Tester OPA
Write-Host "`n2. Test OPA:" -ForegroundColor Yellow
try {
    $policies = Invoke-RestMethod "http://localhost:8181/v1/policies" -ErrorAction Stop
    Write-Host "✅ OPA répond - $($policies.result.Count) politiques" -ForegroundColor Green
} catch {
    Write-Host "❌ OPA ne répond pas" -ForegroundColor Red
}

# 3. Tester Device Posture
Write-Host "`n3. Test Device Posture:" -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod "http://localhost:8082/health" -ErrorAction Stop
    Write-Host "✅ Device Posture répond - $($health.devices_count) devices" -ForegroundColor Green
} catch {
    Write-Host "❌ Device Posture ne répond pas" -ForegroundColor Red
}

# 4. Tester Backend
Write-Host "`n4. Test Backend:" -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod "http://localhost:5000/health" -ErrorAction Stop
    Write-Host "✅ Backend répond" -ForegroundColor Green
    Write-Host "   OPA connecté: $($health.opa_connected)" -ForegroundColor Cyan
    Write-Host "   Device Posture connecté: $($health.device_posture_connected)" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Backend ne répond pas" -ForegroundColor Red
}

# 5. Tester avec un device
Write-Host "`n5. Test enregistrement device:" -ForegroundColor Yellow
$deviceData = @{
    user_id = "admin-001"
    device_name = "Test-Laptop"
    os = "Windows 11"
    os_version_current = $true
    antivirus_active = $true
    firewall_enabled = $true
    disk_encrypted = $true
    screen_lock_enabled = $true
    malware_detected = $false
} | ConvertTo-Json

try {
    $device = Invoke-RestMethod "http://localhost:8082/api/register" -Method Post -Body $deviceData -ContentType "application/json"
    Write-Host "✅ Device enregistré: $($device.device_id)" -ForegroundColor Green
    Write-Host "   Score: $($device.assessment.score)" -ForegroundColor Cyan
    Write-Host "   Trusted: $($device.assessment.trusted)" -ForegroundColor Cyan
    
    # Tester l'accès avec ce device
    $headers = @{
        "X-User-Id" = "admin-001"
        "X-Device-Id" = $device.device_id
    }
    
    $data = Invoke-RestMethod "http://localhost:5000/api/data" -Headers $headers
    Write-Host "✅ Accès aux données: $($data.total) éléments" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Erreur: $($_.Exception.Message)" -ForegroundColor Red
}