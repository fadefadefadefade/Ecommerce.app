<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserAddress extends Model
{
    // Same columns as the web app's UserAddress (shared user_addresses table).
    protected $fillable = [
        'user_id',
        'label',        // e.g. Home, Work, Other
        'full_name',
        'phone',
        'address_line',
        'barangay',
        'city',
        'province',
        'zip',
        'country',
        'is_default',
    ];

    protected $casts = [
        'is_default' => 'boolean',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** Human-readable one-liner for display */
    public function getFullAddressAttribute(): string
    {
        return collect([
            $this->address_line,
            $this->barangay,
            $this->city,
            $this->province,
            $this->zip,
            $this->country,
        ])->filter()->implode(', ');
    }
}
