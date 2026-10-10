<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\CartItem;
use App\Models\Order;
use App\Models\OrderItem;
use Illuminate\Http\Request;

class CheckoutController extends Controller
{
    private function commissionRate(): float
    {
        return (float) config('marketplace.commission_rate', 10);
    }

    private function cartItems($userId)
    {
        return CartItem::where('user_id', $userId)->with('product')->get();
    }

    private function calcTotals($items): array
    {
        $subtotal = $items->sum(fn ($i) => $i->quantity * $i->product->effective_price);
        $shipping = 50; // fixed ₱50 delivery fee
        $total    = round($subtotal + $shipping, 2);
        return compact('subtotal', 'shipping', 'total');
    }

    public function index(Request $request)
    {
        $items = $this->cartItems($request->user()->id);
        
        if ($items->isEmpty()) {
            return response()->json([
                'message' => 'Your cart is empty.',
            ], 400);
        }

        ['subtotal' => $subtotal, 'shipping' => $shipping, 'total' => $total] = $this->calcTotals($items);

        $user = $request->user();

        return response()->json([
            'items' => $items->map(function ($item) {
                return [
                    'id' => $item->id,
                    'quantity' => $item->quantity,
                    'product' => [
                        'id' => $item->product->id,
                        'title' => $item->product->title,
                        'author' => $item->product->author,
                        'price' => $item->product->price,
                        'effective_price' => $item->product->effective_price,
                        'image_url' => $item->product->primaryImage,
                    ],
                    'subtotal' => $item->quantity * $item->product->effective_price,
                ];
            }),
            'subtotal' => $subtotal,
            'shipping' => $shipping,
            'total' => $total,
            'user' => [
                'name' => $user->name,
                'email' => $user->email,
                'phone' => $user->contact_no ?? $user->phone ?? '',
            ],
        ]);
    }

    public function store(Request $request)
    {
        $request->validate([
            'full_name'      => 'required|string|max:255',
            'phone'          => 'required|string|max:30',
            'email'          => 'required|email|max:255',
            'region'         => 'required|string|max:120',
            'province'       => 'required|string|max:120',
            'city'           => 'required|string|max:120',
            'barangay'       => 'required|string|max:120',
            'house_number'   => 'nullable|string|max:100',
            'street'         => 'nullable|string|max:255',
            'zip_code'       => 'required|string|max:20',
            'payment_method' => 'required|in:cod',
        ]);

        $items = $this->cartItems($request->user()->id);
        
        if ($items->isEmpty()) {
            return response()->json([
                'message' => 'Your cart is empty.',
            ], 400);
        }

        ['subtotal' => $subtotal, 'shipping' => $shipping, 'total' => $total] = $this->calcTotals($items);

        $commissionRate = $this->commissionRate();

        $addressLine = trim(implode(', ', array_filter([
            $request->house_number,
            $request->street,
            $request->barangay,
            $request->city,
            $request->province,
            $request->region,
        ])));

        $order = Order::create([
            'user_id'          => $request->user()->id,
            'full_name'        => $request->full_name,
            'phone'            => $request->phone,
            'email'            => $request->email,
            'address_line'     => $addressLine,
            'city'             => $request->city,
            'province'         => $request->province,
            'zip_code'         => $request->zip_code,
            'shipping_address' => $addressLine . ' ' . $request->zip_code,
            'subtotal'         => $subtotal,
            'shipping_fee'     => $shipping,
            'total_price'      => $total,
            'payment_method'   => 'COD',
            'payment_status'   => 'Pending',
            'status'           => 'Pending',
        ]);

        foreach ($items as $item) {
            $lineTotal        = round($item->quantity * $item->product->effective_price, 2);
            $commissionAmount = round($lineTotal * ($commissionRate / 100), 2);
            $sellerEarning    = round($lineTotal - $commissionAmount, 2);

            OrderItem::create([
                'order_id'          => $order->id,
                'product_id'        => $item->product_id,
                'quantity'          => $item->quantity,
                'price'             => $item->product->effective_price,
                'commission_rate'   => $commissionRate,
                'commission_amount' => $commissionAmount,
                'seller_earning'    => $sellerEarning,
            ]);

            // Reduce stock
            Product::where('id', $item->product_id)->decrement('stock', $item->quantity);
        }

        // Clear cart
        CartItem::where('user_id', $request->user()->id)->delete();

        return response()->json([
            'message' => 'Order placed successfully!',
            'order_id' => $order->id,
        ]);
    }
}
