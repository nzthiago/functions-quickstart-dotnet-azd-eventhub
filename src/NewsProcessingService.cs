using Microsoft.Extensions.Logging;

namespace function_app;

public class NewsProcessingService
{
    private readonly ILogger<NewsProcessingService> _logger;

    // In-memory storage for demo purposes (in production, use database)
    private static readonly Dictionary<string, NewsArticle> _processedArticles = new();
    private static readonly List<NewsMetrics> _newsMetrics = new();

    public NewsProcessingService(ILogger<NewsProcessingService> logger)
    {
        _logger = logger;
    }

    public async Task ProcessNewsArticles(List<NewsArticle> articles)
    {
        var tasks = new List<Task>();

        foreach (var article in articles)
        {
            // Process each article
            tasks.Add(ProcessSingleArticle(article));
        }

        await Task.WhenAll(tasks);

        // Generate batch analytics
        await GenerateBatchAnalytics(articles);
    }

    private async Task ProcessSingleArticle(NewsArticle article)
    {
        try
        {
            // 1. Validate article
            await ValidateArticle(article);

            // 2. Update article status
            await UpdateArticleStatus(article);

            // 3. Calculate article metrics
            await CalculateArticleMetrics(article);

            // 4. Store processed article
            _processedArticles[article.ArticleId] = article;

            _logger.LogInformation($"✅ Successfully processed article {article.ArticleId} - '{article.Title}' by {article.Author}");
        }
        catch (Exception ex)
        {
            _logger.LogError($"❌ Error processing article {article.ArticleId}: {ex.Message}");
        }
    }

    private async Task ValidateArticle(NewsArticle article)
    {
        // Simple validation rules
        var validationErrors = new List<string>();

        if (string.IsNullOrWhiteSpace(article.ArticleId))
            validationErrors.Add("ArticleId is required");
        
        if (string.IsNullOrWhiteSpace(article.Title))
            validationErrors.Add("Title is required");
        
        if (string.IsNullOrWhiteSpace(article.Author))
            validationErrors.Add("Author is required");
        
        if (string.IsNullOrWhiteSpace(article.Content))
            validationErrors.Add("Content is required");
        
        if (string.IsNullOrWhiteSpace(article.Source))
            validationErrors.Add("Source is required");

        if (string.IsNullOrWhiteSpace(article.Category))
            validationErrors.Add("Category is required");

        if (article.ViewCount < 0)
            validationErrors.Add("ViewCount cannot be negative");

        if (validationErrors.Any())
        {
            var errorMessage = string.Join(", ", validationErrors);
            _logger.LogWarning($"⚠️ Article validation failed for {article.ArticleId}: {errorMessage}");
            throw new ArgumentException($"Article validation failed: {errorMessage}");
        }

        _logger.LogDebug($"✓ Article {article.ArticleId} passed validation");
        await Task.CompletedTask;
    }

    private async Task UpdateArticleStatus(NewsArticle article)
    {
        // Simulate news processing workflow
        switch (article.Status)
        {
            case ArticleStatus.Draft:
                article.Status = ArticleStatus.Published;
                _logger.LogInformation($"📝 Article {article.ArticleId} moved to Published");
                break;
                
            case ArticleStatus.Published:
                // High engagement articles get featured
                if (article.ViewCount > 5000 || Math.Abs(article.SentimentScore) > 0.7)
                {
                    article.Status = ArticleStatus.Featured;
                    _logger.LogInformation($"⭐ High-engagement article {article.ArticleId} (Views: {article.ViewCount}, Sentiment: {article.SentimentScore:F2}) featured!");
                }
                else
                {
                    _logger.LogInformation($"📰 Article {article.ArticleId} remains published");
                }
                break;
                
            case ArticleStatus.Featured:
                _logger.LogInformation($"🌟 Featured article {article.ArticleId} continues trending");
                break;
                
            case ArticleStatus.Archived:
                _logger.LogInformation($"📚 Article {article.ArticleId} archived");
                break;
        }

        await Task.CompletedTask;
    }

