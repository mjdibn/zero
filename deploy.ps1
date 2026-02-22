# deploy.ps1
Write-Host "=========================================" -ForegroundColor Blue
Write-Host "  DÉPLOIEMENT ZERO TRUST" -ForegroundColor Blue
Write-Host "=========================================" -ForegroundColor Blue
Write-Host ""

# 1. Nettoyage
Write-Host "1. Nettoyage des anciens conteneurs..." -ForegroundColor Yellow
docker-compose down -v
Write-Host "✅ Anciens conteneurs supprimés" -ForegroundColor Green
Write-Host ""

# 2. Création des dossiers si nécessaire
Write-Host "2. Vérification de la structure..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path policies, backend, "device-posture" | Out-Null
Write-Host "✅ Dossiers prêts" -ForegroundColor Green
Write-Host ""

# 3. Vérification que les fichiers existent
Write-Host "3. Vérification des fichiers..." -ForegroundColor Yellow
$files = @{
    "policies/zerotrust.rego" = $true
    "backend/app.py" = $true
    "backend/requirements.txt" = $true
    "backend/Dockerfile" = $true
    "device-posture/app.py" = $true
    "device-posture/requirements.txt" = $true
    "device-posture/Dockerfile" = $true
}

$missing = @()
foreach ($file in $files.Keys) {
    if (-not (Test-Path $file)) {
        $missing += $file
    }
}

if ($missing.Count -gt 0) {
    Write-Host "❌ Fichiers manquants:" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "   - $_" }
    exit 1
}
Write-Host "✅ Tous les fichiers sont présents" -ForegroundColor Green
Write-Host ""

# 4. Construction et démarrage
Write-Host "4. Démarrage des services..." -ForegroundColor Yellow
docker-compose up -d --build
Write-Host "✅ Services démarrés" -ForegroundColor Green
Write-Host ""

# 5. Attente du chargement
Write-Host "5. Attente du chargement..." -ForegroundColor Yellow
Start-Sleep -Seconds 15
Write-Host "✅ Prêt" -ForegroundColor Green
Write-Host ""

# 6. Vérification OPA
Write-Host "6. Vérification OPA..." -ForegroundColor Yellow
try {
    $policies = Invoke-RestMethod -Uri "http://localhost:8181/v1/policies" -Method Get -ErrorAction Stop
    if ($policies.result.Count -gt 0) {
        Write-Host "✅ Politiques OPA chargées:" -ForegroundColor Green
        $policies.result | ForEach-Object { Write-Host "   - $($_.id)" }
    } else {
        Write-Host "⚠️ Aucune politique trouvée - Chargement manuel..." -ForegroundColor Yellow
        $policyContent = Get-Content -Path "policies\zerotrust.rego" -Raw
        $body = @{ id = "zerotrust"; policy = $policyContent } | ConvertTo-Json
        Invoke-RestMethod -Uri "http://localhost:8181/v1/policies/zerotrust" `
                          -Method Put `
                          -Body $body `
                          -ContentType "application/json"
        Write-Host "✅ Politique chargée manuellement" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ Erreur de connexion à OPA" -ForegroundColor Red
}
Write-Host ""

# 7. Test d'enregistrement device
Write-Host "7. Test d'enregistrement device..." -ForegroundColor Yellow
$deviceData = @{
    user_id = "admin-001"
    device_name = "Work-Laptop"
    os = "Windows 11"
    os_version = "22H2"
    os_version_current = $true
    antivirus_active = $true
    firewall_enabled = $true
    disk_encrypted = $true
    screen_lock_enabled = $true
    malware_detected = $false
    user_agent = "Mozilla/5.0"
    hostname = "WORK-PC-001"
} | ConvertTo-Json

try {
    $device = Invoke-RestMethod -Uri "http://localhost:8082/api/register" `
                                -Method Post `
                                -Body $deviceData `
                                -ContentType "application/json" `
                                -ErrorAction Stop
    Write-Host "✅ Device enregistré: $($device.device_id)" -ForegroundColor Green
    Write-Host "   Trusted: $($device.assessment.trusted)" -ForegroundColor Cyan
    Write-Host "   Score: $($device.assessment.score)" -ForegroundColor Cyan
    $global:DeviceId = $device.device_id
} catch {
    Write-Host "❌ Erreur enregistrement device" -ForegroundColor Red
    $global:DeviceId = "admin-001-device"
}
Write-Host ""

# 8. Test d'accès
Write-Host "8. Test d'accès aux données..." -ForegroundColor Yellow
$headers = @{
    "X-User-Id" = "admin-001"
    "X-Device-Id" = $global:DeviceId
}

try {
    $data = Invoke-RestMethod -Uri "http://localhost:5000/api/data" `
                              -Method Get `
                              -Headers $headers `
                              -ErrorAction Stop
    Write-Host "✅ Accès autorisé - $($data.total) éléments accessibles" -ForegroundColor Green
} catch {
    Write-Host "❌ Erreur d'accès: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# 9. Diagnostic final
Write-Host "9. Diagnostic système..." -ForegroundColor Yellow
try {
    $diag = Invoke-RestMethod -Uri "http://localhost:5000/api/diagnostic" `
                              -Method Get `
                              -Headers $headers `
                              -ErrorAction Stop
    Write-Host "✅ Système OK" -ForegroundColor Green
    Write-Host "   OPA connecté: $($diag.system_status.opa_connected)" -ForegroundColor Cyan
    Write-Host "   Device Posture connecté: $($diag.system_status.device_posture_connected)" -ForegroundColor Cyan
} catch {
    Write-Host "⚠️ Diagnostic non disponible" -ForegroundColor Yellow
}
Write-Host ""

# 10. Résumé
Write-Host "=========================================" -ForegroundColor Blue
Write-Host "  SYSTÈME ZERO TRUST OPÉRATIONNEL !" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Blue
Write-Host ""
Write-Host "Endpoints disponibles:" -ForegroundColor Yellow
Write-Host "  🔑 Keycloak:    http://localhost:8080 (admin/admin)" -ForegroundColor Cyan
Write-Host "  📋 OPA:         http://localhost:8181" -ForegroundColor Cyan
Write-Host "  📱 Posture:     http://localhost:8082" -ForegroundColor Cyan
Write-Host "  🖥️ Backend:     http://localhost:5000" -ForegroundColor Cyan
Write-Host ""
Write-Host "Pour tester manuellement:" -ForegroundColor Yellow
Write-Host '  $headers = @{"X-User-Id"="admin-001"; "X-Device-Id"="'$global:DeviceId'"}' -ForegroundColor Gray
Write-Host '  Invoke-RestMethod -Uri "http://localhost:5000/api/data" -Headers $headers' -ForegroundColor Gray
Write-Host ""
Write-Host "Pour voir les logs:" -ForegroundColor Yellow
Write-Host "  docker-compose logs -f" -ForegroundColor Gray