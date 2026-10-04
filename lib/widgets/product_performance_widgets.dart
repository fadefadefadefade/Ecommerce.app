import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/report_service.dart';

class ProductPerformanceCard extends StatelessWidget {
  final ProductPerformance product;
  final int? rank;
  final VoidCallback? onTap;
  final bool showTrend;

  const ProductPerformanceCard({
    super.key,
    required this.product,
    this.rank,
    this.onTap,
    this.showTrend = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (rank != null) ...[
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _getRankColor(rank!),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          rank.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF222222),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (product.product?.brand != null)
                          Text(
                            product.product!.brand!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8a7a70),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: const Color(0xFF8a7a70),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Performance Metrics
              Row(
                children: [
                  Expanded(
                    child: _buildMetric(
                      'Units Sold',
                      product.quantity.toString(),
                      Icons.shopping_cart_outlined,
                      const Color(0xFF3B82F6),
                    ),
                  ),
                  Expanded(
                    child: _buildMetric(
                      'Revenue',
                      product.formattedRevenue,
                      Icons.attach_money,
                      const Color(0xFF10B981),
                    ),
                  ),
                  Expanded(
                    child: _buildMetric(
                      'Earnings',
                      product.formattedEarnings,
                      Icons.account_balance_wallet,
                      const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Additional Metrics
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Avg Price',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8a7a70),
                        ),
                      ),
                      Text(
                        product.formattedAveragePrice,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF222222),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Profit Margin',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8a7a70),
                        ),
                      ),
                      Text(
                        '${product.profitMargin.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _getProfitMarginColor(product.profitMargin),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF8a7a70),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF222222),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Color _getRankColor(int rank) {
    if (rank <= 3) return const Color(0xFFfa4e1c);
    if (rank <= 10) return const Color(0xFF8B5CF6);
    return const Color(0xFF8a7a70);
  }

  Color _getProfitMarginColor(double margin) {
    if (margin >= 50) return const Color(0xFF10B981);
    if (margin >= 30) return const Color(0xFFF59E0B);
    return Colors.red;
  }
}

class ProductComparisonWidget extends StatelessWidget {
  final List<ProductPerformance> products;
  final String comparisonMetric;

  const ProductComparisonWidget({
    super.key,
    required this.products,
    required this.comparisonMetric,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Product Comparison',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222222),
                ),
              ),
              DropdownButton<String>(
                value: comparisonMetric,
                items: const [
                  DropdownMenuItem(value: 'revenue', child: Text('Revenue')),
                  DropdownMenuItem(value: 'earnings', child: Text('Earnings')),
                  DropdownMenuItem(value: 'quantity', child: Text('Units Sold')),
                  DropdownMenuItem(value: 'profitMargin', child: Text('Profit Margin')),
                ],
                onChanged: (value) {
                  // Handle metric change
                },
                underline: const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: _buildComparisonChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonChart() {
    if (products.isEmpty) {
      return const Center(
        child: Text(
          'No products to compare',
          style: TextStyle(color: Color(0xFF8a7a70)),
        ),
      );
    }

    final maxValue = _getMaxValue();
    final topProducts = products.take(5).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: topProducts.map((product) {
        final value = _getMetricValue(product);
        final height = maxValue > 0 ? (value / maxValue) * 160 : 0.0;
        
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              _formatValue(value),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 30,
              height: height > 4 ? height : 4,
              decoration: BoxDecoration(
                color: const Color(0xFFfa4e1c),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 40,
              child: Text(
                product.title.length > 8 ? '${product.title.substring(0, 8)}...' : product.title,
                style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFF8a7a70),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  double _getMaxValue() {
    return products.map((p) => _getMetricValue(p)).reduce((a, b) => a > b ? a : b);
  }

  double _getMetricValue(ProductPerformance product) {
    switch (comparisonMetric) {
      case 'revenue':
        return product.revenue;
      case 'earnings':
        return product.earnings;
      case 'quantity':
        return product.quantity.toDouble();
      case 'profitMargin':
        return product.profitMargin;
      default:
        return product.revenue;
    }
  }

  String _formatValue(double value) {
    if (comparisonMetric == 'profitMargin') {
      return '${value.toStringAsFixed(0)}%';
    } else if (comparisonMetric == 'quantity') {
      return value.toInt().toString();
    } else {
      return '₱${(value / 1000).toStringAsFixed(0)}k';
    }
  }
}

class ProductAnalyticsInsightsWidget extends StatelessWidget {
  final List<ProductPerformance> products;
  final SalesReport? salesReport;

  const ProductAnalyticsInsightsWidget({
    super.key,
    required this.products,
    this.salesReport,
  });

  @override
  Widget build(BuildContext context) {
    final insights = _generateProductInsights();
    
    if (insights.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.insights,
                color: const Color(0xFFfa4e1c),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Product Insights',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222222),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...insights.map((insight) => _buildInsightItem(insight)),
        ],
      ),
    );
  }

  Widget _buildInsightItem(ProductInsight insight) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getInsightColor(insight.type).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getInsightColor(insight.type).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getInsightIcon(insight.type),
            color: _getInsightColor(insight.type),
            size: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _getInsightColor(insight.type),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  insight.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF222222),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<ProductInsight> _generateProductInsights() {
    final insights = <ProductInsight>[];
    
    if (products.isEmpty) return insights;

    // Top performer insight
    final topProduct = products.first;
    if (products.length > 1) {
      insights.add(ProductInsight(
        type: InsightType.success,
        title: 'Top Performer',
        description: '${topProduct.title} is your best-selling product with ${topProduct.formattedRevenue} in revenue.',
      ));
    }

    // Low stock insights
    final lowMarginProducts = products.where((p) => p.profitMargin < 20).toList();
    if (lowMarginProducts.isNotEmpty) {
      insights.add(ProductInsight(
        type: InsightType.warning,
        title: 'Low Profit Margins',
        description: '${lowMarginProducts.length} product${lowMarginProducts.length > 1 ? 's have' : ' has'} profit margins below 20%. Consider price optimization.',
      ));
    }

    // Revenue concentration
    if (salesReport != null && products.isNotEmpty) {
      final topProductShare = (topProduct.revenue / salesReport!.totalRevenue) * 100;
      if (topProductShare > 60) {
        insights.add(ProductInsight(
          type: InsightType.info,
          title: 'Revenue Concentration',
          description: '${topProductShare.toStringAsFixed(0)}% of your revenue comes from one product. Consider diversifying.',
        ));
      }
    }

    // High performing products
    final highMarginProducts = products.where((p) => p.profitMargin > 60).toList();
    if (highMarginProducts.isNotEmpty) {
      insights.add(ProductInsight(
        type: InsightType.success,
        title: 'High-Margin Products',
        description: '${highMarginProducts.length} product${highMarginProducts.length > 1 ? 's have' : ' has'} excellent profit margins above 60%.',
      ));
    }

    // Opportunities for improvement
    final averagePrice = products.map((p) => p.averagePrice).reduce((a, b) => a + b) / products.length;
    final lowPriceProducts = products.where((p) => p.averagePrice < averagePrice * 0.7).toList();
    if (lowPriceProducts.isNotEmpty) {
      insights.add(ProductInsight(
        type: InsightType.opportunity,
        title: 'Pricing Opportunity',
        description: '${lowPriceProducts.length} product${lowPriceProducts.length > 1 ? 's are' : ' is'} priced below average. Consider price testing.',
      ));
    }

    return insights;
  }

  Color _getInsightColor(InsightType type) {
    switch (type) {
      case InsightType.success:
        return const Color(0xFF10B981);
      case InsightType.warning:
        return const Color(0xFFF59E0B);
      case InsightType.error:
        return Colors.red;
      case InsightType.info:
        return const Color(0xFF3B82F6);
      case InsightType.opportunity:
        return const Color(0xFF8B5CF6);
    }
  }

  IconData _getInsightIcon(InsightType type) {
    switch (type) {
      case InsightType.success:
        return Icons.trending_up;
      case InsightType.warning:
        return Icons.warning_amber;
      case InsightType.error:
        return Icons.error;
      case InsightType.info:
        return Icons.info;
      case InsightType.opportunity:
        return Icons.lightbulb;
    }
  }
}

class ProductTrendWidget extends StatelessWidget {
  final List<SalesTrend> trends;
  final String productName;

  const ProductTrendWidget({
    super.key,
    required this.trends,
    required this.productName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$productName Performance Trend',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: _buildTrendChart(),
          ),
          const SizedBox(height: 16),
          _buildTrendSummary(),
        ],
      ),
    );
  }

  Widget _buildTrendChart() {
    if (trends.isEmpty) {
      return const Center(
        child: Text(
          'No trend data available',
          style: TextStyle(color: Color(0xFF8a7a70)),
        ),
      );
    }

    final maxEarnings = trends.map((t) => t.earnings).reduce((a, b) => a > b ? a : b);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: trends.map((trend) {
        final height = maxEarnings > 0 ? (trend.earnings / maxEarnings) * 120 : 0.0;
        
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 16,
              height: height > 4 ? height : 4,
              decoration: BoxDecoration(
                color: const Color(0xFFfa4e1c),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              trend.date.length > 6 ? trend.date.substring(0, 6) : trend.date,
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFF8a7a70),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildTrendSummary() {
    if (trends.length < 2) {
      return const Text(
        'Need more data points to show trend analysis',
        style: TextStyle(
          fontSize: 12,
          color: Color(0xFF8a7a70),
        ),
      );
    }

    final firstHalf = trends.take(trends.length ~/ 2).toList();
    final secondHalf = trends.skip(trends.length ~/ 2).toList();
    
    final firstHalfAvg = firstHalf.map((t) => t.earnings).reduce((a, b) => a + b) / firstHalf.length;
    final secondHalfAvg = secondHalf.map((t) => t.earnings).reduce((a, b) => a + b) / secondHalf.length;
    
    final trendPercentage = firstHalfAvg > 0 ? ((secondHalfAvg - firstHalfAvg) / firstHalfAvg) * 100 : 0.0;
    final isPositive = trendPercentage >= 0;
    
    return Row(
      children: [
        Icon(
          isPositive ? Icons.trending_up : Icons.trending_down,
          color: isPositive ? const Color(0xFF10B981) : Colors.red,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          '${isPositive ? '+' : ''}${trendPercentage.toStringAsFixed(1)}% vs previous period',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isPositive ? const Color(0xFF10B981) : Colors.red,
          ),
        ),
      ],
    );
  }
}

class ProductInsight {
  final InsightType type;
  final String title;
  final String description;

  const ProductInsight({
    required this.type,
    required this.title,
    required this.description,
  });
}

enum InsightType {
  success,
  warning,
  error,
  info,
  opportunity,
}

class QuickProductStatsWidget extends StatelessWidget {
  final List<ProductPerformance> products;

  const QuickProductStatsWidget({
    super.key,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalProducts = products.length;
    final totalRevenue = products.fold(0.0, (sum, p) => sum + p.revenue);
    final averageRevenue = totalRevenue / totalProducts;
    final topPerformer = products.first;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Products',
            totalProducts.toString(),
            Icons.inventory_2,
            const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Avg Revenue',
            ReportService.formatCurrency(averageRevenue),
            Icons.bar_chart,
            const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Top Seller',
            topPerformer.title.length > 10 
                ? '${topPerformer.title.substring(0, 10)}...'
                : topPerformer.title,
            Icons.star,
            const Color(0xFFfa4e1c),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF8a7a70),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF222222),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}