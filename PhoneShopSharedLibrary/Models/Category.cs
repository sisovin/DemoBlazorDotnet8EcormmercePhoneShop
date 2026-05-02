
using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace PhoneShopSharedLibrary.Models
{
    public class Category
    {
        public int Id { get; set; }
        [Required]
        public string? Name { get; set; }

        [JsonIgnore]
        //Relationship : One to Many
        public List<Product>? Products { get; set; }
    }
}
