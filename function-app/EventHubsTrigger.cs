using System.Text.Json;
using Azure.Messaging.EventHubs;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace function_app;

public class EventHubsTrigger
{
    private readonly ILogger<EventHubsTrigger> _logger;
    private readonly OrderProcessingService _orderService;

    public EventHubsTrigger(ILogger<EventHubsTrigger> logger)
    {
        _logger = logger;
        _orderService = new OrderProcessingService(logger);
    }

    [Function(nameof(EventHubsTrigger))]
    public async Task Run([EventHubTrigger("orders", Connection = "EventHubConnection")] EventData[] input)
    {
        var processedOrders = new List<Order>();
        var failedEvents = 0;
        
        foreach (var message in input)
        {
            try
            {
                var messageBody = message.EventBody.ToString();

                // Parse the order event
                var order = ParseOrderEvent(messageBody);

                if (order != null)
                {
                    processedOrders.Add(order);
                }
                else
                {
                    failedEvents++;
                }
            }
            catch (Exception ex)
            {
                failedEvents++;
                _logger.LogWarning($"Error processing message: {ex.Message}");
            }
        }

        // Log summary of this execution
        _logger.LogInformation($"Processed {processedOrders.Count} orders, {failedEvents} failed in batch of {input.Length}");

        // Process all orders in batch
        if (processedOrders.Count > 0)
        {
            await _orderService.ProcessOrders(processedOrders);
        }
    }
    
    private Order? ParseOrderEvent(string message)
    {
        try
        {
            // Parse using JsonSerializer with camelCase policy to match generator
            var options = new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true,
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            };
            
            var order = JsonSerializer.Deserialize<Order>(message, options);
            
            if (order != null)
            {
                _logger.LogDebug($"📥 Received order: {order.OrderId} from {order.CustomerName}");
            }
            
            return order;
        }
        catch (Exception ex)
        {
            _logger.LogError($"Failed to parse order event: {ex.Message}");
            return null;
        }
    }
}

public class Order
{
    public string OrderId { get; set; } = string.Empty;
    public string CustomerName { get; set; } = string.Empty;
    public string Product { get; set; } = string.Empty;
    public int Quantity { get; set; }
    public decimal Price { get; set; }
    public DateTime OrderDate { get; set; }
    public OrderStatus Status { get; set; }
}

public enum OrderStatus
{
    Created,
    Processing,
    Completed,
    Cancelled
}