using Microsoft.Extensions.Diagnostics.HealthChecks;
using System.Net.Mime;
using System.Text.Json.Serialization;
using System.Text.Json;
using Microsoft.Extensions.Options;
using DW.AzureInfraConcepts.AvailabilityTestApp.Components.Settings;

namespace DW.AzureInfraConcepts.AvailabilityTestApp.Components.Health;

public class HealthCheckResponseWriterExtension
{
    public static Task WriteResponse(HttpContext context, HealthReport report)
    {
        var applicationOptions = context.RequestServices.GetService<IOptions<ApplicationOptions>>();

        var jsonSerializerOptions = new JsonSerializerOptions
        {
            WriteIndented = false,
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
        };

        string json = JsonSerializer.Serialize(
            new
            {
                Status = report.Status.ToString(),
                Duration = report.TotalDuration,
                Instance = applicationOptions?.Value?.AppName ?? "UNKNOWN",
                Info = report.Entries
                    .Select(e =>
                        new
                        {
                            Key = e.Key,
                            Description = e.Value.Description,
                            Duration = e.Value.Duration,
                            Status = Enum.GetName(
                                typeof(HealthStatus),
                                e.Value.Status),
                            Error = e.Value.Exception?.Message,
                            Data = e.Value.Data
                        })
                    .ToList()
            },
            jsonSerializerOptions);

        context.Response.ContentType = MediaTypeNames.Application.Json;
        return context.Response.WriteAsync(json);
    }
}
