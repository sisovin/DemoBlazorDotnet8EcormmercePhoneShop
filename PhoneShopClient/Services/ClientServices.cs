using Blazored.LocalStorage;
using PhoneShopClient.Authentication;
using PhoneShopClient.PrivateModels;
using PhoneShopSharedLibrary.DTOs;
using PhoneShopSharedLibrary.Models;
using PhoneShopSharedLibrary.Responses;
namespace PhoneShopClient.Services
{
    public class ClientServices(HttpClient httpClient, AuthenticationService authenticationService, ILocalStorageService localStorageService) :
        IProductService, ICategoryService, IUserAccountService, ICart
    {
        private const string ProductBaseUrl = "api/product";
        private const string CateogryBaseUrl = "api/category";
        private const string AuthenticationBaseUrl = "api/account";

        public Action? CategoryAction { get; set; }
        public List<Category> AllCategories { get; set; }
        public Action? ProductAction { get; set; }
        public List<Product> AllProducts { get; set; }
        public List<Product> FeaturedProducts { get; set; }
        public List<Product> ProductsByCategory { get; set; }
        public bool IsVisible { get; set; }
        public Action? CartAction { get; set; }
        public int CartCount { get; set; }
        public bool IsCartLoaderVisible { get; set; }



        // Products

        public async Task<ServiceResponse> AddProduct(Product model)
        {
            await authenticationService.GetUserDetails();
            var privateHttpClient = await authenticationService.AddHeaderToHttpClient();
            var response = await privateHttpClient.PostAsync(ProductBaseUrl, 
                General.GenerateStringContent(General.SerializeObj(model)));

            var result = CheckResponse(response);
            if (!result.Flag)
                return result;

            var apiResponse = await ReadContent(response);
            var data = General.DeserializeJsonString<ServiceResponse>(apiResponse);
            if (!data.Flag) return data;
            await ClearAndGetAllProducts();
            return data;
        }
        private async Task ClearAndGetAllProducts()
        {
            bool featuredProduct = true;
            bool allProduct = false;
            AllProducts = null!;
            FeaturedProducts = null!;
            await GetAllProducts(featuredProduct);
            await GetAllProducts(allProduct);
        }

        public async Task GetAllProducts(bool featuredProducts)
        {
            if (featuredProducts && FeaturedProducts is null)
            {
                IsVisible = true;
                FeaturedProducts = await GetProducts(featuredProducts);
                IsVisible = false;
                ProductAction?.Invoke();
                return;
            }
            else
            {
                if (!featuredProducts && AllProducts is null)
                {
                    IsVisible = true;
                    AllProducts = await GetProducts(featuredProducts);
                    IsVisible = false;
                    ProductAction?.Invoke();
                    return;
                }
            }


        }
        private async Task<List<Product>> GetProducts(bool featured)
        {
            var response = await httpClient.GetAsync($"{ProductBaseUrl}?featured={featured}");
            var (flag, _) = CheckResponse(response);
            if (!flag) return null!;

            var result = await ReadContent(response);
            return (List<Product>?)General.DeserializeJsonStringList<Product>(result)!;
        }

        public async Task GetProductsByCategory(int categoryId)
        {
            bool featured = false;
            await GetAllProducts(featured);
            ProductsByCategory = AllProducts.Where(_ => _.CategoryId == categoryId).ToList();
            ProductAction?.Invoke();
        }


        //Get Random Product for Banner
        public Product GetRandomProduct()
        {
            if (FeaturedProducts is null)
                return null!;

            Random RandomNumbers = new();
            int minimumNumber = FeaturedProducts.Min(_ => _.Id);
            int maximumNumber = FeaturedProducts.Max(_ => _.Id) + 1;
            int result = RandomNumbers.Next(minimumNumber, maximumNumber);
            return FeaturedProducts.FirstOrDefault(_ => _.Id == result)!;
        }


        //Categories

        public async Task<ServiceResponse> AddCategory(Category model)
        {
            await authenticationService.GetUserDetails();
            var privateHttpClient = await authenticationService.AddHeaderToHttpClient();
            var response = await privateHttpClient.PostAsync(CateogryBaseUrl, 
                General.GenerateStringContent(General.SerializeObj(model)));

            var result = CheckResponse(response);
            if (!result.Flag)
                return result;

            var apiResponse = await ReadContent(response);

            var data = General.DeserializeJsonString<ServiceResponse>(apiResponse);
            if (!data.Flag) return data;
            await ClearAndGetAllCategories();
            return data;
        }

        public async Task GetAllCategories()
        {
            if (AllCategories is null)
            {
                var response = await httpClient.GetAsync($"{CateogryBaseUrl}");
                var (flag, _) = CheckResponse(response);
                if (!flag) return;

                var result = await ReadContent(response);
                AllCategories = (List<Category>?)General.DeserializeJsonStringList<Category>(result)!;
                CategoryAction?.Invoke();
            }
        }

        private async Task ClearAndGetAllCategories()
        {
            AllCategories = null!;
            await GetAllCategories();
        }


        //General Method
        private static async Task<string> ReadContent(HttpResponseMessage response) => 
            await response.Content.ReadAsStringAsync();
        private static ServiceResponse CheckResponse(HttpResponseMessage response)
        {
            //Read Response
            if (!response.IsSuccessStatusCode)
                return new ServiceResponse(false, "Error occured. Try again later...");
            else
                return new ServiceResponse(true, null!);
        }




        //Account/authentication service
        public async Task<ServiceResponse> Register(UserDTO model)
        {
            var response = await httpClient.PostAsync($"{AuthenticationBaseUrl}/register",
                General.GenerateStringContent(General.SerializeObj(model)));
            var result = CheckResponse(response);
            if (!result.Flag)
                return result;

            var apiResponse = await ReadContent(response);
            return General.DeserializeJsonString<ServiceResponse>(apiResponse);
        }

        public async Task<LoginResponse> Login(LoginDTO model)
        {
            var response = await httpClient.PostAsync($"{AuthenticationBaseUrl}/login", 
                General.GenerateStringContent(General.SerializeObj(model)));

            if (!response.IsSuccessStatusCode)
                return new LoginResponse(false, "Error occured", null!, null!);

            var apiResponse = await ReadContent(response);
            return General.DeserializeJsonString<LoginResponse>(apiResponse);
        }






        // Cart Service
        public async Task GetCartCount()
        {
            string cartString = await GetCartFromLocalStorage();
            if (string.IsNullOrEmpty(cartString))
                CartCount = 0;
            else
                CartCount = General.DeserializeJsonStringList<StorageCart>(cartString).Count;

            CartAction?.Invoke();
        }

        public async Task<ServiceResponse> AddToCart(Product model, int updateQuantity = 1)
        {
            string message = string.Empty;
            var MyCart = new List<StorageCart>();
            var getCartFromStroage = await GetCartFromLocalStorage();
            if (!string.IsNullOrEmpty(getCartFromStroage))
            {
                MyCart = (List<StorageCart>)General.DeserializeJsonStringList<StorageCart>(getCartFromStroage);
                var checkIfAddedAlready = MyCart.FirstOrDefault(_ => _.ProductId == model.Id);
                if (checkIfAddedAlready is null)
                {
                    MyCart.Add(new StorageCart() { ProductId = model.Id, Quantity = 1 });
                    message = "Product Added to Cart";
                }
                else
                {
                    var updatedProduct = new StorageCart() { Quantity = updateQuantity, ProductId = model.Id };
                    MyCart.Remove(checkIfAddedAlready!);
                    MyCart.Add(updatedProduct);
                    message = "Product Updated";
                }
            }
            else
            {
                MyCart.Add(new StorageCart() { ProductId = model.Id, Quantity = 1 });
                message = "Product Added to Cart";
            }
            await RemoveCartFromLocalStorage();
            await SetCartToLocalStorage(General.SerializeObj(MyCart));
            await GetCartCount();
            return new ServiceResponse(true, message);
        }

        public async Task<List<Order>> MyOrders()
        {
            IsCartLoaderVisible = true;
            var cartList = new List<Order>();
            string myCartString = await GetCartFromLocalStorage();
            if (string.IsNullOrEmpty(myCartString)) return null!;

            var myCartList = General.DeserializeJsonStringList<StorageCart>(myCartString);
            await GetAllProducts(false);
            foreach (var cartItem in myCartList)
            {
                var product = AllProducts.FirstOrDefault(_ => _.Id == cartItem.ProductId);
                cartList.Add(new Order()
                {
                    Id = product!.Id,
                    Name = product.Name,
                    Quantity = cartItem.Quantity,
                    Price = product.Price,
                    Image = product.Base64Img,
                });
            }
            IsCartLoaderVisible = false;
            await GetCartCount();
            return cartList;
        }

        public async Task<ServiceResponse> DeleteCart(Order cart)
        {
            var myCartList = General.DeserializeJsonStringList<StorageCart>(await GetCartFromLocalStorage());
            if (myCartList is null) 
                return new ServiceResponse(false, "Product not found");

            myCartList.Remove(myCartList.FirstOrDefault(_ => _.ProductId == cart.Id)!);
            await RemoveCartFromLocalStorage();
            await SetCartToLocalStorage(General.SerializeObj(myCartList));
            await GetCartCount();
            return new ServiceResponse(true, "Product removed successfully");
        }

        private async Task<string> GetCartFromLocalStorage() => await localStorageService.GetItemAsStringAsync("cart");
        private async Task SetCartToLocalStorage(string cart) => await localStorageService.SetItemAsStringAsync("cart", cart);
        private async Task RemoveCartFromLocalStorage() => await localStorageService.RemoveItemAsync("cart");
    }
}
