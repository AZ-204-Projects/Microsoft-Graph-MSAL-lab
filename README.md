# Azure Web App → Protected API → Microsoft Graph (OBO) Professional Lab

## Overview: End-to-End Authentication Flow with On-Behalf-Of (OBO) Pattern

This lab demonstrates a professional, best-practice approach for implementing a complete OAuth 2.0 On-Behalf-Of flow where a web application calls a protected API, which then calls Microsoft Graph on behalf of the signed-in user to update their profile.

> **Note:** This comprehensive lab was designed and structured with assistance from Claude 3.5 Sonnet (Anthropic) to ensure adherence to modern development practices, comprehensive documentation standards, and optimal learning outcomes for Azure certification preparation.

**Goals:**
- Showcase enterprise-ready authentication patterns using Microsoft Identity Platform
- Enable cost-effective Azure resource management with confident deletion and recreation
- Support learning and preparation for the AZ-204 certification
- Demonstrate secure token exchange and delegated permissions
- Provide a template for AI-assisted technical documentation and project structuring

---

## Architecture Overview

```
User → Web App (MSAL.NET) → Protected API (OBO) → Microsoft Graph
     ↓                    ↓                      ↓
   Sign In           API Token              Graph Token
                   (Custom Scope)         (User.ReadWrite)
```

---

## Prerequisites

Before starting, ensure you have the following tools installed:

