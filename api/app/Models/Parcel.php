<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Parcel extends Model
{
    protected $fillable = [
        'tracking_number', 'order_id',
        'seller_id', 'pickup_address', 'dropoff_address',
        'destination_municipality', 'destination_province',
        'receiver_name', 'receiver_phone',
        'weight_kg', 'size', 'notes', 'pickup_scheduled_at',
        'area_id', 'status', 'transfer_status',
        'current_sorting_center_id',
        'verified_by', 'verified_at', 'received_at', 'sorted_at', 'failure_reason',
    ];

    protected $casts = [
        'verified_at'         => 'datetime',
        'received_at'         => 'datetime',
        'sorted_at'           => 'datetime',
        'pickup_scheduled_at' => 'datetime',
        'weight_kg'           => 'decimal:2',
    ];

    protected $appends = ['status_label'];

    /** Human labels for each pipeline status (same wording as the web app). */
    public const STATUS_LABELS = [
        'pending_pickup'  => 'Ready for Pickup',
        'pickup_approved' => 'Pickup Confirmed',
        'pickup_rejected' => 'Pickup Rejected',
        'picked_up'       => 'At Sorting Center',
        'sorted'          => 'Sorted',
        'assigned'        => 'Assigned to Rider',
        'in_transit'      => 'Out for Delivery',
        'delivered'       => 'Delivered',
        'failed'          => 'Delivery Failed',
        'returned'        => 'Returned to Seller',
        'cancelled'       => 'Cancelled',
    ];

    public function seller(): BelongsTo { return $this->belongsTo(User::class, 'seller_id'); }
    public function area(): BelongsTo   { return $this->belongsTo(DeliveryArea::class, 'area_id'); }

    /** Latest delivery assignment (a parcel can be re-assigned after a failed attempt). */
    public function parcelDelivery(): HasOne
    {
        return $this->hasOne(ParcelDelivery::class, 'parcel_id')->latestOfMany();
    }

    public function deliveries(): HasMany
    {
        return $this->hasMany(ParcelDelivery::class, 'parcel_id');
    }

    /** Unique tracking number, same format as the web app (ALVY-XXXXXXXXXX). */
    public static function generateTracking(): string
    {
        do {
            $number = 'ALVY-' . strtoupper(substr(md5(uniqid('', true)), 0, 10));
        } while (static::where('tracking_number', $number)->exists());

        return $number;
    }

    public function order(): BelongsTo { return $this->belongsTo(Order::class); }
    public function sortingCenter(): BelongsTo { return $this->belongsTo(User::class, 'current_sorting_center_id'); }

    public function pickups(): HasMany
    {
        return $this->hasMany(ParcelPickup::class, 'parcel_id');
    }

    /** Latest pickup trip (seller → sorting center). */
    public function pickup(): HasOne
    {
        return $this->hasOne(ParcelPickup::class, 'parcel_id')->latestOfMany();
    }

    /**
     * Sorting center (users.id) that covers a buyer's city, else their province.
     * Null when none matches; any sorting center can then take the parcel.
     */
    public static function sortingCenterFor(?string $city, ?string $province): ?int
    {
        $centers = User::where('role', 'sorting_center')
            ->where('approval_status', 'approved')
            ->orderBy('id')
            ->get(['id', 'municipality', 'province']);

        $norm = fn (?string $v) => strtolower(trim(str_ireplace(['city of', 'city'], '', (string) $v)));
        $city = $norm($city);

        $byCity = $city === '' ? null : $centers->first(fn ($c) => $norm($c->municipality) !== ''
            && (str_contains($city, $norm($c->municipality)) || str_contains($norm($c->municipality), $city)));
        if ($byCity) return $byCity->id;

        $province = strtolower(trim((string) $province));
        return $province === '' ? null
            : $centers->first(fn ($c) => strtolower(trim((string) $c->province)) === $province)?->id;
    }

    public function getStatusLabelAttribute(): string
    {
        return self::STATUS_LABELS[$this->status] ?? ucwords(str_replace('_', ' ', (string) $this->status));
    }
}
