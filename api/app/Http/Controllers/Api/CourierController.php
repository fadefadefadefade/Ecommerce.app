<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

class CourierController extends Controller
{
    public function dashboard(Request $request)
    {
        // Mock courier dashboard data
        return response()->json([
            'available' => [],
            'forPickup' => [],
            'forDelivery' => [],
            'todayDone' => 5,
        ]);
    }

    public function deliveries(Request $request)
    {
        return response()->json([
            'deliveries' => [],
        ]);
    }

    public function acceptDelivery($id)
    {
        return response()->json([
            'message' => 'Delivery accepted successfully',
        ]);
    }

    public function markAsPickedUp($id)
    {
        return response()->json([
            'message' => 'Marked as picked up successfully',
        ]);
    }

    public function markAsDelivered($id)
    {
        return response()->json([
            'message' => 'Marked as delivered successfully',
        ]);
    }
}
