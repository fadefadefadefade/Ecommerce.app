<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\Category;
use Illuminate\Http\Request;

class HomeController extends Controller
{
    public function index()
    {
        // Get real categories from database
        $categories = Category::withCount(['products' => function ($query) {
            $query->where('is_archived', false)->where('status', 'active');
        }])->take(10)->get()->map(function ($category) {
            return [
                'id' => $category->id,
                'name' => $category->name,
                'products_count' => $category->products_count,
            ];
        });

        // Get featured products
        $featured = Product::with(['category', 'seller'])
            ->where('is_archived', false)
            ->where('status', 'active')
            ->where('stock', '>', 0)
            ->latest()
            ->take(6)
            ->get()
            ->map(function ($product) {
                return [
                    'id' => $product->id,
                    'title' => $product->title,
                    'author' => $product->author,
                    'price' => $product->price,
                    'effective_price' => $product->effective_price,
                    'stock' => $product->stock,
                    'image_url' => $product->primaryImage,
                    'category' => $product->category ? ['name' => $product->category->name] : null,
                ];
            });

        // Get best sellers (products with most sales - mock for now)
        $bestSellers = Product::with(['category', 'seller'])
            ->where('is_archived', false)
            ->where('status', 'active')
            ->where('stock', '>', 0)
            ->orderByDesc('id') // Mock ordering - replace with actual sales count
            ->take(6)
            ->get()
            ->map(function ($product) {
                return [
                    'id' => $product->id,
                    'title' => $product->title,
                    'author' => $product->author,
                    'price' => $product->price,
                    'effective_price' => $product->effective_price,
                    'stock' => $product->stock,
                    'image_url' => $product->primaryImage,
                    'category' => $product->category ? ['name' => $product->category->name] : null,
                ];
            });

        return response()->json([
            'categories' => $categories,
            'featured' => $featured,
            'bestSellers' => $bestSellers,
        ]);
    }

    public function products(Request $request)
    {
        // Build query with search and filters
        $query = Product::with(['category', 'seller'])
            ->where('is_archived', false)
            ->where('status', 'active')
            ->where('stock', '>', 0);

        // Search
        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('title', 'like', "%{$search}%")
                  ->orWhere('author', 'like', "%{$search}%")
                  ->orWhere('description', 'like', "%{$search}%");
            });
        }

        // Category filter
        if ($request->filled('category_id')) {
            $query->where('category_id', $request->category_id);
        }

        // Price filters
        if ($request->filled('min_price')) {
            $query->where('price', '>=', $request->min_price);
        }
        if ($request->filled('max_price')) {
            $query->where('price', '<=', $request->max_price);
        }

        // Sorting
        match ($request->get('sort', 'newest')) {
            'price_low'  => $query->orderBy('price'),
            'price_high' => $query->orderByDesc('price'),
            'name_asc'   => $query->orderBy('title'),
            'name_desc'  => $query->orderByDesc('title'),
            default      => $query->latest(),
        };

        $products = $query->paginate(20)->through(function ($product) {
            return [
                'id' => $product->id,
                'title' => $product->title,
                'author' => $product->author,
                'price' => $product->price,
                'effective_price' => $product->effective_price,
                'discount_percent' => $product->discount_percent ?? 0,
                'stock' => $product->stock,
                'image_url' => $product->primaryImage,
                'category' => $product->category ? ['name' => $product->category->name] : null,
                'seller' => $product->seller ? ['name' => $product->seller->name] : null,
            ];
        });

        return response()->json([
            'products' => $products->items(),
            'pagination' => [
                'current_page' => $products->currentPage(),
                'last_page' => $products->lastPage(),
                'per_page' => $products->perPage(),
                'total' => $products->total(),
            ],
        ]);
    }

    public function productDetail($id)
    {
        $product = Product::with(['category', 'seller', 'images', 'variations', 'address'])
            ->where('is_archived', false)
            ->findOrFail($id);

        // Get related products
        $related = Product::with(['category', 'images'])
            ->where('category_id', $product->category_id)
            ->where('id', '!=', $product->id)
            ->where('is_archived', false)
            ->where('status', 'active')
            ->where('stock', '>', 0)
            ->take(4)
            ->get()
            ->map(function ($item) {
                return [
                    'id' => $item->id,
                    'title' => $item->title,
                    'author' => $item->author,
                    'price' => $item->price,
                    'effective_price' => $item->effective_price,
                    'discount_percent' => $item->discount_percent ?? 0,
                    'stock' => $item->stock,
                    'image_url' => $item->primaryImage,
                    'category' => $item->category ? ['name' => $item->category->name] : null,
                ];
            });

        return response()->json([
            'product' => [
                'id' => $product->id,
                'title' => $product->title,
                'author' => $product->author,
                'isbn' => $product->isbn,
                'publisher' => $product->publisher,
                'publication_year' => $product->publication_year,
                'edition' => $product->edition,
                'language' => $product->language,
                'pages' => $product->pages,
                'format' => $product->format,
                'price' => $product->price,
                'sale_price' => $product->sale_price,
                'effective_price' => $product->effective_price,
                'discount_percent' => $product->discount_percent ?? 0,
                'stock' => $product->stock,
                'total_stock' => $product->totalStock(),
                'in_stock' => $product->inStock(),
                'description' => $product->description,
                'specs' => $product->specs,
                'weight_kg' => $product->weight_kg,
                'length_cm' => $product->length_cm,
                'width_cm' => $product->width_cm,
                'height_cm' => $product->height_cm,
                'primary_image' => $product->primaryImage,
                'images' => $product->images->map(function ($img) {
                    return [
                        'id' => $img->id,
                        'url' => asset('storage/' . $img->path),
                        'alt_text' => $img->alt_text,
                    ];
                })->toArray(),
                'variations' => $product->variations->map(function ($var) {
                    return [
                        'id' => $var->id,
                        'name' => $var->name,
                        'value' => $var->value,
                        'price_adjustment' => $var->price_adjustment,
                        'stock' => $var->stock,
                        'is_active' => $var->is_active,
                    ];
                })->toArray(),
                'category' => $product->category ? [
                    'id' => $product->category->id,
                    'name' => $product->category->name,
                ] : null,
                'seller' => $product->seller ? [
                    'id' => $product->seller->id,
                    'name' => $product->seller->name,
                    'shop_name' => $product->seller->shop_name ?? $product->seller->name,
                ] : null,
                'address' => $product->address ? [
                    'region' => $product->address->region,
                    'province' => $product->address->province,
                    'municipality' => $product->address->municipality,
                    'barangay' => $product->address->barangay,
                ] : null,
            ],
            'related' => $related,
        ]);
    }

    public function categories()
    {
        $categories = Category::withCount(['products' => function ($query) {
            $query->where('is_archived', false)->where('status', 'active');
        }])->get()->map(function ($category) {
            return [
                'id' => $category->id,
                'name' => $category->name,
                'products_count' => $category->products_count,
            ];
        });

        return response()->json([
            'categories' => $categories,
        ]);
    }
}
