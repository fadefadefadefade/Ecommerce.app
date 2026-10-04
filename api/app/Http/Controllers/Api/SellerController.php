<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Category;
use App\Models\ProductImage;
use App\Models\ProductVariation;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;

class SellerController extends Controller
{
    public function dashboard(Request $request)
    {
        $sellerId = $request->user()->id;
        
        // Get seller's products
        $products = Product::where('seller_id', $sellerId)
            ->where('is_archived', false)
            ->latest()
            ->take(5)
            ->get()
            ->map(function ($product) {
                return [
                    'id' => $product->id,
                    'title' => $product->title,
                    'price' => $product->price,
                    'effective_price' => $product->effective_price,
                    'stock' => $product->stock,
                    'status' => $product->status,
                ];
            });

        // Mock dashboard stats - replace with real calculations
        return response()->json([
            'totalEarnings' => 15000.00,
            'totalRevenue' => 18000.00,
            'totalCommission' => 3000.00,
            'totalOrders' => 45,
            'totalProducts' => $products->count(),
            'products' => $products,
            'recentOrders' => [
                [
                    'order_id' => 101,
                    'quantity' => 2,
                    'seller_earning' => 500.00,
                    'created_at' => now()->toISOString(),
                    'product' => ['title' => 'Sample Product'],
                ],
            ],
        ]);
    }

