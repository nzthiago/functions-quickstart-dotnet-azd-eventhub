#!/bin/bash
set -e

# Get environment values
output=$(azd env get-values)

# Parse the output to get the resource names and the resource group
while IFS= read -r line; do
    if [[ $line == EVENTHUBS_CONNECTION__fullyQualifiedNamespace* ]]; then
        EventHubNamespace=$(echo "$line" | cut -d '=' -f 2 | tr -d '"' | sed 's/.servicebus.windows.net//')
    elif [[ $line == RESOURCE_GROUP* ]]; then
        ResourceGroup=$(echo "$line" | cut -d '=' -f 2 | tr -d '"')
    fi
done <<< "$output"

# Read the config.json file to see if vnet is enabled
ConfigFolder="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../.azure/$AZURE_ENV_NAME"
ConfigFile="$ConfigFolder/config.json"
EnableVirtualNetwork=$(jq -r '.infra.parameters.vnetEnabled' "$ConfigFile")

if [[ $EnableVirtualNetwork == "false" ]]; then
    echo "VNet is not enabled. Skipping adding the client IP to the network rule of the Event Hubs service"
else
    echo "VNet is enabled. Adding the client IP to the network rule of the Event Hubs service"
    
    # Get the client IP
    ClientIP=$(curl -s https://api.ipify.org)
    
    # Check and update Event Hubs network rules
    NetworkRuleSet=$(az eventhubs namespace network-rule-set show --resource-group "$ResourceGroup" --namespace-name "$EventHubNamespace" -o json)
    IPExists=$(echo "$NetworkRuleSet" | jq -r --arg ip "$ClientIP" '.ipRules[]? | select(.ipMask == $ip) | .ipMask')
    
    if [[ -z $IPExists ]]; then
        echo "Adding the client IP $ClientIP to the network rule of the Event Hubs service $EventHubNamespace"
        az eventhubs namespace network-rule-set ip-rule add --resource-group "$ResourceGroup" --namespace-name "$EventHubNamespace" --ip-rule "ip-address=$ClientIP/32 action=Allow" > /dev/null
        
        # Mark the public network access as enabled since the client IP is added to the network rule
        EventHubResourceId=$(az eventhubs namespace show --resource-group "$ResourceGroup" --name "$EventHubNamespace" --query id -o tsv)
        az resource update --ids "$EventHubResourceId" --set properties.publicNetworkAccess="Enabled" > /dev/null
    else
        echo "The client IP $ClientIP is already in the network rule of the Event Hubs service $EventHubNamespace"
    fi
fi
