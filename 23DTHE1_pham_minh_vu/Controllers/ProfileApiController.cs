using _23DTHE1_pham_minh_vu.Models;
using _23DTHE1_pham_minh_vu.Repositories;
using _23DTHE1_pham_minh_vu.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;

namespace _23DTHE1_pham_minh_vu.Controllers;

// Hồ sơ người dùng. Cần đăng nhập. "me" là hồ sơ của chính mình; {userId} là hồ sơ công khai của người khác.
[Route("api/[controller]")]
[ApiController]
[Authorize]
public class ProfileApiController : ControllerBase
{
    private const int DefaultPageSize = 10;
    private const int MaxPageSize = 50;

    private readonly UserManager<User> _userManager;
    private readonly IPostRepository _postRepository;
    private readonly ICurrentUserService _currentUser;
    private readonly ILogger<ProfileApiController> _logger;

    public ProfileApiController(
        UserManager<User> userManager,
        IPostRepository postRepository,
        ICurrentUserService currentUser,
        ILogger<ProfileApiController> logger)
    {
        _userManager = userManager;
        _postRepository = postRepository;
        _currentUser = currentUser;
        _logger = logger;
    }

    private ObjectResult Error(int status, string message) => StatusCode(status, new { status = false, message });

    private async Task<MyProfileDto> BuildMyProfileAsync(User user) => new()
    {
        Id = user.Id,
        UserName = user.UserName,
        Email = user.Email,
        PhoneNumber = user.PhoneNumber,
        DisplayName = user.DisplayName ?? user.UserName,
        AvatarUrl = user.AvatarUrl,
        CoverUrl = user.CoverUrl,
        Bio = user.Bio,
        Initials = user.Initials,
        Roles = await _userManager.GetRolesAsync(user),
        PostCount = await _postRepository.CountByAuthorAsync(user.Id),
    };

    [HttpGet("me")]
    public async Task<IActionResult> GetMe()
    {
        try
        {
            var user = await _currentUser.GetUserAsync(User);
            if (user == null) return Unauthorized();
            return Ok(await BuildMyProfileAsync(user));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi lấy hồ sơ của tôi");
            return StatusCode(500, "Internal server error");
        }
    }

    // Đổi DisplayName, AvatarUrl, CoverUrl, Bio, PhoneNumber. AvatarUrl/CoverUrl rỗng = xóa ảnh.
    [HttpPut("me")]
    public async Task<IActionResult> UpdateMe([FromBody] ProfileUpdateModel model)
    {
        try
        {
            var user = await _currentUser.GetUserAsync(User);
            if (user == null) return Unauthorized();

            var displayName = model.DisplayName.Trim();
            if (displayName.Length == 0) return Error(400, "Tên hiển thị không được để trống");

            static string? NullIfBlank(string? s) => string.IsNullOrWhiteSpace(s) ? null : s.Trim();

            user.DisplayName = displayName;
            user.AvatarUrl = NullIfBlank(model.AvatarUrl);
            user.CoverUrl = NullIfBlank(model.CoverUrl);
            user.Bio = NullIfBlank(model.Bio);

            var phone = NullIfBlank(model.PhoneNumber);
            if (phone != user.PhoneNumber)
            {
                var phoneResult = await _userManager.SetPhoneNumberAsync(user, phone);
                if (!phoneResult.Succeeded)
                    return Error(400, string.Join(" ", phoneResult.Errors.Select(e => e.Description)));
            }

            var result = await _userManager.UpdateAsync(user);
            if (!result.Succeeded)
                return Error(400, string.Join(" ", result.Errors.Select(e => e.Description)));

            return Ok(await BuildMyProfileAsync(user));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi cập nhật hồ sơ");
            return StatusCode(500, "Internal server error");
        }
    }

    // Hồ sơ công khai: không có email, số điện thoại, tên đăng nhập
    [HttpGet("{userId}")]
    public async Task<IActionResult> GetProfile(string userId)
    {
        try
        {
            var user = await _userManager.FindByIdAsync(userId);
            if (user == null) return Error(404, "Không tìm thấy người dùng");

            return Ok(new PublicProfileDto
            {
                Id = user.Id,
                DisplayName = user.DisplayName ?? user.UserName,
                AvatarUrl = user.AvatarUrl,
                CoverUrl = user.CoverUrl,
                Bio = user.Bio,
                PostCount = await _postRepository.CountByAuthorAsync(user.Id),
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi lấy hồ sơ {UserId}", userId);
            return StatusCode(500, "Internal server error");
        }
    }

    /// <summary>Bài đăng của một người, mới nhất trước. Luôn phân trang: { items, page, pageSize, totalCount, hasMore }.</summary>
    [HttpGet("{userId}/posts")]
    public async Task<IActionResult> GetProfilePosts(string userId, [FromQuery] int page = 1, [FromQuery] int? pageSize = null)
    {
        try
        {
            var viewer = await _currentUser.GetUserAsync(User);
            if (viewer == null) return Unauthorized();

            if (page < 1) return Error(400, "page phải từ 1 trở lên");
            if (pageSize is < 1) return Error(400, "pageSize phải từ 1 trở lên");
            var size = Math.Min(pageSize ?? DefaultPageSize, MaxPageSize);

            if (await _userManager.FindByIdAsync(userId) == null) return Error(404, "Không tìm thấy người dùng");

            return Ok(await _postRepository.GetPageAsync(page, size, userId, viewer.Id, User.IsInRole("Admin")));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi lấy bài đăng của {UserId}", userId);
            return StatusCode(500, "Internal server error");
        }
    }
}
