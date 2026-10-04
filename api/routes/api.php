<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\HomeController;
use App\Http\Controllers\Api\CartController;
use App\Http\Controllers\Api\CheckoutController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\ProfileController;
use App\Http\Controllers\Api\AddressController;
use App\Http\Controllers\Api\SellerController;
use App\Http\Controllers\Api\CourierController;
use App\Http\Controllers\Api\AdminController;
use App\Http\Controllers\Api\PsgcController;

// Public routes
Route::post('/login', [AuthController::class, 'login']);
Route::post('/register', [AuthController::class, 'register']);

// PSGC (Philippine Address) routes
Route::get('/psgc/regions', [PsgcController::class, 'regions']);
Route::get('/psgc/regions/{code}/provinces', [PsgcController::class, 'provincesByRegion']);
Route::get('/psgc/provinces/{code}/municipalities', [PsgcController::class, 'municipalities']);
Route::get('/psgc/municipalities/{code}/barangays', [PsgcController::class, 'barangays']);

// Protected routes
Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/user', [AuthController::class, 'user']);
    
    // Buyer/Customer routes
    Route::get('/home', [HomeController::class, 'index']);
    Route::get('/products', [HomeController::class, 'products']);
    Route::get('/products/{id}', [HomeController::class, 'productDetail']);
    Route::get('/categories', [HomeController::class, 'categories']);
    
    // Cart routes
    Route::get('/cart', [CartController::class, 'index']);
    Route::post('/cart', [CartController::class, 'store']);
    Route::patch('/cart/{id}', [CartController::class, 'update']);
    Route::delete('/cart/{id}', [CartController::class, 'destroy']);
    
    // Checkout routes
    Route::get('/checkout', [CheckoutController::class, 'index']);
    Route::post('/checkout', [CheckoutController::class, 'store']);
    
    // Order routes
    Route::get('/orders', [OrderController::class, 'index']);
    Route::get('/orders/{id}', [OrderController::class, 'show']);
    
    // Profile routes
    Route::get('/profile', [ProfileController::class, 'show']);
    Route::post('/profile', [ProfileController::class, 'update']);
    
    // Address routes
    Route::get('/addresses', [AddressController::class, 'index']);
    Route::post('/addresses', [AddressController::class, 'store']);
    Route::put('/addresses/{id}', [AddressController::class, 'update']);
    Route::delete('/addresses/{id}', [AddressController::class, 'destroy']);
    Route::patch('/addresses/{id}/set-default', [AddressController::class, 'setDefault']);
    
    // Seller routes
    Route::prefix('seller')->group(function () {
        Route::get('/dashboard', [SellerController::class, 'dashboard']);
        
        // Product management routes
        Route::get('/products/counts', [SellerController::class, 'getProductCounts']);
        Route::get('/products', [SellerController::class, 'products']);
        Route::get('/products/{id}', [SellerController::class, 'getProduct']);
        Route::post('/products', [SellerController::class, 'createProduct']);
        Route::put('/products/{id}', [SellerController::class, 'updateProduct']);
        Route::delete('/products/{id}', [SellerController::class, 'deleteProduct']);
        Route::patch('/products/{id}/archive', [SellerController::class, 'archiveProduct']);
        Route::patch('/products/{id}/unarchive', [SellerController::class, 'unarchiveProduct']);
        Route::patch('/products/{id}/stock', [SellerController::class, 'updateStock']);
        Route::patch('/products/{id}/status', [SellerController::class, 'updateStatus']);
        
        Route::get('/orders', [SellerController::class, 'orders']);
        Route::get('/orders/counts', [SellerController::class, 'getOrderCounts']);
        Route::get('/orders/{id}', [SellerController::class, 'getOrderDetails']);
        Route::patch('/orders/{id}', [SellerController::class, 'updateOrderStatus']);
        Route::post('/orders/{id}/handover', [SellerController::class, 'schedulePickup']);
        Route::post('/orders/{id}/handed-over', [SellerController::class, 'markHandedOver']);
        
        // Reports and Analytics routes
        Route::get('/reports', [SellerController::class, 'getSalesReport']);
        Route::get('/reports/product-performance', [SellerController::class, 'getProductPerformance']);
    });
    
    // Courier routes
    Route::prefix('courier')->group(function () {
        Route::get('/dashboard', [CourierController::class, 'dashboard']);
        Route::get('/deliveries', [CourierController::class, 'deliveries']);
        Route::post('/deliveries/{id}/accept', [CourierController::class, 'acceptDelivery']);
        Route::post('/deliveries/{id}/pickup', [CourierController::class, 'markAsPickedUp']);
        Route::post('/deliveries/{id}/deliver', [CourierController::class, 'markAsDelivered']);
    });
    
    // Admin routes
    Route::prefix('admin')->group(function () {
        Route::get('/dashboard', [AdminController::class, 'dashboard']);
        Route::get('/users', [AdminController::class, 'users']);
        Route::get('/orders', [AdminController::class, 'orders']);
    });
});
