$ErrorActionPreference = "Stop"

$output = azd env get-values

# Parse the output to get the resource names and the resource group
foreach ($line in $output) {
    if ($line -match "EVENTHUBS_CONNECTION__fullyQualifiedNamespace"){
        $EventHubNamespace = ($line -split "=")[1] -replace '"','' -replace '.servicebus.windows.net',''
    }
    if ($line -match "RESOURCE_GROUP"){
        $ResourceGroup = ($line -split "=")[1] -replace '"',''
    }
}

# Read the config.json file to see if vnet is enabled
$ConfigFolder = Join-Path $PSScriptRoot "../../.azure/$env:AZURE_ENV_NAME"
$ConfigFile = Join-Path $ConfigFolder "config.json"
$jsonContent = Get-Content $ConfigFile | ConvertFrom-Json

if ($jsonContent.infra.parameters.vnetEnabled -eq $false) {
    Write-Output "VNet is not enabled. Skipping adding the client IP to the network rule of the Event Hubs service"
}
else {
    Write-Output "VNet is enabled. Adding the client IP to the network rule of the Event Hubs service"
    
    # Get the client IP
    $ClientIP = Invoke-RestMethod -Uri 'https://api.ipify.org'
    
    # Get current network rule set
    $NetworkRuleSet = az eventhubs namespace network-rule-set show --resource-group $ResourceGroup --namespace-name $EventHubNamespace | ConvertFrom-Json
    $IPExists = $false
    
    if ($NetworkRuleSet.ipRules) {
        foreach ($Rule in $NetworkRuleSet.ipRules) {
            if ($Rule.ipMask -eq $ClientIP) {
                $IPExists = $true
                break
            }
        }
    }
    
    if ($false -eq $IPExists) {
        # Add the client IP to the network rule of the Event Hubs namespace
        Write-Output "Adding the client IP $ClientIP to the network rule of the Event Hubs service $EventHubNamespace"
        az eventhubs namespace network-rule-set ip-rule add --resource-group $ResourceGroup --namespace-name $EventHubNamespace --ip-rule ip-address=$ClientIP/32 action=Allow > $null
        
        # Mark the public network access as enabled since the client IP is added to the network rule
        $EventHubResourceId = az eventhubs namespace show --resource-group $ResourceGroup --name $EventHubNamespace --query id -o tsv
        az resource update --ids $EventHubResourceId --set properties.publicNetworkAccess="Enabled" > $null
    }
    else {
        Write-Output "The client IP $ClientIP is already in the network rule of the Event Hubs service $EventHubNamespace"
    }
}
