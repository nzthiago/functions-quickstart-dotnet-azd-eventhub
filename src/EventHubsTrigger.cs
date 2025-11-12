using System.Text.Json;
using Azure.Messaging.EventHubs;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace function_app;

public class EventHubsTrigger
{
    private readonly ILogger<EventHubsTrigger> _logger;
    private readonly NewsProcessingService _newsService;

    public EventHubsTrigger(ILogger<EventHubsTrigger> logger, NewsProcessingService newsService)
    {
        _logger = logger;
        _newsService = newsService;
    }

    [Function(nameof(EventHubsTrigger))]
    public async Task Run([EventHubTrigger("news", Connection = "EventHubConnection")] EventData[] input)
    {
        var processedArticles = new List<NewsArticle>();
        var failedEvents = 0;
        
        foreach (var message in input)
        {
            try
            {
                var messageBody = message.EventBody.ToString();

                // Parse the news article event
                var article = ParseNewsArticleEvent(messageBody);

                if (article != null)
                {
                    processedArticles.Add(article);
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
        _logger.LogInformation($"📰 Processed {processedArticles.Count} news articles, {failedEvents} failed in batch of {input.Length}");

        // Process all articles in batch
        if (processedArticles.Count > 0)
        {
            await _newsService.ProcessNewsArticles(processedArticles);
        }
    }
    
    private NewsArticle? ParseNewsArticleEvent(string message)
    {
        try
        {
            // Parse using JsonSerializer with camelCase policy to match generator
            var options = new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true,
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            };
            
            var article = JsonSerializer.Deserialize<NewsArticle>(message, options);
            
            if (article != null)
            {
                _logger.LogDebug($"📥 Received news article: {article.ArticleId} - {article.Title} by {article.Author}");
            }
            
            return article;
        }
        catch (Exception ex)
        {
            _logger.LogError($"Failed to parse news article event: {ex.Message}");
            return null;
        }
    }
}

public class NewsArticle
{
    public string ArticleId { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
    public string Author { get; set; } = string.Empty;
    public string Source { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public DateTime PublishedDate { get; set; }
    public int ViewCount { get; set; }
    public double SentimentScore { get; set; }
    public ArticleStatus Status { get; set; }
    public string[] Tags { get; set; } = Array.Empty<string>();
}

public enum ArticleStatus
{
    Draft,
    Published,
    Featured,
    Archived
}