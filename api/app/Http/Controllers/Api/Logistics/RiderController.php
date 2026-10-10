<?php

namespace App\Http\Controllers\Api\Logistics;

use App\Http\Controllers\Controller;
use App\Models\Rider;
use Illuminate\Http\Request;

class RiderController extends Controller
{
    public function index(Request $request)
    {
        $riders = Rider::with(['user:id,name,email', 'area:id,name'])
            ->when($request->status, fn ($q) => $q->where('application_status', $request->status))
            ->when($request->search, fn ($q) => $q->where('full_name', 'like', "%{$request->search}%"))
            ->latest()
            ->paginate(15);

        return response()->json($riders);
    }

    public function show(Rider $rider)
    {
        $rider->load(['user:id,name,email', 'area:id,name', 'parcelDeliveries' => fn ($q) => $q->latest(), 'parcelDeliveries.parcel:id,tracking_number']);

        return response()->json(['rider' => $rider]);
    }

    public function approve(Request $request, Rider $rider)
    {
        $rider->update([
            'application_status' => 'approved',
            'approved_at'        => now(),
            'approved_by'        => $request->user()->id,
            'is_active'          => true,
        ]);

        return response()->json([
            'message' => "{$rider->full_name}'s application has been approved.",
            'rider'   => $rider->fresh(['user:id,name,email', 'area:id,name']),
        ]);
    }

    public function disapprove(Request $request, Rider $rider)
    {
        $request->validate(['rejection_reason' => 'nullable|string|max:500']);

        $rider->update([
            'application_status' => 'rejected',
            'rejection_reason'   => $request->rejection_reason,
            'is_active'          => false,
        ]);

        return response()->json([
            'message' => "{$rider->full_name}'s application has been disapproved.",
            'rider'   => $rider->fresh(['user:id,name,email', 'area:id,name']),
        ]);
    }

    public function toggleActive(Rider $rider)
    {
        if ($rider->application_status !== 'approved') {
            return response()->json(['message' => 'Only approved riders can be activated or deactivated.'], 422);
        }

        $rider->update(['is_active' => ! $rider->is_active]);
        $state = $rider->is_active ? 'activated' : 'deactivated';

        return response()->json([
            'message' => "{$rider->full_name} has been {$state}.",
            'rider'   => $rider->fresh(['user:id,name,email', 'area:id,name']),
        ]);
    }
}
