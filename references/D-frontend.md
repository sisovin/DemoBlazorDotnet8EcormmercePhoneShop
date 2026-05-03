# Section D — Full-Stack Development Skills

## Table of Contents
1. [HTML5 & Razor Integration](#1-html5--razor-integration)
2. [CSS3 Conventions](#2-css3-conventions)
3. [Tailwind CSS Integration](#3-tailwind-css-integration)
4. [JavaScript — Modern ES2020+](#4-javascript--modern-es2020)
5. [jQuery (Legacy / MVC 5)](#5-jquery-legacy--mvc-5)
6. [AJAX with Fetch API](#6-ajax-with-fetch-api)
7. [Client-Server Communication Patterns](#7-client-server-communication-patterns)
8. [Bundling & Minification](#8-bundling--minification)

---

## 1. HTML5 & Razor Integration

### Semantic Layout (_Layout.cshtml)

```cshtml
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="description" content="@ViewData["Description"]" />
    <title>@ViewData["Title"] — MyApp</title>

    <link rel="stylesheet" href="~/css/site.min.css" asp-append-version="true" />
    @await RenderSectionAsync("Styles", required: false)
</head>
<body>
    <a class="skip-link visually-hidden-focusable" href="#main-content">Skip to content</a>

    <header role="banner">
        <nav class="navbar" aria-label="Main navigation">
            <a class="navbar-brand" asp-controller="Home" asp-action="Index">MyApp</a>
            <partial name="_LoginPartial" />
        </nav>
    </header>

    <main id="main-content" role="main" class="container py-5">
        @* Global alert display *@
        @foreach (var (key, msg) in new[] {
            ("Success","alert-success"), ("Error","alert-danger"), ("Info","alert-info") })
        {
            if (TempData[key] is string text)
            {
                <div class="alert @msg alert-dismissible" role="alert" aria-live="polite">
                    @text
                    <button type="button" class="btn-close" data-bs-dismiss="alert"
                            aria-label="Close"></button>
                </div>
            }
        }
        @RenderBody()
    </main>

    <footer role="contentinfo" class="py-4 border-top text-muted small text-center">
        <p>&copy; @DateTime.Now.Year MyApp. All rights reserved.</p>
    </footer>

    <script src="~/lib/jquery/dist/jquery.min.js"></script>
    <script src="~/lib/bootstrap/dist/js/bootstrap.bundle.min.js"></script>
    @await RenderSectionAsync("Scripts", required: false)
</body>
</html>
```

### Accessible Form Pattern

```cshtml
@model CreateProductViewModel
@{  ViewData["Title"] = "Create Product"; }

<h1 class="mb-4">Create Product</h1>

<form asp-action="Create" asp-controller="Product"
      method="post" enctype="multipart/form-data" novalidate>
    <div asp-validation-summary="ModelOnly" class="alert alert-danger" role="alert"></div>

    <div class="mb-3">
        <label asp-for="Name" class="form-label fw-semibold required"></label>
        <input asp-for="Name" class="form-control" autocomplete="off"
               aria-required="true" aria-describedby="name-help name-error" />
        <div id="name-help" class="form-text">2–200 characters.</div>
        <span id="name-error" asp-validation-for="Name"
              class="invalid-feedback d-block" role="alert"></span>
    </div>

    <div class="mb-3">
        <label asp-for="CategoryId" class="form-label fw-semibold required"></label>
        <select asp-for="CategoryId" asp-items="Model.Categories"
                class="form-select" aria-required="true">
            <option value="">— Select a category —</option>
        </select>
        <span asp-validation-for="CategoryId" class="invalid-feedback d-block" role="alert"></span>
    </div>

    <div class="d-flex gap-2">
        <button type="submit" class="btn btn-primary">
            <i class="bi bi-check-lg" aria-hidden="true"></i> Save Product
        </button>
        <a asp-action="Index" class="btn btn-outline-secondary">Cancel</a>
    </div>
</form>

@section Scripts {
    <partial name="_ValidationScriptsPartial" />
}
```

---

## 2. CSS3 Conventions

```css
/* ─── 1. Design Tokens ────────────────────────────────────── */
:root {
    --clr-primary:   #2563eb;
    --clr-primary-h: #1d4ed8;
    --clr-danger:    #dc2626;
    --clr-success:   #16a34a;
    --clr-muted:     #64748b;
    --clr-bg:        #f8fafc;
    --clr-surface:   #ffffff;
    --font-sans:     'Inter', system-ui, -apple-system, sans-serif;
    --font-mono:     'JetBrains Mono', 'Fira Code', monospace;
    --radius-sm:     0.25rem;
    --radius-md:     0.5rem;
    --radius-lg:     1rem;
    --shadow-sm:     0 1px 2px rgb(0 0 0 / .05);
    --shadow-md:     0 4px 6px -1px rgb(0 0 0 / .10);
    --shadow-lg:     0 10px 15px -3px rgb(0 0 0 / .10);
    --transition:    150ms cubic-bezier(.4, 0, .2, 1);
}

/* ─── 2. Reset ────────────────────────────────────────────── */
*, *::before, *::after { box-sizing: border-box; margin: 0; }
html { font-size: 16px; scroll-behavior: smooth; }
body { font-family: var(--font-sans); background: var(--clr-bg); color: #1e293b; }

/* ─── 3. Layout ───────────────────────────────────────────── */
.container { max-width: 1280px; margin-inline: auto; padding-inline: clamp(1rem, 4vw, 2rem); }

/* ─── 4. Component — Card ────────────────────────────────── */
.card {
    background: var(--clr-surface);
    border-radius: var(--radius-md);
    box-shadow: var(--shadow-md);
    padding: 1.5rem;
    transition: box-shadow var(--transition);
}
.card:hover { box-shadow: var(--shadow-lg); }

/* ─── 5. Component — Button ──────────────────────────────── */
.btn {
    display: inline-flex; align-items: center; gap: .5rem;
    padding: .5rem 1.25rem; border-radius: var(--radius-sm);
    font-weight: 600; cursor: pointer; transition: all var(--transition);
    border: 2px solid transparent;
}
.btn-primary {
    background: var(--clr-primary); color: #fff;
}
.btn-primary:hover { background: var(--clr-primary-h); }

/* ─── 6. Accessibility ────────────────────────────────────── */
.visually-hidden {
    position: absolute; width: 1px; height: 1px;
    overflow: hidden; clip: rect(0,0,0,0); white-space: nowrap;
}
:focus-visible { outline: 3px solid var(--clr-primary); outline-offset: 2px; }
```

---

## 3. Tailwind CSS Integration

```bash
npm init -y
npm install -D tailwindcss @tailwindcss/forms @tailwindcss/typography autoprefixer
npx tailwindcss init -p
```

```js
// tailwind.config.js
module.exports = {
    content: [
        "./Views/**/*.cshtml",
        "./Pages/**/*.cshtml",
        "./wwwroot/js/**/*.js"
    ],
    theme: {
        extend: {
            colors: {
                brand: { DEFAULT: "#2563eb", dark: "#1d4ed8", light: "#dbeafe" }
            },
            fontFamily: {
                sans: ["Inter", "system-ui", "sans-serif"]
            }
        }
    },
    plugins: [
        require("@tailwindcss/forms"),
        require("@tailwindcss/typography")
    ]
};
```

```css
/* wwwroot/css/input.css */
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer components {
    .btn-primary {
        @apply inline-flex items-center gap-2 bg-brand text-white font-semibold
               py-2 px-5 rounded-md hover:bg-brand-dark transition-colors
               focus-visible:outline focus-visible:outline-2 focus-visible:outline-brand;
    }
    .form-input {
        @apply block w-full rounded-md border-gray-300 shadow-sm text-sm
               focus:border-brand focus:ring-brand;
    }
    .card {
        @apply bg-white rounded-xl shadow-md p-6 hover:shadow-lg transition-shadow;
    }
}
```

```json
// package.json
{
    "scripts": {
        "css:build": "tailwindcss -i ./wwwroot/css/input.css -o ./wwwroot/css/site.css --minify",
        "css:watch": "tailwindcss -i ./wwwroot/css/input.css -o ./wwwroot/css/site.css --watch"
    }
}
```

```xml
<!-- MyApp.Web.csproj — auto-build CSS on Release publish -->
<Target Name="BuildTailwind" BeforeTargets="Build" Condition="'$(Configuration)'=='Release'">
    <Exec Command="npm run css:build" WorkingDirectory="$(MSBuildProjectDirectory)" />
</Target>
```

---

## 4. JavaScript — Modern ES2020+

```js
// wwwroot/js/api-client.js — reusable fetch wrapper
const ApiClient = (() => {
    'use strict';

    const getToken = () =>
        document.querySelector('meta[name="request-verification-token"]')?.content
        ?? document.querySelector('input[name="__RequestVerificationToken"]')?.value;

    const request = async (method, url, data = null) => {
        const opts = {
            method,
            headers: {
                Accept:  'application/json',
                'RequestVerificationToken': getToken() ?? ''
            }
        };

        if (data) {
            opts.headers['Content-Type'] = 'application/json';
            opts.body = JSON.stringify(data);
        }

        const res = await fetch(url, opts);

        if (!res.ok) {
            const err = await res.json().catch(() => ({ title: res.statusText }));
            throw Object.assign(new Error(err.title ?? 'API Error'), { status: res.status, data: err });
        }

        return res.status === 204 ? null : res.json();
    };

    return {
        get:    (url)       => request('GET',    url),
        post:   (url, data) => request('POST',   url, data),
        put:    (url, data) => request('PUT',    url, data),
        patch:  (url, data) => request('PATCH',  url, data),
        delete: (url)       => request('DELETE', url)
    };
})();

// wwwroot/js/product-list.js — feature module
const ProductList = (() => {
    'use strict';

    const escapeHtml = str =>
        str.replace(/[&<>"']/g, m => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[m]));

    const formatCurrency = n =>
        n.toLocaleString('en-US', { style: 'currency', currency: 'USD' });

    const renderRow = p => `
        <tr data-id="${p.id}">
            <td>${escapeHtml(p.name)}</td>
            <td>${escapeHtml(p.categoryName)}</td>
            <td class="text-end">${formatCurrency(p.price)}</td>
            <td>${p.stock}</td>
            <td>
                <div class="d-flex gap-1">
                    <a href="/product/edit/${p.id}" class="btn btn-sm btn-outline-primary">Edit</a>
                    <button class="btn btn-sm btn-outline-danger btn-delete"
                            data-id="${p.id}" aria-label="Delete ${escapeHtml(p.name)}">
                        Delete
                    </button>
                </div>
            </td>
        </tr>`;

    const tbody = document.getElementById('product-tbody');

    const load = async (page = 1, search = '') => {
        try {
            const data = await ApiClient.get(`/api/products?page=${page}&search=${encodeURIComponent(search)}`);
            tbody.innerHTML = data.items.map(renderRow).join('');
        } catch (err) {
            tbody.innerHTML = `<tr><td colspan="5" class="text-danger text-center">${err.message}</td></tr>`;
        }
    };

    const handleDelete = async (id) => {
        if (!confirm('Delete this product? This cannot be undone.')) return;
        try {
            await ApiClient.delete(`/api/products/${id}`);
            document.querySelector(`tr[data-id="${id}"]`)?.remove();
        } catch (err) {
            alert(`Delete failed: ${err.message}`);
        }
    };

    return {
        init() {
            load();
            document.getElementById('search-input')?.addEventListener(
                'input', debounce(e => load(1, e.target.value), 300));
            tbody.addEventListener('click', e => {
                const btn = e.target.closest('.btn-delete');
                if (btn) handleDelete(btn.dataset.id);
            });
        }
    };
})();

const debounce = (fn, ms) => { let t; return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); }; };
document.addEventListener('DOMContentLoaded', ProductList.init);
```

---

## 5. jQuery (Legacy / MVC 5)

```js
// wwwroot/Scripts/product.js — MVC 5
$(function () {
    // Cascading dropdown (Category → SubCategory)
    $('#CategoryId').on('change', function () {
        $.getJSON('/Product/GetSubCategories', { categoryId: $(this).val() }, function (data) {
            $('#SubCategoryId').empty().append('<option value="">— Select —</option>');
            $.each(data, (_, item) => $('#SubCategoryId').append(
                $('<option>').val(item.value).text(item.text)));
        });
    });

    // AJAX delete with confirmation
    $(document).on('click', '.btn-delete', function (e) {
        e.preventDefault();
        if (!confirm('Delete this product?')) return;
        const $btn  = $(this);
        const token = $('input[name="__RequestVerificationToken"]').val();

        $.ajax({
            url:  $btn.data('url'),
            type: 'POST',
            data: { __RequestVerificationToken: token },
            success() { $btn.closest('tr').fadeOut(300, function () { $(this).remove(); }); },
            error(xhr)  { alert('Error: ' + xhr.statusText); }
        });
    });

    // Client-side validation (jQuery.validate)
    $('#create-form').validate({
        errorClass: 'text-danger',
        highlight:  el => $(el).addClass('is-invalid'),
        unhighlight: el => $(el).removeClass('is-invalid')
    });
});
```

---

## 6. AJAX with Fetch API

```js
// Return partial view (HTML fragment for server-rendered updates)
async function loadProductCard(id) {
    const html = await fetch(`/Product/GetCard/${id}`).then(r => r.text());
    document.getElementById(`card-${id}`).innerHTML = html;
}

// Submit form with JSON (Web API)
document.getElementById('create-form').addEventListener('submit', async e => {
    e.preventDefault();
    const form = e.target;
    const body = Object.fromEntries(new FormData(form));

    try {
        const product = await ApiClient.post('/api/products', body);
        window.location.href = `/product/details/${product.id}`;
    } catch (err) {
        if (err.status === 400 && err.data?.errors) {
            // Map server validation errors to form fields
            Object.entries(err.data.errors).forEach(([field, msgs]) => {
                const el = form.querySelector(`[name="${field}"]`);
                el?.classList.add('is-invalid');
                el?.closest('.mb-3')?.querySelector('.invalid-feedback')
                    ?.textContent = msgs[0];
            });
        } else {
            alert(err.message);
        }
    }
});
```

### Server-Side: Return Partial View or JSON

```csharp
// Returns HTML fragment for AJAX include
[HttpGet]
public async Task<IActionResult> GetCard(int id)
{
    var product = await _svc.GetByIdAsync(id);
    if (product is null) return NotFound();
    return PartialView("_ProductCard", product);
}

// Returns JSON for SPA / API call
[HttpGet]
public async Task<IActionResult> Search([FromQuery] string q, CancellationToken ct)
{
    var results = await _svc.SearchAsync(q, ct);
    return Request.IsAjaxRequest() ? Json(results) : View(results);
}

// Extension method
public static bool IsAjaxRequest(this HttpRequest req)
    => req.Headers.XRequestedWith == "XMLHttpRequest";
```

---

## 7. Client-Server Communication Patterns

| Pattern | Use Case | Implementation |
|---|---|---|
| Traditional form POST | Standard CRUD with full page reload | Razor form + `[ValidateAntiForgeryToken]` |
| AJAX Partial View | Update page sections without reload | `fetch` + `PartialView` |
| REST JSON API | SPA / mobile clients | `[ApiController]` + JSON |
| SignalR | Real-time push (chat, live updates) | `IHubContext<T>` + JS SignalR client |
| Server-Sent Events | One-way real-time (progress, logs) | `IAsyncEnumerable` stream endpoint |

### SignalR Hub

```csharp
public class NotificationHub : Hub
{
    public async Task JoinGroup(string groupName)
        => await Groups.AddToGroupAsync(Context.ConnectionId, groupName);

    public async Task SendToGroup(string groupName, string message)
        => await Clients.Group(groupName).SendAsync("ReceiveMessage", message);
}

// Program.cs
builder.Services.AddSignalR();
app.MapHub<NotificationHub>("/hubs/notifications");

// Server push from service
public class OrderService
{
    private readonly IHubContext<NotificationHub> _hub;
    public OrderService(IHubContext<NotificationHub> hub) => _hub = hub;

    public async Task ProcessOrderAsync(int orderId)
    {
        // ... process ...
        await _hub.Clients.Group($"order-{orderId}")
            .SendAsync("OrderUpdated", new { orderId, status = "Shipped" });
    }
}
```

---

## 8. Bundling & Minification

### ASP.NET Core — bundleconfig.json (BuildBundlerMinifier)

```json
[
  {
    "outputFileName": "wwwroot/css/site.min.css",
    "inputFiles": ["wwwroot/css/normalize.css", "wwwroot/css/site.css"],
    "minify": { "enabled": true }
  },
  {
    "outputFileName": "wwwroot/js/site.min.js",
    "inputFiles": ["wwwroot/js/api-client.js", "wwwroot/js/product-list.js"],
    "minify": { "enabled": true, "renameLocals": true }
  }
]
```

### Cache Busting (Tag Helper)

```cshtml
<link rel="stylesheet" href="~/css/site.min.css" asp-append-version="true" />
<script src="~/js/site.min.js" asp-append-version="true"></script>
```

### [MVC5] BundleConfig.cs

```csharp
public static void RegisterBundles(BundleCollection bundles)
{
    bundles.Add(new ScriptBundle("~/bundles/jquery").Include("~/Scripts/jquery-{version}.js"));
    bundles.Add(new ScriptBundle("~/bundles/site").Include("~/Scripts/product.js"));
    bundles.Add(new StyleBundle("~/Content/css")
        .Include("~/Content/bootstrap.css", "~/Content/site.css"));
    BundleTable.EnableOptimizations = !HttpContext.Current.IsDebuggingEnabled;
}
```