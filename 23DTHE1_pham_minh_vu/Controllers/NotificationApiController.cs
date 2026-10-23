using _23DTHE1_pham_minh_vu.Repositories;
using _23DTHE1_pham_minh_vu.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace _23DTHE1_pham_minh_vu.Controllers;

// Thông báo: lượt thích và bình luận của người khác trên bài của tôi trong 7 ngày gần nhất
[Route("api/[controller]")]
[ApiController]
[Authorize]
public class NotificationApiController : ControllerBase
{
    private const int Days = 7;
    private const int MaxItems = 50;

    private readonly INotificationRepository _notificationRepository;
    private readonly ICurrentUserService _currentUser;
    private readonly ILogger<NotificationApiController> _logger;

    public NotificationApiController(
        INotificationRepository notificationRepository,
        ICurrentUserService currentUser,
        ILogger<NotificationApiController> logger)
    {
        _notificationRepository = notificationRepository;
        _currentUser = currentUser;
        _logger = logger;
    }

    [HttpGet]
    public async Task<IActionResult> GetNotifications()
    {
        try
        {
            var user = await _currentUser.GetUserAsync(User);
            if (user == null) return Unauthorized();

            var since = DateTime.UtcNow.AddDays(-Days);
            return Ok(await _notificationRepository.GetForUserAsync(user.Id, since, MaxItems));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi lấy thông báo");
            return StatusCode(500, "Internal server error");
        }
    }
}
