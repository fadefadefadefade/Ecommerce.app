<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Rider extends Model
{
    protected $fillable = [
        'user_id', 'sorting_center_id', 'full_name', 'phone',
        'vehicle_type', 'license_number', 'id_document_path',
        'area_id',
        'application_status', 'rejection_reason', 'approved_at', 'approved_by',
        'is_active',
    ];

    protected $casts = [
        'approved_at' => 'datetime',
        'is_active'   => 'boolean',
    ];

    protected $appends = ['id_document_url'];

    public function user(): BelongsTo { return $this->belongsTo(User::class); }
    public function area(): BelongsTo { return $this->belongsTo(DeliveryArea::class, 'area_id'); }

    public function parcelDeliveries(): HasMany
    {
        return $this->hasMany(ParcelDelivery::class, 'rider_id');
    }

    /** ID documents are uploaded through the web app, so they live in its public storage. */
    public function getIdDocumentUrlAttribute(): ?string
    {
        if (! $this->id_document_path) {
            return null;
        }

        return rtrim(env('WEB_APP_URL', 'http://10.0.2.2:8000'), '/') . '/storage/' . ltrim($this->id_document_path, '/');
    }
}
