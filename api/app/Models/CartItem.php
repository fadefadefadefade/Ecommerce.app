<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CartItem extends Model
{
    protected $fillable = [
        'user_id',
        'book_id', // Still using book_id FK until we rename tables
        'quantity',
        'selected_variation',
    ];

    protected $casts = [
        'quantity' => 'integer',
        'selected_variation' => 'array',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class, 'book_id');
    }
}