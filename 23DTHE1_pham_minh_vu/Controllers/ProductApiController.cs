using _23DTHE1_pham_minh_vu.Models;
using _23DTHE1_pham_minh_vu.Repositories;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace _23DTHE1_pham_minh_vu.Controllers;

[Route("api/[controller]")]
// Xem sản phẩm: cần đăng nhập (User hoặc Admin). Thêm/sửa/xóa: chỉ Admin.
[ApiController]
[Authorize]
public class ProductApiController : ControllerBase
{
    private readonly IProductRepository _productRepository;
    private readonly ICategoryRepository _categoryRepository;
    private readonly ILogger<ProductApiController> _logger;

    public ProductApiController(
        IProductRepository productRepository,
        ICategoryRepository categoryRepository,
        ILogger<ProductApiController> logger)
    {
        _productRepository = productRepository;
        _categoryRepository = categoryRepository;
        _logger = logger;
    }

    [HttpGet]
    public async Task<IActionResult> GetProducts()
    {
        try
        {
            var products = await _productRepository.GetProductsAsync();
            return Ok(products);
        }
        catch (Exception)
        {
            return StatusCode(500, "Internal server error");
        }
    }

    // GET api/ProductApi/search?name=abc
    // Khai báo trước {id} cho dễ đọc; "search" là literal nên không bị nhầm với {id}
    [HttpGet("search")]
    public async Task<IActionResult> SearchProducts([FromQuery] string? name)
    {
        try
        {
            var products = await _productRepository.SearchProductsAsync(name ?? string.Empty);
            return Ok(products);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi tìm sản phẩm với từ khóa {Name}", name);
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetProductById(int id)
    {
        try
        {
            var product = await _productRepository.GetProductByIdAsync(id);
            if (product == null)
                return NotFound();
            return Ok(product);
        }
        catch (Exception)
        {
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpPost]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> AddProduct([FromBody] Product product)
    {
        try
        {
            if (!await CategoryExistsAsync(product.CategoryId))
                return BadRequest(new { status = false, message = "Danh mục không tồn tại" });
            await _productRepository.AddProductAsync(product);
            return CreatedAtAction(nameof(GetProductById), new { id = product.Id }, product);
        }
        catch (Exception)
        {
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> UpdateProduct(int id, [FromBody] Product product)
    {
        try
        {
            if (id != product.Id)
                return BadRequest();
            if (!await CategoryExistsAsync(product.CategoryId))
                return BadRequest(new { status = false, message = "Danh mục không tồn tại" });
            await _productRepository.UpdateProductAsync(product);
            return NoContent();
        }
        catch (Exception)
        {
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> DeleteProduct(int id)
    {
        try
        {
            await _productRepository.DeleteProductAsync(id);
            return NoContent();
        }
        catch (Exception)
        {
            return StatusCode(500, "Internal server error");
        }
    }

    // CategoryId null = không thuộc danh mục nào (hợp lệ); có giá trị thì danh mục phải tồn tại
    private async Task<bool> CategoryExistsAsync(int? categoryId)
    {
        if (categoryId == null)
            return true;
        return await _categoryRepository.GetCategoryByIdAsync(categoryId.Value) != null;
    }
}
