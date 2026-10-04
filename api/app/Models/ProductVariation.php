<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProductVariation extends Model
{
    protected $fillable = [
        'book_id', // Still using book_id FK until we rename tables
        'name',
        'value',
        'price_adjustment',
        'stock',
        'sort_order',
        'is_active',
    ];

    protected $casts = [
        'price_adjustment' => 'float',
        'stock' => 'integer',
        'sort_order' => 'integer',
        'is_active' => 'boolean',
    ];

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class, 'book_id');
    }
}