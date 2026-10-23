using _23DTHE1_pham_minh_vu.Models;
using _23DTHE1_pham_minh_vu.Repositories;
using Microsoft.AspNetCore.Mvc;

namespace _23DTHE1_pham_minh_vu.Controllers;

[Route("api/[controller]")]
[ApiController]
public class PostApiController : ControllerBase
{
    private readonly IPostRepository _postRepository;
    private readonly ILogger<PostApiController> _logger;

    public PostApiController(IPostRepository postRepository, ILogger<PostApiController> logger)
    {
        _postRepository = postRepository;
        _logger = logger;
    }

    [HttpGet]
    public async Task<IActionResult> GetPosts()
    {
        try
        {
            var posts = await _postRepository.GetPostsAsync();
            return Ok(posts);
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
            var post = await _postRepository.GetPostByIdAsync(id);
            if (post == null)
                return NotFound();
            return Ok(post);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi lấy bài đăng {Id}", id);
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpPost]
    public async Task<IActionResult> AddPost([FromBody] Post post)
    {
        try
        {
            await _postRepository.AddPostAsync(post);
            return CreatedAtAction(nameof(GetPostById), new { id = post.Id }, post);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi thêm bài đăng");
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> UpdatePost(int id, [FromBody] Post post)
    {
        try
        {
            if (id != post.Id)
                return BadRequest();
            await _postRepository.UpdatePostAsync(post);
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
            await _postRepository.DeletePostAsync(id);
            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi xóa bài đăng {Id}", id);
            return StatusCode(500, "Internal server error");
        }
    }
}
