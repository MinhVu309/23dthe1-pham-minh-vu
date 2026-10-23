using _23DTHE1_pham_minh_vu.Models;
using Microsoft.EntityFrameworkCore;

namespace _23DTHE1_pham_minh_vu.Repositories;

public class ProductRepository : IProductRepository
{
    private readonly ApplicationDbContext _context;

    public ProductRepository(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<IEnumerable<Product>> GetProductsAsync()
    {
        return await _context.Products.Include(p => p.Category).ToListAsync();
    }

    public async Task<Product?> GetProductByIdAsync(int id)
    {
        return await _context.Products.Include(p => p.Category).FirstOrDefaultAsync(p => p.Id == id);
    }

    public async Task AddProductAsync(Product product)
    {
        // Chỉ dùng CategoryId; bỏ đối tượng Category client gửi kèm để EF không thêm danh mục mới
        product.Category = null;
        _context.Products.Add(product);
        await _context.SaveChangesAsync();
        await _context.Entry(product).Reference(p => p.Category).LoadAsync();
    }

    public async Task UpdateProductAsync(Product product)
    {
        product.Category = null;
        _context.Entry(product).State = EntityState.Modified;
        await _context.SaveChangesAsync();
    }

    public async Task DeleteProductAsync(int id)
    {
        var product = await _context.Products.FindAsync(id);
        if (product != null)
        {
            _context.Products.Remove(product);
            await _context.SaveChangesAsync();
        }
    }

    // Tìm theo tên, không phân biệt hoa thường (SQL Server collation mặc định đã case-insensitive,
    // ToLower() giữ kết quả đúng kể cả khi collation của CSDL phân biệt hoa thường)
    public async Task<IEnumerable<Product>> SearchProductsAsync(string name)
    {
        var keyword = (name ?? string.Empty).Trim().ToLower();
        return await _context.Products
            .Include(p => p.Category)
            .Where(p => p.Name != null && p.Name.ToLower().Contains(keyword))
            .ToListAsync();
    }
}