    public function products(Request $request)
    {
        $sellerId = $request->user()->id;
        
        $query = Product::where('seller_id', $sellerId)
            ->with(['category', 'images']);

        // Filter by status
        if ($request->has('status')) {
            $status = $request->status;
            if ($status === 'archived') {
                $query->where('is_archived', true);
            } elseif ($status === 'low_stock') {
                $query->where('is_archived', false)->where('stock', '>', 0)->where('stock', '<=', 5);
            } elseif ($status === 'out_of_stock') {
                $query->where('is_archived', false)->where('stock', 0);
            } else {
                $query->where('is_archived', false)->where('status', $status);
            }
        } else {
            $query->where('is_archived', false);
        }

        // Search functionality
        if ($request->has('search') && !empty($request->search)) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('title', 'like', "%{$search}%")
                  ->orWhere('sku', 'like', "%{$search}%")
                  ->orWhere('product_code', 'like', "%{$search}%");
            });
        }

        $products = $query->latest()->paginate(20);

        return response()->json([
            'products' => $products->items(),
            'pagination' => [
                'current_page' => $products->currentPage(),
                'last_page' => $products->lastPage(),
                'per_page' => $products->perPage(),
                'total' => $products->total(),
            ],
        ]);
    }

    public function getProduct(Request $request, $id)
    {
        $sellerId = $request->user()->id;
        
        $product = Product::where('seller_id', $sellerId)
            ->with(['category', 'images', 'variations'])
            ->findOrFail($id);

        return response()->json([
            'product' => $product,
        ]);
    }

    public function createProduct(Request $request)
    {
        $sellerId = $request->user()->id;
        
        // Validate the request
        $validator = $this->validateProductData($request);
        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        try {
            DB::beginTransaction();

            $data = $validator->validated();
            $data['seller_id'] = $sellerId;

            // Handle cover image
            if ($request->hasFile('cover_image')) {
                $data['image'] = $request->file('cover_image')->store('products', 'public');
            }

            // Handle video
            if ($request->hasFile('video')) {
                $data['video_path'] = $request->file('video')->store('products/videos', 'public');
            }

            // Create the product
            $product = Product::create($data);

            // Auto-generate product code
            $product->product_code = 'ALVY-' . str_pad($product->id, 6, '0', STR_PAD_LEFT);
            $product->save();

            // Handle additional images
            if ($request->hasFile('images')) {
                $this->handleImages($request, $product);
            }

            // Handle variations
            if ($request->has('variations')) {
                $this->handleVariations($request, $product);
            }

            DB::commit();

            $product->load(['category', 'images', 'variations']);

            return response()->json([
                'message' => 'Product created successfully',
                'product' => $product,
            ], 201);

        } catch (\Exception $e) {
            DB::rollback();
            return response()->json([
                'message' => 'Failed to create product',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    public function updateProduct(Request $request, $id)
    {
        $sellerId = $request->user()->id;
        
        $product = Product::where('seller_id', $sellerId)->findOrFail($id);

        // Validate the request
        $validator = $this->validateProductData($request, $id);
        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        try {
            DB::beginTransaction();

            $data = $validator->validated();

            // Handle cover image
            if ($request->hasFile('cover_image')) {
                if ($product->image) {
                    Storage::disk('public')->delete($product->image);
                }
                $data['image'] = $request->file('cover_image')->store('products', 'public');
            }

            // Handle video
            if ($request->hasFile('video')) {
                if ($product->video_path) {
                    Storage::disk('public')->delete($product->video_path);
                }
                $data['video_path'] = $request->file('video')->store('products/videos', 'public');
            }

            // Update the product
            $product->update($data);

            // Handle image removal
            if ($request->has('removed_images')) {
                $removedIds = $request->removed_images;
                $imagesToDelete = $product->images()->whereIn('id', $removedIds)->get();
                foreach ($imagesToDelete as $image) {
                    Storage::disk('public')->delete($image->path);
                    $image->delete();
                }
            }

            // Handle new images
            if ($request->hasFile('images')) {
                $this->handleImages($request, $product);
            }

            // Handle image reordering
            if ($request->has('image_order')) {
                $this->reorderImages($request, $product);
            }

            // Handle variations
            if ($request->has('variations')) {
                $product->variations()->delete();
                $this->handleVariations($request, $product);
            }

            DB::commit();

            $product->load(['category', 'images', 'variations']);

            return response()->json([
                'message' => 'Product updated successfully',
                'product' => $product,
            ]);

        } catch (\Exception $e) {
            DB::rollback();
            return response()->json([
                'message' => 'Failed to update product',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    public function deleteProduct(Request $request, $id)
    {
        $sellerId = $request->user()->id;
        
        $product = Product::where('seller_id', $sellerId)->findOrFail($id);

        try {
            // Delete associated images
            foreach ($product->images as $image) {
                Storage::disk('public')->delete($image->path);
            }
            
            if ($product->image) {
                Storage::disk('public')->delete($product->image);
            }
            
            if ($product->video_path) {
                Storage::disk('public')->delete($product->video_path);
            }

            $product->delete();

            return response()->json([
                'message' => 'Product deleted successfully',
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'message' => 'Failed to delete product',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    public function archiveProduct(Request $request, $id)
    {
        $sellerId = $request->user()->id;
        
        $product = Product::where('seller_id', $sellerId)->findOrFail($id);
        
        $product->update([
            'is_archived' => true,
            'archived_at' => now(),
        ]);

        return response()->json([
            'message' => 'Product archived successfully',
            'product' => $product,
        ]);
    }

    public function unarchiveProduct(Request $request, $id)
    {
        $sellerId = $request->user()->id;
        
        $product = Product::where('seller_id', $sellerId)->findOrFail($id);
        
        $product->update([
            'is_archived' => false,
            'archived_at' => null,
        ]);

        return response()->json([
            'message' => 'Product restored successfully',
            'product' => $product,
        ]);
    }

    public function updateStock(Request $request, $id)
    {
        $sellerId = $request->user()->id;
        
        $validator = Validator::make($request->all(), [
            'stock' => 'required|integer|min:0',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $product = Product::where('seller_id', $sellerId)->findOrFail($id);
        
        $product->update([
            'stock' => $request->stock,
            'availability' => $request->stock > 0 ? 'in_stock' : 'out_of_stock',
        ]);

        return response()->json([
            'message' => 'Stock updated successfully',
            'product' => $product,
        ]);
    }

    public function updateStatus(Request $request, $id)
    {
        $sellerId = $request->user()->id;
        
        $validator = Validator::make($request->all(), [
            'status' => 'required|in:active,draft,inactive',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $product = Product::where('seller_id', $sellerId)->findOrFail($id);
        
        $product->update([
            'status' => $request->status,
        ]);

        return response()->json([
            'message' => 'Status updated successfully',
            'product' => $product,
        ]);
    }

    public function getProductCounts(Request $request)
    {
        $sellerId = $request->user()->id;
        
        $allProducts = Product::where('seller_id', $sellerId);

        $counts = [
            'active' => (clone $allProducts)->where('is_archived', false)->where('status', 'active')->count(),
            'draft' => (clone $allProducts)->where('is_archived', false)->where('status', 'draft')->count(),
            'low_stock' => (clone $allProducts)->where('is_archived', false)->where('stock', '>', 0)->where('stock', '<=', 5)->count(),
            'out_of_stock' => (clone $allProducts)->where('is_archived', false)->where('stock', 0)->count(),
            'archived' => (clone $allProducts)->where('is_archived', true)->count(),
        ];

        return response()->json([
            'counts' => $counts,
        ]);
    }

    public function orders(Request $request)
    {
        $sellerId = $request->user()->id;
        
        // Get orders containing this seller's products
        $query = Order::whereHas('items.product', function ($q) use ($sellerId) {
            $q->where('seller_id', $sellerId);
        })->with(['user', 'items' => function ($q) use ($sellerId) {
            $q->whereHas('product', function ($subQ) use ($sellerId) {
                $subQ->where('seller_id', $sellerId);
            })->with('product');
        }]);

        // Filter by status
        if ($request->has('status') && !empty($request->status)) {
            $query->where('status', $request->status);
        }

        // Search functionality
        if ($request->has('search') && !empty($request->search)) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('order_number', 'like', "%{$search}%")
                  ->orWhereHas('user', function ($userQ) use ($search) {
                      $userQ->where('name', 'like', "%{$search}%")
                           ->orWhere('email', 'like', "%{$search}%");
                  });
            });
        }

        $orders = $query->latest()->paginate($request->get('limit', 20));

        // Calculate seller earnings for each order
        $ordersWithEarnings = $orders->getCollection()->map(function ($order) {
            $sellerEarning = 0;
            $commissionAmount = 0;
            
            foreach ($order->items as $item) {
                $itemTotal = $item->price * $item->quantity;
                $commission = $itemTotal * 0.15; // 15% commission
                $earning = $itemTotal - $commission;
                
                $sellerEarning += $earning;
                $commissionAmount += $commission;
                
                // Add calculated fields to item
                $item->seller_earning = $earning;
                $item->commission_amount = $commission;
            }
            
            $order->seller_earning = $sellerEarning;
            $order->commission_amount = $commissionAmount;
            
            return $order;
        });

        $orders->setCollection($ordersWithEarnings);

        // Get status counts for filtering
        $statusCounts = [
            'all' => Order::whereHas('items.product', function ($q) use ($sellerId) {
                $q->where('seller_id', $sellerId);
            })->count(),
            'pending' => Order::where('status', 'Pending')->whereHas('items.product', function ($q) use ($sellerId) {
                $q->where('seller_id', $sellerId);
            })->count(),
            'processing' => Order::where('status', 'Processing')->whereHas('items.product', function ($q) use ($sellerId) {
                $q->where('seller_id', $sellerId);
            })->count(),
            'shipped' => Order::where('status', 'Shipped')->whereHas('items.product', function ($q) use ($sellerId) {
                $q->where('seller_id', $sellerId);
            })->count(),
            'delivered' => Order::where('status', 'Delivered')->whereHas('items.product', function ($q) use ($sellerId) {
                $q->where('seller_id', $sellerId);
            })->count(),
            'cancelled' => Order::where('status', 'Cancelled')->whereHas('items.product', function ($q) use ($sellerId) {
                $q->where('seller_id', $sellerId);
            })->count(),
        ];

        return response()->json([
            'orders' => $orders->items(),
            'pagination' => [
                'current_page' => $orders->currentPage(),
                'last_page' => $orders->lastPage(),
                'per_page' => $orders->perPage(),
                'total' => $orders->total(),
            ],
            'status_counts' => $statusCounts,
        ]);
    }

    public function getOrderCounts(Request $request)
    {
        $sellerId = $request->user()->id;
        
        $counts = [
            'pending' => Order::where('status', 'Pending')->whereHas('items.product', function ($q) use ($sellerId) {
                $q->where('seller_id', $sellerId);
            })->count(),
            'processing' => Order::where('status', 'Processing')->whereHas('items.product', function ($q) use ($sellerId) {
                $q->where('seller_id', $sellerId);
            })->count(),
            'shipped' => Order::where('status', 'Shipped')->whereHas('items.product', function ($q) use ($sellerId) {
                $q->where('seller_id', $sellerId);
            })->count(),
            'delivered' => Order::where('status', 'Delivered')->whereHas('items.product', function ($q) use ($sellerId) {
                $q->where('seller_id', $sellerId);
            })->count(),
            'cancelled' => Order::where('status', 'Cancelled')->whereHas('items.product', function ($q) use ($sellerId) {
                $q->where('seller_id', $sellerId);
            })->count(),
            'total' => Order::whereHas('items.product', function ($q) use ($sellerId) {
                $q->where('seller_id', $sellerId);
            })->count(),
        ];

        return response()->json([
            'counts' => $counts,
        ]);
    }

    public function getOrderDetails(Request $request, $id)
    {
        $sellerId = $request->user()->id;
        
        $order = Order::whereHas('items.product', function ($q) use ($sellerId) {
            $q->where('seller_id', $sellerId);
        })->with(['user', 'items' => function ($q) use ($sellerId) {
            $q->whereHas('product', function ($subQ) use ($sellerId) {
                $subQ->where('seller_id', $sellerId);
            })->with('product');
        }])->findOrFail($id);

        // Calculate seller earnings for the order
        $sellerEarning = 0;
        $commissionAmount = 0;
        
        foreach ($order->items as $item) {
            $itemTotal = $item->price * $item->quantity;
            $commission = $itemTotal * 0.15; // 15% commission
            $earning = $itemTotal - $commission;
            
            $sellerEarning += $earning;
            $commissionAmount += $commission;
            
            // Add calculated fields to item
            $item->seller_earning = $earning;
            $item->commission_amount = $commission;
        }
        
        $order->seller_earning = $sellerEarning;
        $order->commission_amount = $commissionAmount;

        return response()->json([
            'order' => $order,
            'parcel' => null, // Mock parcel tracking data
        ]);
    }

    public function updateOrderStatus(Request $request, $id)
    {
        $sellerId = $request->user()->id;
        
        $validator = Validator::make($request->all(), [
            'status' => 'required|in:Pending,Processing,Shipped,Delivered,Cancelled',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $order = Order::whereHas('items.product', function ($q) use ($sellerId) {
            $q->where('seller_id', $sellerId);
        })->findOrFail($id);

        $order->update(['status' => $request->status]);

        return response()->json([
            'message' => "Order status updated to {$request->status}",
            'order' => $order->load(['user', 'items.product']),
        ]);
    }

    public function schedulePickup(Request $request, $id)
    {
        $sellerId = $request->user()->id;
        
        $validator = Validator::make($request->all(), [
            'courier_name' => 'required|string',
            'tracking_number' => 'nullable|string',
            'pickup_scheduled_at' => 'required|date',
            'notes' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $order = Order::whereHas('items.product', function ($q) use ($sellerId) {
            $q->where('seller_id', $sellerId);
        })->findOrFail($id);

        // Update order status to Shipped
        $order->update(['status' => 'Shipped']);

        return response()->json([
            'message' => 'Pickup scheduled successfully',
            'order' => $order->load(['user', 'items.product']),
            'delivery' => [
                'courier_name' => $request->courier_name,
                'tracking_number' => $request->tracking_number,
                'pickup_scheduled_at' => $request->pickup_scheduled_at,
                'notes' => $request->notes,
            ],
            'parcel' => [
                'status' => 'scheduled',
                'tracking_number' => $request->tracking_number,
            ],
        ]);
    }

    public function markHandedOver(Request $request, $id)
    {
        $sellerId = $request->user()->id;
        
        $order = Order::whereHas('items.product', function ($q) use ($sellerId) {
            $q->where('seller_id', $sellerId);
        })->findOrFail($id);

        // Update order status to Shipped if not already
        if ($order->status !== 'Shipped') {
            $order->update(['status' => 'Shipped']);
        }

        return response()->json([
            'message' => 'Order marked as handed over to courier',
            'order' => $order->load(['user', 'items.product']),
            'delivery' => [
                'handed_over_at' => now()->toISOString(),
                'status' => 'in_transit',
            ],
        ]);
    }

    public function getSalesReport(Request $request)
    {
        $sellerId = $request->user()->id;
        
        // Get date range
        $fromDate = $request->get('from', now()->subDays(30)->startOfDay());
        $toDate = $request->get('to', now()->endOfDay());
        
        if (is_string($fromDate)) {
            $fromDate = \Carbon\Carbon::parse($fromDate)->startOfDay();
        }
        if (is_string($toDate)) {
            $toDate = \Carbon\Carbon::parse($toDate)->endOfDay();
        }

        // Get orders in date range for this seller
        $orders = Order::whereHas('items.product', function ($q) use ($sellerId) {
            $q->where('seller_id', $sellerId);
        })->whereBetween('created_at', [$fromDate, $toDate])
          ->with(['items' => function ($q) use ($sellerId) {
              $q->whereHas('product', function ($subQ) use ($sellerId) {
                  $subQ->where('seller_id', $sellerId);
              })->with('product');
          }])->get();

        // Calculate metrics
        $totalOrders = $orders->count();
        $totalRevenue = 0;
        $totalCommission = 0;
        $totalEarnings = 0;
        $productPerformance = [];

        foreach ($orders as $order) {
            foreach ($order->items as $item) {
                $itemTotal = $item->price * $item->quantity;
                $commission = $itemTotal * 0.15; // 15% commission
                $earning = $itemTotal - $commission;
                
                $totalRevenue += $itemTotal;
                $totalCommission += $commission;
                $totalEarnings += $earning;

                // Track product performance
                $productId = $item->product->id;
                if (!isset($productPerformance[$productId])) {
                    $productPerformance[$productId] = [
                        'book_id' => $productId,
                        'title' => $item->product->title,
                        'quantity' => 0,
                        'revenue' => 0,
                        'earnings' => 0,
                        'commission' => 0,
                        'product' => $item->product,
                    ];
                }

                $productPerformance[$productId]['quantity'] += $item->quantity;
                $productPerformance[$productId]['revenue'] += $itemTotal;
                $productPerformance[$productId]['earnings'] += $earning;
                $productPerformance[$productId]['commission'] += $commission;
            }
        }

        // Sort product performance by revenue
        $productPerformance = collect($productPerformance)->sortByDesc('revenue')->values();

        // Calculate additional metrics
        $averageOrderValue = $totalOrders > 0 ? $totalRevenue / $totalOrders : 0;
        $profitMargin = $totalRevenue > 0 ? ($totalEarnings / $totalRevenue) * 100 : 0;
        $commissionRate = 15; // 15% commission rate

        // Generate sales trend (daily)
        $salesTrend = [];
        $days = $fromDate->diffInDays($toDate) + 1;
        
        for ($i = 0; $i < $days; $i++) {
            $date = $fromDate->copy()->addDays($i);
            $dayOrders = $orders->filter(function ($order) use ($date) {
                return $order->created_at->isSameDay($date);
            });
            
            $dayEarnings = 0;
            foreach ($dayOrders as $order) {
                foreach ($order->items as $item) {
                    $itemTotal = $item->price * $item->quantity;
                    $commission = $itemTotal * 0.15;
                    $dayEarnings += $itemTotal - $commission;
                }
            }
            
            $salesTrend[] = [
                'date' => $date->format('M j'),
                'earnings' => $dayEarnings,
                'orders' => $dayOrders->count(),
            ];
        }

        return response()->json([
            'success' => true,
            'report' => [
                'total_orders' => $totalOrders,
                'total_revenue' => $totalRevenue,
                'total_commission' => $totalCommission,
                'total_earnings' => $totalEarnings,
                'average_order_value' => $averageOrderValue,
                'profit_margin' => $profitMargin,
                'commission_rate' => $commissionRate,
                'product_performance' => $productPerformance,
                'sales_trend' => $salesTrend,
                'from_date' => $fromDate->toDateString(),
                'to_date' => $toDate->toDateString(),
                'formatted_total_revenue' => '₱' . number_format($totalRevenue, 2),
                'formatted_total_earnings' => '₱' . number_format($totalEarnings, 2),
                'formatted_total_commission' => '₱' . number_format($totalCommission, 2),
                'formatted_average_order_value' => '₱' . number_format($averageOrderValue, 2),
            ],
        ]);
    }

    public function getProductPerformance(Request $request)
    {
        $sellerId = $request->user()->id;
        
        // Get date range
        $fromDate = $request->get('from', now()->subDays(30)->startOfDay());
        $toDate = $request->get('to', now()->endOfDay());
        
        if (is_string($fromDate)) {
            $fromDate = \Carbon\Carbon::parse($fromDate)->startOfDay();
        }
        if (is_string($toDate)) {
            $toDate = \Carbon\Carbon::parse($toDate)->endOfDay();
        }

        // Get product performance data
        $products = Product::where('seller_id', $sellerId)
            ->whereHas('orderItems', function ($q) use ($fromDate, $toDate) {
                $q->whereHas('order', function ($orderQ) use ($fromDate, $toDate) {
                    $orderQ->whereBetween('created_at', [$fromDate, $toDate]);
                });
            })
            ->withSum(['orderItems as total_quantity' => function ($q) use ($fromDate, $toDate) {
                $q->whereHas('order', function ($orderQ) use ($fromDate, $toDate) {
                    $orderQ->whereBetween('created_at', [$fromDate, $toDate]);
                });
            }], 'quantity')
            ->with(['orderItems' => function ($q) use ($fromDate, $toDate) {
                $q->whereHas('order', function ($orderQ) use ($fromDate, $toDate) {
                    $orderQ->whereBetween('created_at', [$fromDate, $toDate]);
                });
            }])
            ->get();

        $productPerformance = $products->map(function ($product) {
            $totalRevenue = 0;
            $totalQuantity = 0;
            
            foreach ($product->orderItems as $item) {
                $itemTotal = $item->price * $item->quantity;
                $totalRevenue += $itemTotal;
                $totalQuantity += $item->quantity;
            }
            
            $commission = $totalRevenue * 0.15;
            $earnings = $totalRevenue - $commission;
            $averagePrice = $totalQuantity > 0 ? $totalRevenue / $totalQuantity : 0;
            $profitMargin = $totalRevenue > 0 ? ($earnings / $totalRevenue) * 100 : 0;
            
            return [
                'book_id' => $product->id,
                'title' => $product->title,
                'quantity' => $totalQuantity,
                'revenue' => $totalRevenue,
                'earnings' => $earnings,
                'commission' => $commission,
                'average_price' => $averagePrice,
                'profit_margin' => $profitMargin,
                'formatted_revenue' => '₱' . number_format($totalRevenue, 2),
                'formatted_earnings' => '₱' . number_format($earnings, 2),
                'formatted_average_price' => '₱' . number_format($averagePrice, 2),
                'product' => $product,
            ];
        })->sortByDesc('revenue')->values();

        return response()->json([
            'success' => true,
            'products' => $productPerformance,
            'from_date' => $fromDate->toDateString(),
            'to_date' => $toDate->toDateString(),
        ]);
    }

    private function validateProductData(Request $request, $productId = null)
    {
        $isDraft = $request->input('status') === 'draft';
        
        return Validator::make($request->all(), [
            'title' => ($isDraft ? 'nullable' : 'required') . '|string|max:255',
            'category_id' => ($isDraft ? 'nullable' : 'required') . '|exists:categories,id',
            'subcategory' => 'nullable|string|max:255',
            'brand' => 'nullable|string|max:255',
            'author' => 'nullable|string|max:255',
            'isbn' => ['nullable', 'string', 'max:20', Rule::unique('products', 'isbn')->ignore($productId)],
            'publisher' => 'nullable|string|max:255',
            'publication_year' => 'nullable|integer|min:1000|max:' . (date('Y') + 1),
            'edition' => 'nullable|string|max:50',
            'language' => 'nullable|string|max:50',
            'pages' => 'nullable|integer|min:1',
            'format' => 'nullable|string|max:50',
            'description' => 'nullable|string|max:5000',
            'price' => ($isDraft ? 'nullable' : 'required') . '|numeric|min:0',
            'sale_price' => 'nullable|numeric|min:0|lte:price',
            'discount_percent' => 'nullable|numeric|min:0|max:99',
            'voucher_code' => 'nullable|string|max:50',
            'stock' => ($isDraft ? 'nullable' : 'required') . '|integer|min:0',
            'sku' => ['nullable', 'string', 'max:100', Rule::unique('products', 'sku')->ignore($productId)],
            'status' => 'nullable|in:active,draft,inactive',
            'weight_kg' => 'nullable|numeric|min:0',
            'length_cm' => 'nullable|numeric|min:0',
            'width_cm' => 'nullable|numeric|min:0',
            'height_cm' => 'nullable|numeric|min:0',
            'cover_image' => 'nullable|image|mimes:jpg,jpeg,png,webp|max:5120',
            'images' => 'nullable|array|max:9',
            'images.*' => 'nullable|image|mimes:jpg,jpeg,png,webp|max:5120',
            'video' => 'nullable|mimetypes:video/mp4,video/quicktime,video/webm|max:20480',
            'variations' => 'nullable|array',
            'variations.*.name' => 'nullable|string|max:255',
            'variations.*.price' => 'nullable|numeric|min:0',
            'variations.*.stock' => 'nullable|integer|min:0',
            'variations.*.sku' => 'nullable|string|max:100',
            'removed_images' => 'nullable|array',
            'removed_images.*' => 'nullable|integer',
            'image_order' => 'nullable|array',
            'image_order.*' => 'nullable|integer',
        ]);
    }

    private function handleImages(Request $request, Product $product)
    {
        if ($request->hasFile('images')) {
            $position = $product->images()->max('sort_order') ?? -1;
            
            foreach ($request->file('images') as $file) {
                if ($file && $file->isValid()) {
                    $position++;
                    $path = $file->store('products/gallery', 'public');
                    
                    ProductImage::create([
                        'product_id' => $product->id,
                        'path' => $path,
                        'label' => $position === 0 ? 'Main' : 'Photo ' . ($position + 1),
                        'sort_order' => $position,
                    ]);
                }
            }

            // Update main image if this is the first image
            if ($product->images()->count() > 0 && !$product->image) {
                $firstImage = $product->images()->orderBy('sort_order')->first();
                $product->update(['image' => $firstImage->path]);
            }
        }
    }

    private function handleVariations(Request $request, Product $product)
    {
        if ($request->has('variations')) {
            $variations = $request->input('variations');
            
            if (is_string($variations)) {
                $variations = json_decode($variations, true);
            }
            
            $sortOrder = 0;
            $totalStock = 0;
            
            foreach ($variations as $variation) {
                if (empty($variation['name'])) continue;
                
                $stock = intval($variation['stock'] ?? 0);
                $totalStock += $stock;
                
                ProductVariation::create([
                    'product_id' => $product->id,
                    'name' => $variation['name'],
                    'price' => !empty($variation['price']) ? floatval($variation['price']) : null,
                    'stock' => $stock,
                    'sku' => $variation['sku'] ?? null,
                    'sort_order' => $sortOrder++,
                ]);
            }

            // Update product stock to sum of variations
            if ($sortOrder > 0) {
                $product->update([
                    'stock' => $totalStock,
                    'availability' => $totalStock > 0 ? 'in_stock' : 'out_of_stock',
                ]);
            }
        }
    }

    private function reorderImages(Request $request, Product $product)
    {
        if ($request->has('image_order')) {
            $order = $request->input('image_order');
            
            if (is_string($order)) {
                $order = json_decode($order, true);
            }
            
            foreach ($order as $position => $imageId) {
                $image = $product->images()->where('id', $imageId)->first();
                if ($image) {
                    $image->update(['sort_order' => $position]);
                }
            }

            // Update main product image to first in order
            $product->load('images');
            $firstImage = $product->images->first();
            if ($firstImage && $product->image !== $firstImage->path) {
                $product->update(['image' => $firstImage->path]);
            }
        }
    }
}
