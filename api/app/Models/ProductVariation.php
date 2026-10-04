<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProductVariation extends Model
{
    protected $table = 'product_variations'; // Assuming this table exists or will be created

    protected $fillable = [
        'book_id', // Using book_id for consistency with existing schema
        'product_id', // Alias for book_id
        'name',
        'price',
        'stock',
        'sku',
        'sort_order',
    ];

    protected $casts = [
        'price' => 'float',
        'stock' => 'integer',
        'sort_order' => 'integer',
    ];

    // Automatically set book_id when product_id is set
    public function setProductIdAttribute($value)
    {
        $this->attributes['book_id'] = $value;
    }

    public function getProductIdAttribute()
    {
        return $this->attributes['book_id'];
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class, 'book_id');
    }

    public function book(): BelongsTo
    {
        return $this->belongsTo(Product::class, 'book_id');
    }
}