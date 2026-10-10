<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** Direct-courier delivery of an order (managed by the web courier panel). */
class Delivery extends Model
{
    public const OPEN_STATUSES = ['available', 'accepted', 'picked_up', 'in_transit'];
}
