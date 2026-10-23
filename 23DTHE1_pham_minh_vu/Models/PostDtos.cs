using System.ComponentModel.DataAnnotations;

namespace _23DTHE1_pham_minh_vu.Models;

// ---------- Dữ liệu trả về ----------
// Tên trường giữ nguyên như bản cũ (userName, userAvatar, image, createdAt, likeCount, commentCount); chỉ THÊM trường mới.

public class PostDto
{
    public int Id { get; set; }
    public string? UserId { get; set; }
    public string? UserName { get; set; }
    public string? UserAvatar { get; set; }
    public string? Content { get; set; }
    public string? Image { get; set; }
    public DateTime CreatedAt { get; set; }
    public int LikeCount { get; set; }
    public int CommentCount { get; set; }
    public bool LikedByMe { get; set; }
    public bool CanEdit { get; set; }
}

public class CommentDto
{
    public int Id { get; set; }
    public int PostId { get; set; }
    public string? UserId { get; set; }
    public string? UserName { get; set; }
    public string? UserAvatar { get; set; }
    public string Content { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public bool CanDelete { get; set; }
}

public class NotificationDto
{
    public string Type { get; set; } = string.Empty; // "like" hoặc "comment"
    public int PostId { get; set; }
    public string? PostSnippet { get; set; }
    public string? ActorId { get; set; }
    public string? ActorName { get; set; }
    public string? ActorAvatar { get; set; }
    public string? CommentContent { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class PagedResult<T>
{
    public IReadOnlyList<T> Items { get; set; } = Array.Empty<T>();
    public int Page { get; set; }
    public int PageSize { get; set; }
    public int TotalCount { get; set; }
    public bool HasMore { get; set; }
}

// ---------- Dữ liệu nhận vào ----------
// Chỉ có đúng các trường được phép đổi: mọi trường khác client gửi lên (userName, likeCount, createdAt...) đều bị bỏ qua.

public class PostCreateModel
{
    [MaxLength(2000, ErrorMessage = "Nội dung tối đa 2000 ký tự")]
    public string? Content { get; set; }

    [HttpUrl(ErrorMessage = "Ảnh phải là đường dẫn http:// hoặc https:// (tối đa 500 ký tự)")]
    public string? Image { get; set; }
}

public class PostUpdateModel
{
    // Không bắt buộc; nếu có thì phải trùng id trên URL (giữ hành vi cũ)
    public int? Id { get; set; }

    [MaxLength(2000, ErrorMessage = "Nội dung tối đa 2000 ký tự")]
    public string? Content { get; set; }

    [HttpUrl(ErrorMessage = "Ảnh phải là đường dẫn http:// hoặc https:// (tối đa 500 ký tự)")]
    public string? Image { get; set; }
}

public class CommentCreateModel
{
    [Required(ErrorMessage = "Bình luận không được để trống")]
    [MaxLength(500, ErrorMessage = "Bình luận tối đa 500 ký tự")]
    public string Content { get; set; } = string.Empty;
}
