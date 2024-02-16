<#
.SYNOPSIS
  Script Name:      Deploy-Veeam365-v7.ps1
  Script Summary:   This script is used to provision a Veeam365 backup server in Azure 

.DESCRIPTION
  The script Provisons the following Resources:
    * A New Resource Group for the deployment
    * A Virtual Network and 1 Subnets
    * A virtual Machine with one NIC
    * Veeam Backup for Office 365 Installed
    * Additional Data disk attached to the VM and Mounted as a Veeam Storage Repository

.DISCLAIMER
  This script is provided AS IS without warranty of any kind. In no event shall its author, or anyone else involved in the creation, 
  production, or delivery of the scripts be liable for any damages whatsoever (including, without limitation, damages for loss of 
  business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or 
  inability to use the scripts or documentation, even if the author has been advised of the possibility of such damages. 

.NOTES
  Version:        1.0
  Author:         Nathan Carroll
  Creation Date:  27 Jul 2023
  Purpose/Change: Code Review
  
.EXAMPLE

#>

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

# Get Date and Time format
$date = Get-Date -Format "dd-MM-yyyy"

# Header Function
function Header
{
  Write-Host ""
Write-Host "    SSSSSS\                                                       SS\     "                    
Write-Host "    SS  __SS\                                                     SS |    "              
Write-Host "    SS /  \__| SSSSSS\  SSSSSSS\  SSSSSSS\   SSSSSS\   SSSSSSS\ SSSSSS\   "
Write-Host "    SS |      SS  __SS\ SS  __SS\ SS  __SS\ SS  __SS\ SS  _____|\_SS  _|  "
Write-Host "    SS |      SS /  SS |SS |  SS |SS |  SS |SSSSSSSS |SS /        SS |    "
Write-Host "    SS |  SS\ SS |  SS |SS |  SS |SS |  SS |SS   ____|SS |        SS |SS\ "
Write-Host "    \SSSSSS  |\SSSSSS  |SS |  SS |SS |  SS |\SSSSSSS\ \SSSSSSS\   \SSSS  |"
Write-Host "     \______/  \______/ \__|  \__|\__|  \__| \_______| \_______|   \____/ "
Write-Host ""
}

#-------------------- [ Variables ] -----------------------
$Location = 'Uk South'
$ResourceGroupName = 'Veeam-365-v7-01'

$DeploymentName = "Veeam365v7-"+"$date"

$ImagePublisher = 'Veeam'
$ImageName = 'office365backup'
$ImageSKU = 'veeamoffice365backupv7'
$ImageOffer = 'virtualmachine'

#-------------------- [ Script Body ] -----------------------

# Connect to Azure
Clear-Host
Header
Write-Host
Write-Host "Initializing... " -ForegroundColor Yellow -NoNewline; Write-Host "Connecting to Azure Account..."
Connect-AzAccount

# List and Select Subscriptions
Write-Host "Initializing... " -ForegroundColor Yellow -NoNewline; Write-Host "Listing available Subscriptions.."
$Subscription = Get-AzSubscription | Out-GridView -title "Select Azure Subscription ..." -PassThru
# If a subscription is selected, set the context to that subscription
if ($null -ne $Subscription) {
  Set-AzContext -SubscriptionId $Subscription.Id
  Write-Host "Switched to subscription: $($Subscription.Name)" -ForegroundColor DarkCyan
} else {
  Write-Host "No subscription selected. Exiting..."
  exit
}


# Get Latest Veeam Version
Write-Host ""
Write-Host "Initializing... " -ForegroundColor Yellow -NoNewline; Write-Host "Getting Veeam 365 Images..."
$VMVersion = Get-AzVMImage `
    -location $Location `
    -PublisherName $ImagePublisher `
    -Offer $ImageName `
    -Skus $ImageSKU | Format-Table -Property Version -HideTableHeaders | Out-String
    Write-Host "Status Update... " -ForegroundColor Yellow -NoNewline; Write-Host "Veeam "$VMVersion.trim() "will be installed" 
Write-Host ""

# Prompt to continue install
Function ScriptContinue {
$UserInput = Read-Host -Prompt "Do you wish to continue.. [Y/N]?"
switch ($UserInput) {
    'Y' {
        Write-Host ""
        Write-Host "Status Update... " -ForegroundColor Yellow -NoNewline; Write-host "Deployment Starting... "
        Write-Host ""
      }
    'N' {
        Write-Host ""
        Write-Host "Exiting Script... " -ForegroundColor DarkCyan
        Write-Host ""
      Exit
    }
    Default {
      Write-Warning "Please only enter Y or N"
      ScriptContinue
    }
  }
}
ScriptContinue

# Marketplace Terms
# Get Marketplace Terms and accept
Write-Host "Status Update... " -ForegroundColor Yellow -NoNewline; Write-Host "Retrieving Marketplace Terms for Image..."
Write-Host "Status Update... " -ForegroundColor Yellow -NoNewline; Write-Host "Accepting Marketplace Terms for Image..."
Get-AzMarketplaceTerms `
    -Publisher $ImagePublisher `
    -Product $ImageName `
    -Name $ImageSKU `
    -OfferType $ImageOffer | Set-AzMarketplaceTerms -Accept | Out-Null

# Create Resource Group
Write-Host ""
Write-Host "Deploying... " -ForegroundColor Blue -NoNewline; Write-Host "Creating Azure Resource Group..."
New-AzResourceGroup `
    -Name $ResourceGroupName `
    -Location $Location | Out-Null

# Get password input 
Write-Host "Deploying... " -ForegroundColor Blue -NoNewline; 
$adminpassword = Read-Host "Enter Password for Local Administrator.." -AsSecureString

# Deploy Veeam BR
Write-Host ""
Write-Host "Deploying... " -ForegroundColor Blue -NoNewline; Write-Host "Deploying Solution to Azure..."
Write-Host "Deploying... " -ForegroundColor Blue -NoNewline; Write-Host "This may take around 6 minutes to complete..."
Write-Host "Deploying... " -ForegroundColor Blue -NoNewline; Write-Host "The deployment Status can be monitored in the Azure Portal..."
New-AzResourceGroupDeployment `
    -Name $DeploymentName `
    -ResourceGroupName $ResourceGroupName `
    -TemplateFile .\Veeam365-Backup-v1.main.bicep -adminpassword $adminpassword `
    -TemplateParameterFile .\Parameters\Veeam365-v7.dev.main.parameters.json
Write-Host "Deployment Submitted"