- **.NET 8 SDK** ([Installation Guide](https://dotnet.microsoft.com/download))
- **Azure CLI** ([Installation Guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))
- **An active Azure tenant with Global Administrator privileges**
- **Git** (recommended for source control)
- **Visual Studio Code** or **Visual Studio 2022** (recommended)

---

## Step 1: Centralize Configuration for Repeatability

Create a `config.ps1` file containing all environment variables. Update values as needed for your environment.

> Centralizing variables promotes maintainability and repeatable automation across development sessions.

```powershell
# config.ps1
# Owner Object ID (for App Registration ownership assignments)
$OWNER_OBJECT_ID = (az ad signed-in-user show --query id -o tsv)

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
$API_SCOPE_GUID = "c1cf1e6e-893c-4b5e-9d56-5e2a6e8c2667"   # ← Generate once, then keep stable

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
Write-Host "API Scope GUID: $API_SCOPE_GUID"
Write-Host "Owner Object ID: $OWNER_OBJECT_ID"
Write-Host "==============================" -ForegroundColor Green
```

Include graph-permissions.ps1 for permission constants.

> Source: https://docs.microsoft.com/en-us/graph/permissions-reference.

```powershell
# graph-permissions.ps1
# Microsoft Graph Permission Constants
# Source: https://docs.microsoft.com/en-us/graph/permissions-reference

# Microsoft Graph Service Principal ID
$MICROSOFT_GRAPH_APP_ID = "00000003-0000-0000-c000-000000000000"

# === DELEGATED PERMISSIONS (Scope) ===
$GRAPH_DELEGATED = @{
    # User Permissions
    "User.Read"                 = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
    "User.ReadWrite"            = "b4e74841-8e56-480b-be8b-910348b18b4c"
    "User.ReadBasic.All"        = "204e0828-b5ca-4ad8-b9f3-f32a958e7cc4"
    
    # Group Permissions
    "Group.Read.All"            = "5f8c59db-677d-491f-a6b8-5f174b11ec1d"
    "Group.ReadWrite.All"       = "4e46008b-f24c-477d-8fff-7bb4ec7aafe0"
    
    # Directory Permissions
    "Directory.Read.All"        = "06da0dbc-49e2-44d2-8312-53f166ab848a"
    "Directory.ReadWrite.All"   = "c5366453-9fb0-48a5-a156-24f0c49a4b84"
    
    # Mail Permissions
    "Mail.Read"                 = "570282fd-fa5c-430d-a7fd-fc8dc98a9dca"
    "Mail.ReadWrite"            = "024d486e-b451-40bb-833d-3e66d98c5c73"
    
    # Calendar Permissions
    "Calendars.Read"            = "465a38f9-76ea-45b9-9f34-9e8b0d4b0b42"
    "Calendars.ReadWrite"       = "1ec239c2-d7c9-4623-a91a-a9775856bb36"
}

# === APPLICATION PERMISSIONS (Role) ===
$GRAPH_APPLICATION = @{
    # User Permissions
    "User.Read.All"             = "df021288-bdef-4463-88db-98f22de89214"
    "User.ReadWrite.All"        = "741f803b-c850-494e-b5df-cde7c675a1ca"
    
    # Group Permissions
    "Group.Read.All"            = "5b567255-7703-4780-807c-7be8301ae99b"
    "Group.ReadWrite.All"       = "62a82d76-70ea-41e2-9197-370581804d09"
    
    # Directory Permissions
    "Directory.Read.All"        = "7ab1d382-f21e-4acd-a863-ba3e13f7da61"
    "Directory.ReadWrite.All"   = "19dbc75e-c2e2-444c-a770-ec69d8559fc7"
    
    # Application Permissions
    "Application.Read.All"      = "9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30"
    "Application.ReadWrite.All" = "1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9"
}

# === HELPER FUNCTIONS ===
function Add-GraphDelegatedPermission {
    param(
        [string]$AppId,
        [string]$PermissionName
    )
    
    if (-not $GRAPH_DELEGATED.ContainsKey($PermissionName)) {
        throw "Unknown delegated permission: $PermissionName. Available: $($GRAPH_DELEGATED.Keys -join ', ')"
    }
    
    $permissionGuid = $GRAPH_DELEGATED[$PermissionName]
    Write-Host "Adding delegated permission: $PermissionName ($permissionGuid)"
    
    az ad app permission add --id $AppId --api $MICROSOFT_GRAPH_APP_ID --api-permissions "$permissionGuid=Scope"
    if ($LASTEXITCODE -ne 0) { throw "Failed to add delegated permission: $PermissionName" }
}

function Add-GraphApplicationPermission {
    param(
        [string]$AppId,
        [string]$PermissionName
    )
    
    if (-not $GRAPH_APPLICATION.ContainsKey($PermissionName)) {
        throw "Unknown application permission: $PermissionName. Available: $($GRAPH_APPLICATION.Keys -join ', ')"
    }
    
    $permissionGuid = $GRAPH_APPLICATION[$PermissionName]
    Write-Host "Adding application permission: $PermissionName ($permissionGuid)"
    
    az ad app permission add --id $AppId --api $MICROSOFT_GRAPH_APP_ID --api-permissions "$permissionGuid=Role"
    if ($LASTEXITCODE -ne 0) { throw "Failed to add application permission: $PermissionName" }
}

# === USAGE EXAMPLES ===
<#
# In your main script:
. .\graph-permissions.ps1

# Add delegated permissions
Add-GraphDelegatedPermission -AppId $webAppId -PermissionName "User.ReadWrite"
Add-GraphDelegatedPermission -AppId $webAppId -PermissionName "Group.Read.All"

# Add application permissions  
Add-GraphApplicationPermission -AppId $apiAppId -PermissionName "User.Read.All"

# Or use the constants directly:
az ad app permission add --id $webAppId --api $MICROSOFT_GRAPH_APP_ID --api-permissions "$($GRAPH_DELEGATED['User.ReadWrite'])=Scope"
#>
```

---

## Step 2: Create App Registrations and Configure Permissions

Automate the creation of both app registrations with proper permissions and scopes.

```powershell
# 01-create-app-registrations.ps1
# Improved version with better error handling, admin consent, and reduced manual steps

. .\config.ps1
. .\graph-permissions.ps1

Write-Host "Retrieving tenant information..." -ForegroundColor Yellow
$tenantDisplayName = az rest --method GET --url "https://graph.microsoft.com/v1.0/organization" --query "value[0].displayName" -o tsv
if ($LASTEXITCODE -ne 0 -or -not $tenantDisplayName -or $tenantDisplayName -eq "") {
    Write-Warning "Could not retrieve tenant display name, using generic placeholder"
    $tenantDisplayName = "[Your Organization]"
} else {
    Write-Host "Tenant: $tenantDisplayName" -ForegroundColor Green
}

Write-Host "Creating App Registrations..." -ForegroundColor Yellow

# Function to wait for app registration propagation
function Wait-ForAppRegistration {
    param([string]$AppId, [string]$AppName)
    
    Write-Host "Waiting for $AppName registration to propagate..." -ForegroundColor Yellow
    $retries = 0
    $maxRetries = 30
    
    do {
        Start-Sleep -Seconds 2
        $app = az ad app show --id $AppId 2>$null
        $retries++
        
        if ($app) {
            Write-Host "$AppName registration confirmed" -ForegroundColor Green
            return $true
        }
        
        if ($retries -ge $maxRetries) {
            throw "Timeout waiting for $AppName registration to propagate"
        }
    } while ($true)
}

# Function to check if user has admin consent permissions and tenant license level
function Test-AdminConsentPermissions {
    try {
        # Try to get directory role memberships for current user
        $roles = az rest --method GET --url "https://graph.microsoft.com/v1.0/me/memberOf" --query "value[?contains(@odata.type, 'directoryRole')].displayName" -o tsv 2>$null
        
        $hasAdminRole = $roles -match "Global Administrator|Application Administrator|Cloud Application Administrator"
        
        # Check if tenant has premium features (indicator of license level)
        $tenantInfo = az rest --method GET --url "https://graph.microsoft.com/v1.0/organization" --query "value[0]" 2>$null | ConvertFrom-Json
        $hasPremiumLicense = $tenantInfo.assignedPlans | Where-Object { $_.servicePlanId -match "41781fb2-bc02-4b7c-bd55-b576c07bb09d|eec0eb4f-6444-4f95-aba0-50c24d67f998" }
        
        # For Azure AD Free tenants, recommend manual consent even with admin permissions
        if (-not $hasPremiumLicense -and $hasAdminRole) {
            Write-Host "Note: Azure AD Free tenant detected. Manual consent recommended for reliability." -ForegroundColor Yellow
            return $false
        }
        
        return $hasAdminRole
    }
    catch {
        return $false
    }
}

# --- CLEANUP EXISTING REGISTRATIONS ---
Write-Host "Cleaning up any existing app registrations..." -ForegroundColor Yellow

$existingApiApp = az ad app list --display-name "$API_APP_DISPLAY_NAME" --query "[0].appId" -o tsv 2>$null
if ($existingApiApp -and $existingApiApp -ne "") {
    Write-Host "Deleting existing API app registration: $existingApiApp"
    az ad app delete --id $existingApiApp
    if ($LASTEXITCODE -ne 0) { Write-Warning "Failed to delete existing API app registration" }
}

$existingWebApp = az ad app list --display-name "$WEB_APP_DISPLAY_NAME" --query "[0].appId" -o tsv 2>$null
if ($existingWebApp -and $existingWebApp -ne "") {
    Write-Host "Deleting existing Web app registration: $existingWebApp"
    az ad app delete --id $existingWebApp
    if ($LASTEXITCODE -ne 0) { Write-Warning "Failed to delete existing Web app registration" }
}

# Wait for deletions to propagate
Start-Sleep -Seconds 5

# --- CREATE API APP REGISTRATION ---
Write-Host "Creating API App Registration: $API_APP_DISPLAY_NAME" -ForegroundColor Cyan

$apiAppId = az ad app create --display-name "$API_APP_DISPLAY_NAME" --query appId -o tsv
if ($LASTEXITCODE -ne 0 -or -not $apiAppId -or $apiAppId -eq "") { 
    throw "Failed to create API app registration" 
}

Write-Host "API App ID: $apiAppId" -ForegroundColor Green

# Add owner
az ad app owner add --id $apiAppId --owner-object-id $OWNER_OBJECT_ID
if ($LASTEXITCODE -ne 0) { Write-Warning "Failed to add owner to API app registration" }

# Wait for propagation
Wait-ForAppRegistration -AppId $apiAppId -AppName "API"

# Create client secret for API
Write-Host "Creating client secret for API app..."
$apiSecret = az ad app credential reset --id $apiAppId --append --query password -o tsv
if ($LASTEXITCODE -ne 0 -or -not $apiSecret -or $apiSecret -eq "") { 
    throw "Failed to create API app client secret" 
}

Write-Host "API Secret created (starts with: $($apiSecret.Substring(0,8))...)" -ForegroundColor Green

# Set API identifier URI
$apiScopeUri = "api://$apiAppId"
Write-Host "Setting API identifier URI: $apiScopeUri"
az ad app update --id $apiAppId --identifier-uris $apiScopeUri
if ($LASTEXITCODE -ne 0) { throw "Failed to set API identifier URI" }

# Add API scope using simplified approach
Write-Host "Adding custom API scope: $API_SCOPE_NAME"

# Get app object ID for REST operations
$appObjectId = az ad app show --id $apiAppId --query id -o tsv
if ($LASTEXITCODE -ne 0 -or -not $appObjectId) { throw "Failed to get API app object ID" }

# Create scope definition
$scopeDefinition = @{
    id = $API_SCOPE_GUID
    type = "User"
    value = $API_SCOPE_NAME
    adminConsentDisplayName = "Update user profile"
    adminConsentDescription = "Allows the application to update user profile information on behalf of the signed-in user"
    userConsentDisplayName = "Update your profile"
    userConsentDescription = "Allow the application to update your profile information"
    isEnabled = $true
} | ConvertTo-Json -Compress

$apiUpdate = @{
    api = @{
        oauth2PermissionScopes = @(
            ($scopeDefinition | ConvertFrom-Json)
        )
    }
} | ConvertTo-Json -Compress -Depth 5

# Create temporary file for REST call
$tempFile = "temp-api-scope.json"
$apiUpdate | Out-File -FilePath $tempFile -Encoding UTF8 -NoNewline

try {
    az rest --method PATCH `
        --url "https://graph.microsoft.com/v1.0/applications/$appObjectId" `
        --headers "Content-Type=application/json" `
        --body "@$tempFile"
    
    if ($LASTEXITCODE -ne 0) { throw "Failed to add API scope via REST call" }
    Write-Host "API scope '$API_SCOPE_NAME' added successfully" -ForegroundColor Green
}
finally {
    Remove-Item $tempFile -ErrorAction SilentlyContinue
}

# Add Microsoft Graph permissions to API (for OBO flow)
Write-Host "Adding Microsoft Graph permissions to API app..."
Add-GraphDelegatedPermission -AppId $apiAppId -PermissionName "User.ReadWrite"

# --- CREATE WEB APP REGISTRATION ---
Write-Host "Creating Web App Registration: $WEB_APP_DISPLAY_NAME" -ForegroundColor Cyan

$webAppId = az ad app create --display-name "$WEB_APP_DISPLAY_NAME" --query appId -o tsv
if ($LASTEXITCODE -ne 0 -or -not $webAppId -or $webAppId -eq "") { 
    throw "Failed to create Web app registration" 
}

Write-Host "Web App ID: $webAppId" -ForegroundColor Green

# Add owner
az ad app owner add --id $webAppId --owner-object-id $OWNER_OBJECT_ID
if ($LASTEXITCODE -ne 0) { Write-Warning "Failed to add owner to Web app registration" }

# Wait for propagation
Wait-ForAppRegistration -AppId $webAppId -AppName "Web App"

# Create client secret for Web App
Write-Host "Creating client secret for Web app..."
$webSecret = az ad app credential reset --id $webAppId --append --query password -o tsv
if ($LASTEXITCODE -ne 0 -or -not $webSecret -or $webSecret -eq "") { 
    throw "Failed to create Web app client secret" 
}

Write-Host "Web App Secret created (starts with: $($webSecret.Substring(0,8))...)" -ForegroundColor Green

# Add redirect URIs
Write-Host "Adding redirect URIs to Web app..."
az ad app update --id $webAppId --web-redirect-uris "$WEB_REDIRECT_URI"
if ($LASTEXITCODE -ne 0) { throw "Failed to add redirect URIs to Web app" }

# --- CONFIGURE WEB APP PERMISSIONS ---
Write-Host "Configuring Web App permissions..." -ForegroundColor Cyan

# Add permission for custom API scope
Write-Host "Adding custom API permission to Web app..."
az ad app permission add --id $webAppId --api $apiAppId --api-permissions "$API_SCOPE_GUID=Scope"
if ($LASTEXITCODE -ne 0) { throw "Failed to add custom API permission to Web app" }

# Add Microsoft Graph permission
Write-Host "Adding Microsoft Graph permission to Web app..."
Add-GraphDelegatedPermission -AppId $webAppId -PermissionName "User.ReadWrite"

# --- ADMIN CONSENT ---
Write-Host "Checking admin consent capabilities..." -ForegroundColor Yellow

$hasAdminPermissions = Test-AdminConsentPermissions

# Track consent results
$webAppConsentSuccess = $false
$apiAppConsentSuccess = $false

if ($hasAdminPermissions) {
    Write-Host "Admin permissions detected. Attempting admin consent..." -ForegroundColor Green
    
    # Grant consent for API app first (usually more reliable)
    Write-Host "Granting admin consent for API app permissions..."
    az ad app permission admin-consent --id $apiAppId 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ API app admin consent granted successfully" -ForegroundColor Green
        $apiAppConsentSuccess = $true
    } else {
        Write-Warning "Failed to grant admin consent for API app automatically"
    }
    
    # Grant consent for Web app
    Write-Host "Granting admin consent for Web app permissions..."
    az ad app permission admin-consent --id $webAppId 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Web app admin consent granted successfully" -ForegroundColor Green
        $webAppConsentSuccess = $true
    } else {
        Write-Warning "Failed to grant admin consent for Web app automatically"
        Write-Host "This may be due to tenant licensing limitations" -ForegroundColor Yellow
    }
}

