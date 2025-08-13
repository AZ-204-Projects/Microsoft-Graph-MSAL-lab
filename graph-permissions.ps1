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