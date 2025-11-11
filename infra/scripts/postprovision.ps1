Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host ""

# Get the outputs from the deployment
$outputs = azd env get-values --output json | ConvertFrom-Json
$EventHubNamespace = $outputs.EVENTHUB_CONNECTION__fullyQualifiedNamespace
$EventHubName = $outputs.EVENTHUB_NAME

Write-Host "News Streaming System deployed successfully!" -ForegroundColor Yellow
Write-Host ""
Write-Host "System components:" -ForegroundColor Cyan
Write-Host "  - News Generator Function: Generates 3-8 news articles every 10 seconds" -ForegroundColor White
Write-Host "  - News Processor Function: Processes articles from Event Hub with sentiment analysis" -ForegroundColor White
Write-Host "  - Event Hub: $EventHubName" -ForegroundColor White
Write-Host "  - Event Hub Namespace: $EventHubNamespace" -ForegroundColor White
Write-Host ""
Write-Host "Both functions are now running in Azure!" -ForegroundColor Green
Write-Host ""
Write-Host "To monitor the system:" -ForegroundColor Yellow
Write-Host "  1. View Function App logs in Azure Portal" -ForegroundColor White
Write-Host "  2. Check Application Insights for real-time metrics" -ForegroundColor White
Write-Host "  3. Monitor Event Hub message flow (32 partitions)" -ForegroundColor White
Write-Host ""
Write-Host "Expected behavior:" -ForegroundColor Cyan
Write-Host "  - News Generator creates 3-8 realistic articles every 10 seconds" -ForegroundColor White
Write-Host "  - News Processor analyzes sentiment and detects viral content" -ForegroundColor White
Write-Host "  - View processing logs with emojis in Azure Portal" -ForegroundColor White
Write-Host "  - High throughput: ~180-270 articles/minute" -ForegroundColor White
Write-Host ""
Write-Host "Function App Name: $($outputs.SERVICE_API_NAME)" -ForegroundColor Yellow

$ErrorActionPreference = "Stop"

Write-Host "Creating/updating local.settings.json..." -ForegroundColor Yellow

@{
    "IsEncrypted" = "false";
    "Values" = @{
        "AzureWebJobsStorage" = "UseDevelopmentStorage=true";
        "FUNCTIONS_WORKER_RUNTIME" = "dotnet-isolated";
        "EventHubConnection__fullyQualifiedNamespace" = "$EventHubNamespace";
        "EventHubNamespace" = "$EventHubNamespace";
        "EventHubName" = "$EventHubName";
    }
} | ConvertTo-Json | Out-File -FilePath ".\function-app\local.settings.json" -Encoding ascii -Force

Write-Host "local.settings.json has been created/updated successfully!" -ForegroundColor Green