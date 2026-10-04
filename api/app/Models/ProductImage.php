<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProductImage extends Model
{
    protected $table = 'book_images'; // Using existing book_images table

    protected $fillable = [
        'book_id', // Using existing book_id FK
        'product_id', // Alias for book_id
        'path',
        'label',
        'sort_order',
    ];

    protected $casts = [
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

    public function url(): string
    {
        return $this->path ? asset('storage/' . $this->path) : '';
    }
}