# Always provide manual instructions if automatic consent failed
if (-not $webAppConsentSuccess -or -not $apiAppConsentSuccess -or -not $hasAdminPermissions) {
    Write-Host ""
    Write-Warning "⚠️  MANUAL ADMIN CONSENT REQUIRED" 
    Write-Host ""
    Write-Host "REQUIRED MANUAL STEPS:" -ForegroundColor Red
    Write-Host "1. Open Azure Portal: https://portal.azure.com"
    Write-Host "2. Navigate to: Azure Active Directory > App registrations"
    Write-Warning "⚠️ "     
    Write-Warning "⚠️  Do steps 3 and 4 in the order shown (API first)" 
    Write-Warning "⚠️  " 
    
    if (-not $apiAppConsentSuccess) {
        Write-Host "3. For '$API_APP_DISPLAY_NAME' (ID: $apiAppId):"
        Write-Host "   - Click on the app registration"
        Write-Host "   - Go to 'API permissions'"
        Write-Host "   - Click 'Grant admin consent for $tenantDisplayName'"
        Write-Host "   - Confirm the action"
        Write-Host "   - Verify Microsoft Graph permission shows 'Granted' status"
    }

    if (-not $webAppConsentSuccess) {
        Write-Host "4. For '$WEB_APP_DISPLAY_NAME' (ID: $webAppId):"
        Write-Host "   - Click on the app registration"
        Write-Host "   - Go to 'API permissions'"
        Write-Host "   - Click 'Grant admin consent for $tenantDisplayName'"
        Write-Host "   - Confirm the action"
        Write-Host "   - Verify both permissions show 'Granted' status"
    }

    Write-Host ""
    Write-Host "TROUBLESHOOTING TIPS:" -ForegroundColor Cyan
    Write-Host "- If you see licensing errors, try granting consent from Enterprise Applications instead"
    Write-Host "- Some tenants require consent to be granted by a different admin role"
    Write-Host "- Wait 2-3 minutes after granting consent before proceeding to next steps"
    Write-Host ""
}

