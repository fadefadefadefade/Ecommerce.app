<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use App\Models\User;

class LogisticsSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // Create logistics admin user
        User::updateOrCreate(
            ['email' => 'logistics@admin.com'],
            [
                'name' => 'Logistics Admin',
                'email' => 'logistics@admin.com',
                'password' => Hash::make('logistics123'),
                'role' => 'admin',
                'email_verified_at' => now(),
                'created_at' => now(),
                'updated_at' => now(),
            ]
        );

        // Create sorting center managers
        $sortingCenters = [
            ['name' => 'Central Sorting Manager', 'email' => 'central@sorting.com'],
            ['name' => 'North Zone Manager', 'email' => 'north@sorting.com'],
            ['name' => 'South Zone Manager', 'email' => 'south@sorting.com'],
        ];

        foreach ($sortingCenters as $manager) {
            User::updateOrCreate(
                ['email' => $manager['email']],
                [
                    'name' => $manager['name'],
                    'email' => $manager['email'],
                    'password' => Hash::make('sorting123'),
                    'role' => 'sorting_center',
                    'email_verified_at' => now(),
                    'created_at' => now(),
                    'updated_at' => now(),
                ]
            );
        }

        // Create courier users
        $couriers = [
            ['name' => 'John Courier', 'email' => 'john@courier.com'],
            ['name' => 'Sarah Delivery', 'email' => 'sarah@courier.com'],
            ['name' => 'Mike Express', 'email' => 'mike@courier.com'],
            ['name' => 'Lisa Swift', 'email' => 'lisa@courier.com'],
        ];

        foreach ($couriers as $courier) {
            User::updateOrCreate(
                ['email' => $courier['email']],
                [
                    'name' => $courier['name'],
                    'email' => $courier['email'],
                    'password' => Hash::make('courier123'),
                    'role' => 'courier',
                    'email_verified_at' => now(),
                    'created_at' => now(),
                    'updated_at' => now(),
                ]
            );
        }

        // Create seller accounts
        $sellers = [
            ['name' => 'Tech Store', 'email' => 'tech@store.com'],
            ['name' => 'Fashion Hub', 'email' => 'fashion@hub.com'],
            ['name' => 'Home Essentials', 'email' => 'home@essentials.com'],
        ];

        foreach ($sellers as $seller) {
            User::updateOrCreate(
                ['email' => $seller['email']],
                [
                    'name' => $seller['name'],
                    'email' => $seller['email'],
                    'password' => Hash::make('seller123'),
                    'role' => 'seller',
                    'email_verified_at' => now(),
                    'created_at' => now(),
                    'updated_at' => now(),
                ]
            );
        }

        $this->command->info('Logistics users created successfully!');
        $this->command->info('Login credentials:');
        $this->command->info('Admin: logistics@admin.com / logistics123');
        $this->command->info('Sorting Centers: central@sorting.com, north@sorting.com, south@sorting.com / sorting123');
        $this->command->info('Couriers: john@courier.com, sarah@courier.com, mike@courier.com, lisa@courier.com / courier123');
        $this->command->info('Sellers: tech@store.com, fashion@hub.com, home@essentials.com / seller123');
    }
}