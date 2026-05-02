namespace PhoneShopClient.PrivateModels
{
    public class Order
    {
        public int Id { get; set; }
        public string? Name { get; set; }
        public decimal Price { get; set; }
        public int Quantity { get; set; }
        public string? Image { get; set; }
        public decimal SubTotal => Quantity * Price;
    }
}
