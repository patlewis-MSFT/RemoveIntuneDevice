<#

.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.

#>
####################################################
function Get-AuthToken
{

    <#
    .SYNOPSIS
    This function is used to authenticate with the Graph API REST interface
    .DESCRIPTION
    The function authenticate with the Graph API Interface with the tenant name
    .EXAMPLE
    Get-AuthToken
    Authenticates you with the Graph API interface
    .NOTES
    NAME: Get-AuthToken
    #>

    [cmdletbinding()]

    param
    (
        [Parameter(Mandatory = $true)]
        $User
    )

    $userUpn = New-Object "System.Net.Mail.MailAddress" -ArgumentList $User
    $tenant = $userUpn.Host

    Write-Host "Checking for AzureAD module..."

    $AadModule = Get-Module -Name "AzureAD" -ListAvailable

    if ($null -eq $AadModule)
    {
        Write-Host "AzureAD PowerShell module not found, looking for AzureADPreview"
        $AadModule = Get-Module -Name "AzureADPreview" -ListAvailable
    }

    if ($null -eq $AadModule)
    {
        Write-Host ""
        Write-Host "AzureAD Powershell module not installed..."
        Write-Host "Install by running 'Install-Module AzureAD' or 'Install-Module AzureADPreview' from an elevated PowerShell prompt"
        Write-Host "Script can't continue..."
        Write-Host ""
        exit
    }

    # Getting path to ActiveDirectory Assemblies
    # If the module count is greater than 1 find the latest version

    if ($AadModule.count -gt 1)
    {
        $Latest_Version = ($AadModule | Select-Object version | Sort-Object)[-1]
        $aadModule = $AadModule | Where-Object { $_.version -eq $Latest_Version.version }

        # Checking if there are multiple versions of the same module found
        if ($AadModule.count -gt 1)
        {
            $aadModule = $AadModule | Select-Object -Unique
        }

        $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
        $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"
    }
    else
    {

        $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
        $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"
    }

    [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
    [System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null

    $clientId = "d1ddf0e4-d672-4dae-b554-9d5bdfd93547"
    $redirectUri = "urn:ietf:wg:oauth:2.0:oob"
    $resourceAppIdURI = "https://graph.microsoft.com"
    $authority = "https://login.microsoftonline.com/$Tenant"

    try
    {

        $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority

        $platformParameters = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList "Auto"
        $userId = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.UserIdentifier" -ArgumentList ($User, "OptionalDisplayableId")
        $authResult = $authContext.AcquireTokenAsync($resourceAppIdURI, $clientId, $redirectUri, $platformParameters, $userId).Result

        # If the accesstoken is valid then create the authentication header
        if ($authResult.AccessToken)
        {

            # Creating header for Authorization token
            $authHeader = @{
                'Content-Type'  = 'application/json'
                'Authorization' = "Bearer " + $authResult.AccessToken
                'ExpiresOn'     = $authResult.ExpiresOn
            }
            return $authHeader
        }
        else
        {
            Write-Host ""
            Write-Host "Authorization Access Token is null, please re-run authentication..."
            Write-Host ""
            break
        }
    }
    catch
    {
        Write-Host $_.Exception.Message -f Red
        Write-Host $_.Exception.ItemName -f Red
        Write-Host ""
        break
    }

}

####################################################
Function Get-AADUser()
{
    <#
    .SYNOPSIS
    This function is used to get AAD Users from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any users registered with AAD
    .EXAMPLE
    Get-AADUser
    Returns user registered with Azure AD
    .EXAMPLE
    Get-AADUser -userPrincipleName user@domain.com
    Returns specific user by UserPrincipalName registered with Azure AD
    .NOTES
    NAME: Get-AADUser
    #>

    [cmdletbinding()]

    param
    (
        [Parameter(Mandatory = $true)]
        $userPrincipalName
    )

    # Defining Variables
    $User_resource = "users"

    try
    {
        $uri = "https://graph.microsoft.com/$global:graphApiVersion/$($User_resource)/$userPrincipalName"
        Invoke-RestMethod -Uri $uri -Headers $global:authToken -Method Get
    }
    catch
    {
        #TODO if you throw exception with not found then could be deleted user
        $ex = $_.Exception

        #Checking for Request_ResourceNotFound
        if ($ex.HResult -eq '-2146233079')
        {
            Write-Host "User not found as active in AAD. Now checking deleted users"
            Get-DeletedAADUser($userPrincipalName)
        }
        else
        {
            #Other exception encountered
            $errorResponse = $ex.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($errorResponse)
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $responseBody = $reader.ReadToEnd();
            Write-Host "Response content:`n$responseBody" -f Red
            Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
            Write-Host ""
            break
        }
    }
}

####################################################
Function Get-DeletedAADUser()
{

    <#
    .SYNOPSIS
    This function is used to get deleted AAD Users using Msol with -ReturnDeletedUsers property
    .DESCRIPTION
    The function connects to the MsolService then returns user based on UPN
    .EXAMPLE
    Get-DeletedAADUser
    Returns deleted user if exist. Otherwise null
    .EXAMPLE
    Get-DeletedAADUser -deletedUserPrincipleName user@domain.com
    Returns specific user by UserPrincipalName registered with Azure AD
    .NOTES
    NAME: Get-DeletedAADUser
    #>

    [cmdletbinding()]

    param
    (
        [Parameter(Mandatory = $true)]
        $deletedUserPrincipalName
    )


    Write-Host "Checking for MSOnline module..."

    $MSOLModule = Get-Module -Name "MSOnline" -ListAvailable

    if ($null -eq $MSOLModule)
    {
        Write-Host ""
        Write-Host "MSOnline PowerShell module not found"
        Write-Host "Install by running 'Install-Module MSOnline' from an elevated PowerShell prompt"
        Write-Host "Script can't continue..."
        Write-Host ""
        exit
    }

    # Getting path to MSOnline Assemblies
    # If the module count is greater than 1 find the latest version

    if ($MSOLModule.count -gt 1)
    {
        $Latest_Version = ($MSOLModule | Select-Object version | Sort-Object)[-1]
        $MSOLModule = $MSOLModule | Where-Object { $_.version -eq $Latest_Version.version }

        # Checking if there are multiple versions of the same module found
        if ($MSOLModule.count -gt 1)
        {
            $MSOLModule = $MSOLModule | Select-Object -Unique
        }

        $MSOL = Join-Path $MSOLModule.ModuleBase "Microsoft.Online.Administration.Automation.PSModule.dll"
        $MSOLRes = Join-Path $MSOLModule.ModuleBase "Microsoft.Online.Administration.Automation.PSModule.Resources.dll"
    }
    else
    {
        $MSOL = Join-Path $MSOLModule.ModuleBase "Microsoft.Online.Administration.Automation.PSModule.dll"
        $MSOLRes = Join-Path $MSOLModule.ModuleBase "Microsoft.Online.Administration.Automation.PSModule.Resources.dll"
    }

    [System.Reflection.Assembly]::LoadFrom($MSOL) | Out-Null
    [System.Reflection.Assembly]::LoadFrom($MSOLRes) | Out-Null


    try
    {
        Connect-MsolService -Credential $global:MyCreds
    }
    catch  [Microsoft.Online.Administration.Automation.MicrosoftOnlineException]
    {
        Write-Host "caught unknown exception in Connect-MsolService" -ForegroundColor Red
    }
    catch
    {
        #TODO Discover and plan for any unhandled exceptions
        $ex = $_.Exception
        exit

        #Checking for Request_ResourceNotFound
        if ($ex.HResult -eq 0)
        {
            Write-Host "Token expired. Reauthenticating..."
            Get-DeletedAADUser($deletedUserPrincipalName)

        }
        else
        {
            #Other exception encountered
            $errorResponse = $ex.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($errorResponse)
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $responseBody = $reader.ReadToEnd();
            Write-Host "Response content:`n$responseBody" -f Red
            Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
            Write-Host ""
            break
        }
    }

    $DeletedUser = Get-MsolUser -ReturnDeletedUsers -UserPrincipalName $deletedUserPrincipalName
    if ($DeletedUser.Count -gt 0)
    {
        Write-Host ""
        Write-Host "Found deleted user: " $DeletedUser.UserPrincipalName
        $global:UserIsDeleted = $true
    }

    $DeletedUser
}

####################################################
Function Get-AADUserDevice()
{

    <#
    .SYNOPSIS
    This function is used to get an AAD User Devices from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets a users devices registered with Intune MDM
    .EXAMPLE
    Get-AADUserDevice -UserID $UserID
    Returns all user devices registered in Intune MDM
    .NOTES
    NAME: Get-AADUserDevice
    #>

    [cmdletbinding()]

    param
    (
        [Parameter(Mandatory = $true, HelpMessage = "UserID (guid) for the user you want to take action on must be specified:")]
        $UserID
    )

    # Defining Variables
    $Resource = "users/$UserID/managedDevices"

    try
    {
        $uri = "https://graph.microsoft.com/$global:graphApiVersion/$($Resource)"
        (Invoke-RestMethod -Uri $uri -Headers $global:authToken -Method Get).Value
    }
    catch
    {
        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response content:`n$responseBody" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        Write-Host ""
        break
    }
}

####################################################
Function Get-AADAllDevice()
{
    <#
    .SYNOPSIS
    This function is used to get an AAD User Devices from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets a users devices registered with Intune MDM
    .EXAMPLE
    Get-AADUserDevice -UserID $UserID
    Returns all user devices registered in Intune MDM
    .NOTES
    NAME: Get-AADUserDevice
    #>

    [cmdletbinding()]

    # Defining Variables
    $Resource = "devicemanagement/managedDevices"

    try
    {
        $uri = "https://graph.microsoft.com/$global:graphApiVersion/$($Resource)"
        (Invoke-RestMethod -Uri $uri -Headers $global:authToken -Method Get).Value
    }
    catch
    {
        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Host "Response content:`n$responseBody" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        Write-Host ""
        break
    }
}


####################################################
Function Invoke-DeviceAction()
{
    <#
.SYNOPSIS
This function is used to set a generic intune resources from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and sets a generic Intune Resource
.EXAMPLE
Invoke-DeviceAction -DeviceID $DeviceID -remoteLock
Resets a managed device passcode
.NOTES
NAME: Invoke-DeviceAction
#>

    [cmdletbinding()]

    param
    (
        [switch]$RemoteLock,
        [switch]$ResetPasscode,
        [switch]$Wipe,
        [switch]$Retire,
        [switch]$Delete,
        [switch]$Sync,
        [switch]$Rename,
        [Parameter(Mandatory = $true, HelpMessage = "DeviceId (guid) for the Device you want to take action on must be specified:")]
        $DeviceID
    )

    $graphApiVersion = "Beta"

    try
    {

        $Count_Params = 0

        if ($RemoteLock.IsPresent) { $Count_Params++ }
        if ($ResetPasscode.IsPresent) { $Count_Params++ }
        if ($Wipe.IsPresent) { $Count_Params++ }
        if ($Retire.IsPresent) { $Count_Params++ }
        if ($Delete.IsPresent) { $Count_Params++ }
        if ($Sync.IsPresent) { $Count_Params++ }
        if ($Rename.IsPresent) { $Count_Params++ }

        if ($Count_Params -eq 0)
        {
            write-host "No parameter set, specify -RemoteLock -ResetPasscode -Wipe -Delete -Sync or -rename against the function" -f Red
        }
        elseif ($Count_Params -gt 1)
        {
            write-host "Multiple parameters set, specify a single parameter -RemoteLock -ResetPasscode -Wipe -Delete or -Sync against the function" -f Red
        }
        elseif ($RemoteLock)
        {
            $Resource = "deviceManagement/managedDevices/$DeviceID/remoteLock"
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($resource)"
            write-verbose $uri
            Write-Verbose "Sending remoteLock command to $DeviceID"
            Invoke-RestMethod -Uri $uri -Headers $authToken -Method Post
        }
        elseif ($ResetPasscode)
        {
            write-host
            write-host "Are you sure you want to reset the Passcode this device? Y or N?"
            $Confirm = read-host

            if ($Confirm -eq "y" -or $Confirm -eq "Y")
            {
                $Resource = "deviceManagement/managedDevices/$DeviceID/resetPasscode"
                $uri = "https://graph.microsoft.com/$graphApiVersion/$($resource)"
                write-verbose $uri
                Write-Verbose "Sending remotePasscode command to $DeviceID"
                Invoke-RestMethod -Uri $uri -Headers $authToken -Method Post
            }
            else
            {
                Write-Host "Reset of the Passcode for the device $DeviceID was cancelled..."
            }
        }
        elseif ($Wipe)
        {
            write-host
            write-host "Are you sure you want to wipe this device? Y or N?"
            $Confirm = read-host

            if ($Confirm -eq "y" -or $Confirm -eq "Y")
            {
                $Resource = "deviceManagement/managedDevices/$DeviceID/wipe"
                $uri = "https://graph.microsoft.com/$graphApiVersion/$($resource)"
                write-verbose $uri
                Write-Verbose "Sending wipe command to $DeviceID"
                Invoke-RestMethod -Uri $uri -Headers $authToken -Method Post
            }
            else
            {
                Write-Host "Wipe of the device $DeviceID was cancelled..."
            }
        }
        elseif ($Retire)
        {
            write-host
            write-host "Retiring device......"
            
            #$Confirm = read-host
            $Confirm = 'y'
            #Setting Confirm since we have already confirmed prior to calling

            if ($Confirm -eq "y" -or $Confirm -eq "Y")
            {
                $Resource = "deviceManagement/managedDevices/$DeviceID/retire"
                $uri = "https://graph.microsoft.com/$graphApiVersion/$($resource)"
                write-verbose $uri
                Write-Verbose "Sending retire command to $DeviceID"
                Invoke-RestMethod -Uri $uri -Headers $authToken -Method Post
            }
            else
            {
                Write-Host "Retire of the device $DeviceID was cancelled..."
            }
        }
        elseif ($Delete)
        {
            Write-Warning "A deletion of a device will only work if the device has already had a retire or wipe request sent to the device..."
            Write-Host
            write-host "Deleting device......"

            #$Confirm = read-host
            $Confirm = 'y'

            if ($Confirm -eq "y" -or $Confirm -eq "Y")
            {
                $Resource = "deviceManagement/managedDevices('$DeviceID')"
                $uri = "https://graph.microsoft.com/$graphApiVersion/$($resource)"
                write-verbose $uri
                Write-Verbose "Sending delete command to $DeviceID"
                Invoke-RestMethod -Uri $uri -Headers $authToken -Method Delete
            }
            else
            {
                Write-Host "Deletion of the device $DeviceID was cancelled..."
            }
        }   
        elseif ($Sync)
        {
            write-host
            write-host "Are you sure you want to sync this device? Y or N?"
            $Confirm = read-host

            if ($Confirm -eq "y" -or $Confirm -eq "Y")
            {
                $Resource = "deviceManagement/managedDevices('$DeviceID')/syncDevice"
                $uri = "https://graph.microsoft.com/$graphApiVersion/$($resource)"
                write-verbose $uri
                Write-Verbose "Sending sync command to $DeviceID"
                Invoke-RestMethod -Uri $uri -Headers $authToken -Method Post
            }
            else
            {
                Write-Host "Sync of the device $DeviceID was cancelled..."
            }
        }
        elseif ($Rename)
        {
            write-host "Please type the new device name:" -ForegroundColor Yellow
            $NewDeviceName = Read-Host

            $JSON = @"
{
    deviceName:"$($NewDeviceName)"
}

"@

            write-host
            write-host "Note: The RenameDevice remote action is only supported on supervised iOS devices"
            write-host "Are you sure you want to rename this device to" $($NewDeviceName) "(Y or N?)"
            $Confirm = read-host

            if ($Confirm -eq "y" -or $Confirm -eq "Y")
            {
                $Resource = "deviceManagement/managedDevices('$DeviceID')/setDeviceName"
                $uri = "https://graph.microsoft.com/$graphApiVersion/$($resource)"
                write-verbose $uri
                Write-Verbose "Sending rename command to $DeviceID"
                Invoke-RestMethod -Uri $uri -Headers $authToken -Method Post -Body $Json -ContentType "application/json"
            }
            else
            {
                Write-Host "Rename of the device $DeviceID was cancelled..."
            }
        }
    }
    catch
    {
        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Host "Response content:`n$responseBody" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        write-host
        break
    }
}

####################################################
# Start main                                       #
####################################################
# Version 1.0.1
####################################################

$global:graphApiVersion = "beta"
$global:UserIsDeleted = $false

# Checking if authToken exists before running authentication
if ($global:authToken)
{

    # Setting DateTime to Universal time to work in all timezones
    $DateTime = (Get-Date).ToUniversalTime()

    # If the authToken exists checking when it expires
    $TokenExpires = ($authToken.ExpiresOn.datetime - $DateTime).Minutes

    if ($TokenExpires -le 0)
    {
        Write-Host "Authentication Token expired $($TokenExpires) minutes ago" -ForegroundColor Yellow
        Write-Host ""

        $global:MyCreds = Get-Credential -Message 'Enter specify UPN for Azure authentication:'
        $global:authToken = Get-AuthToken -User $global:MyCreds.UserName
    }
}
else
{
    # Authentication doesn't exist, calling Get-AuthToken function
    if (($null -eq $User) -or ($User -eq ""))
    {
        $global:MyCreds = Get-Credential -Message 'Enter specify UPN for Azure authentication:'
    }
    # Getting the authorization token
    $global:authToken = Get-AuthToken -User $global:MyCreds.UserName
}

Write-Host ""
Write-Host "Please enter the UPN for the user to view or remove their devices:" -ForegroundColor Yellow
$UPN = Read-Host
$User = Get-AADUser -userPrincipalName $UPN

if ($null -eq $User)
{
    Write-Host ""
    Write-Host "UPN not found as active or deleted user."
    exit
}

####################################################
# Get Users Devices
####################################################
Write-Host ""
Write-Host "Checking if the user $($User.UserPrincipalName) has any devices assigned..."

#Get devices for deleted user using MSOL. First get all devices
if ($true -eq $global:UserIsDeleted)
{
    $DeletedDevices = Get-AADAllDevice
    $Devices = $DeletedDevices | Where-Object {$_.usersLoggedOn.userId -eq $global:UserId.Guid}
}
else
{
    #Get devices for user using graph
    $Devices = Get-AADUserDevice($User.id)
}

####################################################
# Invoke-DeviceAction and menu
####################################################
if ($Devices)
{

    $DeviceCount = @($Devices).count

    #Need array if more than 1 device
    if ($DeviceCount -gt 1)
    {
        Write-Host "User has $DeviceCount devices."
        Write-Host ""

        Write-Host "Devices:"
        Write-Host "--------"

        $Managed_Devices = $Devices.deviceName | Sort-Object -Unique
        $menu = @{}

        for ($i = 1; $i -le $DeviceCount; $i++)
        {
            Write-Host "$i. $($Managed_Devices[$i-1])"
            $menu.Add($i, ($Managed_Devices[$i - 1]))
        }

        Write-Host ""
        [int]$ans = Read-Host 'Enter Device id to delete (Numerical value)'
        $selection = $menu.Item($ans)

        if ($selection)
        {
            $SelectedDevice = $Devices | Where-Object { $_.deviceName -eq "$Selection" }
            $SelectedDeviceId = $SelectedDevice | Select-Object -ExpandProperty id
            Write-Host "User $($User.userPrincipalName) has device $($SelectedDevice.deviceName)"
        }
    }
    elseif ($DeviceCount -eq 1)
    {
        $SelectedDevice = $Devices
        $SelectedDeviceId = $SelectedDevice | Select-Object -ExpandProperty id
        Write-Host "User $($User.userPrincipalName) has one device $($SelectedDevice.deviceName)"
    }
}
else
{
    Write-Host "No devices found for UPN." -ForegroundColor Red
    Write-Host ""
    exit
}

Write-Host ""
Write-Host "This operation will retire and delete this device: $($SelectedDevice.devicename)" -ForegroundColor Red
Write-Host ""
Write-Host "Are you sure? (Y/N)"
$Confirm = read-host

if ($Confirm -eq "y" -or $Confirm -eq "Y")
{
    Invoke-DeviceAction -DeviceID $SelectedDeviceId -Retire -Verbose
    Invoke-DeviceAction -DeviceID $SelectedDeviceId -Delete -Verbose
    Write-Host "Request sent. Please re-run for additional devices"
}

