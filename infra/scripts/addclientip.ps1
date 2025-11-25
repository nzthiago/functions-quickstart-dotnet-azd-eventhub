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
<<<<<<< HEAD
        az eventhubs namespace network-rule-set ip-rule add --resource-group $ResourceGroup --namespace-name $EventHubNamespace --ip-rule ip-address=$ClientIP action=Allow > $null
        
        Write-Output "Setting Event Hubs network access to 'Selected networks' mode only"
        az eventhubs namespace network-rule-set update --resource-group $ResourceGroup --name $EventHubNamespace --default-action "Deny" > $null

        # Mark the public network access as enabled since the client IP is added to the network rule
        $EventHubResourceId = az eventhubs namespace show --resource-group $ResourceGroup --name $EventHubNamespace --query id -o tsv
        az resource update --ids $EventHubResourceId --set properties.publicNetworkAccess="Enabled" > $null
=======

        # Add the client IP to the network rule and mark the public network access as enabled since the client IP is added to the network rule
        az eventhubs namespace network-rule-set create --resource-group $ResourceGroup --namespace-name $EventHubNamespace --default-action "Deny" --public-network-access "Enabled" --ip-rules "[{action:Allow,ip-mask:$ClientIP}]" | Out-Null

>>>>>>> fe06523 (Simplifying post provision ip script)
    }
    else {
        Write-Output "The client IP $ClientIP is already in the network rule of the Event Hubs service $EventHubNamespace"
    }
}
