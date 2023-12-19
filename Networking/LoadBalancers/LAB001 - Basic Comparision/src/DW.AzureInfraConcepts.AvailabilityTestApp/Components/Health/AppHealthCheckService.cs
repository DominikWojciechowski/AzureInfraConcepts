using DW.AzureInfraConcepts.AvailabilityTestApp.Components.Notifications;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace DW.AzureInfraConcepts.AvailabilityTestApp.Components.Health;

public interface IAppHealthCheckService : IHealthCheck
{
    List<HealthHistoryModel> HealthCheckHistory { get; set; }

    IHealthConfigurationModel AppHealthConfiguration { get; set; }
}

public class AppHealthCheckService : IAppHealthCheckService
{
    private IHealthConfigurationModel _appHealthConfiguration;
    private List<HealthHistoryModel> _healthCheckHistory = new();
    private Random _random = new Random();
    private IHttpContextAccessor _httpContextAccessor;
    private IHubContext<NotificationHub, INotificationHubClient> _notificationHubContext;

    public AppHealthCheckService(
        IHttpContextAccessor httpContextAccessor,
        IHubContext<NotificationHub, INotificationHubClient> notificationHubContext,
        IHealthConfigurationModel healthConfigurationModel
    )
    {
        _httpContextAccessor = httpContextAccessor;
        _notificationHubContext = notificationHubContext;
        _appHealthConfiguration = healthConfigurationModel;
    }

    public List<HealthHistoryModel> HealthCheckHistory
    {
        get { return _healthCheckHistory; }
        set { _healthCheckHistory = value; }
    }

    public IHealthConfigurationModel AppHealthConfiguration
    {
        get { return _appHealthConfiguration; }
        set { _appHealthConfiguration = value; }
    }

    public Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        if (_random.Next(100) < _appHealthConfiguration.FailurePercentage)
        {
            LogStatus("Unhealthy");
            return Task.FromResult(HealthCheckResult.Unhealthy());
        }

        LogStatus("Healthy");
        return Task.FromResult(HealthCheckResult.Healthy());
    }

    private void LogStatus(string status)
    {
        var connection = _httpContextAccessor.HttpContext?.Connection;
        string source = $"{connection?.Id} | {connection?.RemoteIpAddress?.ToString()}:{connection?.RemotePort}";

        HealthCheckHistory.Add(new HealthHistoryModel(status, source));

        _notificationHubContext.Clients.All.GlobalMessage("HealthCheckRequestReceived");
    }
}
