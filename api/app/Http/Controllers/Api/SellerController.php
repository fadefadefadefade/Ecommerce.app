<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Category;
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

        // Line items of this seller's products, excluding cancelled orders
        $sales = OrderItem::query()
            ->join('orders', 'orders.id', '=', 'order_items.order_id')
            ->join('products', 'products.id', '=', 'order_items.product_id')
            ->where('products.seller_id', $sellerId)
            ->where('orders.status', '!=', 'Cancelled');

        $totals = (clone $sales)->selectRaw('
                COUNT(DISTINCT order_items.order_id) as orders,
                COALESCE(SUM(order_items.price * order_items.quantity), 0) as gross,
                COALESCE(SUM(order_items.commission_amount), 0) as commission,
                COALESCE(SUM(order_items.seller_earning), 0) as earnings
            ')->first();

        // Latest orders containing this seller's products; total = this seller's share
        $recentOrders = (clone $sales)
            ->groupBy('orders.id', 'orders.full_name', 'orders.status', 'orders.created_at')
            ->orderByDesc('orders.created_at')
            ->limit(5)
            ->get([
                'orders.id',
                'orders.full_name',
                'orders.status',
                'orders.created_at',
                DB::raw('SUM(order_items.price * order_items.quantity) as seller_total'),
                DB::raw('MIN(products.image) as image'),
            ])
            ->map(fn ($o) => [
                'id' => $o->id,
                'image' => $o->image,
                'customer' => $o->full_name ?: 'Customer',
                'total' => (float) $o->seller_total,
                'status' => $o->status,
                'date' => \Illuminate\Support\Carbon::parse($o->created_at)->toDateString(),
            ]);

        return response()->json([
            'totalProducts' => Product::where('seller_id', $sellerId)->where('is_archived', false)->count(),
            'totalOrders' => (int) $totals->orders,
            'grossRevenue' => (float) $totals->gross,
            'totalCommission' => (float) $totals->commission,
            'totalEarnings' => (float) $totals->earnings,
            'commissionRate' => (float) config('marketplace.commission_rate', 10),
            'products' => $products,
            'recentOrders' => $recentOrders,
        ]);
    }

    public function products(Request $request)
    {
        $sellerId = $request->user()->id;
        
        $query = Product::where('seller_id', $sellerId)
            ->with(['category']);

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
            ->with(['category', 'variations'])
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

            // Products have a single image; use the first gallery upload if no cover was sent
            $this->useFirstUploadAsImage($request, $product);

            // Handle variations
            if ($request->has('variations')) {
                $this->handleVariations($request, $product);
            }

            DB::commit();

            $product->load(['category', 'variations']);

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

            // Products have a single image; use the first gallery upload if no cover was sent
            $this->useFirstUploadAsImage($request, $product);

            // Handle variations
            if ($request->has('variations')) {
                $product->variations()->delete();
                $this->handleVariations($request, $product);
            }

            DB::commit();

            $product->load(['category', 'variations']);

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
            'inactive' => (clone $allProducts)->where('is_archived', false)->where('status', 'inactive')->count(),
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
                // Order "number" is the zero-padded id (e.g. 000081)
                $q->where('id', ltrim($search, '#0') === '' ? 0 : (int) ltrim($search, '#0'))
                  ->orWhere('full_name', 'like', "%{$search}%")
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
                $commission = $this->itemCommission($item);
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

        // Progress step (Pending … Delivered) for each order card
        $orders->getCollection()->each(fn (Order $order) => $order->withTrackingStage());

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
            // Use what checkout stored; fall back to the platform rate for old rows.
            $commission = (float) ($item->commission_amount
                ?: $itemTotal * ((float) config('marketplace.commission_rate', 10) / 100));
            $earning = (float) ($item->seller_earning ?: $itemTotal - $commission);

            $sellerEarning += $earning;
            $commissionAmount += $commission;

            $item->seller_earning = $earning;
            $item->commission_amount = $commission;
        }

        $order->seller_earning = $sellerEarning;
        $order->commission_amount = $commissionAmount;
        $order->withTrackingStage();

        $parcel = \App\Models\Parcel::where('order_id', $order->id)->latest('id')->first();

        return response()->json([
            'order' => $order,
            'parcel' => $parcel ? [
                'tracking_number' => $parcel->tracking_number,
                'status' => $parcel->status,
                'status_label' => $parcel->status_label,
                'updated_at' => $parcel->updated_at,
            ] : null,
        ]);
    }

    public function updateOrderStatus(Request $request, $id)
    {
        $sellerId = $request->user()->id;
        
        // Sellers move an order Pending → Processing → Shipped (to warehouse), or
        // cancel it before shipping. Delivering/Delivered belong to the courier.
        $validator = Validator::make($request->all(), [
            'status' => 'required|in:Processing,Shipped,Cancelled',
            'cancellation_reason' => 'required_if:status,Cancelled|nullable|string|max:500',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => $validator->errors()->first(),
                'errors' => $validator->errors(),
            ], 422);
        }

        return DB::transaction(function () use ($request, $sellerId, $id) {
            $order = Order::whereHas('items.product', function ($q) use ($sellerId) {
                $q->where('seller_id', $sellerId);
            })->lockForUpdate()->findOrFail($id);

            $allowedFrom = [
                'Processing' => ['Pending'],
                'Shipped' => ['Processing'],
                'Cancelled' => Order::CANCELLABLE,
            ][$request->status];

            if (! in_array($order->status, $allowedFrom, true)) {
                $current = Order::stageLabel($order->trackingStage());
                return response()->json([
                    'message' => "Can't change a {$current} order to " . ($request->status === 'Shipped' ? 'Shipped to Warehouse' : $request->status) . '.',
                ], 422);
            }

            $parcel = null;
            if ($request->status === 'Shipped') {
                $parcel = $order->shipToWarehouse($request->user());
            } elseif ($request->status === 'Cancelled') {
                $order->cancelWithRestock('Cancelled by seller: ' . $request->cancellation_reason);
            } else {
                $order->update(['status' => $request->status]);
            }

            $label = Order::stageLabel($order->fresh()->trackingStage());

            return response()->json([
                'message' => $parcel
                    ? "Shipped to warehouse. Parcel {$parcel->tracking_number} is waiting for a rider."
                    : "Order is now {$label}.",
                'order' => $order->fresh()->load(['user', 'items.product'])->withTrackingStage(),
            ]);
        });
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

        if (! in_array($order->status, ['Processing', 'Shipped'], true)) {
            return response()->json(['message' => 'Only Processing orders can be shipped to the warehouse.'], 422);
        }
        $parcel = DB::transaction(fn () => $order->shipToWarehouse($request->user()));

        return response()->json([
            'message' => 'Pickup scheduled successfully',
            'order' => $order->load(['user', 'items.product'])->withTrackingStage(),
            'delivery' => [
                'courier_name' => $request->courier_name,
                'tracking_number' => $request->tracking_number,
                'pickup_scheduled_at' => $request->pickup_scheduled_at,
                'notes' => $request->notes,
            ],
            'parcel' => [
                'status' => $parcel->status,
                'status_label' => $parcel->status_label,
                'tracking_number' => $parcel->tracking_number,
            ],
        ]);
    }

    public function markHandedOver(Request $request, $id)
    {
        $sellerId = $request->user()->id;
        
        $order = Order::whereHas('items.product', function ($q) use ($sellerId) {
            $q->where('seller_id', $sellerId);
        })->findOrFail($id);

        if (! in_array($order->status, ['Processing', 'Shipped'], true)) {
            return response()->json(['message' => 'Only Processing orders can be shipped to the warehouse.'], 422);
        }
        DB::transaction(fn () => $order->shipToWarehouse($request->user()));

        return response()->json([
            'message' => 'Order marked as handed over to courier',
            'order' => $order->load(['user', 'items.product'])->withTrackingStage(),
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
                $commission = $this->itemCommission($item);
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
        $commissionRate = $this->commissionRate();

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
                    $commission = $this->itemCommission($item);
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
            
            $commission = $totalRevenue * ($this->commissionRate() / 100);
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

    /**
     * The book_images gallery table was dropped (same as the web app), so a product
     * keeps one image. When only gallery photos are uploaded, the first becomes it.
     */
    private function useFirstUploadAsImage(Request $request, Product $product)
    {
        if ($request->hasFile('cover_image') || ! $request->hasFile('images')) {
            return;
        }

        $first = collect($request->file('images'))->first(fn ($file) => $file && $file->isValid());
        if (! $first) {
            return;
        }

        if ($product->image) {
            Storage::disk('public')->delete($product->image);
        }
        $product->update(['image' => $first->store('products', 'public')]);
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

    /** Platform commission (%), same setting as the web app. */
    private function commissionRate(): float
    {
        return (float) config('marketplace.commission_rate', 10);
    }

    /** Commission on one order item: what checkout stored, else the current rate. */
    private function itemCommission($item): float
    {
        if ((float) $item->commission_amount > 0) {
            return (float) $item->commission_amount;
        }
        return $item->price * $item->quantity * ($this->commissionRate() / 100);
    }
}
