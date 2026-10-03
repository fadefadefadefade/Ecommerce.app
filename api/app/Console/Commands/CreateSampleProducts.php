<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\Product;
use App\Models\Category;
use App\Models\User;

class CreateSampleProducts extends Command
{
    protected $signature = 'products:create-samples';
    protected $description = 'Create sample products for testing';

    public function handle()
    {
        // Create sample categories first
        $categories = [
            ['id' => 1, 'name' => 'Electronics', 'description' => 'Electronic devices and gadgets'],
            ['id' => 2, 'name' => 'Clothing', 'description' => 'Fashion and apparel'],
            ['id' => 3, 'name' => 'Books', 'description' => 'Books and educational materials'],
            ['id' => 4, 'name' => 'Home & Garden', 'description' => 'Home improvement and gardening'],
            ['id' => 5, 'name' => 'Sports', 'description' => 'Sports and outdoor equipment'],
        ];

        foreach ($categories as $cat) {
            Category::updateOrCreate(['id' => $cat['id']], $cat);
        }

        // Get a seller user (create one if needed)
        $seller = User::where('role', 'seller')->first();
        if (!$seller) {
            $seller = User::create([
                'name' => 'Test Seller',
                'email' => 'seller@test.com',
                'password' => bcrypt('password123'),
                'role' => 'seller',
                'approval_status' => 'approved',
            ]);
        }

        // Create sample products
        $products = [
            [
                'title' => 'Wireless Bluetooth Headphones',
                'author' => 'TechBrand',
                'description' => 'High-quality wireless headphones with noise cancellation.',
                'category_id' => 1, // Electronics
                'price' => 2999.00,
                'stock' => 25,
                'status' => 'active',
                'seller_id' => $seller->id,
                'is_archived' => false,
            ],
            [
                'title' => 'Cotton Casual T-Shirt',
                'author' => 'FashionCo',
                'description' => 'Comfortable 100% cotton t-shirt in various colors.',
                'category_id' => 2, // Clothing
                'price' => 599.00,
                'sale_price' => 499.00,
                'stock' => 50,
                'status' => 'active',
                'seller_id' => $seller->id,
                'is_archived' => false,
            ],
            [
                'title' => 'The Great Gatsby',
                'author' => 'F. Scott Fitzgerald',
                'description' => 'Classic American novel about the Jazz Age.',
                'category_id' => 3, // Books
                'price' => 350.00,
                'stock' => 15,
                'status' => 'active',
                'seller_id' => $seller->id,
                'is_archived' => false,
            ],
            [
                'title' => 'Smartphone',
                'author' => 'PhoneBrand',
                'description' => 'Latest smartphone with advanced camera and fast processor.',
                'category_id' => 1, // Electronics
                'price' => 25999.00,
                'stock' => 10,
                'status' => 'active',
                'seller_id' => $seller->id,
                'is_archived' => false,
            ],
            [
                'title' => 'Running Shoes',
                'author' => 'SportsBrand',
                'description' => 'Professional running shoes for athletes.',
                'category_id' => 5, // Sports
                'price' => 3999.00,
                'discount_percent' => 15,
                'stock' => 30,
                'status' => 'active',
                'seller_id' => $seller->id,
                'is_archived' => false,
            ],
            [
                'title' => 'Coffee Maker',
                'author' => 'KitchenPro',
                'description' => 'Automatic drip coffee maker with programmable timer.',
                'category_id' => 4, // Home & Garden
                'price' => 4500.00,
                'stock' => 8,
                'status' => 'active',
                'seller_id' => $seller->id,
                'is_archived' => false,
            ]
        ];

        foreach ($products as $product) {
            Product::create($product);
        }

        $this->info('Created ' . count($categories) . ' categories and ' . count($products) . ' sample products!');
        
        return 0;
    }
}