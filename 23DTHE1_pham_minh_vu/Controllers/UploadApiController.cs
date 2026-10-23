using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace _23DTHE1_pham_minh_vu.Controllers;

// Upload ảnh (đăng nhập mới được dùng). Lưu vào wwwroot/uploads với tên ngẫu nhiên, phục vụ qua /uploads/<tên>.
[Route("api/[controller]")]
[ApiController]
[Authorize]
public class UploadApiController : ControllerBase
{
    public const long MaxFileBytes = 5 * 1024 * 1024; // 5MB
    public const long MaxRequestBytes = MaxFileBytes + 1024 * 1024; // chừa 1MB cho phần đầu/ranh giới multipart

    // Đuôi tệp được phép -> loại ảnh. Đuôi lưu trên đĩa luôn do SERVER quyết định theo loại ảnh đã nhận diện.
    private static readonly Dictionary<string, string> AllowedExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        [".jpg"] = "jpeg",
        [".jpeg"] = "jpeg",
        [".png"] = "png",
        [".webp"] = "webp",
    };

    private static readonly Dictionary<string, string> StoredExtensions = new()
    {
        ["jpeg"] = ".jpg",
        ["png"] = ".png",
        ["webp"] = ".webp",
    };

    private readonly IWebHostEnvironment _environment;
    private readonly ILogger<UploadApiController> _logger;

    public UploadApiController(IWebHostEnvironment environment, ILogger<UploadApiController> logger)
    {
        _environment = environment;
        _logger = logger;
    }

    private ObjectResult Error(int status, string message) => StatusCode(status, new { status = false, message });

    /// <summary>
    /// multipart/form-data, trường "file". Trả { url } đầy đủ (VD http://host/uploads/xxxx.jpg).
    /// </summary>
    [HttpPost]
    [RejectOversizedUpload]
    [RequestSizeLimit(MaxRequestBytes)] // chốt chặn cuối của Kestrel nếu client không khai báo Content-Length
    public async Task<IActionResult> Upload(IFormFile? file)
    {
        try
        {
            if (file == null || file.Length == 0)
                return Error(400, "Vui lòng chọn một tệp ảnh (trường form tên \"file\")");
            if (file.Length > MaxFileBytes)
                return Error(413, "Ảnh tối đa 5MB");

            // 1) Đuôi tệp client gửi chỉ dùng để KIỂM TRA, không bao giờ dùng làm tên/đường dẫn lưu
            var claimedKind = AllowedExtensions.GetValueOrDefault(Path.GetExtension(file.FileName));
            if (claimedKind == null)
                return Error(400, "Chỉ nhận ảnh .jpg, .jpeg, .png hoặc .webp");

            // 2) Kiểm tra NỘI DUNG (magic bytes) và phải khớp với đuôi đã khai báo
            var header = new byte[12];
            int read;
            await using (var peek = file.OpenReadStream())
            {
                read = await peek.ReadAsync(header.AsMemory(0, header.Length));
            }
            var actualKind = DetectImageKind(header.AsSpan(0, read));
            if (actualKind == null || actualKind != claimedKind)
                return Error(400, "Nội dung tệp không phải là ảnh hợp lệ");

            // 3) Tên ngẫu nhiên + đuôi theo loại ảnh thật
            var uploadsDir = Path.Combine(_environment.ContentRootPath, "wwwroot", "uploads");
            Directory.CreateDirectory(uploadsDir);
            var storedName = Guid.NewGuid().ToString("N") + StoredExtensions[actualKind];

            await using (var source = file.OpenReadStream())
            await using (var target = new FileStream(Path.Combine(uploadsDir, storedName), FileMode.CreateNew, FileAccess.Write))
            {
                await source.CopyToAsync(target);
            }

            var url = $"{Request.Scheme}://{Request.Host}/uploads/{storedName}";
            return Ok(new { url });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi upload ảnh");
            return StatusCode(500, "Internal server error");
        }
    }

    /// <summary>Nhận diện JPEG / PNG / WEBP theo byte đầu tệp; không nhận diện được thì null.</summary>
    internal static string? DetectImageKind(ReadOnlySpan<byte> h)
    {
        // JPEG: FF D8 FF
        if (h.Length >= 3 && h[0] == 0xFF && h[1] == 0xD8 && h[2] == 0xFF) return "jpeg";

        // PNG: 89 50 4E 47 0D 0A 1A 0A
        if (h.Length >= 8 && h[0] == 0x89 && h[1] == 0x50 && h[2] == 0x4E && h[3] == 0x47
            && h[4] == 0x0D && h[5] == 0x0A && h[6] == 0x1A && h[7] == 0x0A) return "png";

        // WEBP: "RIFF" .... "WEBP"
        if (h.Length >= 12
            && h[0] == (byte)'R' && h[1] == (byte)'I' && h[2] == (byte)'F' && h[3] == (byte)'F'
            && h[8] == (byte)'W' && h[9] == (byte)'E' && h[10] == (byte)'B' && h[11] == (byte)'P') return "webp";

        return null;
    }
}

/// <summary>
/// Từ chối yêu cầu có Content-Length quá lớn bằng 413 TRƯỚC khi framework đọc form
/// (nếu để framework tự đọc thì lỗi "quá lớn" bị đổi thành 400 chung chung).
/// </summary>
[AttributeUsage(AttributeTargets.Method)]
public class RejectOversizedUploadAttribute : Attribute, IResourceFilter
{
    public void OnResourceExecuting(ResourceExecutingContext context)
    {
        var length = context.HttpContext.Request.ContentLength;
        if (length > UploadApiController.MaxRequestBytes)
        {
            context.Result = new ObjectResult(new { status = false, message = "Ảnh tối đa 5MB" })
            {
                StatusCode = StatusCodes.Status413PayloadTooLarge,
            };
        }
    }

    public void OnResourceExecuted(ResourceExecutedContext context) { }
}
