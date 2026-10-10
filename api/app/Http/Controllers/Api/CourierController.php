<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\ParcelDelivery;
use App\Models\Rider;
use App\Models\UserNotification;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Courier (rider) side of a delivery. Logistics assigns a parcel to a rider;
 * the rider then moves it Delivering (out_for_delivery) → Delivered, or Failed.
 */
class CourierController extends Controller
{
    private const ACTIVE = ['assigned', 'out_for_delivery'];

    public function dashboard(Request $request)
    {
        $rider = $this->rider($request);
        $mine = fn () => ParcelDelivery::where('rider_id', $rider->id);

        $active = $mine()->whereIn('status', self::ACTIVE)->with('parcel.order')->get();

        return response()->json([
            'rider' => [
                'id' => $rider->id,
                'full_name' => $rider->full_name,
                'vehicle_type' => $rider->vehicle_type,
                'area' => $rider->area?->name,
                'is_active' => $rider->is_active,
            ],
            'stats' => [
                'to_deliver' => $active->where('status', 'assigned')->count(),
                'delivering' => $active->where('status', 'out_for_delivery')->count(),
                'delivered_today' => $mine()->where('status', 'delivered')->whereDate('delivered_at', today())->count(),
                'delivered_total' => $mine()->where('status', 'delivered')->count(),
                // Cash-on-delivery the rider still has to collect
                'cod_to_collect' => (float) $active
                    ->filter(fn ($d) => strtoupper((string) $d->parcel?->order?->payment_method) === 'COD'
                        && $d->parcel?->order?->payment_status !== 'Paid')
                    ->sum(fn ($d) => (float) $d->parcel->order->total_price),
            ],
        ]);
    }

    /** ?tab=active (default) or history */
    public function deliveries(Request $request)
    {
        $rider = $this->rider($request);
        $history = $request->get('tab') === 'history';

        $deliveries = ParcelDelivery::where('rider_id', $rider->id)
            ->when($history,
                fn ($q) => $q->whereIn('status', ['delivered', 'failed', 'returned'])->latest('updated_at'),
                fn ($q) => $q->whereIn('status', self::ACTIVE)->orderByRaw("status = 'out_for_delivery' DESC")->oldest())
            ->with(['parcel.order.items.product', 'area'])
            ->limit(100)
            ->get();

        return response()->json(['deliveries' => $deliveries->map(fn ($d) => $this->present($d))->values()]);
    }

    public function show(Request $request, int $id)
    {
        return response()->json(['delivery' => $this->present($this->find($request, $id))]);
    }

    /** Assigned → Delivering */
    public function start(Request $request, int $id)
    {
        return DB::transaction(function () use ($request, $id) {
            $delivery = $this->find($request, $id, lock: true);
            if ($delivery->status !== 'assigned') {
                return response()->json(['message' => 'This delivery has already been started.'], 422);
            }

            $delivery->update(['status' => 'out_for_delivery', 'picked_up_at' => now()]);
            $delivery->parcel->update(['status' => 'in_transit']);

            $this->notifyBuyer($delivery, 'Your order is on the way',
                'Rider ' . $delivery->rider->full_name . ' is delivering your order.');

            return response()->json([
                'message' => 'Delivery started. The buyer can now see it as Delivering.',
                'delivery' => $this->present($delivery->fresh()),
            ]);
        });
    }

    /** Delivering → Delivered */
    public function deliver(Request $request, int $id)
    {
        return DB::transaction(function () use ($request, $id) {
            $delivery = $this->find($request, $id, lock: true);
            if ($delivery->status !== 'out_for_delivery') {
                return response()->json(['message' => 'Start the delivery before marking it delivered.'], 422);
            }

            $delivery->update(['status' => 'delivered', 'delivered_at' => now()]);
            $delivery->parcel->update(['status' => 'delivered']);
            $delivery->parcel->order?->markDeliveredIfComplete();

            $this->notifyBuyer($delivery, 'Order delivered', 'Your order has been delivered. Thank you for shopping!');

            return response()->json([
                'message' => 'Marked as delivered.',
                'delivery' => $this->present($delivery->fresh()),
            ]);
        });
    }

