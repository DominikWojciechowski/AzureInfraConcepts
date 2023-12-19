using Microsoft.AspNetCore.SignalR;

namespace DW.AzureInfraConcepts.AvailabilityTestApp.Components.Notifications;

public class NotificationHub : Hub<INotificationHubClient>
{
}

public interface INotificationHubClient
{
    Task GlobalMessage(string message);
}