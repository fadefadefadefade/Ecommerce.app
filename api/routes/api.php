<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\HomeController;
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
    
    // Seller routes
    Route::prefix('seller')->group(function () {
        Route::get('/dashboard', [SellerController::class, 'dashboard']);
        Route::get('/books', [SellerController::class, 'books']);
        Route::get('/orders', [SellerController::class, 'orders']);
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
