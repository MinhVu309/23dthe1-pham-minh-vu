using System.Security.Claims;
using _23DTHE1_pham_minh_vu.Models;
using Microsoft.AspNetCore.Identity;

namespace _23DTHE1_pham_minh_vu.Services;

/// <summary>Tìm người dùng đang đăng nhập từ token.</summary>
public interface ICurrentUserService
{
    /// <summary>null nếu token không còn khớp với tài khoản nào (VD tài khoản đã bị xóa).</summary>
    Task<User?> GetUserAsync(ClaimsPrincipal principal);
}

public class CurrentUserService : ICurrentUserService
{
    private readonly UserManager<User> _userManager;

    public CurrentUserService(UserManager<User> userManager)
    {
        _userManager = userManager;
    }

    public async Task<User?> GetUserAsync(ClaimsPrincipal principal)
    {
        // Token mới có claim NameIdentifier (Id người dùng)
        var id = principal.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!string.IsNullOrEmpty(id))
        {
            var byId = await _userManager.FindByIdAsync(id);
            if (byId != null) return byId;
        }

        // Token cấp trước khi có claim đó (còn hạn tới 1 giờ) vẫn dùng được: tra theo tên đăng nhập
        var name = principal.FindFirstValue(ClaimTypes.Name);
        return string.IsNullOrEmpty(name) ? null : await _userManager.FindByNameAsync(name);
    }
}
