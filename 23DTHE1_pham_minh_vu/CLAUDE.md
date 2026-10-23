# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

ASP.NET Core Web API (`net10.0`, controllers-based, not minimal APIs) backed by SQL Server via EF Core, with ASP.NET Core Identity + JWT for login and roles (`Admin`, `User`). Resources: `Product` (with name search and an optional `Category`), `Category`, `Post` (Facebook-style posts) and `Authenticate` (register/login). It is a coursework project (student ID `23DTHE1`). Consumers: a static frontend on VS Code Live Server, and the Flutter app in the sibling directory `../pham_minh_vu_23dthe1` (Android emulator reaches this backend at `http://10.0.2.2:5126`). There is no test project and the directory is not a git repository.

Root namespace is `_23DTHE1_pham_minh_vu` (the project name starts with a digit, so the namespace has a leading underscore). Use it for any new files.

## Commands

```bash
dotnet build
dotnet run --launch-profile http     # http://localhost:5126
dotnet run --launch-profile https    # https://localhost:7014 and http://localhost:5126

# EF Core migrations (dotnet-ef is installed globally)
dotnet ef migrations add <Name>
dotnet ef database update
dotnet ef migrations list
```

- `launchBrowser` is false. In Development, `app.MapOpenApi()` serves the raw OpenAPI document at `/openapi/v1.json`, and `Swashbuckle.AspNetCore.SwaggerUI` (UI only, no SwaggerGen) serves Swagger UI at `/swagger` reading that document. A document transformer adds a Bearer scheme, so Swagger UI has an **Authorize** button: log in via `api/Authenticate/login`, paste the token.
- [23DTHE1_pham_minh_vu.http](23DTHE1_pham_minh_vu.http) is the only request file (VS Code REST Client); it covers Authenticate, ProductApi, CategoryApi and PostApi, and captures the login tokens into `@adminToken` / `@userToken`.
- Run the backend with the `http` profile when testing from a mobile emulator; the https dev certificate is rejected by emulators.
- Test accounts (create with `register` if the database is fresh): `admin1` / `Admin@12345` (role Admin) and `user1` / `User@12345` (role User). Passwords must contain upper case, lower case, a digit and a symbol.
- To test token expiry quickly, override the lifetime for one run: `JWTKey__TokenExpiryTimeInHour=0.004 dotnet run --launch-profile http` (about 14 seconds).

## Architecture

Request flow: controller → repository interface → `ApplicationDbContext` → SQL Server. `AuthenticateController` is the exception: it uses `UserManager<User>` directly.

