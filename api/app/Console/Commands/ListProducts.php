<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\Product;

class ListProducts extends Command
{
    protected $signature = 'products:list';
    protected $description = 'List products in database';

    public function handle()
    {
        $products = Product::take(10)->get(['id', 'title', 'status', 'is_archived', 'stock']);
        
        $this->info("Products in Database:");
        foreach ($products as $product) {
            $this->line("ID: {$product->id}, Title: {$product->title}, Status: {$product->status}, Stock: {$product->stock}, Archived: " . ($product->is_archived ? 'Yes' : 'No'));
        }
        
        $this->info("Total products: " . Product::count());
        
        return 0;
    }
}