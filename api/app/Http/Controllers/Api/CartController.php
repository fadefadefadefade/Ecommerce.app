<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\CartItem;
use Illuminate\Http\Request;

class CartController extends Controller
{
    public function index(Request $request)
    {
        $items = CartItem::where('user_id', $request->user()->id)
            ->with('product.category')
            ->get();

        $cartItems = $items->map(function ($item) {
            return [
                'id' => $item->id,
                'quantity' => $item->quantity,
                'product' => [
                    'id' => $item->product->id,
                    'title' => $item->product->title,
                    'author' => $item->product->author,
                    'price' => $item->product->price,
                    'effective_price' => $item->product->effective_price,
                    'discount_percent' => $item->product->discount_percent ?? 0,
                    'stock' => $item->product->stock,
                    'image_url' => $item->product->primaryImage,
                    'category' => $item->product->category ? ['name' => $item->product->category->name] : null,
                ],
                'subtotal' => $item->quantity * $item->product->effective_price,
            ];
        });

        $subtotal = $cartItems->sum('subtotal');

        return response()->json([
            'items' => $cartItems,
            'subtotal' => $subtotal,
            'count' => $items->count(),
        ]);
    }

    public function store(Request $request)
    {
        $request->validate([
            'product_id' => 'required|exists:products,id',
            'quantity' => 'nullable|integer|min:1|max:99',
        ]);

        $product = Product::findOrFail($request->product_id);

        if (!$product->inStock()) {
            return response()->json([
                'message' => 'This item is out of stock.',
            ], 400);
        }

        $qty = max(1, (int) $request->input('quantity', 1));

        $item = CartItem::firstOrNew([
            'user_id' => $request->user()->id,
            'product_id' => $product->id,
        ]);

        // Increment if already in cart, otherwise set the requested qty
        $newQty = $item->exists ? $item->quantity + $qty : $qty;
        if ($newQty > $product->stock) {
            $inCart = $item->exists ? " You already have {$item->quantity} in your cart." : '';
            return response()->json([
                'message' => "Only {$product->stock} left in stock.{$inCart}",
                'stock' => $product->stock,
            ], 400);
        }

        $item->quantity = $newQty;
        $item->save();

        return response()->json([
            'message' => '"' . $product->title . '" added to your cart.',
            'item' => [
                'id' => $item->id,
                'quantity' => $item->quantity,
            ],
        ]);
    }

    public function update(Request $request, int $cartItemId)
    {
        $request->validate([
            'quantity' => 'required|integer|min:1|max:99',
        ]);

        $item = CartItem::where('id', $cartItemId)
            ->where('user_id', $request->user()->id)
            ->firstOrFail();

        $stock = (int) $item->product?->stock;
        if ($request->quantity > $stock) {
            return response()->json([
                'message' => $stock > 0 ? "Only {$stock} left in stock." : 'This item is now out of stock.',
                'stock' => $stock,
            ], 400);
        }

        $item->update(['quantity' => $request->quantity]);

        return response()->json([
            'message' => 'Cart updated.',
            'item' => [
                'id' => $item->id,
                'quantity' => $item->quantity,
            ],
        ]);
    }

    public function destroy(Request $request, int $cartItemId)
    {
        CartItem::where('id', $cartItemId)
            ->where('user_id', $request->user()->id)
            ->firstOrFail()
            ->delete();

        return response()->json([
            'message' => 'Item removed from cart.',
        ]);
    }
}