- [Program.cs](Program.cs) wires everything, in this order: `AddDbContext` (`DefaultConnection`), `AddIdentity<User, IdentityRole>` + EF stores, then `AddAuthentication` with JwtBearer as default scheme (**must come after `AddIdentity`**, which otherwise makes cookies the default), controllers (invalid model state is returned as `{ status: false, message }`), `AddScoped` for the Product/Post/Category repositories, OpenAPI (+ Bearer scheme), CORS policy `MyAllowOrigins`. On startup it creates the `Admin` and `User` roles (logs an error instead of crashing if the tables don't exist yet). `UseAuthentication()` runs before `UseAuthorization()`. Identity's `MapIdentityApi` is intentionally **not** used.
- JWT settings are in the `JWTKey` section of [appsettings.json](appsettings.json) (`Secret`, `ValidIssuer`, `ValidAudience`, `TokenExpiryTimeInHour`, a double). `ClockSkew` is zero, so expired tokens are rejected immediately. The `Secret` is a dev-only random string; replace it (user-secrets or `JWTKey__Secret`) for anything real.
- [Controllers/AuthenticateController.cs](Controllers/AuthenticateController.cs): `register` and `login` always answer `{ status: bool, message, token? }` (`status` is a boolean, the Flutter client depends on that). Register only accepts role `Admin` or `User` (empty means `User`, anything else is 400), and returns 400 with the Identity error descriptions for duplicates or weak passwords. Login returns 401 for a wrong username or password. The token is built with `new JwtSecurityToken(...)`, so claim names are **full URIs**: username `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name`, role `http://schemas.microsoft.com/ws/2008/06/identity/claims/role` (a string for one role, an array for several). Clients must read these exact names.
- Authorization: `ProductApiController` and `CategoryApiController` are `[Authorize]` at class level (any logged-in user can read); POST/PUT/DELETE on both are `[Authorize(Roles = "Admin")]`. `PostApiController` and `AuthenticateController` are anonymous.
- [Controllers/ProductApiController.cs](Controllers/ProductApiController.cs) is routed at `api/ProductApi` (from `api/[controller]`), so routes keep the `Api` suffix; `GET search?name=` does a case-insensitive `Contains` on `Name`. Every action wraps its body in a try/catch that logs via `ILogger` and returns a bare `500 "Internal server error"`. PUT requires the body `Id` to equal the URL id, otherwise 400. POST/PUT validate `CategoryId` (null is allowed, an unknown id is 400).
- `ProductRepository` always `Include`s `Category`, and nulls the `Category` navigation on add/update so a client-sent `category` object can never create a category; only `CategoryId` counts. `UpdateProductAsync` marks the whole entity `Modified`, so PUT overwrites every column (the client must resend `categoryId`, even `null`).
- `Category.Products` is `[JsonIgnore]` (avoids a Product→Category→Products JSON cycle). The `Product`→`Category` relationship is configured in `OnModelCreating` with `DeleteBehavior.SetNull`: deleting a category sets `CategoryId` to `NULL` on its products instead of deleting them or failing.
- `PostRepository` sets `CreatedAt` server-side on insert (client value ignored), keeps it unchanged on update, and returns posts newest first. SQL Server returns `CreatedAt` without a `Z` suffix although values are UTC; clients must treat it as UTC (the Flutter `Post` model does).
- [Controllers/WeatherForecastController.cs](Controllers/WeatherForecastController.cs) and [WeatherForecast.cs](WeatherForecast.cs) are leftover template code.

## Database and migrations

- `ApplicationDbContext` extends `IdentityDbContext<User>` (`User` adds `Initials`, max length 5). `OnModelCreating` calls `HasDefaultSchema("identity")`, so **all tables, including `Products`, `Posts` and `Categories`, live in the `identity` schema**. Raw SQL must write `[identity].Products` (`identity` is a reserved word). `__EFMigrationsHistory` stays in `dbo`.
- Migrations in order: `InitialModel` (`Products`), `AddPost` (`Posts` + 5 seed posts), `FixPostSeedDates`, `InitialIdentityModel` (Identity tables; moves `Products`/`Posts` to the `identity` schema with `RenameTable`, no data loss), `AddCategory` (`Categories`, nullable `Products.CategoryId`, FK `ON DELETE SET NULL`). Always read a generated migration before applying it: a `DropTable`/`CreateTable` of an existing business table would lose data.
- `Post` seed data lives in `OnModelCreating` via `HasData`, so changing it needs a new migration, and seed `CreatedAt` values must be fixed and not in the future. EF warns that `Product.Price` has no explicit precision (the column is `decimal(18,2)`).

## Environment gotchas

- SQL Server must be reachable at `localhost,1433` (the Docker container `sqlserver`; start it with `docker start sqlserver`). The connection string in [appsettings.json](appsettings.json) uses the `sa` account with a plaintext password and `TrustServerCertificate=True`. Don't copy that password into other files, and prefer user-secrets or an environment variable (`ConnectionStrings__DefaultConnection`) for any new credentials.
- Nothing applies migrations at startup. Run `dotnet ef database update` before the first run, or every endpoint that touches the database fails (and the role seeding logs an error).
- Stop old backend processes before restarting: a leftover process keeps port 5126 and the new one fails to start, so you silently keep testing the old build.
- CORS only allows `http://127.0.0.1:5500` and `http://localhost:5500` (VS Code Live Server); native mobile apps are not affected. Add other frontend origins in the `MyAllowOrigins` policy in [Program.cs](Program.cs).
- EF Core packages are pinned to `8.0.3`, and so are `Microsoft.AspNetCore.Identity.EntityFrameworkCore` and `Microsoft.AspNetCore.Authentication.JwtBearer`, while the target framework is `net10.0` and `Microsoft.AspNetCore.OpenApi` is `10.0.2`. Keep all of these on the same version when upgrading, since mismatches break migrations.
