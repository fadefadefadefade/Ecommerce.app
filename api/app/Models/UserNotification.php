<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** In-app notifications, created by the web app (orders, deliveries, approvals). */
class UserNotification extends Model
{
    protected $fillable = ['user_id', 'title', 'body', 'type', 'link', 'read_at'];

    protected $casts = [
        'read_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
