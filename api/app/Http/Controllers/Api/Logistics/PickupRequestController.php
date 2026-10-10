<?php

namespace App\Http\Controllers\Api\Logistics;

use App\Http\Controllers\Controller;
use App\Models\Delivery;
use App\Models\Parcel;
use Illuminate\Http\Request;

class PickupRequestController extends Controller
{
    public function index(Request $request)
    {
        $tab = $request->get('tab', 'all');

        $requests = Parcel::with('seller:id,name')
            ->when($tab === 'pending',   fn ($q) => $q->where('status', 'pending_pickup'))
            ->when($tab === 'confirmed', fn ($q) => $q->where('status', 'pickup_approved'))
            ->when($tab === 'approved',  fn ($q) => $q->whereIn('status', ['picked_up', 'sorted', 'assigned', 'in_transit', 'delivered']))
            ->when($tab === 'rejected',  fn ($q) => $q->where('status', 'pickup_rejected'))
            ->when($request->search,     fn ($q) => $q->where('tracking_number', 'like', "%{$request->search}%"))
            ->latest()
            ->paginate(15);

        return response()->json($requests);
    }

    public function approve(Request $request, Parcel $parcel)
    {
        // One route per order: a direct courier is already handling it.
        if ($parcel->order_id && Delivery::where('order_id', $parcel->order_id)
                ->whereIn('status', Delivery::OPEN_STATUSES)->exists()) {
            return response()->json([
                'message' => "{$parcel->tracking_number}: this order is already being delivered by a direct courier.",
            ], 422);
        }

        $parcel->update([
            'status'      => 'pickup_approved',
            'verified_by' => $request->user()->id,
            'verified_at' => now(),
        ]);

        return response()->json(['message' => "Pickup for {$parcel->tracking_number} has been approved."]);
    }

    public function reject(Request $request, Parcel $parcel)
    {
        $request->validate(['reason' => 'nullable|string|max:500']);

        $parcel->update([
            'status' => 'pickup_rejected',
            'notes'  => trim(($parcel->notes ?? '') . "\nRejection reason: " . $request->reason),
        ]);

        return response()->json(['message' => "Pickup request for {$parcel->tracking_number} was rejected."]);
    }
}
