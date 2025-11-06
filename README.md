# Order Processing with Event Hubs and Azure Functions

This sample demonstrates a simple order processing system using Azure Event Hubs and Azure Functions. The solution includes:

- **Order Generator**: A .NET Azure Function that generates random orders on a timer and sends them to Event Hubs
- **Order Processor**: A .NET Azure Function that processes orders received from Event Hubs
- **Infrastructure**: Bicep templates using Azure Verified Modules for deployment

## Architecture

```
┌─────────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│  Order Generator    │───▶│  Azure Event Hub │───▶│  Order Processor    │
│  (Function App)     │    │    "orders"      │    │  (Function App)     │
│  Timer Trigger      │    │                  │    │  EventHub Trigger   │
└─────────────────────┘    └──────────────────┘    └─────────────────────┘
```

## Features

- **Simple order generation** with timer-triggered Azure Function
- **Real-time order processing** with Event Hub triggers  
- **Order validation and status tracking**
- **Serverless compute** with Azure Functions
- **Infrastructure as Code** using Azure Verified Modules
- **Azure Developer CLI (azd)** integration for easy deployment

## Domain Model

### Order
- OrderId: Unique identifier
- CustomerName: Customer who placed the order
- Product: Product being ordered
- Quantity: Number of items
- Price: Unit price
- OrderDate: When the order was created
- Status: Created, Processing, Completed, Cancelled

## Quick Start

### 1. Deploy Infrastructure

```powershell
# Login to Azure
azd auth login

# Initialize and deploy
azd init
azd up
```

### 2. Monitor Order Processing

- **Application Insights**: View logs and performance metrics
- **Azure Portal**: Monitor Function Apps execution
- **Event Hub Metrics**: See message throughput

## Project Structure

```
order-processing-demo/
├── order-generator/          # Timer-triggered function for order generation
│   ├── OrderGenerator.cs     # Order generation logic
│   ├── local.settings.json   # Local development settings
│   └── order-generator.csproj
├── function-app/             # Event Hub triggered function for order processing
│   ├── EventHubsTrigger.cs   # Order processing function
│   ├── OrderProcessingService.cs # Order processing logic
│   └── function-app.csproj
├── infra/                    # Infrastructure as Code
│   ├── main.bicep           # Main deployment template
│   └── main.parameters.json
├── azure.yaml               # Azure Developer CLI configuration
└── README.md
```

## Order Generator

The order generator runs every minute and creates 1-5 random orders:

### Features
- **Timer trigger**: Generates orders every minute
- **Random data**: Creates realistic orders with random customers and products
- **Event Hub integration**: Sends orders to Azure Event Hubs
- **Configurable**: Easy to adjust generation frequency and patterns

### Sample Generated Orders
- Customer names from predefined list
- Products: Laptop, Smartphone, Headphones, etc.
- Realistic pricing with variations
- Random quantities (1-10 items)

## Order Processor

The order processor function handles incoming orders from Event Hubs:

### Features
- **Event Hub trigger**: Automatically processes orders as they arrive
- **Order validation**: Validates order data and logs errors
- **Status tracking**: Updates order status during processing
- **Business logic**: Applies rules for high-value orders, bulk orders
- **Metrics collection**: Tracks order processing metrics

### Processing Logic
- ✅ **Validation**: Ensures all required fields are present
- 🔄 **Status Updates**: Moves orders through processing workflow
- 💰 **High-value detection**: Special handling for orders > $1000
- 📦 **Bulk order detection**: Identifies orders with > 10 items
- 📊 **Batch analytics**: Provides summary statistics per batch

## Sample Processing Output

```
✅ Successfully processed order ORD-20251105-A1B2C3D4 for Alice Johnson
💰 High-value order: ORD-20251105-E5F6G7H8 - $1,299.99
📦 Bulk order: ORD-20251105-I9J0K1L2 - 15 units of Laptop
📊 BATCH SUMMARY: 3 orders | Total: $2,199.97 | Avg: $733.32
```

## Configuration

### Order Generator Settings
```json
{
  "EventHubConnection": "connection-string-or-empty-for-managed-identity",
  "EventHubNamespace": "namespace-name-for-managed-identity", 
  "EventHubName": "orders"
}
```

### Order Processor Settings
```json
{
  "EventHubConnection": "connection-string-or-empty-for-managed-identity"
}
```

## Infrastructure

Uses Azure Verified Modules (AVM) for best practices:

### Components
- **Event Hub Namespace**: Standard tier for order messaging
- **Event Hub**: "orders" hub with multiple partitions
- **Function Apps**: Both generator and processor (Flex Consumption plan)
- **Storage Account**: Required for Function App operation
- **Application Insights**: Monitoring and telemetry
- **Log Analytics**: Centralized logging

## Monitoring

### Application Insights Queries

**Orders Generated Per Minute**
```kusto
traces
| where message contains "Successfully generated and sent"
| summarize OrdersGenerated = sum(toint(extract(@"(\d+) orders", 1, message))) by bin(timestamp, 1m)
| render timechart
```

**Orders Processed Per Minute**  
```kusto
traces
| where message contains "BATCH SUMMARY"
| extend OrderCount = toint(extract(@"(\d+) orders", 1, message))
| summarize OrdersProcessed = sum(OrderCount) by bin(timestamp, 1m)
| render timechart
```

**High-Value Orders**
```kusto
traces
| where message contains "High-value order"
| extend OrderValue = todouble(extract(@"\$([0-9,]+\.?\d*)", 1, message))
| summarize HighValueOrders = count(), TotalValue = sum(OrderValue) by bin(timestamp, 5m)
```

## Development

### Running Locally
1. Set up Event Hub connection in `local.settings.json`
2. Start both function apps:
   ```powershell
   # Terminal 1 - Order Generator
   cd order-generator
   func start
   
   # Terminal 2 - Order Processor  
   cd function-app
   func start
   ```

### Testing
- Orders are generated automatically every minute
- View logs in both function app terminals
- Monitor Event Hub metrics in Azure Portal

## License

This project is licensed under the MIT License.

## Resources

- [Azure Event Hubs Documentation](https://docs.microsoft.com/azure/event-hubs/)
- [Azure Functions Documentation](https://docs.microsoft.com/azure/azure-functions/)
- [Azure Developer CLI](https://docs.microsoft.com/azure/developer/azure-developer-cli/)
