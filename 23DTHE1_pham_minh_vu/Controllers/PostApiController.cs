using _23DTHE1_pham_minh_vu.Models;
using _23DTHE1_pham_minh_vu.Repositories;
using _23DTHE1_pham_minh_vu.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace _23DTHE1_pham_minh_vu.Controllers;

// Bài đăng kiểu Facebook. Mọi thao tác cần đăng nhập; sửa/xóa chỉ chủ bài hoặc Admin.
[Route("api/[controller]")]
[ApiController]
[Authorize]
public class PostApiController : ControllerBase
{
    private const int DefaultPageSize = 10;
    private const int MaxPageSize = 50;
    private const int DefaultCommentPageSize = 50;
    private const int MaxCommentPageSize = 100;

    private readonly IPostRepository _postRepository;
    private readonly ICommentRepository _commentRepository;
    private readonly ICurrentUserService _currentUser;
    private readonly ILogger<PostApiController> _logger;

    public PostApiController(
        IPostRepository postRepository,
        ICommentRepository commentRepository,
        ICurrentUserService currentUser,
        ILogger<PostApiController> logger)
    {
        _postRepository = postRepository;
        _commentRepository = commentRepository;
        _currentUser = currentUser;
        _logger = logger;
    }

    private bool IsAdmin => User.IsInRole("Admin");

    private ObjectResult Error(int status, string message) => StatusCode(status, new { status = false, message });

    // Chủ bài hoặc Admin. Bài mẫu cũ không có chủ (UserId null) thì chỉ Admin.
    private bool CanModify(Post post, string userId) => IsAdmin || (post.UserId != null && post.UserId == userId);

    private static string? NormalizeImage(string? image) => string.IsNullOrWhiteSpace(image) ? null : image.Trim();

