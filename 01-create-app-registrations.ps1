# 01-create-app-registrations.ps1

. .\config.ps1

Write-Host "Creating App Registrations..." -ForegroundColor Yellow

# --- API App Registration ---
Write-Host "Creating or updating API App Registration: $API_APP_NAME"

# Delete any existing app registration with same display name (for idempotency)
$existingApiApp = az ad app list --display-name "$API_APP_DISPLAY_NAME" --query "[0].appId" -o tsv
if ($existingApiApp) {
    Write-Host "Deleting existing API app registration $existingApiApp"
    az ad app delete --id $existingApiApp
}

# Create API App Registration
$apiAppId = az ad app create --display-name "$API_APP_DISPLAY_NAME" --query appId -o tsv
if ($LASTEXITCODE -ne 0 -or -not $apiAppId) { throw "Failed to create API app registration" }
az ad app owner add --id $apiAppId --owner-object-id $OWNER_OBJECT_ID
if ($LASTEXITCODE -ne 0 ) { throw "Failed to create API owner" }

Read-Host "Check Azure Portal or CLI to confirm Entra ID app registration of $apiAppId, then press Enter to continue..."
# throw "Done with API App creation!"

# Create a client secret for API
$apiSecret = az ad app credential reset --id $apiAppId --append --query password -o tsv
if ($LASTEXITCODE -ne 0 -or -not $apiSecret) { throw "Failed to create API app secret" }

Read-Host "Check Azure Portal or CLI to confirm client secret starts with: $($apiSecret.Substring(0,3)), then press Enter to continue..."
# throw "Done with Create a client secret for API!"


# Add API scope (User.Write) to API app registration
$apiScopeUri = "api://$apiAppId"
az ad app update --id $apiAppId --identifier-uris $apiScopeUri
if ($LASTEXITCODE -ne 0) { throw "Failed to set API identifier URI" }
Read-Host "Check Azure Portal or CLI to confirm Application ID URI is $apiScopeUri, then press Enter to continue..."
# throw "Done with Add Application ID URI!"


# Get the object ID of your app registration
$appObjectId = az ad app show --id $apiAppId --query id -o tsv

# Build the JSON for the new scope
$scope = @{
    id = $API_SCOPE_GUID
    type = "User"
    value = $API_SCOPE_NAME
    adminConsentDisplayName = "Update user profile"
    adminConsentDescription = "Allows updating user profile via the API"
    isEnabled = $true
}

$bodyObject = @{
    api = @{
        oauth2PermissionScopes = @($scope)
    }
}

# Convert to JSON and save to a temporary file
$body = $bodyObject | ConvertTo-Json -Compress -Depth 5
$tempFile = "temp-scope-update.json"
$body | Out-File -FilePath $tempFile -Encoding UTF8 -NoNewline

Write-Host "JSON Body: $body"

# Use the file-based approach for the REST call
az rest --method PATCH `
  --url "https://graph.microsoft.com/v1.0/applications/$appObjectId" `
  --headers "Content-Type=application/json" `
  --body "@$tempFile"

# Clean up the temporary file
Remove-Item $tempFile -ErrorAction SilentlyContinue

if ($LASTEXITCODE -ne 0) { 
    throw "Failed to add API scope" 
}

Read-Host "Check Azure Portal or CLI to confirm app permissions updated, then press Enter to continue..."
# throw "Done with permissions updated!"

# --- Web App Registration ---
Write-Host "Creating or updating Web App Registration: $WEB_APP_NAME"

$existingWebApp = az ad app list --display-name "$WEB_APP_DISPLAY_NAME" --query "[0].appId" -o tsv
if ($existingWebApp) {
    Write-Host "Deleting existing Web app registration $existingWebApp"
    az ad app delete --id $existingWebApp
}

# Create Web App Registration
$webAppId = az ad app create --display-name "$WEB_APP_DISPLAY_NAME" --query appId -o tsv
if ($LASTEXITCODE -ne 0 -or -not $webAppId) { throw "Failed to create Web app registration" }

az ad app owner add --id $webAppId --owner-object-id $OWNER_OBJECT_ID
if ($LASTEXITCODE -ne 0 ) { throw "Failed to create Web app owner" }

Read-Host "Check Azure Portal or CLI to confirm Entra ID app registration of $webAppId, then press Enter to continue..."
# throw "Done with Web App creation!"

# Create a client secret for Web
$webSecret = az ad app credential reset --id $webAppId --append --query password -o tsv
if ($LASTEXITCODE -ne 0 -or -not $webSecret) { throw "Failed to create Web app secret" }

Read-Host "Check Azure Portal or CLI to confirm client secret starts with: $($webSecret.Substring(0,3)), then press Enter to continue..."
# throw "Done with Create a client secret for Web app!"

# Add redirect URIs
az ad app update --id $webAppId --web-redirect-uris "$WEB_REDIRECT_URI"
if ($LASTEXITCODE -ne 0) { throw "Failed to update Web app redirect URIs" }
Read-Host "Check Azure Portal or CLI to confirm Application ID URI is $WEB_REDIRECT_URI, then press Enter to continue..."
throw "Done with Add redirect URIs!"

# --- Permissions: Grant Web App permission to call API (custom scope) and Microsoft Graph ---
Write-Host "Configuring Web App API permissions..."

# Add permission for custom API scope
az ad app permission add --id $webAppId --api $apiAppId --api-permissions "$API_SCOPE_GUID=Delegated"
if ($LASTEXITCODE -ne 0) { throw "Failed to add API permission to Web app" }

# Add MS Graph User.ReadWrite permission
az ad app permission add --id $webAppId --api 00000003-0000-0000-c000-000000000000 --api-permissions "User.ReadWrite=Delegated"
if ($LASTEXITCODE -ne 0) { throw "Failed to add Graph permission to Web app" }

# Grant admin consent for all permissions (if you have permissions to do so)
Write-Host "Granting admin consent for Web app permissions (requires admin)..."
az ad app permission admin-consent --id $webAppId

# --- Expose API permissions for the API App ---
Write-Host "Exposing API permissions on API app..."

# Add MS Graph delegated permissions to API app (so it can acquire tokens OBO)
az ad app permission add --id $apiAppId --api 00000003-0000-0000-c000-000000000000 --api-permissions "User.ReadWrite=Delegated"
if ($LASTEXITCODE -ne 0) { throw "Failed to add Graph delegated permission to API app" }

# Grant admin consent for API app (so OBO works)
az ad app permission admin-consent --id $apiAppId

# --- Output configuration ---
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