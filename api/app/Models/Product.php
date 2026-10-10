<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

class Product extends Model
{
    protected $table = 'products';

    protected $fillable = [
        'category_id', 'subcategory', 'seller_id',
        'product_code', 'brand',
        'title', 'author', 'isbn',
        'publisher', 'publication_year', 'edition', 'language', 'pages', 'format',
        'price', 'sale_price', 'discount_percent', 'voucher_code',
        'stock', 'sku', 'availability', 'status',
        'description', 'specs', 'image', 'video_path',
        'weight_kg', 'length_cm', 'width_cm', 'height_cm', 'address_id',
        'is_archived', 'archived_at',
    ];

    protected $casts = [
        'price'            => 'float',
        'sale_price'       => 'float',
        'discount_percent' => 'float',
        'stock'            => 'integer',
        'pages'            => 'integer',
        'specs'            => 'array',
        'weight_kg'        => 'float',
        'length_cm'        => 'float',
        'width_cm'         => 'float',
        'height_cm'        => 'float',
        'is_archived'      => 'boolean',
        'archived_at'      => 'datetime',
    ];

    // ── Relationships ─────────────────────────────────────────
    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function seller(): BelongsTo
    {
        return $this->belongsTo(User::class, 'seller_id');
    }

    public function variations(): HasMany
    {
        return $this->hasMany(ProductVariation::class, 'product_id');
    }

    public function address(): BelongsTo
    {
        return $this->belongsTo(UserAddress::class, 'address_id');
    }

    public function cartItems(): HasMany
    {
        return $this->hasMany(CartItem::class, 'product_id');
    }

    public function orderItems(): HasMany
    {
        return $this->hasMany(OrderItem::class, 'product_id');
    }

    // ── Accessors ─────────────────────────────────────────────
    public function getSlugAttribute(): string
    {
        return Str::slug($this->title) . '-' . $this->id;
    }

    /** Primary display image (products have a single image since book_images was dropped). */
    public function getPrimaryImageAttribute(): ?string
    {
        if ($this->image) return asset('storage/' . $this->image);
        return null;
    }

    public function inStock(): bool
    {
        return $this->totalStock() > 0
            && $this->availability !== 'out_of_stock'
            && $this->status !== 'out_of_stock';
    }

    /** Total stock across variations, or the base stock when there are none. */
    public function totalStock(): int
    {
        if ($this->relationLoaded('variations') ? $this->variations->isNotEmpty() : $this->variations()->exists()) {
            return (int) $this->variations()->sum('stock');
        }
        return (int) $this->stock;
    }

    /** Effective price: sale price if valid, otherwise discount %, otherwise base price. */
    public function getEffectivePriceAttribute(): float
    {
        if ($this->sale_price !== null && $this->sale_price > 0 && $this->sale_price < $this->price) {
            return round((float) $this->sale_price, 2);
        }
        if ($this->discount_percent > 0) {
            return round($this->price * (1 - $this->discount_percent / 100), 2);
        }
        return (float) $this->price;
    }

    public function hasDiscount(): bool
    {
        return ($this->sale_price !== null && $this->sale_price > 0 && $this->sale_price < $this->price)
            || $this->discount_percent > 0;
    }

    public function isLowStock(int $threshold = 5): bool
    {
        return $this->stock > 0 && $this->stock <= $threshold;
    }

    // ── Scopes ────────────────────────────────────────────────
    public function scopeActive($query)
    {
        return $query->where('is_archived', false);
    }

    public function scopeArchived($query)
    {
        return $query->where('is_archived', true);
    }

    public function scopeLowStock($query, int $threshold = 5)
    {
        return $query->where('stock', '>', 0)->where('stock', '<=', $threshold);
    }

    /** Publicly visible listings (published + not archived). */
    public function scopePublished($query)
    {
        return $query->where('is_archived', false)->where('status', 'active');
    }

    public function scopeStatus($query, string $status)
    {
        return $query->where('status', $status);
    }

    public function isDraft(): bool
    {
        return $this->status === 'draft';
    }
}