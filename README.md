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
       "EventHubConnection__fullyQualifiedNamespace": "your-eventhub-namespace.servicebus.windows.net",
       "EventHubConnection__clientId": "your-managed-identity-client-id",
       "EventHubConnection__credential": "managedidentity",
       "EventHubName": "news",
       "APPLICATIONINSIGHTS_CONNECTION_STRING": "your-appinsights-connection-string"
     }
   }
   ```

   The `azd` command automatically sets up the required connection strings and application settings.

4. Start the function locally
   ```bash
   func start
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

   > **Note:** If you deploy with `vnetEnabled=true`, see the [Networking and VNet Integration](#networking-and-vnet-integration) section below for important details about network security and deployment.

7. Test the deployed function by monitoring the logs in Azure Portal:
   - Navigate to your Function App in the Azure Portal
   - Go to Functions → NewsGenerator or EventHubsTrigger
   - Check the Monitor tab to verify both functions are working
   - Use Application Insights Live Metrics to see real-time news processing

## Understanding the Functions

This sample contains two functions that work together:

### News Generator (Timer Trigger)
Runs every 10 seconds and generates 3-8 realistic news articles, then sends them to Event Hubs. The key configuration:

- **Timer**: `*/10 * * * * *` (every 10 seconds)
- **Output**: Event Hubs output binding to "news" hub
- **Articles**: Realistic content with authors, sources, categories

### News Processor (Event Hubs Trigger) 
Triggered automatically when articles arrive in Event Hubs. Performs sentiment analysis and engagement tracking. The key environment variables that configure its behavior are:

- `EventHubConnection__fullyQualifiedNamespace`: The Event Hubs namespace endpoint
- `EventHubName`: The name of the hub to monitor (defaults to "news")
- `APPLICATIONINSIGHTS_CONNECTION_STRING`: For logging and monitoring

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

## Domain Model

### NewsArticle
- ArticleId: Unique identifier (NEWS-YYYYMMDD-XXXXXXXX)
- Title: Article headline
- Content: Article summary/snippet
- Author: Article author from pool of 10 journalists
- Source: News source (TechDaily, Global News, etc.)
- Category: News category (Technology, Business, Sports, etc.)
- PublishedDate: When the article was published
- ViewCount: Simulated engagement (100-10,000 views)
- SentimentScore: AI sentiment analysis (-1.0 to 1.0)
- Status: Draft, Published, Featured, Archived
- Tags: Category-specific tags for classification

## Monitoring and Logs

You can monitor your functions in the Azure Portal:
1. Navigate to your function app in the Azure Portal
2. Select "Functions" from the left menu
3. Click on your function (NewsGenerator or EventHubsTrigger)
4. Select "Monitor" to view execution logs

Use the "Live Metrics" feature in Application Insights to see real-time information when testing.

### Application Insights Queries

**News Articles Generated Per Minute**
```kusto
traces
| where message contains "Successfully generated and sent"
| summarize ArticlesGenerated = sum(toint(extract(@"(\d+) news articles", 1, message))) by bin(timestamp, 1m)
| render timechart
```

**News Articles Processed Per Minute**  
```kusto
traces
| where message contains "NEWS BATCH SUMMARY"
| extend ArticleCount = toint(extract(@"(\d+) articles", 1, message))
| summarize ArticlesProcessed = sum(ArticleCount) by bin(timestamp, 1m)
| render timechart
```

**Viral Articles Detection**
```kusto
traces
| where message contains "Viral article"
| extend ViewCount = toint(extract(@"(\d+,?\d*) views", 1, message))
| summarize ViralArticles = count(), TotalViews = sum(ViewCount) by bin(timestamp, 5m)
| render timechart
```

**Sentiment Analysis Trends**
```kusto
traces
| where message contains "Avg Sentiment"
| extend AvgSentiment = todouble(extract(@"Avg Sentiment: ([+-]?\d*\.?\d+)", 1, message))
| summarize AverageSentiment = avg(AvgSentiment) by bin(timestamp, 5m)
| render timechart
```

## Project Structure

```
news-streaming-demo/
├── function-app/                    # Consolidated function app with both triggers
│   ├── NewsGenerator.cs            # Timer-triggered news generation
│   ├── EventHubsTrigger.cs         # EventHub-triggered news processing  
│   ├── NewsProcessingService.cs    # News analytics and sentiment analysis
│   └── function-app.csproj         # Single project with all dependencies
├── infra/                          # Infrastructure as Code
│   ├── main.bicep                  # Single function app deployment template
│   └── main.parameters.json
├── azure.yaml                      # Azure Developer CLI configuration
├── news-streaming-demo.sln         # Solution file
└── README.md
```

## News Generator

The news generator runs every 10 seconds and creates 3-8 realistic news articles:

### Features
- **High-frequency timer trigger**: Generates articles every 10 seconds for demo throughput
- **Realistic news data**: Creates authentic articles with proper journalism structure
- **Multi-category support**: Technology, Business, Science, Sports, Health, etc.
- **Event Hub streaming**: Sends articles to Azure Event Hubs with rich metadata
- **Configurable**: Easy to adjust generation frequency and content patterns

### Sample Generated Articles
- **Authors**: Pool of 10 realistic journalist names
- **Sources**: TechDaily, Global News, Business Wire, Science Today, etc.
- **Categories**: 10 different news categories with specific content
- **Content**: Realistic headlines and article snippets
- **Metadata**: Sentiment scores, view counts, category tags

## News Processor

The news processor function handles incoming articles from Event Hubs with advanced analytics:

### Features
- **Event Hub trigger**: Automatically processes articles as they stream in
- **News validation**: Validates article data and metadata  
- **Sentiment analysis**: Tracks article sentiment scores (-1.0 to 1.0)
- **Engagement tracking**: Monitors view counts and viral detection
- **Category analytics**: Analyzes trends across news categories
- **Source monitoring**: Tracks performance by news source

### Processing Logic
- ✅ **Validation**: Ensures all required fields are present (title, author, content, etc.)
- � **Status Updates**: Moves articles through publishing workflow (Published → Featured)
- � **Viral detection**: Special handling for articles with >5,000 views
- 😊� **Sentiment tracking**: Identifies articles with strong positive/negative sentiment (>0.7)
- 🏷️ **Tag analysis**: Processes category-specific tags for better classification
- � **Batch analytics**: Provides comprehensive statistics per processing batch

## Sample Processing Output

```
✅ Successfully processed article NEWS-20251110-A1B2C3D4 - 'Breaking: Major Discovery in Renewable Energy Technology' by Sarah Johnson
� Viral article: NEWS-20251110-E5F6G7H8 - 8,547 views  
�😢 Strong sentiment article: NEWS-20251110-I9J0K1L2 - Very Positive (0.89)
🏷️ Well-tagged article: NEWS-20251110-M3N4O5P6 - 5 tags
📊 NEWS BATCH SUMMARY: 5 articles | Total Views: 18,432 | Avg Views: 3,686 | Avg Sentiment: 0.34
📂 Top Categories: [Technology: 2, Business: 2, Science: 1] | Top Sources: [TechDaily: 2, Global News: 2, Science Today: 1]
🔥 Viral articles in batch: 2 | 😊😢 Strong sentiment articles in batch: 3 | 🏷️ Well-tagged articles in batch: 4
```

## Project Structure

```
functions-quickstart-dotnet-azd-eventhub/
├── function-app/                    # Azure Functions project
│   ├── NewsGenerator.cs            # Timer-triggered news generation
│   ├── EventHubsTrigger.cs         # EventHub-triggered news processing  
│   ├── NewsProcessingService.cs    # News analytics and sentiment analysis
│   ├── Models/                     # NewsArticle and related models
│   └── function-app.csproj         # .NET 8 isolated function project
├── infra/                          # Infrastructure as Code
│   ├── main.bicep                  # Main infrastructure template
│   ├── main.parameters.json        # Infrastructure parameters
│   ├── app/                        # Modular infrastructure components
│   │   ├── functions-flexconsumption.bicep
│   │   ├── eventhub.bicep
│   │   └── monitoring.bicep
│   └── scripts/                    # Deployment and setup scripts
│       ├── createlocalsettings.ps1 # Local development setup (Windows)
│       ├── createlocalsettings.sh  # Local development setup (POSIX)
│       ├── setuplocalenvironment.ps1
│       └── setuplocalenvironment.sh
├── azure.yaml                      # Azure Developer CLI configuration
├── func-eventhub-new-sample.sln    # Visual Studio solution
└── README.md
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

## Resources

- [Azure Functions Documentation](https://docs.microsoft.com/azure/azure-functions/)
- [Azure Event Hubs Documentation](https://docs.microsoft.com/azure/event-hubs/)
- [Azure Developer CLI Documentation](https://docs.microsoft.com/azure/developer/azure-developer-cli/)
