using DW.AzureInfraConcepts.AvailabilityTestApp.Components.Settings;
using Microsoft.Extensions.Options;

namespace DW.AzureInfraConcepts.AvailabilityTestApp.Components.Health;

public interface IHealthConfigurationModel
{
    int FailurePercentage { get; set; }
}

public class HealthConfigurationModel : IHealthConfigurationModel
{
    public HealthConfigurationModel(IOptions<ApplicationOptions> applicationOptions) 
    {
        if (int.TryParse(applicationOptions.Value.FailurePercentage, out var failurePercentage))
        {
            FailurePercentage = failurePercentage;
        }
    }

    public int FailurePercentage { get; set; } = 0;
}

