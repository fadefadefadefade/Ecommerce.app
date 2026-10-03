<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

class HomeController extends Controller
{
    public function index()
    {
        // Mock data for now - you'll connect this to your actual database
        $categories = [
            ['id' => 1, 'name' => 'Fiction', 'books_count' => 45],
            ['id' => 2, 'name' => 'Non-Fiction', 'books_count' => 32],
            ['id' => 3, 'name' => 'Science', 'books_count' => 28],
            ['id' => 4, 'name' => 'History', 'books_count' => 19],
            ['id' => 5, 'name' => 'Biography', 'books_count' => 15],
        ];

        $featured = [
            [
                'id' => 1,
                'title' => 'The Great Adventure',
                'author' => 'John Doe',
                'price' => 599.00,
                'stock' => 10,
                'image_url' => null,
                'category' => ['name' => 'Fiction'],
            ],
            [
                'id' => 2,
                'title' => 'Learning PHP',
                'author' => 'Jane Smith',
                'price' => 899.00,
                'stock' => 5,
                'image_url' => null,
                'category' => ['name' => 'Programming'],
            ],
            [
                'id' => 3,
                'title' => 'World History',
                'author' => 'Bob Johnson',
                'price' => 750.00,
                'stock' => 8,
                'image_url' => null,
                'category' => ['name' => 'History'],
            ],
        ];

        $bestSellers = [
            [
                'id' => 4,
                'title' => 'Popular Book 1',
                'author' => 'Author Name',
                'price' => 499.00,
                'stock' => 15,
                'image_url' => null,
                'category' => ['name' => 'Fiction'],
            ],
            [
                'id' => 5,
                'title' => 'Popular Book 2',
                'author' => 'Another Author',
                'price' => 699.00,
                'stock' => 0,
                'image_url' => null,
                'category' => ['name' => 'Science'],
            ],
        ];

        return response()->json([
            'categories' => $categories,
            'featured' => $featured,
            'bestSellers' => $bestSellers,
        ]);
    }

    public function products(Request $request)
    {
        // Return paginated products
        return response()->json([
            'products' => [],
            'pagination' => [
                'current_page' => 1,
                'total_pages' => 1,
                'per_page' => 20,
            ],
        ]);
    }

    public function productDetail($id)
    {
        // Return single product details
        return response()->json([
            'product' => [
                'id' => $id,
                'title' => 'Sample Book',
                'author' => 'Author Name',
                'price' => 599.00,
                'description' => 'Sample description',
                'stock' => 10,
            ],
        ]);
    }

    public function categories()
    {
        return response()->json([
            'categories' => [
                ['id' => 1, 'name' => 'Fiction', 'books_count' => 45],
                ['id' => 2, 'name' => 'Non-Fiction', 'books_count' => 32],
            ],
        ]);
    }
}
