<#
 .SYNOPSIS
    Deploys a template to Azure

 .DESCRIPTION
    Deploys an Azure Resource Manager template

 .PARAMETER resourceGroupName
    The resource group where the template will be deployed. Can be the name of an existing or a new resource group.

 .PARAMETER resourceGroupLocation
    Optional, a resource group location. If specified, will try to create a new resource group in this location. If not specified, assumes resource group is existing.

 .PARAMETER vmName
    The name of the Virtual Machine (if omitted then the resourceGroupName will be used).

 .PARAMETER templateFilePath
    Optional, path to the template file. Defaults to template.json.

 .PARAMETER parametersFilePath
    Optional, path to the parameters file. Defaults to parameters.json. If file is not found, will prompt for parameter values based on template.

 .PARAMETER subscriptionName
    The name of the Subscription.
#>

param(
 # [Parameter(Mandatory=$True)]
 # [string]
 # $subscriptionId,
 
 [string]
 $resourceGroupName,
 
[Parameter(Mandatory=$True)]
 [string]
 $vmName,

 [string]
 $resourceGroupLocation = "westeurope",

 #[Parameter(Mandatory=$True)]
 [string]
 $deploymentName,

 [string]
 $templateFilePath = "AzureDeploy.json",

 [string]
 $parametersFilePath = "parameters.json",
 
 [string]
 $subscriptionName = "BlueCielo-NextGen-QA-Automation"
)

<#
.SYNOPSIS
    Registers RPs
#>
Function RegisterRP {
    Param(
        [string]$ResourceProviderNamespace
    )

    Write-Host "Registering resource provider '$ResourceProviderNamespace'";
    Register-AzureRmResourceProvider -ProviderNamespace $ResourceProviderNamespace;
}

#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************
#$ErrorActionPreference = "Stop"

# Login if not authenticated yet
Try {
    Get-AzureRmContext -ErrorAction Continue
}
Catch [System.Management.Automation.PSInvalidOperationException] {
	# sign in
	Write-Host "Logging in...";
    Login-AzureRmAccount
}

if ( [string]::IsNullOrWhitespace($resourceGroupName) ) {
	$resourceGroupName= $vmName
}

if ( [string]::IsNullOrWhitespace($deploymentName) ) {
	$deploymentName = $resourceGroupName + ($templateFilePath).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')
} 

if ( [string]::IsNullOrWhitespace($vmName) ) {
	$vmName = $resourceGroupName
} 

# select subscription
Write-Host "Selecting subscription '$subscriptionName'";
Select-AzureRmSubscription -SubscriptionName $subscriptionName;

# Register RPs
$resourceProviders = @("microsoft.storage","microsoft.network","microsoft.compute");
if($resourceProviders.length) {
    Write-Host "Registering resource providers"
    foreach($resourceProvider in $resourceProviders) {
        RegisterRP($resourceProvider);
    }
}

#Create or check for existing resource group
$resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if(!$resourceGroup)
{
    Write-Host "Resource group '$resourceGroupName' does not exist. To create a new resource group, please enter a location.";
    if(!$resourceGroupLocation) {
        $resourceGroupLocation = Read-Host "resourceGroupLocation";
    }
    Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
    New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation
}
else{
    Write-Host "Using existing resource group '$resourceGroupName'";
}

# Start the deployment
Write-Host "Starting deployment...";

if ( !(Split-Path $templateFilePath -IsAbsolute) ) {
	$templateFilePath = Join-Path -Path (Split-Path $PSCommandPath -Parent) -ChildPath $templateFilePath	
}

if ( !(Split-Path $parametersFilePath -IsAbsolute) ) {
	$parametersFilePath = Join-Path -Path  (Split-Path $PSCommandPath -Parent) -ChildPath $parametersFilePath
}

if(Test-Path $parametersFilePath) {
    $editedParametersFilePath = $parametersFilePath + "-edited.json"
    $params = Get-Content $parametersFilePath | Out-String | ConvertFrom-Json 
    $params.parameters | Add-Member -PassThru NoteProperty vmName @{value= $vmName} 
    $params.parameters | Add-Member -PassThru NoteProperty dnsLabelPrefix @{value= $vmName + "dns"} #just for testing add dns postfix 
    # it is important to set -Depth for ConvertTo-JSON, otherwise objects of the 3rd level and deeper will not be done properly!
    $params | ConvertTo-JSON -Depth 1024 | Out-File -File $editedParametersFilePath -Force
    New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $editedParametersFilePath
} else {
    New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $editedParametersFilePath
}

