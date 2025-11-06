using Microsoft.Extensions.Logging;

namespace function_app;

public class OrderProcessingService
{
    private readonly ILogger _logger;

    // In-memory storage for demo purposes (in production, use database)
    private static readonly Dictionary<string, Order> _processedOrders = new();
    private static readonly List<OrderMetrics> _orderMetrics = new();

    public OrderProcessingService(ILogger logger)
    {
        _logger = logger;
    }

    public async Task ProcessOrders(List<Order> orders)
    {
        var tasks = new List<Task>();

        foreach (var order in orders)
        {
            // Process each order
            tasks.Add(ProcessSingleOrder(order));
        }

        await Task.WhenAll(tasks);

        // Generate batch analytics
        await GenerateBatchAnalytics(orders);
    }

    private async Task ProcessSingleOrder(Order order)
    {
        try
        {
            // 1. Validate order
            await ValidateOrder(order);

            // 2. Update order status
            await UpdateOrderStatus(order);

            // 3. Calculate order metrics
            await CalculateOrderMetrics(order);

            // 4. Store processed order
            _processedOrders[order.OrderId] = order;

            _logger.LogInformation($"✅ Successfully processed order {order.OrderId} for {order.CustomerName}");
        }
        catch (Exception ex)
        {
            _logger.LogError($"❌ Error processing order {order.OrderId}: {ex.Message}");
        }
    }

    private async Task ValidateOrder(Order order)
    {
        // Simple validation rules
        var validationErrors = new List<string>();

        if (string.IsNullOrWhiteSpace(order.OrderId))
            validationErrors.Add("OrderId is required");
        
        if (string.IsNullOrWhiteSpace(order.CustomerName))
            validationErrors.Add("CustomerName is required");
        
        if (string.IsNullOrWhiteSpace(order.Product))
            validationErrors.Add("Product is required");
        
        if (order.Quantity <= 0)
            validationErrors.Add("Quantity must be greater than 0");
        
        if (order.Price <= 0)
            validationErrors.Add("Price must be greater than 0");

        if (validationErrors.Any())
        {
            var errorMessage = string.Join(", ", validationErrors);
            _logger.LogWarning($"⚠️ Order validation failed for {order.OrderId}: {errorMessage}");
            throw new ArgumentException($"Order validation failed: {errorMessage}");
        }

        _logger.LogDebug($"✓ Order {order.OrderId} passed validation");
        await Task.CompletedTask;
    }

    private async Task UpdateOrderStatus(Order order)
    {
        // Simulate order processing workflow
        switch (order.Status)
        {
            case OrderStatus.Created:
                order.Status = OrderStatus.Processing;
                _logger.LogInformation($"� Order {order.OrderId} moved to Processing");
                break;
                
            case OrderStatus.Processing:
                // Randomly complete or keep processing based on order value
                var totalValue = order.Price * order.Quantity;
                if (totalValue > 1000)
                {
                    // High-value orders need more processing time
                    _logger.LogInformation($"💰 High-value order {order.OrderId} (${totalValue:F2}) requires additional processing");
                }
                else
                {
                    order.Status = OrderStatus.Completed;
                    _logger.LogInformation($"✨ Order {order.OrderId} completed");
                }
                break;
                
            case OrderStatus.Completed:
                _logger.LogInformation($"📦 Order {order.OrderId} is ready for shipping");
                break;
                
            case OrderStatus.Cancelled:
                _logger.LogWarning($"❌ Order {order.OrderId} was cancelled");
                break;
        }

        await Task.CompletedTask;
    }

    private async Task CalculateOrderMetrics(Order order)
    {
        var totalValue = order.Price * order.Quantity;
        
        var metrics = new OrderMetrics
        {
            OrderId = order.OrderId,
            CustomerName = order.CustomerName,
            Product = order.Product,
            TotalValue = totalValue,
            ProcessingTime = DateTime.UtcNow,
            Status = order.Status
        };

        _orderMetrics.Add(metrics);

        // Keep only recent metrics (last 100 orders)
        if (_orderMetrics.Count > 100)
        {
            _orderMetrics.RemoveRange(0, _orderMetrics.Count - 100);
        }

        // Log interesting metrics
        if (totalValue > 500)
        {
            _logger.LogInformation($"� High-value order: {order.OrderId} - ${totalValue:F2}");
        }

        if (order.Quantity > 10)
        {
            _logger.LogInformation($"� Bulk order: {order.OrderId} - {order.Quantity} units of {order.Product}");
        }

        await Task.CompletedTask;
    }

    private async Task GenerateBatchAnalytics(List<Order> orders)
    {
        var totalOrders = orders.Count;
        var totalValue = orders.Sum(o => o.Price * o.Quantity);
        var avgOrderValue = totalOrders > 0 ? totalValue / totalOrders : 0;
        
        var statusCounts = orders.GroupBy(o => o.Status)
            .ToDictionary(g => g.Key, g => g.Count());

        var productCounts = orders.GroupBy(o => o.Product)
            .OrderByDescending(g => g.Count())
            .Take(3)
            .ToDictionary(g => g.Key, g => g.Count());

        // Log batch summary
        var statusSummary = string.Join(", ", statusCounts.Select(kvp => $"{kvp.Key}: {kvp.Value}"));
        var topProducts = string.Join(", ", productCounts.Select(kvp => $"{kvp.Key}: {kvp.Value}"));

        _logger.LogInformation(
            $"� BATCH SUMMARY: {totalOrders} orders | Total: ${totalValue:F2} | " +
            $"Avg: ${avgOrderValue:F2} | Status: [{statusSummary}] | Top Products: [{topProducts}]"
        );

        // Check for interesting patterns
        var highValueOrders = orders.Count(o => o.Price * o.Quantity > 1000);
        if (highValueOrders > 0)
        {
            _logger.LogInformation($"💰 High-value orders in batch: {highValueOrders}");
        }

        var bulkOrders = orders.Count(o => o.Quantity > 10);
        if (bulkOrders > 0)
        {
            _logger.LogInformation($"📦 Bulk orders in batch: {bulkOrders}");
        }

        await Task.CompletedTask;
    }
}

// Supporting data model
public class OrderMetrics
{
    public string OrderId { get; set; } = string.Empty;
    public string CustomerName { get; set; } = string.Empty;
    public string Product { get; set; } = string.Empty;
    public decimal TotalValue { get; set; }
    public DateTime ProcessingTime { get; set; }
    public OrderStatus Status { get; set; }
}