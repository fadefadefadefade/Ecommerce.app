<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

class SellerController extends Controller
{
    public function dashboard(Request $request)
    {
        // Mock seller dashboard data
        return response()->json([
            'totalEarnings' => 15000.00,
            'totalRevenue' => 18000.00,
            'totalCommission' => 3000.00,
            'totalOrders' => 45,
            'books' => [
                ['id' => 1, 'title' => 'My Book 1', 'price' => 599.00, 'stock' => 10],
                ['id' => 2, 'title' => 'My Book 2', 'price' => 799.00, 'stock' => 5],
            ],
            'recentOrders' => [
                [
                    'order_id' => 101,
                    'quantity' => 2,
                    'seller_earning' => 500.00,
                    'created_at' => now()->toISOString(),
                    'book' => ['title' => 'Sample Book'],
                ],
            ],
        ]);
    }

    public function books(Request $request)
    {
        return response()->json([
            'books' => [],
        ]);
    }

    public function orders(Request $request)
    {
        return response()->json([
            'orders' => [],
        ]);
    }
}
