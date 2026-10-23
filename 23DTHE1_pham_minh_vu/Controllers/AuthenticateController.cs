using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using _23DTHE1_pham_minh_vu.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;

namespace _23DTHE1_pham_minh_vu.Controllers;

[Route("api/[controller]")]
[ApiController]
public class AuthenticateController : ControllerBase
{
    // Chỉ cho phép đăng ký với hai vai trò này
    public static readonly string[] AllowedRoles = { "Admin", "User" };

    private readonly UserManager<User> _userManager;
    private readonly IConfiguration _configuration;
    private readonly ILogger<AuthenticateController> _logger;

    public AuthenticateController(
        UserManager<User> userManager,
        IConfiguration configuration,
        ILogger<AuthenticateController> logger)
    {
        _userManager = userManager;
        _configuration = configuration;
        _logger = logger;
    }

    // POST api/Authenticate/login -> { status (bool), message, token }
    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginModel model)
    {
        try
        {
            var user = await _userManager.FindByNameAsync(model.Username);
            if (user == null || !await _userManager.CheckPasswordAsync(user, model.Password))
            {
                // Không tiết lộ là sai tên đăng nhập hay sai mật khẩu
                return Unauthorized(new { status = false, message = "Sai tên đăng nhập hoặc mật khẩu" });
            }

            var userRoles = await _userManager.GetRolesAsync(user);
            var authClaims = new List<Claim>
            {
                new Claim(ClaimTypes.Name, user.UserName!),
                // Id người dùng: bài đăng/like/bình luận gắn theo Id này. Token cũ (không có claim này) vẫn dùng được
                // vì CurrentUserService tra theo tên đăng nhập.
                new Claim(ClaimTypes.NameIdentifier, user.Id),
                new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            };
            authClaims.AddRange(userRoles.Select(role => new Claim(ClaimTypes.Role, role)));

            var token = CreateToken(authClaims);
            return Ok(new
            {
                status = true,
                message = "Đăng nhập thành công",
                token = new JwtSecurityTokenHandler().WriteToken(token),
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi đăng nhập user {Username}", model.Username);
            return StatusCode(500, new { status = false, message = "Internal server error" });
        }
    }

    // POST api/Authenticate/register
    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegistrationModel model)
    {
        try
        {
            var role = string.IsNullOrWhiteSpace(model.Role) ? "User" : model.Role.Trim();
            // So khớp không phân biệt hoa thường rồi chuẩn hóa về đúng tên role
            var normalizedRole = AllowedRoles.FirstOrDefault(r => r.Equals(role, StringComparison.OrdinalIgnoreCase));
            if (normalizedRole == null)
            {
                return BadRequest(new { status = false, message = "Role chỉ được là Admin hoặc User" });
            }

            if (await _userManager.FindByNameAsync(model.Username) != null)
            {
                return BadRequest(new { status = false, message = "Tên đăng nhập đã tồn tại" });
            }

            var user = new User
            {
                UserName = model.Username,
                Email = model.Email,
                Initials = model.Initials,
                // Tên hiển thị mặc định = tên đăng nhập (cắt còn 50 ký tự)
                DisplayName = string.IsNullOrWhiteSpace(model.DisplayName)
                    ? Truncate(model.Username, 50)
                    : model.DisplayName.Trim(),
                PhoneNumber = string.IsNullOrWhiteSpace(model.PhoneNumber) ? null : model.PhoneNumber.Trim(),
                SecurityStamp = Guid.NewGuid().ToString(),
            };

            var result = await _userManager.CreateAsync(user, model.Password);
            if (!result.Succeeded)
            {
                // Mật khẩu yếu, email trùng... -> 400 kèm toàn bộ mô tả lỗi
                var errors = string.Join(" ", result.Errors.Select(e => e.Description));
                return BadRequest(new { status = false, message = errors });
            }

            var roleResult = await _userManager.AddToRoleAsync(user, normalizedRole);
            if (!roleResult.Succeeded)
            {
                // Tránh để lại user không có role
                await _userManager.DeleteAsync(user);
                var errors = string.Join(" ", roleResult.Errors.Select(e => e.Description));
                return StatusCode(500, new { status = false, message = errors });
            }

            return Ok(new { status = true, message = "Tạo tài khoản thành công" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi đăng ký user {Username}", model.Username);
            return StatusCode(500, new { status = false, message = "Internal server error" });
        }
    }

    private static string Truncate(string value, int max) => value.Length <= max ? value : value[..max];

    private JwtSecurityToken CreateToken(List<Claim> authClaims)
    {
        var jwt = _configuration.GetSection("JWTKey");
        var signingKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt["Secret"]!));
        var expiryHours = double.Parse(jwt["TokenExpiryTimeInHour"]!, System.Globalization.CultureInfo.InvariantCulture);

        return new JwtSecurityToken(
            issuer: jwt["ValidIssuer"],
            audience: jwt["ValidAudience"],
            expires: DateTime.UtcNow.AddHours(expiryHours),
            claims: authClaims,
            signingCredentials: new SigningCredentials(signingKey, SecurityAlgorithms.HmacSha256));
    }
}
