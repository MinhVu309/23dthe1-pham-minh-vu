namespace _23DTHE1_pham_minh_vu.Models;

public class Product
{
    public int Id { get; set; }
    public string? Name { get; set; }
    public decimal Price { get; set; }
    public string? Image { get; set; }
    public string? Description { get; set; }

    // Mỗi sản phẩm thuộc tối đa một danh mục; null = không thuộc danh mục nào
    public int? CategoryId { get; set; }
    public Category? Category { get; set; }
}
