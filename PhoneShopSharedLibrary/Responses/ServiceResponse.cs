namespace PhoneShopSharedLibrary.Responses
{
    public record class ServiceResponse(bool Flag, string Message=null!);
    public record class LoginResponse(bool Flag, string? Message, string Token = null!, string RefreshToken = null!);
}
