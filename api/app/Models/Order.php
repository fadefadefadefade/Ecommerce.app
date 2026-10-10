<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Facades\DB;

/** Same columns as the web app's Order model (shared `orders` table). */
class Order extends Model
{
    protected $fillable = [
        'user_id',
        'full_name', 'phone', 'email',
        'address_line', 'city', 'province', 'zip_code',
        'municipality_code', 'province_code',
        'shipping_address',
        'subtotal', 'shipping_fee', 'total_price',
        'payment_method', 'payment_status',
        'status', 'cancellation_reason',
    ];

    protected $casts = [
        'subtotal'     => 'decimal:2',
        'shipping_fee' => 'decimal:2',
        'total_price'  => 'decimal:2',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(OrderItem::class);
    }

    /** Progress steps shown to buyers and sellers, in order. */
    public const STAGES = [
        'pending'    => 'Pending',
        'processing' => 'Processing',
        'warehouse'  => 'Shipped to Warehouse',
        'delivering' => 'Delivering',
        'delivered'  => 'Delivered',
    ];

    /**
     * Current progress step. The orders table only has Pending/Processing/
     * Shipped/Delivered/Cancelled, so "Shipped to Warehouse" vs "Delivering"
     * comes from the order's parcel (logistics) or direct-courier delivery.
     */
    public function trackingStage(): string
    {
        if ($this->status === 'Cancelled') return 'cancelled';
        if ($this->status === 'Delivered') return 'delivered';

        $parcel = Parcel::where('order_id', $this->id)->latest('id')->value('status');
        $delivery = DB::table('deliveries')->where('order_id', $this->id)->latest('id')->value('status');

        if ($parcel === 'delivered' || $delivery === 'delivered') return 'delivered';
        if ($parcel === 'in_transit' || in_array($delivery, ['picked_up', 'in_transit'], true)) return 'delivering';
        if ($this->status === 'Shipped' || in_array($parcel, ['picked_up', 'sorted', 'assigned'], true)) return 'warehouse';
        if ($this->status === 'Processing') return 'processing';

        return 'pending';
    }

    public static function stageLabel(string $stage): string
    {
        return self::STAGES[$stage] ?? 'Cancelled';
    }

    /** Statuses in which the order can still be cancelled (buyer or seller). */
    public const CANCELLABLE = ['Pending', 'Processing'];

    /**
     * Cancel the order: put items back in stock and stop logistics work that
     * hasn't started. Call inside a DB transaction.
     */
    public function cancelWithRestock(string $reason): void
    {
        $this->update(['status' => 'Cancelled', 'cancellation_reason' => $reason]);

        foreach ($this->items()->get() as $item) {
            Product::where('id', $item->product_id)->increment('stock', $item->quantity);
        }

        Parcel::where('order_id', $this->id)
            ->whereIn('status', ['pending_pickup', 'pickup_approved', 'picked_up', 'sorted'])
            ->update(['status' => 'cancelled']);
        DB::table('deliveries')
            ->where('order_id', $this->id)
            ->whereIn('status', ['available', 'accepted'])
            ->update(['status' => 'failed', 'notes' => 'Order cancelled.', 'updated_at' => now()]);
    }

    /**
     * Seller hands the order to logistics ("Shipped to Warehouse"): one parcel per
     * seller, already at the sorting center, ready for logistics to sort and
     * assign to a rider.
     */
    public function shipToWarehouse(User $seller): Parcel
    {
        $parcel = Parcel::where('order_id', $this->id)
            ->where('seller_id', $seller->id)
            ->whereNotIn('status', ['cancelled', 'failed', 'returned'])
            ->first();

        if (! $parcel) {
            $pickup = collect([$seller->house_number, $seller->street, $seller->barangay, $seller->municipality, $seller->province])
                ->filter()->implode(', ');

            $parcel = Parcel::create([
                'tracking_number' => Parcel::generateTracking(),
                'order_id' => $this->id,
                'seller_id' => $seller->id,
                'pickup_address' => $pickup ?: $seller->name,
                'dropoff_address' => $this->address_line ?: $this->shipping_address,
                'destination_municipality' => $this->city,
                'destination_province' => $this->province,
                'receiver_name' => $this->full_name,
                'receiver_phone' => $this->phone,
                'status' => 'picked_up',
                'received_at' => now(),
            ]);
        }

        $this->update(['status' => 'Shipped']);

        return $parcel;
    }

    /** Once every parcel of the order is delivered, the order is Delivered (and COD is paid). */
    public function markDeliveredIfComplete(): void
    {
        $open = Parcel::where('order_id', $this->id)
            ->whereNotIn('status', ['delivered', 'cancelled'])
            ->exists();

        if (! $open) {
            $this->update(['status' => 'Delivered', 'payment_status' => 'Paid']);
        }
    }

    /** Adds `stage` and `stage_label` to the serialized order. */
    public function withTrackingStage(): static
    {
        $stage = $this->trackingStage();
        $this->setAttribute('stage', $stage);
        $this->setAttribute('stage_label', self::stageLabel($stage));
        return $this;
    }
}
