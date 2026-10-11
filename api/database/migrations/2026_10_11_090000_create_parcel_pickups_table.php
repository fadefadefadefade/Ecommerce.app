<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Rider trips from the seller to the sorting center (first mile).
 * parcel_deliveries stays the last mile (sorting center → buyer).
 */
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('parcel_pickups')) {
            return;
        }

        Schema::create('parcel_pickups', function (Blueprint $table) {
            $table->id();
            $table->foreignId('parcel_id')->constrained('parcels')->cascadeOnDelete();
            $table->foreignId('rider_id')->constrained('riders');
            // users.id of the sorting center the rider brings the parcel to
            $table->foreignId('sorting_center_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('assigned_by')->nullable()->constrained('users')->nullOnDelete();
            $table->enum('status', ['assigned', 'picked_up', 'received', 'cancelled'])->default('assigned');
            $table->text('remarks')->nullable();
            $table->timestamp('picked_up_at')->nullable();
            $table->timestamp('received_at')->nullable();
            $table->foreignId('received_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->index(['rider_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('parcel_pickups');
    }
};
