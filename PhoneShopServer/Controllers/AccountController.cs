using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using PhoneShopServer.Repositories;
using PhoneShopSharedLibrary.DTOs;
using PhoneShopSharedLibrary.Responses;
namespace PhoneShopServer.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AccountController(IUserAccount accountService) : ControllerBase
    {
        [HttpPost("register")]
        public async Task<ActionResult<ServiceResponse>> CreateAccount(UserDTO model)
        {
            if (model is null) return BadRequest("Model is Null");
            var response = await accountService.Register(model);
            return Ok(response);
        }

        [HttpPost("login")]
        public async Task<ActionResult<LoginResponse>> LoginAccount(LoginDTO model)
        {
            if (model is null) return BadRequest("Model is Null");
            var response = await accountService.Login(model);
            return Ok(response);
        }

        [HttpGet("user-info")]
        public async Task<IActionResult> GetUserInfo()
        {
            var token = GetTokenFromHeader();
            if (string.IsNullOrEmpty(token))
                return Unauthorized();

            var getUser = await accountService.GetUserByToken(token!);
            if (getUser is null || string.IsNullOrEmpty(getUser.Email))
                return Unauthorized();

            return Ok(getUser);
        }

        [HttpPost("refresh-token")]
        public async Task<ActionResult<LoginResponse>> RefreshToken(PostRefreshTokenDTO model)
        {
            if (model is null) return Unauthorized();
            var result = await accountService.GetRefreshToken(model);
            return Ok(result);
        }

        private string GetTokenFromHeader()
        {
            string Token = string.Empty;
            foreach (var header in Request.Headers)
            {
                if (header.Key.ToString().Equals("Authorization"))
                {
                    Token = header.Value.ToString();
                    break;
                }
            }
            return Token.Split(" ").LastOrDefault()!;
        }
    }
}
