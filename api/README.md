# ALVY Mobile API

Laravel API backend for the ALVY mobile application.

## Setup

1. Install dependencies:
```bash
composer install
```

2. Configure environment:
```bash
cp .env.example .env
php artisan key:generate
```

3. Configure database in `.env`:
```env
DB_CONNECTION=sqlite
```

4. Run migrations:
```bash
php artisan migrate
```

5. Start the server:
```bash
php artisan serve --port=8001
```

The API will be available at: `http://127.0.0.1:8001`

## API Endpoints

### Authentication
- `POST /api/login` - User login
- `POST /api/register` - User registration
- `POST /api/logout` - User logout (requires authentication)
- `GET /api/user` - Get authenticated user

### Home (Buyer)
- `GET /api/home` - Get home data (categories, featured, best sellers)
- `GET /api/products` - Get all products
- `GET /api/products/{id}` - Get product details
- `GET /api/categories` - Get all categories

### Seller
- `GET /api/seller/dashboard` - Seller dashboard data
- `GET /api/seller/books` - Get seller's books
- `GET /api/seller/orders` - Get seller's orders

### Courier
- `GET /api/courier/dashboard` - Courier dashboard data
- `GET /api/courier/deliveries` - Get deliveries
- `POST /api/courier/deliveries/{id}/accept` - Accept delivery
- `POST /api/courier/deliveries/{id}/pickup` - Mark as picked up
- `POST /api/courier/deliveries/{id}/deliver` - Mark as delivered

### Admin
- `GET /api/admin/dashboard` - Admin dashboard data
- `GET /api/admin/users` - Get all users
- `GET /api/admin/orders` - Get all orders

## Update Flutter App Configuration

In your Flutter app, update `lib/config/api_config.dart`:

```dart
static const String baseUrl = 'http://127.0.0.1:8001/api';
```

For Android emulator, use: `http://10.0.2.2:8001/api`
For iOS simulator, use: `http://127.0.0.1:8001/api`
For physical device, use your computer's IP address

## Testing the API

Create a test user:
```bash
php artisan tinker
```

```php
User::create([
    'name' => 'Buyer User',
    'email' => 'buyer@test.com',
    'password' => bcrypt('password'),
    'role' => 'buyer',
    'approval_status' => 'approved'
]);

User::create([
    'name' => 'Seller User',
    'email' => 'seller@test.com',
    'password' => bcrypt('password'),
    'role' => 'seller',
    'approval_status' => 'approved'
]);

User::create([
    'name' => 'Admin User',
    'email' => 'admin@test.com',
    'password' => bcrypt('password'),
    'role' => 'admin',
    'approval_status' => 'approved'
]);
```

## Notes

- Currently using mock data in controllers
- You can connect this to your main Laravel web database later
- All routes except login/register require authentication via Bearer token
