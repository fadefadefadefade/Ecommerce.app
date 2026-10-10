<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ParcelDelivery extends Model
{
    protected $fillable = [
        'parcel_id', 'rider_id', 'area_id', 'assigned_by',
        'status', 'remarks',
        'picked_up_at', 'delivered_at',
    ];

    protected $casts = [
        'picked_up_at' => 'datetime',
        'delivered_at' => 'datetime',
    ];

    public const STATUSES = ['assigned', 'out_for_delivery', 'delivered', 'failed', 'returned'];

    public function parcel(): BelongsTo { return $this->belongsTo(Parcel::class, 'parcel_id'); }
    public function rider(): BelongsTo  { return $this->belongsTo(Rider::class, 'rider_id'); }
    public function area(): BelongsTo   { return $this->belongsTo(DeliveryArea::class, 'area_id'); }
}
