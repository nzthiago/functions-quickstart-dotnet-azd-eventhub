Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host ""

# Get the outputs from the deployment
$outputs = azd env get-values --output json | ConvertFrom-Json

Write-Host "Order Processing System deployed successfully!" -ForegroundColor Yellow
Write-Host ""
Write-Host "System components:" -ForegroundColor Cyan
Write-Host "  📦 Order Generator Function: Generates orders every minute" -ForegroundColor White
Write-Host "  🔄 Order Processor Function: Processes orders from Event Hub" -ForegroundColor White
Write-Host "  📨 Event Hub: $($outputs.eventHubName)" -ForegroundColor White
Write-Host "  🌐 Event Hub Namespace: $($outputs.eventHubNamespaceFqdn)" -ForegroundColor White
Write-Host ""
Write-Host "🚀 Both functions are now running in Azure!" -ForegroundColor Green
Write-Host ""
Write-Host "To monitor the system:" -ForegroundColor Yellow
Write-Host "  1. View Function App logs in Azure Portal" -ForegroundColor White
Write-Host "  2. Check Application Insights for real-time metrics" -ForegroundColor White
Write-Host "  3. Monitor Event Hub message flow" -ForegroundColor White
Write-Host ""
Write-Host "Expected behavior:" -ForegroundColor Cyan
Write-Host "  • Order Generator creates 1-5 orders every minute" -ForegroundColor White
Write-Host "  • Order Processor receives and processes orders" -ForegroundColor White
Write-Host "  • View processing logs with emojis (✅ 💰 📦 📊)" -ForegroundColor White
Write-Host ""
Write-Host "Function App Name: $($outputs.functionAppName)" -ForegroundColor Yellow