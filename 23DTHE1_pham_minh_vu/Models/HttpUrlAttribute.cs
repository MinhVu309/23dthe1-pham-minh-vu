using System.ComponentModel.DataAnnotations;

namespace _23DTHE1_pham_minh_vu.Models;

/// <summary>
/// Chuỗi rỗng/null là hợp lệ; còn lại phải là đường dẫn tuyệt đối http:// hoặc https:// (tối đa 500 ký tự).
/// Chặn các scheme nguy hiểm như javascript: hoặc file:.
/// </summary>
[AttributeUsage(AttributeTargets.Property | AttributeTargets.Field)]
public class HttpUrlAttribute : ValidationAttribute
{
    public const int MaxLength = 500;

    protected override ValidationResult? IsValid(object? value, ValidationContext validationContext)
    {
        if (value is not string text || string.IsNullOrWhiteSpace(text))
            return ValidationResult.Success;

        var name = validationContext.DisplayName;
        if (text.Trim().Length > MaxLength)
            return new ValidationResult(ErrorMessage ?? $"{name} tối đa {MaxLength} ký tự");

        if (!Uri.TryCreate(text.Trim(), UriKind.Absolute, out var uri)
            || (uri.Scheme != Uri.UriSchemeHttp && uri.Scheme != Uri.UriSchemeHttps))
            return new ValidationResult(ErrorMessage ?? $"{name} phải là đường dẫn http:// hoặc https://");

        return ValidationResult.Success;
    }
}
