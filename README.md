# RemoveIntuneDevice
Removes a device even if the user has been deleted

Version 1.0.4

The RemoveIntuneDevice.ps1 script enables you to retire and delete a device owned by the specified UPN. 

This is particularly useful if a user has been deleted from AAD without first deleting the device from Intune. When this occurs you will see the device listed in the Azure Intune portal without an owner. 

## Prerequisites
* The Azure Active Directory recycle bin must be enabled before deleting a device from a deleted user: https://docs.microsoft.com/en-us/azure/active-directory/hybrid/how-to-connect-sync-recycle-bin
* If the user is deleted the MSOnline module must be installed: https://docs.microsoft.com/en-us/powershell/azure/active-directory/overview?view=azureadps-1.0. Run 'Install-Module MSOnline'
* The logged on user must have the appropriate Graph permissions setup in Intune prior to running the script: https://docs.microsoft.com/en-us/intune/intune-graph-apis#intune-permission-scopes
* Install the AzureAD PowerShell module by running 'Install-Module AzureAD' or 'Install-Module AzureADPreview' from an elevated PowerShell prompt
* An Intune tenant which supports the Azure Portal with a production or trial license (https://docs.microsoft.com/en-us/intune-azure/introduction/what-is-microsoft-intune)
* Using the Microsoft Graph APIs to configure Intune controls and policies requires an Intune license.
* An account with permissions to administer the Intune Service
* PowerShell v5.0 on Windows 10 x64 (PowerShell v4.0 is a minimum requirement for the scripts to function correctly)
Note: For PowerShell 4.0 you will require the PowershellGet Module for PS 4.0 to enable the usage of the Install-Module functionality
First time usage of these scripts requires a Global Administrator of the Tenant to accept the permissions of the application
* If you receive an error that scripts are disabled on your machine, you will need to allow the script to run by running the Set-ExecutionPolicy cmdlet. For more information: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-executionpolicy?view=powershell-6

## Getting Started
After the prerequisites are installed or met, perform the following steps to use the script:
1. Download the RemoveIntuneDevice.ps1 to your local Windows machine
1. Run PowerShell from an elevated Administrator account
1. Browse to the directory where you copied RemoveIntuneDevice.ps1
   * Type: **.\RemoveIntuneDevice.ps1**
1. Follow the prompts for authentication and for the UPN of the owner or previous owner's device
