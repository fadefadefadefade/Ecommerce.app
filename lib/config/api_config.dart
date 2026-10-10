class ApiConfig {
  // Mobile API backend URL
  // Use 10.0.2.2 for Android Emulator (points to host machine's localhost)
  static const String baseUrl = 'http://10.0.2.2:8000/api';
  // For iOS simulator use: http://127.0.0.1:8000/api
  // For physical device use your computer's IP address (e.g., http://192.168.1.100:8000/api)
  
  // Public files (product images) served by the same API server
  static final String storageUrl = baseUrl.replaceFirst(RegExp(r'/api$'), '/storage');

  static const String login = '/login';
  static const String logout = '/logout';
  static const String register = '/register';
  
  // Buyer endpoints
  static const String home = '/home';
  static const String products = '/products';
  static const String categories = '/categories';
  
  // Seller endpoints
  static const String sellerDashboard = '/seller/dashboard';
  static const String sellerProducts = '/seller/products';
  static const String sellerOrders = '/seller/orders';
  
  // Courier endpoints
  static const String courierDashboard = '/courier/dashboard';
  static const String courierDeliveries = '/courier/deliveries';
  
  // Admin endpoints
  static const String adminDashboard = '/admin/dashboard';
  static const String adminUsers = '/admin/users';
  
  // Logistics endpoints (admin)
  static const String logistics = '/logistics';

  // Sorting Center endpoints
  static const String scDashboard = '/sorting-center/dashboard';
}
