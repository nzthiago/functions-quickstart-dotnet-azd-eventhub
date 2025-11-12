using Azure.Identity;
using Azure.Monitor.OpenTelemetry.Exporter;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Builder;
using Microsoft.Azure.Functions.Worker.OpenTelemetry;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using function_app;

var builder = FunctionsApplication.CreateBuilder(args);

builder.ConfigureFunctionsWebApplication();

// Register services
builder.Services.AddScoped<NewsProcessingService>();

// Configure OpenTelemetry
var openTelemetryBuilder = builder.Services.AddOpenTelemetry()
    .UseFunctionsWorkerDefaults();

// Only use Azure Monitor exporter when running in Azure (not locally)
var isRunningInAzure = !string.IsNullOrEmpty(Environment.GetEnvironmentVariable("AZURE_CLIENT_ID"));
if (isRunningInAzure)
{
    openTelemetryBuilder.UseAzureMonitorExporter(options =>
    {
        options.Credential = new DefaultAzureCredential();
    });
}

builder.Build().Run();
