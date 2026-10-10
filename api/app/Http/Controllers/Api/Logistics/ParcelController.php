<?php

namespace App\Http\Controllers\Api\Logistics;

use App\Http\Controllers\Controller;
use App\Models\DeliveryArea;
use App\Models\Parcel;
use Illuminate\Http\Request;

class ParcelController extends Controller
{
    /** Statuses handled on the Parcels & Sorting screen (pickup_approved so they can be marked picked up). */
    private const HUB_STATUSES = ['pickup_approved', 'picked_up', 'sorted', 'assigned', 'in_transit'];

    public function index(Request $request)
    {
        $parcels = Parcel::with(['seller:id,name', 'area:id,name'])
            ->whereIn('status', self::HUB_STATUSES)
            ->when($request->status, fn ($q) => $q->where('status', $request->status))
            ->when($request->search, fn ($q) => $q->where('tracking_number', 'like', "%{$request->search}%"))
            ->latest()
            ->paginate(15);

        return response()->json($parcels);
    }

    public function show(Parcel $parcel)
    {
        $parcel->load(['seller:id,name', 'area:id,name', 'parcelDelivery.rider:id,full_name']);

        return response()->json(['parcel' => $parcel]);
    }

    public function areas()
    {
        return response()->json([
            'areas' => DeliveryArea::orderBy('name')->get(['id', 'name', 'code']),
        ]);
    }

    public function markPickedUp(Parcel $parcel)
    {
        $parcel->update(['status' => 'picked_up']);

        return response()->json(['message' => "{$parcel->tracking_number} marked as picked up."]);
    }

    public function sort(Request $request, Parcel $parcel)
    {
        $request->validate(['area_id' => 'required|exists:delivery_areas,id']);

        $parcel->update([
            'area_id' => $request->area_id,
            'status'  => 'sorted',
        ]);

        return response()->json(['message' => "{$parcel->tracking_number} has been sorted."]);
    }
}