    /** Delivering/Assigned → Failed (logistics can re-assign it) */
    public function fail(Request $request, int $id)
    {
        $request->validate(['reason' => 'required|string|max:500']);

        return DB::transaction(function () use ($request, $id) {
            $delivery = $this->find($request, $id, lock: true);
            if (! in_array($delivery->status, self::ACTIVE, true)) {
                return response()->json(['message' => 'This delivery is already finished.'], 422);
            }

            $delivery->update(['status' => 'failed', 'remarks' => $request->reason]);
            $delivery->parcel->update(['status' => 'failed', 'failure_reason' => $request->reason]);

            $this->notifyBuyer($delivery, 'Delivery attempt failed',
                'We could not deliver your order: ' . $request->reason . '. We will try again soon.');

            return response()->json([
                'message' => 'Marked as failed. Logistics will re-assign the parcel.',
                'delivery' => $this->present($delivery->fresh()),
            ]);
        });
    }

    // ── helpers ──────────────────────────────────────────────

    /** The approved, active rider profile of the logged-in courier. */
    private function rider(Request $request): Rider
    {
        $rider = Rider::with('area')->where('user_id', $request->user()->id)->first();

        abort_unless($request->user()->role === 'courier' && $rider, 403, 'This account is not a registered rider.');
        abort_unless($rider->application_status === 'approved', 403, 'Your rider application is not approved yet.');

        return $rider;
    }

    private function find(Request $request, int $id, bool $lock = false): ParcelDelivery
    {
        $rider = $this->rider($request);

        return ParcelDelivery::where('rider_id', $rider->id)
            ->with(['parcel.order.items.product', 'area', 'rider'])
            ->when($lock, fn ($q) => $q->lockForUpdate())
            ->findOrFail($id);
    }

    private function notifyBuyer(ParcelDelivery $delivery, string $title, string $body): void
    {
        $order = $delivery->parcel?->order;
        if (! $order) return;

        UserNotification::create([
            'user_id' => $order->user_id,
            'title' => $title . ' · Order #' . str_pad($order->id, 6, '0', STR_PAD_LEFT),
            'body' => $body,
            'type' => 'delivery',
        ]);
    }

    private function present(ParcelDelivery $d): array
    {
        $parcel = $d->parcel;
        $order = $parcel?->order;

        return [
            'id' => $d->id,
            'status' => $d->status,
            'status_label' => match ($d->status) {
                'assigned' => 'To Deliver',
                'out_for_delivery' => 'Delivering',
                'delivered' => 'Delivered',
                'failed' => 'Failed',
                'returned' => 'Returned',
                default => ucfirst($d->status),
            },
            'remarks' => $d->remarks,
            'assigned_at' => $d->created_at,
            'picked_up_at' => $d->picked_up_at,
            'delivered_at' => $d->delivered_at,
            'area' => $d->area?->name,
            'parcel' => $parcel ? [
                'id' => $parcel->id,
                'tracking_number' => $parcel->tracking_number,
                'receiver_name' => $parcel->receiver_name,
                'receiver_phone' => $parcel->receiver_phone,
                'dropoff_address' => $parcel->dropoff_address,
                'pickup_address' => $parcel->pickup_address,
                'notes' => $parcel->notes,
            ] : null,
            'order' => $order ? [
                'id' => $order->id,
                'order_number' => str_pad($order->id, 6, '0', STR_PAD_LEFT),
                'total_price' => (float) $order->total_price,
                'payment_method' => $order->payment_method,
                'payment_status' => $order->payment_status,
                'stage' => $order->trackingStage(),
                'stage_label' => Order::stageLabel($order->trackingStage()),
                'items' => $order->items->map(fn ($i) => [
                    'title' => $i->product?->title ?? 'Item',
                    'quantity' => $i->quantity,
                    'image_url' => $i->product?->primaryImage,
                ])->values(),
            ] : null,
        ];
    }
}
