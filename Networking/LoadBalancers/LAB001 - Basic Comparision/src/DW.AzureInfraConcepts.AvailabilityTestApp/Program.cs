using DW.AzureInfraConcepts.AvailabilityTestApp.Components;
using DW.AzureInfraConcepts.AvailabilityTestApp.Components.Health;
using DW.AzureInfraConcepts.AvailabilityTestApp.Components.Notifications;
using DW.AzureInfraConcepts.AvailabilityTestApp.Components.Settings;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

builder.Services.Configure<ApplicationOptions>(
    builder.Configuration.GetSection(nameof(ApplicationOptions))
);

builder.Services.AddSingleton<IAppHealthCheckService, AppHealthCheckService>();
builder.Services.AddSingleton<IHealthConfigurationModel, HealthConfigurationModel>();

builder.Services.AddHealthChecks().AddCheck<IAppHealthCheckService>("Application");

builder.Services.AddHttpClient();
builder.Services.AddHttpContextAccessor();

builder.Services.AddSignalR();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

// app.UseHttpsRedirection();

app.MapHealthChecks("/_health", new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions
{
    ResponseWriter = HealthCheckResponseWriterExtension.WriteResponse
});

app.UseStaticFiles();
app.UseAntiforgery();

app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.MapHub<NotificationHub>("/_notifications");

app.Run();