    /// <summary>
    /// Không truyền page: trả MẢNG như bản cũ (mới nhất trước, tối đa 50 bài; có thể giới hạn thêm bằng pageSize).
    /// Có page: trả { items, page, pageSize, totalCount, hasMore } (pageSize mặc định 10, tối đa 50).
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetPosts([FromQuery] int? page, [FromQuery] int? pageSize)
    {
        try
        {
            var user = await _currentUser.GetUserAsync(User);
            if (user == null) return Unauthorized();

            if (page == null)
            {
                var max = Math.Clamp(pageSize ?? MaxPageSize, 1, MaxPageSize);
                return Ok(await _postRepository.GetLatestAsync(max, user.Id, IsAdmin));
            }

            if (page < 1) return Error(400, "page phải từ 1 trở lên");
            if (pageSize is < 1) return Error(400, "pageSize phải từ 1 trở lên");
            var size = Math.Min(pageSize ?? DefaultPageSize, MaxPageSize);

            return Ok(await _postRepository.GetPageAsync(page.Value, size, null, user.Id, IsAdmin));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi lấy danh sách bài đăng");
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetPostById(int id)
    {
        try
        {
            var user = await _currentUser.GetUserAsync(User);
            if (user == null) return Unauthorized();

            var post = await _postRepository.GetDtoByIdAsync(id, user.Id, IsAdmin);
            if (post == null) return Error(404, "Không tìm thấy bài đăng");
            return Ok(post);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi lấy bài đăng {Id}", id);
            return StatusCode(500, "Internal server error");
        }
    }

    // Chủ bài, tên và ảnh đại diện do SERVER lấy từ tài khoản đăng nhập; các trường client gửi thêm đều bị bỏ qua
    [HttpPost]
    public async Task<IActionResult> AddPost([FromBody] PostCreateModel model)
    {
        try
        {
            var user = await _currentUser.GetUserAsync(User);
            if (user == null) return Unauthorized();

            var content = model.Content?.Trim() ?? string.Empty;
            var image = NormalizeImage(model.Image);
            if (content.Length == 0 && image == null)
                return Error(400, "Bài viết cần có nội dung hoặc ảnh");

            var post = new Post
            {
                UserId = user.Id,
                UserName = user.DisplayName ?? user.UserName,
                UserAvatar = user.AvatarUrl,
                Content = content,
                Image = image,
            };
            await _postRepository.AddAsync(post);

            var dto = await _postRepository.GetDtoByIdAsync(post.Id, user.Id, IsAdmin);
            return CreatedAtAction(nameof(GetPostById), new { id = post.Id }, dto);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi thêm bài đăng");
            return StatusCode(500, "Internal server error");
        }
    }

    // Chỉ đổi được nội dung và ảnh
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdatePost(int id, [FromBody] PostUpdateModel model)
    {
        try
        {
            if (model.Id != null && model.Id != id)
                return BadRequest();

            var user = await _currentUser.GetUserAsync(User);
            if (user == null) return Unauthorized();

            var post = await _postRepository.GetByIdAsync(id);
            if (post == null) return Error(404, "Không tìm thấy bài đăng");
            if (!CanModify(post, user.Id)) return Error(403, "Bạn chỉ được sửa bài viết của chính mình");

            var content = model.Content?.Trim() ?? string.Empty;
            var image = NormalizeImage(model.Image);
            if (content.Length == 0 && image == null)
                return Error(400, "Bài viết cần có nội dung hoặc ảnh");

            await _postRepository.UpdateContentAsync(post, content, image);
            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi sửa bài đăng {Id}", id);
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeletePost(int id)
    {
        try
        {
            var user = await _currentUser.GetUserAsync(User);
            if (user == null) return Unauthorized();

            var post = await _postRepository.GetByIdAsync(id);
            if (post == null) return NoContent(); // xóa bài không còn tồn tại: coi như đã xong (như bản cũ)
            if (!CanModify(post, user.Id)) return Error(403, "Bạn chỉ được xóa bài viết của chính mình");

            await _postRepository.DeleteAsync(post);
            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi xóa bài đăng {Id}", id);
            return StatusCode(500, "Internal server error");
        }
    }

    // ---------------- Thích ----------------

    /// <summary>Bật/tắt thích của người đang đăng nhập. Trả { liked, likeCount }.</summary>
    [HttpPost("{id}/like")]
    public async Task<IActionResult> ToggleLike(int id)
    {
        try
        {
            var user = await _currentUser.GetUserAsync(User);
            if (user == null) return Unauthorized();

            var post = await _postRepository.GetByIdAsync(id);
            if (post == null) return Error(404, "Không tìm thấy bài đăng");

            var (liked, likeCount) = await _postRepository.ToggleLikeAsync(post, user.Id);
            return Ok(new { liked, likeCount });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi thích/bỏ thích bài đăng {Id}", id);
            return StatusCode(500, "Internal server error");
        }
    }

    // ---------------- Bình luận ----------------

    /// <summary>Cũ nhất trước. page mặc định 1, pageSize mặc định 50 (tối đa 100); tổng số nằm ở header X-Total-Count.</summary>
    [HttpGet("{id}/comments")]
    public async Task<IActionResult> GetComments(int id, [FromQuery] int page = 1, [FromQuery] int? pageSize = null)
    {
        try
        {
            var user = await _currentUser.GetUserAsync(User);
            if (user == null) return Unauthorized();

            if (page < 1) return Error(400, "page phải từ 1 trở lên");
            if (pageSize is < 1) return Error(400, "pageSize phải từ 1 trở lên");
            var size = Math.Min(pageSize ?? DefaultCommentPageSize, MaxCommentPageSize);

            if (await _postRepository.GetByIdAsync(id) == null) return Error(404, "Không tìm thấy bài đăng");

            var (items, total) = await _commentRepository.GetByPostAsync(id, page, size, user.Id, IsAdmin);
            Response.Headers["X-Total-Count"] = total.ToString();
            return Ok(items);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi lấy bình luận của bài đăng {Id}", id);
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpPost("{id}/comments")]
    public async Task<IActionResult> AddComment(int id, [FromBody] CommentCreateModel model)
    {
        try
        {
            var user = await _currentUser.GetUserAsync(User);
            if (user == null) return Unauthorized();

            var content = model.Content.Trim();
            if (content.Length == 0) return Error(400, "Bình luận không được để trống");

            if (await _postRepository.GetByIdAsync(id) == null) return Error(404, "Không tìm thấy bài đăng");

            var comment = new Comment { PostId = id, UserId = user.Id, Content = content };
            await _commentRepository.AddAsync(comment);

            var dto = await _commentRepository.GetDtoAsync(comment.Id, user.Id, IsAdmin);
            return Created($"api/PostApi/{id}/comments/{comment.Id}", dto);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi thêm bình luận vào bài đăng {Id}", id);
            return StatusCode(500, "Internal server error");
        }
    }

    // Được xóa: chủ bình luận, chủ bài, hoặc Admin
    [HttpDelete("{id}/comments/{commentId}")]
    public async Task<IActionResult> DeleteComment(int id, int commentId)
    {
        try
        {
            var user = await _currentUser.GetUserAsync(User);
            if (user == null) return Unauthorized();

            var comment = await _commentRepository.GetAsync(id, commentId);
            if (comment == null) return Error(404, "Không tìm thấy bình luận");

            var allowed = IsAdmin || comment.UserId == user.Id || comment.Post?.UserId == user.Id;
            if (!allowed) return Error(403, "Bạn không có quyền xóa bình luận này");

            await _commentRepository.DeleteAsync(comment);
            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi xóa bình luận {CommentId} của bài đăng {Id}", commentId, id);
            return StatusCode(500, "Internal server error");
        }
    }
}
