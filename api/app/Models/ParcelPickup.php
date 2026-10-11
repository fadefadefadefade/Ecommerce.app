<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** A rider's trip from the seller to the sorting center. */
class ParcelPickup extends Model
{
    /** Pickups still in progress (one per parcel at a time). */
    public const OPEN = ['assigned', 'picked_up'];

    public const STATUS_LABELS = [
        'assigned'  => 'To Pick Up',
        'picked_up' => 'Picked Up',
        'received'  => 'Received',
        'cancelled' => 'Cancelled',
    ];

    protected $fillable = [
        'parcel_id', 'rider_id', 'sorting_center_id', 'assigned_by',
        'status', 'remarks', 'picked_up_at', 'received_at', 'received_by',
    ];

    protected $casts = [
        'picked_up_at' => 'datetime',
        'received_at'  => 'datetime',
    ];

    public function parcel(): BelongsTo        { return $this->belongsTo(Parcel::class); }
    public function rider(): BelongsTo         { return $this->belongsTo(Rider::class); }
    public function sortingCenter(): BelongsTo { return $this->belongsTo(User::class, 'sorting_center_id'); }

    public function statusLabel(): string
    {
        return self::STATUS_LABELS[$this->status] ?? ucfirst($this->status);
    }
}
