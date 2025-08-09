# config.ps1

# All configuration variables in one place
$RG_NAME = "az-204-msal-obo-lab-rg"
$LOCATION = "westus"

# App Registration Names
$WEB_APP_NAME = "ContosoWebApp"
$API_APP_NAME = "ContosoApi"
$WEB_APP_DISPLAY_NAME = "Contoso Web Application"
$API_APP_DISPLAY_NAME = "Contoso Protected API"

# Local Development URLs
$WEB_APP_LOCAL_URL = "https://localhost:5001"
$API_LOCAL_URL = "https://localhost:7001"
$WEB_REDIRECT_URI = "$WEB_APP_LOCAL_URL/signin-oidc"

# Azure App Service Names (must be globally unique)
$WEB_APP_SERVICE_NAME = "contoso-web-app-20250809AM" # ensure uniqueness
$API_APP_SERVICE_NAME = "contoso-api-app-20250809AM" # ensure uniqueness

# App Service Plan
$APP_SERVICE_PLAN = "msal-obo-plan"

# Custom API Scope
$API_SCOPE_NAME = "User.Write"

# Project Folders
$WEB_PROJECT_FOLDER = "ContosoWebApp"
$API_PROJECT_FOLDER = "ContosoApi"

# Subscription ID handling
if ($env:AZURE_SUBSCRIPTION_ID) {
    $SUBSCRIPTION_ID = $env:AZURE_SUBSCRIPTION_ID
} else {
    $SUBSCRIPTION_ID = (az account show --query id -o tsv)
}

# Output configuration for transparency and troubleshooting
Write-Host "=== Lab Configuration ===" -ForegroundColor Green
Write-Host "Resource Group: $RG_NAME"
Write-Host "Location: $LOCATION"
Write-Host "Web App Name: $WEB_APP_NAME"
Write-Host "API App Name: $API_APP_NAME"
Write-Host "Web App Service: $WEB_APP_SERVICE_NAME"
Write-Host "API App Service: $API_APP_SERVICE_NAME"
Write-Host "Subscription ID: $SUBSCRIPTION_ID"
Write-Host "==============================" -ForegroundColor Green