    private async Task CalculateArticleMetrics(NewsArticle article)
    {
        var metrics = new NewsMetrics
        {
            ArticleId = article.ArticleId,
            Title = article.Title,
            Author = article.Author,
            Category = article.Category,
            Source = article.Source,
            ViewCount = article.ViewCount,
            SentimentScore = article.SentimentScore,
            ProcessingTime = DateTime.UtcNow,
            Status = article.Status,
            EngagementScore = CalculateEngagementScore(article)
        };

        _newsMetrics.Add(metrics);

        // Keep only recent metrics (last 100 articles)
        if (_newsMetrics.Count > 100)
        {
            _newsMetrics.RemoveRange(0, _newsMetrics.Count - 100);
        }

        // Log interesting metrics
        if (article.ViewCount > 5000)
        {
            _logger.LogInformation($"🔥 Viral article: {article.ArticleId} - {article.ViewCount:N0} views");
        }

        if (Math.Abs(article.SentimentScore) > 0.8)
        {
            var sentiment = article.SentimentScore > 0 ? "Very Positive" : "Very Negative";
            _logger.LogInformation($"😊😢 Strong sentiment article: {article.ArticleId} - {sentiment} ({article.SentimentScore:F2})");
        }

        if (article.Tags?.Length > 3)
        {
            _logger.LogInformation($"🏷️ Well-tagged article: {article.ArticleId} - {article.Tags.Length} tags");
        }

        await Task.CompletedTask;
    }

    private double CalculateEngagementScore(NewsArticle article)
    {
        // Simple engagement scoring algorithm
        var baseScore = Math.Log10(Math.Max(1, article.ViewCount)) * 10;
        var sentimentBonus = Math.Abs(article.SentimentScore) * 20;
        var tagBonus = (article.Tags?.Length ?? 0) * 2;
        
        return Math.Round(baseScore + sentimentBonus + tagBonus, 2);
    }

    private async Task GenerateBatchAnalytics(List<NewsArticle> articles)
    {
        var totalArticles = articles.Count;
        var totalViews = articles.Sum(a => a.ViewCount);
        var avgViews = totalArticles > 0 ? totalViews / totalArticles : 0;
        var avgSentiment = totalArticles > 0 ? articles.Average(a => a.SentimentScore) : 0;
        
        var statusCounts = articles.GroupBy(a => a.Status)
            .ToDictionary(g => g.Key, g => g.Count());

        var categoryCounts = articles.GroupBy(a => a.Category)
            .OrderByDescending(g => g.Count())
            .Take(3)
            .ToDictionary(g => g.Key, g => g.Count());

        var sourceCounts = articles.GroupBy(a => a.Source)
            .OrderByDescending(g => g.Count())
            .Take(3)
            .ToDictionary(g => g.Key, g => g.Count());

        // Log batch summary
        var statusSummary = string.Join(", ", statusCounts.Select(kvp => $"{kvp.Key}: {kvp.Value}"));
        var topCategories = string.Join(", ", categoryCounts.Select(kvp => $"{kvp.Key}: {kvp.Value}"));
        var topSources = string.Join(", ", sourceCounts.Select(kvp => $"{kvp.Key}: {kvp.Value}"));

        _logger.LogInformation(
            $"📊 NEWS BATCH SUMMARY: {totalArticles} articles | Total Views: {totalViews:N0} | " +
            $"Avg Views: {avgViews:N0} | Avg Sentiment: {avgSentiment:F2} | Status: [{statusSummary}]"
        );

        _logger.LogInformation($"📂 Top Categories: [{topCategories}] | Top Sources: [{topSources}]");

        // Check for interesting patterns
        var viralArticles = articles.Count(a => a.ViewCount > 5000);
        if (viralArticles > 0)
        {
            _logger.LogInformation($"🔥 Viral articles in batch: {viralArticles}");
        }

        var strongSentimentArticles = articles.Count(a => Math.Abs(a.SentimentScore) > 0.7);
        if (strongSentimentArticles > 0)
        {
            _logger.LogInformation($"😊😢 Strong sentiment articles in batch: {strongSentimentArticles}");
        }

        var wellTaggedArticles = articles.Count(a => a.Tags?.Length > 3);
        if (wellTaggedArticles > 0)
        {
            _logger.LogInformation($"🏷️ Well-tagged articles in batch: {wellTaggedArticles}");
        }

        await Task.CompletedTask;
    }
}

// Supporting data model
public class NewsMetrics
{
    public string ArticleId { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Author { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public string Source { get; set; } = string.Empty;
    public int ViewCount { get; set; }
    public double SentimentScore { get; set; }
    public double EngagementScore { get; set; }
    public DateTime ProcessingTime { get; set; }
    public ArticleStatus Status { get; set; }
}