<?php

namespace App\Http\Controllers\Api\Logistics;

use App\Http\Controllers\Controller;
use App\Models\DeliveryArea;
use App\Models\Parcel;
use App\Models\ParcelDelivery;
use App\Models\Rider;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class DeliveryController extends Controller
{
    public function assignmentIndex(Request $request)
    {
        $center = (int) $request->user()->id;

        // "Unassigned": sorted parcels at this sorting center (or not routed yet), for its own riders.
        $parcels = Parcel::with('area:id,name')
            ->where('status', 'sorted')
            ->where(fn ($q) => $q->where('current_sorting_center_id', $center)->orWhereNull('current_sorting_center_id'))
            ->when($request->area_id, fn ($q) => $q->where('area_id', $request->area_id))
            ->latest()
            ->paginate(15);

        $riders = Rider::where('application_status', 'approved')
            ->where('is_active', true)
            ->where('sorting_center_id', $center)
            ->when($request->area_id, fn ($q) => $q->where('area_id', $request->area_id))
            ->with('area:id,name')
            ->get();

        return response()->json([
            'parcels' => $parcels,
            'areas'   => DeliveryArea::orderBy('name')->get(['id', 'name']),
            'riders'  => $riders,
        ]);
    }

    public function assign(Request $request, Parcel $parcel)
    {
        $request->validate(['rider_id' => 'required|exists:riders,id']);

        $center = (int) $request->user()->id;
        $rider = Rider::findOrFail($request->rider_id);

        if ((int) $rider->sorting_center_id !== $center) {
            return response()->json(['message' => 'Choose a rider from your sorting center.'], 422);
        }
        if ($parcel->status !== 'sorted') {
            return response()->json(['message' => "{$parcel->tracking_number} is not waiting for a delivery rider."], 422);
        }
        if ($parcel->current_sorting_center_id && (int) $parcel->current_sorting_center_id !== $center) {
            return response()->json(['message' => "{$parcel->tracking_number} belongs to another sorting center."], 403);
        }

        ParcelDelivery::create([
            'parcel_id'   => $parcel->id,
            'rider_id'    => $rider->id,
            'area_id'     => $parcel->area_id,
            'assigned_by' => $request->user()->id,
            'status'      => 'assigned',
        ]);

        $parcel->update(['status' => 'assigned', 'current_sorting_center_id' => $parcel->current_sorting_center_id ?? $center]);

        return response()->json(['message' => "{$parcel->tracking_number} assigned to {$rider->full_name}."]);
    }

    public function monitor(Request $request)
    {
        $deliveries = ParcelDelivery::with(['parcel:id,tracking_number,receiver_name,status', 'rider:id,full_name', 'area:id,name'])
            ->when($request->status,   fn ($q) => $q->where('status', $request->status))
            ->when($request->rider_id, fn ($q) => $q->where('rider_id', $request->rider_id))
            ->latest()
            ->paginate(20);

        return response()->json([
            'deliveries' => $deliveries,
            'riders'     => Rider::where('application_status', 'approved')->orderBy('full_name')->get(['id', 'full_name']),
        ]);
    }

    public function updateStatus(Request $request, ParcelDelivery $delivery)
    {
        $request->validate([
            'status'  => ['required', Rule::in(ParcelDelivery::STATUSES)],
            'remarks' => 'nullable|string|max:500',
        ]);

        $delivery->update([
            'status'       => $request->status,
            'remarks'      => $request->remarks,
            'delivered_at' => $request->status === 'delivered' ? now() : $delivery->delivered_at,
        ]);

        match ($request->status) {
            'delivered'        => $delivery->parcel->update(['status' => 'delivered']),
            'out_for_delivery' => $delivery->parcel->update(['status' => 'in_transit']),
            'failed'           => $delivery->parcel->update(['status' => 'failed']),
            default            => null,
        };

        return response()->json(['message' => 'Delivery status updated.']);
    }
}
