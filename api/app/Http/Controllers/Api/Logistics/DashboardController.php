<?php

namespace App\Http\Controllers\Api\Logistics;

use App\Http\Controllers\Controller;
use App\Models\Parcel;
use App\Models\ParcelDelivery;
use App\Models\Rider;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    public function index()
    {
        $stats = [
            'pending_rider_applications' => Rider::where('application_status', 'pending')->count(),
            'active_riders'              => Rider::where('application_status', 'approved')->where('is_active', true)->count(),
            'pending_pickup_requests'    => Parcel::where('status', 'pending_pickup')->count(),
            'incoming_parcels'           => Parcel::whereIn('status', ['picked_up', 'sorted'])->count(),
            'in_transit'                 => ParcelDelivery::where('status', 'out_for_delivery')->count(),
            'delivered_today'            => ParcelDelivery::where('status', 'delivered')
                                               ->whereDate('delivered_at', today())->count(),
            'failed_deliveries'          => ParcelDelivery::where('status', 'failed')->count(),
        ];

        $parcelsByStatus = Parcel::select('status', DB::raw('count(*) as total'))
            ->groupBy('status')->pluck('total', 'status');

        $recentActivity = ParcelDelivery::with(['parcel:id,tracking_number,status', 'rider:id,full_name'])
            ->latest()->take(8)->get();

        return response()->json([
            'stats'             => $stats,
            'parcels_by_status' => $parcelsByStatus,
            'recent_activity'   => $recentActivity,
        ]);
    }
}
