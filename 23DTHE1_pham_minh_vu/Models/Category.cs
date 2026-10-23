using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace _23DTHE1_pham_minh_vu.Models;

// Danh mục sản phẩm; một danh mục có nhiều sản phẩm
public class Category
{
    public int Id { get; set; }

    [Required(ErrorMessage = "Vui lòng nhập tên danh mục")]
    public string? Name { get; set; }

    public string? Description { get; set; }

    // Không đưa danh sách sản phẩm vào JSON: tránh vòng lặp Product -> Category -> Products
    // và không cho client gửi lên danh sách sản phẩm khi thêm/sửa danh mục
    [JsonIgnore]
    public ICollection<Product> Products { get; set; } = new List<Product>();
}
