using System;
using System.Text.Json;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace function_app;

public class NewsGenerator
{
    private readonly ILogger _logger;
    private readonly Random _random = new();

    // Sample data for generating realistic news articles
    private readonly string[] _authors = {
        "Sarah Johnson", "Michael Chen", "Emily Rodriguez", "David Kim", "Jessica Taylor",
        "Robert Anderson", "Lisa Zhang", "James Wilson", "Maria Garcia", "Alex Thompson"
    };

    private readonly string[] _sources = {
        "TechDaily", "Global News", "Business Wire", "Science Today", "Sports Central",
        "Health Herald", "Finance Focus", "Travel Times", "Culture Corner", "Politics Plus"
    };

    private readonly string[] _categories = {
        "Technology", "Business", "Science", "Sports", "Health",
        "Finance", "Travel", "Culture", "Politics", "Entertainment"
    };

    private readonly string[] _newsTitles = {
        "Breaking: Major Discovery in Renewable Energy Technology",
        "Global Markets Show Strong Recovery Amid Economic Uncertainty",
        "Scientists Announce Breakthrough in AI Research",
        "Championship Finals Draw Record-Breaking Viewership",
        "New Health Study Reveals Surprising Benefits of Exercise",
        "Tech Giant Announces Revolutionary Product Launch",
        "International Trade Agreements Reshape Global Economy",
        "Climate Change Research Shows Promising Solutions",
        "Sports Stars Unite for Charitable Cause",
        "Cultural Festival Celebrates Diversity and Innovation"
    };

    private readonly string[] _contentSnippets = {
        "In a groundbreaking development that could reshape the industry...",
        "Experts from around the world gathered to discuss the implications...",
        "The latest findings suggest significant potential for future growth...",
        "This unprecedented event has captured global attention...",
        "Researchers have been working tirelessly to understand the impact...",
        "The announcement comes at a critical time for the sector...",
        "Industry leaders expressed optimism about the developments...",
        "The study, conducted over several months, reveals important insights...",
        "This milestone represents years of dedicated effort and innovation...",
        "The collaboration between experts has yielded remarkable results..."
    };

    private readonly string[][] _tagsByCategory = {
        new[] { "innovation", "ai", "software", "hardware", "startup" },
        new[] { "market", "economy", "investment", "growth", "profit" },
        new[] { "research", "discovery", "experiment", "breakthrough", "study" },
        new[] { "championship", "team", "victory", "competition", "athlete" },
        new[] { "wellness", "medicine", "fitness", "nutrition", "mental-health" }
    };

    public NewsGenerator(ILoggerFactory loggerFactory)
    {
        _logger = loggerFactory.CreateLogger<NewsGenerator>();
    }

    [Function("NewsGenerator")]
    [EventHubOutput("news", Connection = "EventHubConnection")]
    public string[] Run([TimerTrigger("*/10 * * * * *")] TimerInfo myTimer) // Every 10 seconds - HIGH THROUGHPUT DEMO!
    {
        _logger.LogInformation("� HIGH-THROUGHPUT News Generator started at: {executionTime}", DateTime.Now);
        
        try
        {
            // Generate 3-8 news articles per execution for HIGH THROUGHPUT DEMO
            var articleCount = _random.Next(3, 9);
            var articlesJson = new List<string>();

            for (int i = 0; i < articleCount; i++)
            {
                var article = GenerateRandomNewsArticle();
                
                // Serialize article to JSON for EventHub
                var articleJson = JsonSerializer.Serialize(article, new JsonSerializerOptions
                {
                    PropertyNamingPolicy = JsonNamingPolicy.CamelCase
                });

                articlesJson.Add(articleJson);
                _logger.LogDebug("📤 Generated article {articleId} for EventHub output", article.ArticleId);
            }

            _logger.LogInformation("✅ HIGH-THROUGHPUT: Successfully generated {articleCount} news articles in ~10 seconds", articleCount);
            
            if (myTimer.ScheduleStatus is not null)
            {
                _logger.LogInformation("⏰ Next news generation scheduled at: {nextSchedule}", myTimer.ScheduleStatus.Next);
            }

            return articlesJson.ToArray();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "❌ Error generating news articles: {errorMessage}", ex.Message);
            throw;
        }
    }

    private NewsArticle GenerateRandomNewsArticle()
    {
        var authorIndex = _random.Next(_authors.Length);
        var sourceIndex = _random.Next(_sources.Length);
        var categoryIndex = _random.Next(_categories.Length);
        var titleIndex = _random.Next(_newsTitles.Length);
        var contentIndex = _random.Next(_contentSnippets.Length);
        
        var article = new NewsArticle
        {
            ArticleId = $"NEWS-{DateTime.UtcNow:yyyyMMdd}-{Guid.NewGuid().ToString()[..8].ToUpper()}",
            Title = _newsTitles[titleIndex],
            Content = _contentSnippets[contentIndex],
            Author = _authors[authorIndex],
            Source = _sources[sourceIndex],
            Category = _categories[categoryIndex],
            PublishedDate = DateTime.UtcNow,
            ViewCount = _random.Next(100, 10000),
            SentimentScore = Math.Round(_random.NextDouble() * 2 - 1, 2), // -1 to 1
            Status = ArticleStatus.Published,
            Tags = _tagsByCategory[categoryIndex % _tagsByCategory.Length]
        };

        _logger.LogDebug("� Generated article: {articleId} - '{title}' by {author} ({category})",
            article.ArticleId, article.Title, article.Author, article.Category);

        return article;
    }


}