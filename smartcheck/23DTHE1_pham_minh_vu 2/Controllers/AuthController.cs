using System.Security.Claims;
using Google.Apis.Auth;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartCheck.Api.Dtos;
using SmartCheck.Api.Models;
using SmartCheck.Api.Services;

namespace SmartCheck.Api.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController(UserManager<AppUser> users, OtpService otp, JwtService jwt, IConfiguration cfg) : ControllerBase
{
    private async Task<AppUser?> FindAsync(string key) =>
        await users.FindByEmailAsync(key) ?? await users.FindByNameAsync(key);

    private async Task<AuthResultDto> IssueAsync(AppUser u)
    {
        var roles = await users.GetRolesAsync(u);
        return new AuthResultDto(jwt.Create(u, roles), roles.FirstOrDefault() ?? Roles.Employee, u.Id, u.FullName, u.Email ?? "");
    }

    /// <summary>Đăng ký tài khoản bằng email (mặc định role Employee).</summary>
    [HttpPost("register")]
    public async Task<IActionResult> Register(RegisterDto dto)
    {
        var user = new AppUser { UserName = dto.Email, Email = dto.Email, FullName = dto.FullName };
        var result = await users.CreateAsync(user, dto.Password);
        if (!result.Succeeded) return BadRequest(new { errors = result.Errors.Select(e => e.Description) });
        await users.AddToRoleAsync(user, Roles.Employee);
        return Ok(new { message = "Đăng ký thành công, hãy đăng nhập." });
    }

    /// <summary>Bước 1: tên đăng nhập/email + mật khẩu. Đúng thì gửi Email OTP.</summary>
    [HttpPost("login")]
    public async Task<IActionResult> Login(LoginDto dto)
    {
        var user = await FindAsync(dto.UserNameOrEmail);
        if (user is null || !await users.CheckPasswordAsync(user, dto.Password))
            return Unauthorized(new { message = "Sai tài khoản hoặc mật khẩu" });
        if (!user.IsActive) return StatusCode(403, new { message = "Tài khoản đã bị khoá" });

        await otp.SendAsync(user);
        return Ok(new { requiresOtp = true, message = "Đã gửi mã OTP tới email" });
    }

    [HttpPost("resend-otp")]
    public async Task<IActionResult> Resend(ResendOtpDto dto)
    {
        var user = await FindAsync(dto.UserNameOrEmail);
        if (user is not null && user.IsActive) await otp.SendAsync(user);
        return Ok(new { message = "Nếu tài khoản tồn tại, mã OTP mới đã được gửi" });
    }

    /// <summary>Bước 2: nhập OTP → nhận JWT. Role trả về để app điều hướng Admin / Employee.</summary>
    [HttpPost("verify-otp")]
    public async Task<IActionResult> VerifyOtp(VerifyOtpDto dto)
    {
        var user = await FindAsync(dto.UserNameOrEmail);
        if (user is null || !await otp.VerifyAsync(user, dto.Code))
            return Unauthorized(new { message = "OTP sai hoặc hết hạn" });
        return Ok(await IssueAsync(user));
    }

    /// <summary>OAuth2: app đăng nhập Google, gửi idToken lên đây để backend xác thực.</summary>
    [HttpPost("google-login")]
    public async Task<IActionResult> GoogleLogin(GoogleLoginDto dto)
    {
        GoogleJsonWebSignature.Payload payload;
        try
        {
            payload = await GoogleJsonWebSignature.ValidateAsync(dto.IdToken,
                new GoogleJsonWebSignature.ValidationSettings { Audience = new[] { cfg["Google:ClientId"] } });
        }
        catch (InvalidJwtException)
        {
            return Unauthorized(new { message = "Google token không hợp lệ" });
        }

        var user = await users.FindByEmailAsync(payload.Email);
        if (user is null)
        {
            user = new AppUser { UserName = payload.Email, Email = payload.Email, EmailConfirmed = true,
                FullName = payload.Name ?? payload.Email };
            var created = await users.CreateAsync(user);
            if (!created.Succeeded) return BadRequest(new { errors = created.Errors.Select(e => e.Description) });
            await users.AddToRoleAsync(user, Roles.Employee);
        }
        if (!user.IsActive) return StatusCode(403, new { message = "Tài khoản đã bị khoá" });
        return Ok(await IssueAsync(user));
    }

    [Authorize, HttpGet("me")]
    public async Task<IActionResult> Me()
    {
        var user = await users.FindByIdAsync(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        if (user is null) return Unauthorized();
        var roles = await users.GetRolesAsync(user);
        return Ok(new { user.Id, user.FullName, user.Email, user.EmployeeCode, user.DepartmentId,
            role = roles.FirstOrDefault(), hasFace = user.FaceEmbeddingJson != null, deviceBound = user.DeviceId != null });
    }
}
