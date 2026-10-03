<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Order;
use Illuminate\Http\Request;

class OrderController extends Controller
{
    public function show(Request $request, int $id)
    {
        $order = Order::with(['items.product.images'])
            ->where('id', $id)
            ->where('user_id', $request->user()->id)
            ->firstOrFail();

        return response()->json([
            'order' => [
                'id' => $order->id,
                'order_number' => str_pad($order->id, 6, '0', STR_PAD_LEFT),
                'status' => $order->status,
                'payment_status' => $order->payment_status,
                'payment_method' => $order->payment_method,
                'subtotal' => $order->subtotal,
                'shipping_fee' => $order->shipping_fee,
                'total_price' => $order->total_price,
                'full_name' => $order->full_name,
                'phone' => $order->phone,
                'email' => $order->email,
                'shipping_address' => $order->shipping_address,
                'address_line' => $order->address_line,
                'city' => $order->city,
                'province' => $order->province,
                'zip_code' => $order->zip_code,
                'created_at' => $order->created_at->toIso8601String(),
                'items' => $order->items->map(function ($item) {
                    return [
                        'id' => $item->id,
                        'quantity' => $item->quantity,
                        'price' => $item->price,
                        'subtotal' => $item->quantity * $item->price,
                        'product' => [
                            'id' => $item->product->id,
                            'title' => $item->product->title,
                            'author' => $item->product->author,
                            'image_url' => $item->product->primaryImage,
                        ],
                    ];
                }),
            ],
        ]);
    }

    public function index(Request $request)
    {
        $orders = Order::where('user_id', $request->user()->id)
            ->with(['items.product'])
            ->latest()
            ->get();

        return response()->json([
            'orders' => $orders->map(function ($order) {
                return [
                    'id' => $order->id,
                    'order_number' => str_pad($order->id, 6, '0', STR_PAD_LEFT),
                    'status' => $order->status,
                    'payment_status' => $order->payment_status,
                    'payment_method' => $order->payment_method,
                    'total_price' => $order->total_price,
                    'created_at' => $order->created_at->toIso8601String(),
                    'items_count' => $order->items->count(),
                    'first_item_image' => $order->items->first()?->product?->primaryImage,
                ];
            }),
        ]);
    }
}
