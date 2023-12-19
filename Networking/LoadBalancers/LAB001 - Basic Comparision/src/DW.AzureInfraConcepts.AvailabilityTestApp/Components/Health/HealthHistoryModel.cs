namespace DW.AzureInfraConcepts.AvailabilityTestApp.Components.Health;

public class HealthHistoryModel
{
    public HealthHistoryModel(string status) : this(status, "UNKNOWN") { }

    public HealthHistoryModel(string status, string source)
    {
        Status = status;
        Source = source;
        Timestamp = DateTime.UtcNow;
    }

    public DateTime Timestamp { get; }
    public string Status { get; } 
    public string Source { get; }
}