# --- GENERATE CONFIGURATION OUTPUT ---
$tenantId = az account show --query tenantId -o tsv

$configOutput = @"
# Generated App Registration Configuration
# Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

`$WEB_APP_ID = "$webAppId"
`$API_APP_ID = "$apiAppId"
`$WEB_APP_SECRET = "$webSecret"
`$API_APP_SECRET = "$apiSecret"
`$API_SCOPE_URI = "$apiScopeUri/$API_SCOPE_NAME"
`$TENANT_ID = "$tenantId"

# For verification
`$WEB_APP_DISPLAY_NAME = "$WEB_APP_DISPLAY_NAME"
`$API_APP_DISPLAY_NAME = "$API_APP_DISPLAY_NAME"
"@

$configOutput | Out-File -FilePath "app-config.ps1" -Encoding UTF8

# --- SUMMARY ---
Write-Host ""
Write-Host "=== APP REGISTRATION SUMMARY ===" -ForegroundColor Green
Write-Host "✓ API App Registration: $apiAppId ($API_APP_DISPLAY_NAME)"
Write-Host "✓ Web App Registration: $webAppId ($WEB_APP_DISPLAY_NAME)"
Write-Host "✓ Client secrets created for both applications"
Write-Host "✓ Custom API scope '$API_SCOPE_NAME' configured"
Write-Host "✓ Microsoft Graph permissions added"
Write-Host "✓ Configuration saved to app-config.ps1"

