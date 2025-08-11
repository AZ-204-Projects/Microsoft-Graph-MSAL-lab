# 01-create-app-registrations.ps1

. .\config.ps1

Write-Host "Creating App Registrations..." -ForegroundColor Yellow

# Create API App Registration first (to get App ID for scope)
Write-Host "Creating API App Registration: $API_APP_NAME"
$apiAppId = az ad app create --display-name "$API_APP_DISPLAY_NAME" --query appId -o tsv

if (-not $apiAppId) {
    Write-Error "Failed to create API app registration"
    exit 1
}

Write-Host "API App ID: $apiAppId"

# Generate a client secret for the API
$apiSecret = az ad app credential reset --id $apiAppId --query password -o tsv
Write-Host "API Secret generated (store securely)"

# Create the API scope URI
$apiScopeUri = "api://$apiAppId"

# Add Application ID URI to the API app
az ad app update --id $apiAppId --identifier-uris "$apiScopeUri"

# Expose API scope for the API app
$scopeJson = @"
{
    "adminConsentDescription": "Allow the application to write user data on behalf of the signed-in user",
    "adminConsentDisplayName": "Write user data",
    "id": "$(New-Guid)",
    "isEnabled": true,
    "type": "User",
    "userConsentDescription": "Allow the application to write your user data on your behalf",
    "userConsentDisplayName": "Write your user data",
    "value": "$API_SCOPE_NAME"
}
"@

$scopeFile = "api-scope.json"
$scopeJson | Out-File -FilePath $scopeFile -Encoding UTF8

az ad app update --id $apiAppId --set oauth2Permissions=@$scopeFile
Remove-Item $scopeFile

# Create Web App Registration
Write-Host "Creating Web App Registration: $WEB_APP_NAME"
$webAppId = az ad app create --display-name "$WEB_APP_DISPLAY_NAME" --query appId -o tsv

if (-not $webAppId) {
    Write-Error "Failed to create web app registration"
    exit 1
}

Write-Host "Web App ID: $webAppId"

# Generate a client secret for the Web App
$webSecret = az ad app credential reset --id $webAppId --query password -o tsv
Write-Host "Web Secret generated (store securely)"

# Add redirect URI to Web App
az ad app update --id $webAppId --web-redirect-uris "$WEB_REDIRECT_URI"

# Add API permissions to Web App (custom scope)
$apiPermissionId = (az ad app show --id $apiAppId --query "oauth2Permissions[0].id" -o tsv)
az ad app permission add --id $webAppId --api $apiAppId --api-permissions "$apiPermissionId=Scope"

# Add Microsoft Graph permissions to API app
az ad app permission add --id $apiAppId --api 00000003-0000-0000-c000-000000000000 --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope

# Grant admin consent for both apps
Write-Host "Granting admin consent for Web App..."
az ad app permission admin-consent --id $webAppId

Write-Host "Granting admin consent for API App..."
az ad app permission admin-consent --id $apiAppId

# Save configuration to file for other scripts
$configOutput = @"
# Generated App Registration IDs
`$WEB_APP_ID = "$webAppId"
`$API_APP_ID = "$apiAppId"
`$WEB_APP_SECRET = "$webSecret"
`$API_APP_SECRET = "$apiSecret"
`$API_SCOPE_URI = "$apiScopeUri/$API_SCOPE_NAME"
`$TENANT_ID = "$((az account show --query tenantId -o tsv))"
"@

$configOutput | Out-File -FilePath "app-config.ps1" -Encoding UTF8

Write-Host "App registrations created successfully!" -ForegroundColor Green
Write-Host "Configuration saved to app-config.ps1" -ForegroundColor Green