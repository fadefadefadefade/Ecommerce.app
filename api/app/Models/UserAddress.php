<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserAddress extends Model
{
    protected $fillable = [
        'user_id',
        'label',
        'first_name',
        'last_name',
        'phone',
        'region',
        'province',
        'municipality',
        'barangay',
        'zip_code',
        'house_number',
        'street',
        'landmark',
        'is_default',
    ];

    protected $casts = [
        'is_default' => 'boolean',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function getFullAddressAttribute(): string
    {
        return implode(', ', array_filter([
            $this->house_number,
            $this->street,
            $this->barangay,
            $this->municipality,
            $this->province,
            $this->region,
            $this->zip_code,
        ]));
    }
}