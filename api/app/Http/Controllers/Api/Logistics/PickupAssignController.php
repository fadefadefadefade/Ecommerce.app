<?php

namespace App\Http\Controllers\Api\Logistics;

use App\Http\Controllers\Controller;
use App\Models\Parcel;
use App\Models\ParcelPickup;
use App\Models\Rider;
use App\Models\UserNotification;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * First mile: the sorting center sends one of its riders to the seller, and
 * checks the parcel in when the rider brings it ("Shipped to Warehouse").
 * A sorting center only sees parcels routed to it (or not routed yet) and its own riders.
 */
class PickupAssignController extends Controller
{
    private const WAITING = ['pending_pickup', 'pickup_approved'];

    /** ?tab=to_assign (default) | with_rider | received, &search= */
    public function index(Request $request)
    {
        $center = (int) $request->user()->id;
        $tab = $request->get('tab', 'to_assign');

        $parcels = $this->tabQuery($center, $tab)
            ->with(['seller:id,name,contact_no', 'pickup.rider:id,full_name,phone', 'sortingCenter:id,name'])
            ->when($request->search, fn ($q, $s) => $q->where(fn ($q) => $q
                ->where('tracking_number', 'like', "%{$s}%")
                ->orWhere('receiver_name', 'like', "%{$s}%")))
            ->when($tab === 'received', fn ($q) => $q->latest('received_at'), fn ($q) => $q->oldest())
            ->paginate(15);

        $parcels->getCollection()->transform(fn ($p) => $this->present($p));

        return response()->json([
            'parcels' => $parcels,
            'counts' => [
                'to_assign'  => $this->tabQuery($center, 'to_assign')->count(),
                'with_rider' => $this->tabQuery($center, 'with_rider')->count(),
                'received'   => $this->tabQuery($center, 'received')->count(),
            ],
        ]);
    }

    /** Approved, active riders of this sorting center, with how many pickups they already carry. */
    public function riders(Request $request)
    {
        $riders = Rider::where('sorting_center_id', $request->user()->id)
            ->where('application_status', 'approved')
            ->where('is_active', true)
            ->with('area:id,name')
            ->withCount(['pickups as open_pickups' => fn ($q) => $q->whereIn('status', ParcelPickup::OPEN)])
            ->orderBy('full_name')
            ->get();

        return response()->json([
            'riders' => $riders->map(fn ($r) => [
                'id' => $r->id,
                'full_name' => $r->full_name,
                'phone' => $r->phone,
                'vehicle_type' => $r->vehicle_type,
                'area' => $r->area?->name,
                'open_pickups' => $r->open_pickups,
            ])->values(),
        ]);
    }

    public function assign(Request $request, Parcel $parcel)
    {
        $request->validate(['rider_id' => 'required|integer']);
        $center = (int) $request->user()->id;

        return DB::transaction(function () use ($request, $parcel, $center) {
            $parcel = Parcel::lockForUpdate()->findOrFail($parcel->id);

            if (! $this->tabQuery($center, 'to_assign')->whereKey($parcel->id)->exists()) {
                return response()->json(['message' => "{$parcel->tracking_number} is not waiting for a pickup rider."], 422);
            }

            $rider = Rider::where('sorting_center_id', $center)
                ->where('application_status', 'approved')
                ->where('is_active', true)
                ->find($request->rider_id);
            if (! $rider) {
                return response()->json(['message' => 'Choose an active rider from your sorting center.'], 422);
            }

            ParcelPickup::create([
                'parcel_id' => $parcel->id,
                'rider_id' => $rider->id,
                'sorting_center_id' => $center,
                'assigned_by' => $request->user()->id,
                'status' => 'assigned',
            ]);

            // Assigning a rider also confirms the pickup and claims the parcel for this center.
            $parcel->update([
                'status' => 'pickup_approved',
                'current_sorting_center_id' => $center,
                'verified_by' => $parcel->verified_by ?? $request->user()->id,
                'verified_at' => $parcel->verified_at ?? now(),
            ]);

            $this->notify($parcel->seller_id, 'Rider on the way for pickup',
                "Rider {$rider->full_name} will pick up parcel {$parcel->tracking_number}. Please have it ready.", 'order');

            return response()->json(['message' => "{$rider->full_name} will pick up {$parcel->tracking_number}."]);
        });
    }

