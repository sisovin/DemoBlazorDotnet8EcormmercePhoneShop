namespace PhoneShopServer.Data
{
    public class TokenInfo
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public string? AccessToken { get; set; }
        public string? RefreshToken { get; set; }
        public DateTime ExpiryDate { get; set; } = DateTime.Now.AddDays(1);
        public DateTime CreatedDate { get; set; } = DateTime.Now;
    }
}
