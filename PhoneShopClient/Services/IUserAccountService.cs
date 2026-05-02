using PhoneShopSharedLibrary.DTOs;
using PhoneShopSharedLibrary.Responses;
namespace PhoneShopClient.Services
{
    public interface IUserAccountService
    {
        Task<ServiceResponse> Register(UserDTO model);
        Task<LoginResponse> Login(LoginDTO model);
    }
}
