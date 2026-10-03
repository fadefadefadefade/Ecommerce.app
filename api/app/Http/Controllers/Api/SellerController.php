<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use Illuminate\Http\Request;

class SellerController extends Controller
{
    public function dashboard(Request $request)
    {
        $sellerId = $request->user()->id;
        
        // Get seller's products
        $products = Product::where('seller_id', $sellerId)
            ->where('is_archived', false)
            ->latest()
            ->take(5)
            ->get()
            ->map(function ($product) {
                return [
                    'id' => $product->id,
                    'title' => $product->title,
                    'price' => $product->price,
                    'effective_price' => $product->effective_price,
                    'stock' => $product->stock,
                    'status' => $product->status,
                ];
            });

        // Mock dashboard stats - replace with real calculations
        return response()->json([
            'totalEarnings' => 15000.00,
            'totalRevenue' => 18000.00,
            'totalCommission' => 3000.00,
            'totalOrders' => 45,
            'totalProducts' => $products->count(),
            'products' => $products,
            'recentOrders' => [
                [
                    'order_id' => 101,
                    'quantity' => 2,
                    'seller_earning' => 500.00,
                    'created_at' => now()->toISOString(),
                    'product' => ['title' => 'Sample Product'],
                ],
            ],
        ]);
    }

    public function products(Request $request)
    {
        $sellerId = $request->user()->id;
        
        $products = Product::where('seller_id', $sellerId)
            ->with(['category', 'images'])
            ->when($request->status, function ($query, $status) {
                $query->where('status', $status);
            })
            ->when($request->search, function ($query, $search) {
                $query->where('title', 'like', "%{$search}%");
            })
            ->paginate(20)
            ->through(function ($product) {
                return [
                    'id' => $product->id,
                    'title' => $product->title,
                    'author' => $product->author,
                    'price' => $product->price,
                    'effective_price' => $product->effective_price,
                    'stock' => $product->stock,
                    'status' => $product->status,
                    'is_archived' => $product->is_archived,
                    'image_url' => $product->primaryImage,
                    'category' => $product->category ? ['name' => $product->category->name] : null,
                    'created_at' => $product->created_at,
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

    public function orders(Request $request)
    {
        // Mock orders for now - replace with real order data
        return response()->json([
            'orders' => [],
        ]);
    }
}
