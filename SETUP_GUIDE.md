# ALVY Mobile App - Complete Setup Guide

## 📁 Project Structure

```
Ecommerce.app/
├── lib/              # Flutter mobile app
├── api/              # Laravel API backend (SHARES DATABASE with Ecommerce.web)
└── SETUP_GUIDE.md    # This file
```

## ✅ Database Configuration

**The mobile API now uses the SAME MySQL database as your web application!**

- Database: `ecommerce_db`
- All users from your web app can login to the mobile app
- No need to create duplicate test accounts
- Data is synchronized between web and mobile

## 🚀 Quick Start

### Step 1: Start the Laravel API

```bash
cd api
php artisan serve --port=8001
```

The API will run at: `http://127.0.0.1:8001`

### Step 2: Run the Flutter App

```bash
# Open a new terminal
flutter run
```

### Step 3: Login with Your Existing Users

Use any existing user from your web application database!

**Examples:**
- Any admin account with `role = 'admin'`
- Any buyer account with `role = 'buyer'`  
- Any seller account with `role = 'seller'`
- Any courier account with `role = 'courier'`

---

## 📱 Flutter App Setup

### Prerequisites
- Flutter SDK installed
- Android Studio / Xcode (for mobile development)
- VS Code with Flutter extension (recommended)

### Installation

1. **Install Dependencies**
   ```bash
   cd "d:\Ecommerece Web and App\Ecommerce.app"
   flutter pub get
   ```

2. **Check Flutter Setup**
   ```bash
   flutter doctor
   ```

3. **Run the App**
   ```bash
   # Android
   flutter run

   # iOS (Mac only)
   flutter run

   # Web
   flutter run -d chrome
   ```

### API Configuration

The API URL is configured in `lib/config/api_config.dart`:

- **For Web/iOS Simulator**: `http://127.0.0.1:8001/api`
- **For Android Emulator**: `http://10.0.2.2:8001/api`
- **For Physical Device**: Use your computer's local IP (e.g., `http://192.168.1.100:8001/api`)

---

## 🔧 Laravel API Setup

### Prerequisites
- PHP 8.2 or higher
- Composer
- SQLite (default) or MySQL/PostgreSQL

### Installation

1. **Navigate to API Directory**
   ```bash
   cd api
   ```

2. **Configure Environment**
   ```bash
   # Already done during creation
   cp .env.example .env
   php artisan key:generate
   ```

3. **Configure Database** (`.env` file)
   ```env
   DB_CONNECTION=sqlite
   # SQLite database is already created
   ```

4. **Run Migrations**
   ```bash
   php artisan migrate
   ```

5. **Create Test Users**
   ```bash
   php artisan tinker
   ```
   
   In tinker console:
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

6. **Start the API Server**
   ```bash
   php artisan serve --port=8001
   ```

---

## 📋 Available Features

### ✅ Completed
- [x] Login Screen
- [x] Multi-role Authentication (Buyer, Seller, Courier, Admin, Sorting Center)
- [x] Buyer Home Screen with categories and products
- [x] Secure token storage
- [x] Role-based routing
- [x] API authentication with Laravel Sanctum

### 🚧 Next Steps (To Be Implemented)
- [ ] Seller Dashboard (full implementation)
- [ ] Courier Dashboard (full implementation)  
- [ ] Admin Dashboard (full implementation)
- [ ] Product Detail Page
- [ ] Shopping Cart
- [ ] Checkout Flow
- [ ] Order History
- [ ] User Profile Management
- [ ] Push Notifications

---

## 🧪 Testing

### Test API Endpoints with cURL

**Login:**
```bash
curl -X POST http://127.0.0.1:8001/api/login \
  -H "Content-Type: application/json" \
  -d '{"email":"buyer@test.com","password":"password"}'
```

**Get Home Data (requires authentication):**
```bash
curl -X GET http://127.0.0.1:8001/api/home \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

---

## 🔥 Troubleshooting

### Flutter App Can't Connect to API

1. **Check API is running:**
   ```bash
   curl http://127.0.0.1:8001/api
   ```

2. **For Android Emulator**, use `10.0.2.2` instead of `127.0.0.1`
   
   Update `lib/config/api_config.dart`:
   ```dart
   static const String baseUrl = 'http://10.0.2.2:8001/api';
   ```

3. **For Physical Device**, find your computer's IP:
   ```bash
   # Windows
   ipconfig
   
   # Mac/Linux
   ifconfig
   ```
   
   Then update the API URL with your IP address.

### CORS Issues

If you see CORS errors, check `api/config/cors.php`:
```php
'allowed_origins' => ['*'],
```

### Database Issues

Reset database:
```bash
cd api
php artisan migrate:fresh
```

Then recreate test users.

---

## 📚 Documentation

### API Documentation
See `api/README.md` for all available endpoints and request/response formats.

### Flutter Documentation
See main `README.md` for Flutter app architecture and structure.

---

## 🎯 Development Workflow

1. **Start API Backend:**
   ```bash
   cd api
   php artisan serve --port=8001
   ```

2. **Start Flutter App:**
   ```bash
   flutter run
   ```

3. **Hot Reload:**
   - Press `r` in the Flutter terminal to hot reload
   - Press `R` for hot restart
   - Press `q` to quit

4. **View Logs:**
   - Flutter logs appear in the terminal
   - Laravel logs in `api/storage/logs/laravel.log`

---

## 🔐 Security Notes

- Never commit `.env` files
- Use environment variables for sensitive data
- Implement proper API rate limiting for production
- Use HTTPS in production
- Implement proper input validation
- Use SQL injection protection (Laravel handles this)

---

## 📝 Next Development Steps

1. **Connect to Main Database**
   - Currently using SQLite with mock data
   - Connect to your main `Ecommerce.web` database
   - Share the same User model and database

2. **Implement Full Dashboards**
   - Seller: Product management, orders, analytics
   - Courier: Delivery tracking, route optimization
   - Admin: User management, system settings

3. **Add Product Features**
   - Product search and filters
   - Product details page
   - Reviews and ratings
   - Wishlist

4. **Add Cart & Checkout**
   - Shopping cart management
   - Multiple payment methods
   - Address management
   - Order tracking

5. **Push Notifications**
   - Order status updates
   - Delivery notifications
   - Admin announcements

---

## 💡 Tips

- Use `flutter clean` if you encounter build issues
- Run `composer dump-autoload` if Laravel classes aren't found
- Check `php artisan route:list` to see all API routes
- Use Laravel Tinker for quick database testing
- Enable debug mode during development

---

## 🆘 Support

For issues or questions:
1. Check the troubleshooting section above
2. Review the API and Flutter documentation
3. Check Laravel logs: `api/storage/logs/laravel.log`
4. Check Flutter console for error messages

---

**Happy Coding! 🎉**
