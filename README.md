# RemoveIntuneDevice
Removes a device even if the user has been deleted

Version 1.0.0

The RemoveIntuneDevice.ps1 script enables you to retire and delete a device owned by the specified UPN. 

This is particularly useful if a user has been deleted from AAD without first deleting the device from Intune. When this occurs you will see the device listed in the Azure Intune portal without an owner. 

## Prerequisites
* The Azure Active Directory recycle bin must be enabled before deleting a device from a deleted user: https://docs.microsoft.com/en-us/azure/active-directory/hybrid/how-to-connect-sync-recycle-bin
* The logged on user must have the appropriate Graph permissions setup in Intune prior to running the script: https://docs.microsoft.com/en-us/intune/intune-graph-apis#intune-permission-scopes
* Install the AzureAD PowerShell module by running 'Install-Module AzureAD' or 'Install-Module AzureADPreview' from an elevated PowerShell prompt
* An Intune tenant which supports the Azure Portal with a production or trial license (https://docs.microsoft.com/en-us/intune-azure/introduction/what-is-microsoft-intune)
* Using the Microsoft Graph APIs to configure Intune controls and policies requires an Intune license.
* An account with permissions to administer the Intune Service
* PowerShell v5.0 on Windows 10 x64 (PowerShell v4.0 is a minimum requirement for the scripts to function correctly)
Note: For PowerShell 4.0 you will require the PowershellGet Module for PS 4.0 to enable the usage of the Install-Module functionality
First time usage of these scripts requires a Global Administrator of the Tenant to accept the permissions of the application