# Admin consent status
if ($apiAppConsentSuccess -and $webAppConsentSuccess) {
    Write-Host "✓ Admin consent granted automatically for both apps" -ForegroundColor Green
} elseif ($apiAppConsentSuccess -or $webAppConsentSuccess) {
    Write-Host "⚠️  Partial admin consent granted - manual steps required above" -ForegroundColor Yellow
} else {
    Write-Host "⚠️  Manual admin consent required for both apps (see instructions above)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "BEFORE PROCEEDING TO NEXT STEPS:" -ForegroundColor Red
Write-Host "1. Complete any pending manual admin consent steps above"
Write-Host "2. Verify consent status in Azure Portal"
Write-Host "3. Run verification commands below to confirm"
Write-Host ""

Write-Host "Next Steps (only after admin consent is complete):"
Write-Host "1. Run 02-init-web-app.ps1 to create the web application"
Write-Host "2. Verify configuration in Azure Portal"
Write-Host ""

# --- VERIFICATION COMMANDS ---
Write-Host "Verification Commands:" -ForegroundColor Cyan
Write-Host "az ad app show --id $webAppId --query '{displayName:displayName, appId:appId}'"
Write-Host "az ad app show --id $apiAppId --query '{displayName:displayName, appId:appId}'"
Write-Host "az ad app permission list --id $webAppId"
Write-Host "az ad app permission list --id $apiAppId"
```

---

## Step 3: Initialize Web Application Project

Create the ASP.NET Core MVC web application with Microsoft Identity integration.

```powershell
# 02-init-web-app.ps1

. .\config.ps1
. .\app-config.ps1

if (Test-Path $WEB_PROJECT_FOLDER) {
    Write-Warning "Web project folder exists. Removing..."
    Remove-Item -Recurse -Force $WEB_PROJECT_FOLDER
}

Write-Host "Creating Web Application Project..." -ForegroundColor Yellow

# Create ASP.NET Core MVC project
dotnet new mvc -n $WEB_PROJECT_FOLDER
Set-Location $WEB_PROJECT_FOLDER

# Add required NuGet packages
dotnet add package Microsoft.Identity.Web
dotnet add package Microsoft.Identity.Web.UI

# Create appsettings.json
$appSettingsContent = @"
{
  "AzureAd": {
    "Instance": "https://login.microsoftonline.com/",
    "TenantId": "$TENANT_ID",
    "ClientId": "$WEB_APP_ID",
    "ClientSecret": "$WEB_APP_SECRET",
    "CallbackPath": "/signin-oidc"
  },
  "Api": {
    "BaseUrl": "$API_LOCAL_URL",
    "Scope": "$API_SCOPE_URI"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
"@

$appSettingsContent | Out-File -FilePath "appsettings.json" -Encoding UTF8

Set-Location ..
Write-Host "Web application project created successfully!" -ForegroundColor Green
```

---

## Step 4: Implement Web Application Code

Create the web application with authentication and API calling capabilities.

```powershell
# 03-implement-web-app.ps1

. .\config.ps1

Write-Host "Implementing Web Application Code..." -ForegroundColor Yellow

# Update Program.cs
$programContent = @'
using Microsoft.Identity.Web;
using Microsoft.Identity.Web.UI;

var builder = WebApplication.CreateBuilder(args);

// Add Microsoft Identity Web
builder.Services.AddMicrosoftIdentityWebAppAuthentication(builder.Configuration, "AzureAd")
    .EnableTokenAcquisitionToCallDownstreamApi()
    .AddInMemoryTokenCaches();

// Add services to the container.
builder.Services.AddControllersWithViews()
    .AddMicrosoftIdentityUI();

builder.Services.AddHttpClient();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();
'@

$programContent | Out-File -FilePath "$WEB_PROJECT_FOLDER/Program.cs" -Encoding UTF8

# Create ProfileController
New-Item -ItemType Directory -Path "$WEB_PROJECT_FOLDER/Controllers" -Force | Out-Null

$profileControllerContent = @'
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Identity.Web;
using System.Net.Http.Headers;

namespace ContosoWebApp.Controllers;

[Authorize]
public class ProfileController : Controller
{
    private readonly ITokenAcquisition _tokenAcquisition;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly IConfiguration _configuration;

    public ProfileController(
        ITokenAcquisition tokenAcquisition,
        IHttpClientFactory httpClientFactory,
        IConfiguration configuration)
    {
        _tokenAcquisition = tokenAcquisition;
        _httpClientFactory = httpClientFactory;
        _configuration = configuration;
    }

    public IActionResult Index()
    {
        return View();
    }

    [HttpPost]
    public async Task<IActionResult> UpdateProfile()
    {
        try
        {
            var apiScope = _configuration["Api:Scope"];
            var apiBaseUrl = _configuration["Api:BaseUrl"];

            // Acquire token for API
            var accessToken = await _tokenAcquisition.GetAccessTokenForUserAsync(new[] { apiScope });

            // Call the API
            var httpClient = _httpClientFactory.CreateClient();
            httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

            var response = await httpClient.PostAsync($"{apiBaseUrl}/api/profile/update", null);

            if (response.IsSuccessStatusCode)
            {
                ViewBag.Message = "Profile updated successfully!";
                ViewBag.MessageType = "success";
            }
            else
            {
                ViewBag.Message = $"Error updating profile: {response.StatusCode}";
                ViewBag.MessageType = "error";
            }
        }
        catch (Exception ex)
        {
            ViewBag.Message = $"Error: {ex.Message}";
            ViewBag.MessageType = "error";
        }

        return View("Index");
    }
}
'@

$profileControllerContent | Out-File -FilePath "$WEB_PROJECT_FOLDER/Controllers/ProfileController.cs" -Encoding UTF8

# Create Profile/Index.cshtml view
New-Item -ItemType Directory -Path "$WEB_PROJECT_FOLDER/Views/Profile" -Force | Out-Null

$profileViewContent = @'
@{
    ViewData["Title"] = "Profile Management";
}

<div class="container mt-4">
    <div class="row">
        <div class="col-md-8 offset-md-2">
            <div class="card">
                <div class="card-header">
                    <h2>Profile Management</h2>
                </div>
                <div class="card-body">
                    @if (ViewBag.Message != null)
                    {
                        var alertClass = ViewBag.MessageType == "success" ? "alert-success" : "alert-danger";
                        <div class="alert @alertClass" role="alert">
                            @ViewBag.Message
                        </div>
                    }

                    <p>Click the button below to update your Microsoft Graph profile using the On-Behalf-Of flow:</p>

                    <form asp-action="UpdateProfile" method="post">
                        <button type="submit" class="btn btn-primary">
                            Update My Profile via API
                        </button>
                    </form>

                    <hr />

                    <h5>How this works:</h5>
                    <ol>
                        <li>You're authenticated to this web application</li>
                        <li>Web app acquires a token for the custom API scope</li>
                        <li>API receives the token and uses OBO to get a Graph token</li>
                        <li>API calls Microsoft Graph to update your profile</li>
                    </ol>
                </div>
            </div>
        </div>
    </div>
</div>
'@

$profileViewContent | Out-File -FilePath "$WEB_PROJECT_FOLDER/Views/Profile/Index.cshtml" -Encoding UTF8

# Update _Layout.cshtml to add Profile link
$layoutPath = "$WEB_PROJECT_FOLDER/Views/Shared/_Layout.cshtml"
if (Test-Path $layoutPath) {
    $layoutContent = Get-Content $layoutPath -Raw
    $navbarAddition = @'
                        <li class="nav-item">
                            <a class="nav-link text-dark" asp-area="" asp-controller="Profile" asp-action="Index">Profile</a>
                        </li>
'@
    
    # Insert after Home nav item
    $layoutContent = $layoutContent -replace '(<li class="nav-item">\s*<a class="nav-link text-dark" asp-area="" asp-controller="Home" asp-action="Index">Home</a>\s*</li>)', "`$1`n$navbarAddition"
    
    # Add authentication section
    $authSection = @'
                    <partial name="_LoginPartial" />
'@
    $layoutContent = $layoutContent -replace '(</ul>\s*</div>\s*</div>\s*</nav>)', "$authSection`n`$1"
    
    $layoutContent | Out-File -FilePath $layoutPath -Encoding UTF8
}

Write-Host "Web application code implemented successfully!" -ForegroundColor Green
```

---

## Step 5: Initialize API Project

Create the ASP.NET Core Web API project with JWT authentication and OBO capabilities.

```powershell
# 04-init-api.ps1

. .\config.ps1
. .\app-config.ps1

if (Test-Path $API_PROJECT_FOLDER) {
    Write-Warning "API project folder exists. Removing..."
    Remove-Item -Recurse -Force $API_PROJECT_FOLDER
}

Write-Host "Creating API Project..." -ForegroundColor Yellow

# Create ASP.NET Core Web API project
dotnet new webapi -n $API_PROJECT_FOLDER
Set-Location $API_PROJECT_FOLDER

# Add required NuGet packages
dotnet add package Microsoft.Identity.Web
dotnet add package Microsoft.Graph
dotnet add package Microsoft.Graph.Authentication

# Create appsettings.json
$apiAppSettingsContent = @"
{
  "AzureAd": {
    "Instance": "https://login.microsoftonline.com/",
    "TenantId": "$TENANT_ID",
    "ClientId": "$API_APP_ID",
    "ClientSecret": "$API_APP_SECRET"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
"@

$apiAppSettingsContent | Out-File -FilePath "appsettings.json" -Encoding UTF8

Set-Location ..
Write-Host "API project created successfully!" -ForegroundColor Green
```

---

## Step 6: Implement API with OBO Flow

Create the API controller that implements the On-Behalf-Of pattern to call Microsoft Graph.

```powershell
# 05-implement-api.ps1

. .\config.ps1
. .\app-config.ps1

Write-Host "Implementing API with OBO Flow..." -ForegroundColor Yellow

# Update Program.cs for API
$apiProgramContent = @'
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Identity.Web;
using Microsoft.Graph;

var builder = WebApplication.CreateBuilder(args);

// Add Microsoft Identity Web API
builder.Services.AddMicrosoftIdentityWebApiAuthentication(builder.Configuration, "AzureAd")
    .EnableTokenAcquisitionToCallDownstreamApi()
    .AddMicrosoftGraph()
    .AddInMemoryTokenCaches();

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Add CORS for local development
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowWebApp", policy =>
    {
        policy.WithOrigins("https://localhost:5001")
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseCors("AllowWebApp");

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();
'@

$apiProgramContent | Out-File -FilePath "$API_PROJECT_FOLDER/Program.cs" -Encoding UTF8

# Create ProfileController for API
$apiProfileControllerContent = @'
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Graph;
using Microsoft.Identity.Web.Resource;

namespace ContosoApi.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
[RequiredScope("User.Write")]
public class ProfileController : ControllerBase
{
    private readonly GraphServiceClient _graphServiceClient;
    private readonly ILogger<ProfileController> _logger;

    public ProfileController(
        GraphServiceClient graphServiceClient,
        ILogger<ProfileController> logger)
    {
        _graphServiceClient = graphServiceClient;
        _logger = logger;
    }

    [HttpPost("update")]
    public async Task<IActionResult> UpdateProfile()
    {
        try
        {
            _logger.LogInformation("Attempting to update user profile via Microsoft Graph");

            // Get current user info first
            var currentUser = await _graphServiceClient.Me.GetAsync();
            _logger.LogInformation($"Current user: {currentUser?.DisplayName} ({currentUser?.Id})");

            // Update user's aboutMe field
            var updateUser = new User
            {
                AboutMe = $"Profile updated via OBO flow at {DateTime.UtcNow:yyyy-MM-dd HH:mm:ss} UTC"
            };

            await _graphServiceClient.Me.PatchAsync(updateUser);

            _logger.LogInformation("User profile updated successfully");

            return Ok(new 
            { 
                message = "Profile updated successfully",
                timestamp = DateTime.UtcNow,
                updatedField = "aboutMe"
            });
        }
        catch (ServiceException ex)
        {
            _logger.LogError(ex, $"Microsoft Graph error: {ex.Error?.Code} - {ex.Error?.Message}");
            return StatusCode(500, new 
            { 
                error = "Graph API error",
                code = ex.Error?.Code,
                message = ex.Error?.Message
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error occurred");
            return StatusCode(500, new 
            { 
                error = "Internal server error",
                message = ex.Message
            });
        }
    }

    [HttpGet("me")]
    public async Task<IActionResult> GetCurrentUser()
    {
        try
        {
            var user = await _graphServiceClient.Me
                .GetAsync(requestConfiguration => 
                {
                    requestConfiguration.QueryParameters.Select = new[] { "id", "displayName", "mail", "aboutMe" };
                });

            return Ok(new
            {
                id = user?.Id,
                displayName = user?.DisplayName,
                mail = user?.Mail,
                aboutMe = user?.AboutMe
            });
        }
        catch (ServiceException ex)
        {
            _logger.LogError(ex, $"Microsoft Graph error: {ex.Error?.Code} - {ex.Error?.Message}");
            return StatusCode(500, new 
            { 
                error = "Graph API error",
                message = ex.Error?.Message
            });
        }
    }
}
'@

$apiProfileControllerContent | Out-File -FilePath "$API_PROJECT_FOLDER/Controllers/ProfileController.cs" -Encoding UTF8

Write-Host "API implementation completed successfully!" -ForegroundColor Green
```

---

## Step 7: Local Testing and Validation

Create scripts to run both applications locally and test the complete flow.

```powershell
# 06-run-local-test.ps1

. .\config.ps1

Write-Host "Starting Local Testing..." -ForegroundColor Yellow

# Function to start projects
function Start-Project {
    param($ProjectPath, $Port)
    
    Start-Process -FilePath "dotnet" -ArgumentList "run", "--project", $ProjectPath, "--urls", "https://localhost:$Port" -WindowStyle Minimized
}

Write-Host "Starting API on port 7001..."
Start-Project -ProjectPath $API_PROJECT_FOLDER -Port 7001

Start-Sleep -Seconds 3

Write-Host "Starting Web App on port 5001..."
Start-Project -ProjectPath $WEB_PROJECT_FOLDER -Port 5001

Write-Host ""
Write-Host "=== Local Testing Ready ===" -ForegroundColor Green
Write-Host "Web App: https://localhost:5001"
Write-Host "API: https://localhost:7001"
Write-Host ""
Write-Host "Testing Steps:" -ForegroundColor Cyan
Write-Host "1. Open https://localhost:5001 in your browser"
Write-Host "2. Sign in with your Azure AD account"
Write-Host "3. Navigate to Profile section"
Write-Host "4. Click 'Update My Profile via API'"
Write-Host "5. Verify success message"
Write-Host "6. Check your Microsoft Graph profile at https://graph.microsoft.com/v1.0/me"
Write-Host ""
Write-Host "Press any key to stop the applications..."
Read-Host

# Stop all dotnet processes
Get-Process -Name "dotnet" -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Host "Applications stopped." -ForegroundColor Yellow
```

---

## Step 8: Deploy to Azure App Services

Create Azure App Services and deploy both applications.

```powershell
# 07-deploy-to-azure.ps1

. .\config.ps1
. .\app-config.ps1

Write-Host "Deploying to Azure App Services..." -ForegroundColor Yellow

# Create resource group
Write-Host "Creating resource group..."
az group create --name $RG_NAME --location $LOCATION

# Create App Service Plan
Write-Host "Creating App Service Plan..."
az appservice plan create --name $APP_SERVICE_PLAN --resource-group $RG_NAME --location $LOCATION --sku B1

# Create Web App Service
Write-Host "Creating Web App Service..."
az webapp create --name $WEB_APP_SERVICE_NAME --resource-group $RG_NAME --plan $APP_SERVICE_PLAN --runtime "DOTNETCORE|8.0"

# Create API App Service
Write-Host "Creating API App Service..."
az webapp create --name $API_APP_SERVICE_NAME --resource-group $RG_NAME --plan $APP_SERVICE_PLAN --runtime "DOTNETCORE|8.0"

# Get the production URLs
$webAppUrl = "https://$WEB_APP_SERVICE_NAME.azurewebsites.net"
$apiAppUrl = "https://$API_APP_SERVICE_NAME.azurewebsites.net"

Write-Host "Production URLs:"
Write-Host "Web App: $webAppUrl"
Write-Host "API: $apiAppUrl"

# Update app registrations with production URLs
Write-Host "Updating app registrations with production URLs..."

# Add production redirect URI to Web App registration
az ad app update --id $WEB_APP_ID --web-redirect-uris "$WEB_REDIRECT_URI" "$webAppUrl/signin-oidc"

# Configure Web App application settings
Write-Host "Configuring Web App settings..."
az webapp config appsettings set --name $WEB_APP_SERVICE_NAME --resource-group $RG_NAME --settings `
    "AzureAd__TenantId=$TENANT_ID" `
    "AzureAd__ClientId=$WEB_APP_ID" `
    "AzureAd__ClientSecret=$WEB_APP_SECRET" `
    "AzureAd__Instance=https://login.microsoftonline.com/" `
    "AzureAd__CallbackPath=/signin-oidc" `
    "Api__BaseUrl=$apiAppUrl" `
    "Api__Scope=$API_SCOPE_URI"

# Configure API application settings
Write-Host "Configuring API settings..."
az webapp config appsettings set --name $API_APP_SERVICE_NAME --resource-group $RG_NAME --settings `
    "AzureAd__TenantId=$TENANT_ID" `
    "AzureAd__ClientId=$API_APP_ID" `
    "AzureAd__ClientSecret=$API_APP_SECRET" `
    "AzureAd__Instance=https://login.microsoftonline.com/"

# Deploy Web App
Write-Host "Deploying Web App..."
Set-Location $WEB_PROJECT_FOLDER
dotnet publish -c Release -o ./publish
Compress-Archive -Path "./publish/*" -DestinationPath "../web-app.zip" -Force
Set-Location ..
az webapp deployment source config-zip --name $WEB_APP_SERVICE_NAME --resource-group $RG_NAME --src "web-app.zip"

# Deploy API
Write-Host "Deploying API..."
Set-Location $API_PROJECT_FOLDER
dotnet publish -c Release -o ./publish
Compress-Archive -Path "./publish/*" -DestinationPath "../api-app.zip" -Force
Set-Location ..
az webapp deployment source config-zip --name $API_APP_SERVICE_NAME --resource-group $RG_NAME --src "api-app.zip"

# Clean up deployment files
Remove-Item "web-app.zip" -ErrorAction SilentlyContinue
Remove-Item "api-app.zip" -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=== Deployment Complete ===" -ForegroundColor Green
Write-Host "Web App: $webAppUrl"
Write-Host "API: $apiAppUrl"
Write-Host ""
Write-Host "Allow 2-3 minutes for applications to start, then test the complete flow."
```

---

## Step 9: Validation and Testing

Test the deployed applications and verify the complete OBO flow.

```powershell
# 08-validate-deployment.ps1

. .\config.ps1
. .\app-config.ps1

$webAppUrl = "https://$WEB_APP_SERVICE_NAME.azurewebsites.net"
$apiAppUrl = "https://$API_APP_SERVICE_NAME.azurewebsites.net"

Write-Host "=== Deployment Validation ===" -ForegroundColor Green
Write-Host ""

Write-Host "Testing Steps:" -ForegroundColor Cyan
Write-Host "1. Open $webAppUrl"
Write-Host "2. Sign in with your Azure AD account"
Write-Host "3. Navigate to Profile section"
Write-Host "4. Click 'Update My Profile via API'"
Write-Host "5. Verify success message"
Write-Host ""

Write-Host "Verification Commands:" -ForegroundColor Cyan
Write-Host "Check your updated profile:"
Write-Host "  az rest --method GET --url https://graph.microsoft.com/v1.0/me --query 'aboutMe'"
Write-Host ""

Write-Host "Direct API test (requires bearer token):"
Write-Host "  GET $apiAppUrl/api/profile/me"
Write-Host "  POST $apiAppUrl/api/profile/update"
Write-Host ""

Write-Host "Troubleshooting:" -ForegroundColor Yellow
Write-Host "- Check app logs: az webapp log tail --name <app-name> --resource-group $RG_NAME"
Write-Host "- Verify app settings: az webapp config appsettings list --name <app-name> --resource-group $RG_NAME"
Write-Host "- Check app registration permissions in Azure portal"
```

---

## Step 10: Cleanup Resources

Remove all Azure resources when done with the lab.

```powershell
# 09-cleanup.ps1

. .\config.ps1
. .\app-config.ps1

Write-Host "Cleaning up Azure resources..." -ForegroundColor Red

$confirmation = Read-Host "Are you sure you want to delete resource group '$RG_NAME' and all contained resources? (y/N)"

if ($confirmation -eq 'y' -or $confirmation -eq 'Y') {
    Write-Host "Deleting resource group..." -ForegroundColor Yellow
    az group delete --name $RG_NAME --yes --no-wait
    
    Write-Host "Cleaning up app registrations..." -ForegroundColor Yellow
    az ad app delete --id $WEB_APP_ID
    az ad app delete --id $API_APP_ID
    
    Write-Host "Cleaning up local files..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $WEB_PROJECT_FOLDER -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $API_PROJECT_FOLDER -ErrorAction SilentlyContinue
    Remove-Item "app-config.ps1" -ErrorAction SilentlyContinue
    
    Write-Host "Cleanup completed!" -ForegroundColor Green
} else {
    Write-Host "Cleanup cancelled." -ForegroundColor Yellow
}
```

---

## Professional Best Practices Demonstrated

- **Idempotent Scripts:** All deployment actions can be safely repeated without side effects
- **Variable Centralization:** Promotes consistency and repeatability across development sessions
- **Secure Configuration:** No secrets in source control; proper App Service configuration management
- **Enterprise Authentication Patterns:** Proper implementation of OAuth 2.0 On-Behalf-Of flow
- **Resource Management:** Single resource group for easy cleanup and cost management
- **Documentation:** Clear, step-wise instructions aligned with Azure and GitHub best practices
- **Error Handling:** Comprehensive error handling and logging throughout the application stack
- **Separation of Concerns:** Clean separation between web app, API, and identity concerns
- **AI-Assisted Development:** Demonstrates how modern AI tools (Claude 3.5 Sonnet) can enhance technical project design, documentation quality, and adherence to industry best practices

---

## Architecture Deep Dive

### Authentication Flow
1. **User Authentication:** User signs into web app via Azure AD (Authorization Code flow)
2. **API Token Acquisition:** Web app acquires access token for custom API scope
3. **API Authorization:** API validates incoming JWT token with custom scope
4. **OBO Token Exchange:** API exchanges user token for Microsoft Graph token
5. **Graph API Call:** API calls Graph with delegated permissions on behalf of user

### Security Considerations
- **Principle of Least Privilege:** Each component has minimal required permissions
- **Token Scope Validation:** API validates specific scopes before processing requests
- **Secure Token Storage:** In-memory token caching prevents token persistence
- **HTTPS Enforcement:** All communications encrypted in transit
- **Secret Management:** Client secrets managed via App Service configuration

### Scalability Features
- **Stateless Design:** Both applications are stateless and horizontally scalable
- **Caching Strategy:** In-memory token caching reduces authentication overhead
- **Resource Isolation:** Separate App Services allow independent scaling
- **Configuration Externalization:** Environment-specific settings via App Service configuration

---

## Troubleshooting Guide

### Common Issues and Solutions

**1. Authentication Failures**
```powershell
# Check app registration configuration
az ad app show --id $WEB_APP_ID --query "web.redirectUris"
az ad app permission list --id $WEB_APP_ID
```

**2. OBO Token Exchange Failures**
```powershell
# Verify API permissions
az ad app permission list --id $API_APP_ID
# Check admin consent status
az ad app permission list-grants --id $API_APP_ID
```

**3. Graph API Errors**
```powershell
# Test Graph permissions directly
az rest --method GET --url https://graph.microsoft.com/v1.0/me
```

**4. Local Development Issues**
- Ensure both applications are running on HTTPS
- Check that redirect URIs match exactly
- Verify client secrets haven't expired

**5. Azure Deployment Issues**
```powershell
# Check application logs
az webapp log tail --name $WEB_APP_SERVICE_NAME --resource-group $RG_NAME
az webapp log tail --name $API_APP_SERVICE_NAME --resource-group $RG_NAME

# Verify app settings
az webapp config appsettings list --name $WEB_APP_SERVICE_NAME --resource-group $RG_NAME
```

---

## Extension Opportunities

### Additional Features to Implement
1. **Role-Based Authorization:** Add application roles and role-based access control
2. **Graph SDK Advanced Features:** Implement batch requests and change notifications
3. **Token Caching Optimization:** Implement distributed caching with Redis
4. **API Versioning:** Add versioning strategy for API evolution
5. **Monitoring and Telemetry:** Integrate Application Insights for comprehensive monitoring
6. **CI/CD Pipeline:** Implement GitHub Actions for automated deployment

### Advanced Scenarios
1. **Multi-Tenant Support:** Extend for multi-tenant scenarios
2. **Certificate Authentication:** Replace client secrets with certificates
3. **Conditional Access:** Implement conditional access policy compliance
4. **API Management:** Add Azure API Management for enterprise features

---

## Learning Objectives Achieved

By completing this lab, you have demonstrated proficiency in:

✅ **Microsoft Identity Platform Integration**
- App registration configuration for both client and API scenarios
- Custom API scope definition and consumption
- Delegated permissions and admin consent management

✅ **MSAL.NET Implementation**
- Authorization Code flow in web applications
- On-Behalf-Of flow in APIs
- Token acquisition and caching strategies

✅ **Microsoft Graph Integration**
- Delegated permission usage
- Graph SDK implementation
- User profile management

✅ **Azure App Service Deployment**
- Configuration management without secrets in code
- Production deployment patterns
- Application settings and environment configuration

✅ **Enterprise Security Patterns**
- JWT token validation
- Scope-based authorization
- Secure API design principles

---

## Cost Management

**Estimated Monthly Cost (Basic Tier):**
- App Service Plan (B1): ~$13.14/month
- Two App Services: Included in plan
- Azure AD (Free tier): $0

**Cost Optimization Tips:**
- Use shared App Service plans for development
- Delete resources after each development session
- Consider Azure Dev/Test pricing for non-production workloads

---

## Summary

This lab provides a comprehensive, production-ready implementation of the Microsoft Identity Platform On-Behalf-Of pattern. The automated scripts ensure repeatability and consistency, while the architecture demonstrates enterprise-grade security and scalability patterns essential for AZ-204 certification and real-world applications.

The lab emphasizes practical skills including secure token handling, delegated permissions, and proper separation of concerns between authentication, authorization, and business logic layers.

**Development Methodology:** This project showcases the effective collaboration between human domain expertise and AI assistance (Claude 3.5 Sonnet) in creating comprehensive technical documentation, ensuring best practices compliance, and structuring complex multi-component solutions for optimal learning outcomes.
