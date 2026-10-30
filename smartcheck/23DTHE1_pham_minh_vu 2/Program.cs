using System.Text;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using SmartCheck.Api.Data;
using SmartCheck.Api.Models;
using SmartCheck.Api.Services;

var builder = WebApplication.CreateBuilder(args);
var cfg = builder.Configuration;

builder.Services.AddDbContext<AppDbContext>(o => o.UseSqlServer(cfg.GetConnectionString("DefaultConnection")));

builder.Services.AddIdentityCore<AppUser>(o =>
{
    o.Password.RequireNonAlphanumeric = false;
    o.Password.RequireUppercase = false;
    o.Password.RequiredLength = 6;
    o.User.RequireUniqueEmail = true;
})
.AddRoles<IdentityRole>()
.AddEntityFrameworkStores<AppDbContext>()
.AddDefaultTokenProviders();

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true, ValidIssuer = cfg["Jwt:Issuer"],
            ValidateAudience = true, ValidAudience = cfg["Jwt:Audience"],
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(cfg["Jwt:Key"]!)),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromMinutes(1)
        };
    });
builder.Services.AddAuthorization();

builder.Services.AddScoped<JwtService>();
builder.Services.AddScoped<EmailService>();
builder.Services.AddScoped<OtpService>();
builder.Services.AddScoped<BiometricService>();
builder.Services.AddScoped<FraudService>();
builder.Services.AddSingleton<QrTokenService>();

builder.Services.AddCors(o => o.AddDefaultPolicy(p => p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));

builder.Services.AddControllers().AddJsonOptions(o =>
{
    o.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter());
    o.JsonSerializerOptions.Converters.Add(new UtcDateTimeConverter());
});

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "SmartCheck API - 23DTHE1_pham_minh_vu", Version = "v1" });
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization", Type = SecuritySchemeType.Http, Scheme = "bearer",
        BearerFormat = "JWT", In = ParameterLocation.Header, Description = "Dán JWT (không cần chữ Bearer)"
    });
    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        { new OpenApiSecurityScheme { Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" } }, Array.Empty<string>() }
    });
});

var app = builder.Build();

// Tạo schema + seed. Khi đã dùng migration (dotnet ef migrations add Init) thì đổi EnsureCreated -> Migrate.
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await db.Database.EnsureCreatedAsync();
    // EnsureCreated không thêm bảng mới vào DB đã tồn tại, nên tự bổ sung bảng đăng nhập sinh trắc học nếu thiếu.
    await db.Database.ExecuteSqlRawAsync("""
        IF OBJECT_ID(N'[BiometricCredentials]', N'U') IS NULL
        BEGIN
            CREATE TABLE [BiometricCredentials] (
                [Id] int NOT NULL IDENTITY(1,1) CONSTRAINT [PK_BiometricCredentials] PRIMARY KEY,
                [UserId] nvarchar(450) NOT NULL,
                [DeviceId] nvarchar(200) NOT NULL,
                [TokenHash] nvarchar(64) NOT NULL,
                [CreatedAt] datetime2 NOT NULL,
                [ExpiresAt] datetime2 NOT NULL,
                [LastUsedAt] datetime2 NULL,
                [Revoked] bit NOT NULL
            );
            CREATE UNIQUE INDEX [IX_BiometricCredentials_TokenHash] ON [BiometricCredentials] ([TokenHash]);
            CREATE INDEX [IX_BiometricCredentials_UserId_DeviceId] ON [BiometricCredentials] ([UserId], [DeviceId]);
        END
        """);
    await DbSeeder.SeedAsync(scope.ServiceProvider, cfg);
}

// Swagger luôn bật (kể cả khi deploy) để thầy/nhóm test API trên URL thật.
app.UseSwagger();
app.UseSwaggerUI();

app.UseCors();
app.UseAuthentication();
app.UseAuthorization();
app.MapGet("/", () => Results.Redirect("/swagger"));
app.MapControllers();

app.Run();
