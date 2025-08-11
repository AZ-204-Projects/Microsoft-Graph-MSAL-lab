. .\config.ps1

Write-Host "Creating API App Registration..." -ForegroundColor Yellow

# Check if exists
$existingApiApp = az ad app list --display-name "$API_APP_DISPLAY_NAME" --query "[0].appId" -o tsv
if ($existingApiApp) {
    Write-Host "API App Registration already exists. AppId: $existingApiApp"
    $apiAppId = $existingApiApp
} else {
    $apiAppId = az ad app create --display-name "$API_APP_DISPLAY_NAME" --query appId -o tsv
    Write-Host "API App Registration created. AppId: $apiAppId"
}

# (Continue with identifier URI, scope exposure, etc.)