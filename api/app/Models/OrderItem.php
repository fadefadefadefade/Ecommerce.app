<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class OrderItem extends Model
{
    protected $fillable = [
        'order_id',
        'book_id', // Still using book_id FK until we rename tables
        'quantity',
        'price',
        'selected_variation',
    ];

    protected $casts = [
        'quantity' => 'integer',
        'price' => 'float',
        'selected_variation' => 'array',
    ];

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class, 'book_id');
    }
}