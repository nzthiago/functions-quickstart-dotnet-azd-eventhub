using System;
using System.Text.Json;
using Azure.Identity;
using Azure.Messaging.EventHubs;
using Azure.Messaging.EventHubs.Producer;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace order_generator;

public class OrderGenerator
{
    private readonly ILogger _logger;
    private readonly EventHubProducerClient _eventHubClient;
    private readonly Random _random = new();

    // Sample data for generating realistic orders
    private readonly string[] _customerNames = {
        "Alice Johnson", "Bob Smith", "Carol Brown", "David Wilson", "Emma Davis",
        "Frank Miller", "Grace Lee", "Henry Garcia", "Ivy Martinez", "Jack Anderson"
    };

    private readonly string[] _products = {
        "Laptop", "Smartphone", "Headphones", "Tablet", "Monitor",
        "Keyboard", "Mouse", "Webcam", "Speaker", "Charger"
    };

    private readonly decimal[] _basePrices = {
        999.99m, 699.99m, 149.99m, 499.99m, 299.99m,
        79.99m, 49.99m, 89.99m, 199.99m, 39.99m
    };

    public OrderGenerator(ILoggerFactory loggerFactory)
    {
        _logger = loggerFactory.CreateLogger<OrderGenerator>();
        
        // Initialize EventHub client using connection string or managed identity
        var eventHubNamespace = Environment.GetEnvironmentVariable("EventHubNamespace");
        var eventHubName = Environment.GetEnvironmentVariable("EventHubName") ?? "orders";
        var connectionString = Environment.GetEnvironmentVariable("EventHubConnection");

        if (!string.IsNullOrEmpty(connectionString))
        {
            _eventHubClient = new EventHubProducerClient(connectionString, eventHubName);
        }
        else if (!string.IsNullOrEmpty(eventHubNamespace))
        {
            var fullyQualifiedNamespace = $"{eventHubNamespace}.servicebus.windows.net";
            _eventHubClient = new EventHubProducerClient(fullyQualifiedNamespace, eventHubName, new DefaultAzureCredential());
        }
        else
        {
            throw new InvalidOperationException("EventHub connection string or namespace must be configured");
        }
    }

    [Function("OrderGenerator")]
    public async Task Run([TimerTrigger("*/10 * * * * *")] TimerInfo myTimer) // Every 10 seconds - HIGH THROUGHPUT DEMO!
    {
        _logger.LogInformation("🚀 HIGH-THROUGHPUT Order Generator started at: {executionTime}", DateTime.Now);
        
        try
        {
            // Generate 5-15 orders per execution for HIGH THROUGHPUT DEMO
            var orderCount = _random.Next(5, 16);
            var orders = new List<Order>();

            for (int i = 0; i < orderCount; i++)
            {
                var order = GenerateRandomOrder();
                orders.Add(order);
            }

            // Send orders to EventHub
            await SendOrdersToEventHub(orders);

            _logger.LogInformation("✅ HIGH-THROUGHPUT: Successfully generated and sent {orderCount} orders in ~10 seconds", orderCount);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "❌ Error generating orders: {errorMessage}", ex.Message);
            throw;
        }
        
        if (myTimer.ScheduleStatus is not null)
        {
            _logger.LogInformation("⏰ Next order generation scheduled at: {nextSchedule}", myTimer.ScheduleStatus.Next);
        }
    }

    private Order GenerateRandomOrder()
    {
        var productIndex = _random.Next(_products.Length);
        var customerIndex = _random.Next(_customerNames.Length);
        
        var order = new Order
        {
            OrderId = $"ORD-{DateTime.UtcNow:yyyyMMdd}-{Guid.NewGuid().ToString()[..8].ToUpper()}",
            CustomerName = _customerNames[customerIndex],
            Product = _products[productIndex],
            Quantity = _random.Next(1, 11), // 1-10 items
            Price = _basePrices[productIndex] * (decimal)(0.8 + _random.NextDouble() * 0.4), // ±20% price variation
            OrderDate = DateTime.UtcNow,
            Status = OrderStatus.Created
        };

        _logger.LogDebug("📦 Generated order: {orderId} - {customerName} ordered {quantity}x {product} for ${totalValue:F2}",
            order.OrderId, order.CustomerName, order.Quantity, order.Product, order.Price * order.Quantity);

        return order;
    }

    private async Task SendOrdersToEventHub(List<Order> orders)
    {
        using var eventBatch = await _eventHubClient.CreateBatchAsync();

        foreach (var order in orders)
        {
            var orderJson = JsonSerializer.Serialize(order, new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            });

            var eventData = new EventData(orderJson);
            
            // Add properties for routing and filtering
            eventData.Properties.Add("orderType", "newOrder");
            eventData.Properties.Add("customerId", order.CustomerName.Replace(" ", "").ToLower());
            eventData.Properties.Add("totalValue", (order.Price * order.Quantity).ToString("F2"));

            if (!eventBatch.TryAdd(eventData))
            {
                _logger.LogWarning("⚠️ Event batch is full. Order {orderId} may not be sent in this batch.", order.OrderId);
            }
            else
            {
                _logger.LogDebug("📤 Added order {orderId} to batch", order.OrderId);
            }
        }

        if (eventBatch.Count > 0)
        {
            await _eventHubClient.SendAsync(eventBatch);
            _logger.LogInformation("📨 Sent batch of {batchSize} orders to EventHub", eventBatch.Count);
        }
        else
        {
            _logger.LogWarning("⚠️ No orders were added to the batch");
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