    /** The parcel arrived and was checked: it is now at the sorting center. */
    public function receive(Request $request, ParcelPickup $pickup)
    {
        $request->validate(['remarks' => 'nullable|string|max:500']);
        $center = (int) $request->user()->id;

        return DB::transaction(function () use ($request, $pickup, $center) {
            $pickup = ParcelPickup::with('parcel.order', 'rider')->lockForUpdate()->findOrFail($pickup->id);

            if ((int) $pickup->sorting_center_id !== $center) {
                return response()->json(['message' => 'This pickup belongs to another sorting center.'], 403);
            }
            if (! in_array($pickup->status, ParcelPickup::OPEN, true)) {
                return response()->json(['message' => 'This pickup is already ' . strtolower($pickup->statusLabel()) . '.'], 422);
            }

            $pickup->update([
                'status' => 'received',
                'picked_up_at' => $pickup->picked_up_at ?? now(),
                'received_at' => now(),
                'received_by' => $request->user()->id,
                'remarks' => $request->remarks ?: $pickup->remarks,
            ]);

            $parcel = $pickup->parcel;
            $parcel->update([
                'status' => 'picked_up', // "At Sorting Center", ready to be sorted
                'received_at' => now(),
                'current_sorting_center_id' => $center,
            ]);

            if ($order = $parcel->order) {
                $order->markShippedToWarehouse();
                $this->notify($order->user_id,
                    'Shipped to warehouse · Order #' . str_pad($order->id, 6, '0', STR_PAD_LEFT),
                    'Your order arrived at our sorting center and will be delivered soon.', 'delivery');
            }

            return response()->json(['message' => "{$parcel->tracking_number} received at the sorting center."]);
        });
    }

    /** Take the parcel back from a rider who hasn't picked it up yet. */
    public function cancel(Request $request, ParcelPickup $pickup)
    {
        if ((int) $pickup->sorting_center_id !== (int) $request->user()->id) {
            return response()->json(['message' => 'This pickup belongs to another sorting center.'], 403);
        }
        if ($pickup->status !== 'assigned') {
            return response()->json(['message' => 'Only pickups the rider has not collected yet can be unassigned.'], 422);
        }

        $pickup->update(['status' => 'cancelled', 'remarks' => 'Unassigned by sorting center.']);

        return response()->json(['message' => 'Rider unassigned. The parcel is back in To Assign.']);
    }

    // ── helpers ──────────────────────────────────────────────

    private function tabQuery(int $center, string $tab): Builder
    {
        $mine = fn (Builder $q) => $q->where(fn ($q) => $q
            ->where('current_sorting_center_id', $center)
            ->orWhereNull('current_sorting_center_id'));

        return match ($tab) {
            'with_rider' => Parcel::whereHas('pickups', fn ($q) => $q
                ->where('sorting_center_id', $center)->whereIn('status', ParcelPickup::OPEN)),
            'received' => Parcel::whereHas('pickups', fn ($q) => $q
                ->where('sorting_center_id', $center)->where('status', 'received')),
            default => Parcel::whereIn('status', self::WAITING)
                ->where($mine)
                ->whereDoesntHave('pickups', fn ($q) => $q->whereIn('status', ParcelPickup::OPEN)),
        };
    }

    private function present(Parcel $p): array
    {
        $pickup = $p->pickup;

        return [
            'id' => $p->id,
            'tracking_number' => $p->tracking_number,
            'status' => $p->status,
            'status_label' => $p->status_label,
            'order_id' => $p->order_id,
            'seller_name' => $p->seller?->name,
            'seller_phone' => $p->seller?->contact_no,
            'pickup_address' => $p->pickup_address,
            'receiver_name' => $p->receiver_name,
            'dropoff_address' => $p->dropoff_address,
            'destination' => collect([$p->destination_municipality, $p->destination_province])->filter()->implode(', '),
            'sorting_center' => $p->sortingCenter?->name,
            'created_at' => $p->created_at,
            'pickup' => $pickup && $pickup->status !== 'cancelled' ? [
                'id' => $pickup->id,
                'status' => $pickup->status,
                'status_label' => $pickup->statusLabel(),
                'rider_name' => $pickup->rider?->full_name,
                'rider_phone' => $pickup->rider?->phone,
                'assigned_at' => $pickup->created_at,
                'picked_up_at' => $pickup->picked_up_at,
                'received_at' => $pickup->received_at,
                'remarks' => $pickup->remarks,
            ] : null,
        ];
    }

    private function notify(?int $userId, string $title, string $body, string $type): void
    {
        if (! $userId) return;

        UserNotification::create(['user_id' => $userId, 'title' => $title, 'body' => $body, 'type' => $type]);
    }
}
