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

    /// <summary>
    /// Đăng ký tài khoản bằng email (mặc định role Employee). Tài khoản mới CHƯA xác minh email: server gửi mã 6 số
    /// tới email, người dùng nhập mã ở <c>verify-otp</c> thì email mới được xác minh và nhận được JWT.
    /// </summary>
    [HttpPost("register")]
    public async Task<IActionResult> Register(RegisterDto dto)
    {
        var user = await users.FindByEmailAsync(dto.Email);
        if (user is null)
        {
            user = new AppUser { UserName = dto.Email, Email = dto.Email, FullName = dto.FullName, EmailConfirmed = false };
            var result = await users.CreateAsync(user, dto.Password);
            if (!result.Succeeded) return BadRequest(new { errors = result.Errors.Select(e => e.Description) });
            await users.AddToRoleAsync(user, Roles.Employee);
        }
        else if (user.EmailConfirmed)
        {
            // Cùng dạng lỗi với Identity để app dịch sang tiếng Việt.
            return BadRequest(new { errors = new[] { $"Email '{dto.Email}' is already taken." } });
        }
        else
        {
            // Email này đã có người đăng ký nhưng chưa ai xác minh được. Cho đăng ký lại (ghi đè tên và mật khẩu)
            // để người giữ hộp thư thật không bị kẻ khác chiếm email; ai cũng vẫn phải nhập mã gửi về hộp thư mới vào được.
            var reset = await users.ResetPasswordAsync(user, await users.GeneratePasswordResetTokenAsync(user), dto.Password);
            if (!reset.Succeeded) return BadRequest(new { errors = reset.Errors.Select(e => e.Description) });
            user.FullName = dto.FullName;
            await users.UpdateAsync(user);
        }

        await otp.SendAsync(user);
        return Ok(new { requiresEmailVerification = true, message = "Đã gửi mã xác minh tới email. Nhập mã để hoàn tất đăng ký." });
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

    /// <summary>
    /// Quên mật khẩu, bước 1: gửi mã 6 số tới email. Luôn trả cùng một thông báo dù email có tài khoản hay không,
    /// để không lộ email nào đã đăng ký. Gửi dồn dập (dưới 1 phút) bị bỏ qua.
    /// </summary>
    [HttpPost("forgot-password")]
    public async Task<IActionResult> ForgotPassword(ForgotPasswordDto dto)
    {
        var user = await users.FindByEmailAsync(dto.Email);
        if (user is not null && user.IsActive && !await otp.SentRecentlyAsync(user))
            await otp.SendAsync(user, OtpPurpose.PasswordReset);
        return Ok(new { message = "Nếu email có tài khoản, mã đặt lại mật khẩu đã được gửi. Mã có hiệu lực 5 phút." });
    }

    /// <summary>
    /// Quên mật khẩu, bước 2: nhập mã + mật khẩu mới. Đúng mã thì đổi mật khẩu, xác minh email và đăng nhập luôn (trả JWT):
    /// người nhập được mã đã chứng tỏ giữ hộp thư, cùng mức bảo đảm với OTP đăng nhập.
    /// </summary>
    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword(ResetPasswordDto dto)
    {
        var user = await users.FindByEmailAsync(dto.Email);
        if (user is null || !user.IsActive) return Unauthorized(new { message = "Mã không đúng hoặc đã hết hạn" });

        // Kiểm tra luật mật khẩu TRƯỚC khi dùng mã, để nhập mật khẩu yếu không làm mất mã.
        foreach (var validator in users.PasswordValidators)
        {
            var check = await validator.ValidateAsync(users, user, dto.NewPassword);
            if (!check.Succeeded) return BadRequest(new { errors = check.Errors.Select(e => e.Description) });
        }

        if (!await otp.VerifyAsync(user, dto.Code, OtpPurpose.PasswordReset))
            return Unauthorized(new { message = "Mã không đúng hoặc đã hết hạn" });

        var reset = await users.ResetPasswordAsync(user, await users.GeneratePasswordResetTokenAsync(user), dto.NewPassword);
        if (!reset.Succeeded) return BadRequest(new { errors = reset.Errors.Select(e => e.Description) });

        if (!user.EmailConfirmed)
        {
            user.EmailConfirmed = true;
            await users.UpdateAsync(user);
        }
        return Ok(await IssueAsync(user));
    }

    /// <summary>Bước 2: nhập OTP → nhận JWT. Role trả về để app điều hướng Admin / Employee.</summary>
    [HttpPost("verify-otp")]
    public async Task<IActionResult> VerifyOtp(VerifyOtpDto dto)
    {
        var user = await FindAsync(dto.UserNameOrEmail);
        if (user is null || !await otp.VerifyAsync(user, dto.Code))
            return Unauthorized(new { message = "OTP sai hoặc hết hạn" });

        // Nhập đúng mã gửi tới hộp thư nghĩa là người dùng giữ hộp thư này: coi như email đã xác minh.
        if (!user.EmailConfirmed)
        {
            user.EmailConfirmed = true;
            await users.UpdateAsync(user);
        }
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
