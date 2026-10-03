<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

class AdminController extends Controller
{
    public function dashboard(Request $request)
    {
        // Mock admin dashboard data
        return response()->json([
            'totalUsers' => 150,
            'activeUsers' => 142,
            'suspendedUsers' => 8,
            'totalBuyers' => 100,
            'totalSellers' => 42,
            'newToday' => 5,
            'newWeek' => 23,
            'newMonth' => 45,
            'pendingRequests' => 3,
        ]);
    }

    public function users(Request $request)
    {
        return response()->json([
            'users' => [],
        ]);
    }

    public function orders(Request $request)
    {
        return response()->json([
            'orders' => [],
        ]);
    }
}
