#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo ""

# Get the outputs from the deployment
outputs=$(azd env get-values --output json)

# Extract values using jq (more robust) or grep/sed fallback
if command -v jq &> /dev/null; then
    eventHubsNamespace=$(echo "$outputs" | jq -r '.EVENTHUBS_CONNECTION__fullyQualifiedNamespace')
    functionAppName=$(echo "$outputs" | jq -r '.SERVICE_API_NAME')
else
    # Fallback using grep and sed if jq is not available
    eventHubsNamespace=$(echo "$outputs" | grep '"EVENTHUBS_CONNECTION__fullyQualifiedNamespace"' | sed 's/.*"EVENTHUBS_CONNECTION__fullyQualifiedNamespace"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    functionAppName=$(echo "$outputs" | grep '"SERVICE_API_NAME"' | sed 's/.*"SERVICE_API_NAME"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
fi

echo -e "${YELLOW}News Streaming System deployed successfully!${NC}"
echo ""
echo -e "${CYAN}System components:${NC}"
echo -e "${WHITE}  📰 News Generator Function: Generates 3-8 news articles every 10 seconds${NC}"
echo -e "${WHITE}  🔄 News Processor Function: Processes articles from Event Hub with sentiment analysis${NC}"
echo -e "${WHITE}  📨 Event Hub: news${NC}"
echo -e "${WHITE}  🌐 Event Hubs Namespace: $eventHubsNamespace${NC}"
echo ""
echo -e "${GREEN}🚀 Both functions are now running in Azure!${NC}"
echo ""
echo -e "${YELLOW}To monitor the system:${NC}"
echo -e "${WHITE}  1. View Function App logs in Azure Portal${NC}"
echo -e "${WHITE}  2. Check Application Insights for real-time metrics${NC}"
echo -e "${WHITE}  3. Monitor Event Hub message flow (32 partitions)${NC}"
echo ""
echo -e "${CYAN}Expected behavior:${NC}"
echo -e "${WHITE}  • News Generator creates 3-8 realistic articles every 10 seconds${NC}"
echo -e "${WHITE}  • News Processor analyzes sentiment and detects viral content${NC}"
echo -e "${WHITE}  • View processing logs with emojis (📰 😊 😢 🔥 📊)${NC}"
echo -e "${WHITE}  • High throughput: ~180-270 articles/minute${NC}"
echo ""
echo -e "${YELLOW}Function App Name: $functionAppName${NC}"

set -e

echo -e "${YELLOW}Creating/updating local.settings.json...${NC}"

cat <<EOF > ./src/local.settings.json
{
    "IsEncrypted": "false",
    "Values": {
        "AzureWebJobsStorage": "UseDevelopmentStorage=true",
        "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
        "EventHubConnection__fullyQualifiedNamespace": "$eventHubsNamespace"
    }
}
EOF

echo -e "${GREEN}✅ local.settings.json has been created/updated successfully!${NC}"