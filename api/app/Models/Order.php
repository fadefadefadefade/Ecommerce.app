<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

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
}
