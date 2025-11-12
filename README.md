<!--
---
name: Azure Functions C# Event Hubs Trigger using Azure Developer CLI
description: This repository contains an Azure Functions Event Hubs trigger quickstart written in C# and deployed to Azure Functions Flex Consumption using the Azure Developer CLI (azd). The sample demonstrates real-time news streaming with sentiment analysis and engagement tracking.
page_type: sample
products:
- azure-functions
- azure-event-hubs
- azure
- entra-id
urlFragment: functions-quickstart-dotnet-azd-eventhub
languages:
- csharp
- bicep
- azdeveloper
---
-->

# Azure Functions with Event Hubs Trigger

An Azure Functions QuickStart project that demonstrates how to use an Event Hubs Trigger with Azure Developer CLI (azd) for quick and easy deployment. This sample showcases a real-time news streaming system with automated content generation and intelligent processing.

## Architecture

This architecture shows how the Azure Function processes news articles through Event Hubs in real-time. The key components include:

- **News Generator (Timer Trigger)**: Automatically generates realistic news articles every 10 seconds and streams them to Event Hubs
- **Azure Event Hubs**: Scalable messaging service that handles high-throughput news streaming with 32 partitions
- **News Processor (Event Hub Trigger)**: Executes automatically when news articles arrive, performing sentiment analysis and engagement tracking
- **Azure Monitor**: Provides logging and metrics for function execution and news analytics
- **Downstream Integration**: Optional integration with other services for search indexing, push notifications, or analytics

This serverless architecture enables highly scalable, event-driven news processing with built-in resiliency and automatic scaling.

## Top Use Cases

1. **Real-time News Processing Pipeline**: Automatically process news articles as they're generated or updated. Perfect for scenarios where you need to analyze sentiment, detect viral content, or trigger notifications when new articles arrive without polling.

2. **Event-Driven Content Management**: Build event-driven architectures where new content automatically triggers downstream business logic. Ideal for content moderation workflows, search index updates, or social media distribution systems.

## Features

* Event Hubs Trigger with high-throughput news streaming (180-270 articles/minute)
* Azure Functions Flex Consumption plan for automatic scaling
* Real-time sentiment analysis and engagement tracking
* Optional VNet integration with private endpoints for enhanced security
* Azure Developer CLI (azd) integration for easy deployment
* Infrastructure as Code using Bicep templates with Azure Verified Modules
* Comprehensive monitoring with Application Insights
* Managed Identity authentication for secure, passwordless access

## Getting Started

### Prerequisites

- [.NET 8.0 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) or later
- [Azure Functions Core Tools](https://docs.microsoft.com/azure/azure-functions/functions-run-local#install-the-azure-functions-core-tools)
- [Azure Developer CLI (azd)](https://docs.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- [Azurite](https://github.com/Azure/Azurite) for local development
- An Azure subscription

### Quickstart

1. Clone this repository
   ```bash
   git clone https://github.com/Azure-Samples/functions-quickstart-dotnet-azd-eventhub.git
   cd functions-quickstart-dotnet-azd-eventhub
   ```

2. Make sure to run this before calling azd to provision resources so azd can run scripts required to setup permissions

   Mac/Linux:
   ```bash
   chmod +x ./infra/scripts/*.sh 
   ```
  
   Windows:
   ```powershell
   Set-ExecutionPolicy RemoteSigned
   ```

3. Configure VNet settings (optional)
   
   By default, you must explicitly choose whether to enable VNet integration:
   
   **For simple deployment without VNet (public endpoints):**
   ```bash
   azd env set VNET_ENABLED false
   ```
   
   **For secure deployment with VNet (private endpoints):**
   ```bash
   azd env set VNET_ENABLED true
   ```
   
   > **Note:** If you don't set `VNET_ENABLED`, the deployment will fail with an error asking you to make an explicit choice.

4. Provision Azure resources using azd
   ```bash
   azd provision
   ```
   This will create all necessary Azure resources including:
   - Azure Event Hubs namespace and hub
   - Azure Function App (Flex Consumption)
   - Application Insights for monitoring
   - Storage Account for function app
   - Virtual Network with private endpoints (if `VNET_ENABLED=true`)
   - Other supporting resources
   - local.settings.json for local development with Azure Functions Core Tools, which should look like this:
   ```json
   {
     "IsEncrypted": false,
     "Values": {
       "AzureWebJobsStorage": "UseDevelopmentStorage=true",
       "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
       "EventHubConnection__fullyQualifiedNamespace": "your-eventhubs-namespace.servicebus.windows.net"
     }
   }
   ```

   The `azd` command automatically sets up the required connection strings and application settings.

4. Start the function locally
   ```bash
   cd src
   dotnet run
   ```
   
   Or use VS Code to run the project with the built-in Azure Functions extension by pressing F5.

5. Test the function locally by watching the automatic news generation

   The News Generator will automatically start creating articles every 10 seconds. You should see console output like:
   ```
   [2024-11-10T10:30:15.123Z] Successfully generated and sent 5 news articles to Event Hub
   [2024-11-10T10:30:15.145Z] ✅ Successfully processed article NEWS-20241110-A1B2C3D4 - 'Breaking: Major Discovery in Renewable Energy Technology' by Sarah Johnson
   [2024-11-10T10:30:15.147Z] 🔥 Viral article: NEWS-20241110-E5F6G7H8 - 8,547 views
   [2024-11-10T10:30:15.149Z] 📊 NEWS BATCH SUMMARY: 5 articles | Total Views: 18,432 | Avg Views: 3,686 | Avg Sentiment: 0.34
   ```

6. Deploy to Azure
   ```bash
   azd up
   ```
   This will build your function app and deploy it to Azure. The deployment process:
   - Checks for any bicep changes using `azd provision`
   - Builds the .NET project using `azd package`
   - Publishes the function app using `azd deploy`
   - Updates application settings in Azure

7. Test the deployed function by monitoring the logs in Azure Portal:
   - Navigate to your Function App in the Azure Portal
   - Go to Functions → NewsGenerator or EventHubsTrigger
   - Check the Monitor tab to verify both functions are working
   - Use Application Insights Live Metrics to see real-time news processing

## Understanding the Code

This sample contains two functions that work together:

### News Generator (Timer Trigger)
Runs every 10 seconds and generates 3-8 realistic news articles, then sends them to Event Hubs. The key configuration:

- **Timer**: `*/10 * * * * *` (every 10 seconds)
- **Output**: Event Hubs output binding to "news" hub
- **Articles**: Realistic content with authors, sources, categories

### News Processor (Event Hubs Trigger) 
Triggered automatically when articles arrive in Event Hubs. Performs sentiment analysis and engagement tracking. The key environment variable that configures its behavior is:

- `EventHubConnection__fullyQualifiedNamespace`: The Event Hubs namespace endpoint


These are automatically set up by azd during deployment for both local and cloud environments.

Here's the core implementation of the Event Hubs trigger function:

```csharp
[Function("EventHubsTrigger")]
public async Task Run([EventHubTrigger("news", Connection = "EventHubConnection")] EventData[] events)
{
    foreach (EventData eventData in events)
    {
        var newsArticle = JsonSerializer.Deserialize<NewsArticle>(eventData.EventBody);
        
        // Process news article with sentiment analysis and engagement tracking
        await _newsProcessingService.ProcessNewsArticleAsync(newsArticle);
    }
}

// News article structure expected by the function
public class NewsArticle
{
    public required string ArticleId { get; set; }
    public required string Title { get; set; }
    public required string Content { get; set; }
    public required string Author { get; set; }
    public required string Source { get; set; }
    public required string Category { get; set; }
    public DateTime PublishedDate { get; set; }
    public int ViewCount { get; set; }
    public double SentimentScore { get; set; }
    public ArticleStatus Status { get; set; }
    public List<string> Tags { get; set; } = new();
}
```

## Project Structure

```
functions-quickstart-dotnet-azd-eventhub/
├── src/                            # Azure Functions project
│   ├── NewsGenerator.cs            # Timer-triggered news generation
│   ├── EventHubsTrigger.cs         # Event Hubs-triggered news processing  
│   ├── NewsProcessingService.cs    # News analytics and sentiment analysis
│   ├── Program.cs                  # Function app host configuration
│   ├── host.json                   # Function host settings
│   ├── local.settings.json         # Local development settings
│   └── function-app.csproj         # .NET 8 isolated function project
├── infra/                          # Infrastructure as Code
│   ├── main.bicep                  # Main infrastructure template
│   ├── main.parameters.json        # Infrastructure parameters
│   ├── abbreviations.json          # Resource naming abbreviations
│   ├── app/                        # Modular infrastructure components
│   │   ├── api.bicep               # Function App (Flex Consumption)
│   │   ├── eventhubs.bicep         # Event Hubs namespace and hub
│   │   ├── eventhubs-PrivateEndpoint.bicep  # Event Hubs private endpoint
│   │   ├── storage-PrivateEndpoint.bicep    # Storage private endpoint
│   │   ├── vnet.bicep              # Virtual Network configuration
│   │   └── rbac.bicep              # Role-based access control
│   └── scripts/                    # Deployment and setup scripts
│       ├── postprovision.ps1       # Post-provision setup (Windows)
│       ├── postprovision.sh        # Post-provision setup (POSIX)
│       ├── setuplocalenvironment.ps1
│       ├── setuplocalenvironment.sh
│       ├── addclientip.ps1         # Add client IP to Event Hubs (Windows)
│       └── addclientip.sh          # Add client IP to Event Hubs (POSIX)
├── .azure/                         # Azure Developer CLI environment
├── azure.yaml                      # Azure Developer CLI configuration
├── README.md                       # Quick start guide
└── DOCUMENTATION.md                # Detailed documentation
```

## Networking and VNet Integration

This sample supports optional VNet integration with private endpoints for enhanced security. 

### Configuration

Set the `VNET_ENABLED` environment variable before deployment:

**For simple deployment without VNet (public endpoints):**
```bash
azd env set VNET_ENABLED false
```

**For secure deployment with VNet (private endpoints):**
```bash
azd env set VNET_ENABLED true
```

When `vnetEnabled=true`, the deployment creates:
- Virtual Network with three subnets (app integration, storage endpoints, Event Hub endpoints)
- Private endpoints for Storage (blob, table, queue) and Event Hubs
- Private DNS zones for name resolution
- Network isolation with public access disabled

The VNet deployment takes longer (~4-5 minutes) but provides enhanced security suitable for production workloads.

### VNet Architecture

When VNet integration is enabled, the following network architecture is created:

#### Subnets
1. **App Integration Subnet**: For Function App VNet integration
2. **Storage Private Endpoints Subnet**: For Storage Account private endpoints
3. **Event Hubs Private Endpoints Subnet**: For Event Hubs private endpoints

#### Private Endpoints
- **Storage Account**: Blob, Table, and Queue private endpoints
- **Event Hubs**: Namespace private endpoint

#### DNS Configuration
- Private DNS zones are automatically created and linked to the VNet
- Ensures proper name resolution for private endpoints

### Security Considerations

When using VNet integration:
- Public access to Event Hubs and Storage is disabled
- All traffic flows through private endpoints within the VNet
- Client IP must be added to Event Hubs network rules for local development (done automatically by `addclientip` scripts)
- Managed Identity is used for authentication between services

## Resources

- [Azure Functions Documentation](https://docs.microsoft.com/azure/azure-functions/)
- [Azure Event Hubs Documentation](https://docs.microsoft.com/azure/event-hubs/)
- [Azure Developer CLI Documentation](https://docs.microsoft.com/azure/developer/azure-developer-cli/)

## Additional Information

For detailed documentation including domain model, monitoring queries, and feature details, see [DOCUMENTATION.md](./DOCUMENTATION.md).
