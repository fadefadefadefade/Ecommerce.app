import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/report_service.dart';

class DateRangePickerWidget extends StatefulWidget {
  final DateTime initialFromDate;
  final DateTime initialToDate;
  final Function(DateTime from, DateTime to) onDateRangeChanged;
  
  const DateRangePickerWidget({
    super.key,
    required this.initialFromDate,
    required this.initialToDate,
    required this.onDateRangeChanged,
  });

  @override
  State<DateRangePickerWidget> createState() => _DateRangePickerWidgetState();
}

class _DateRangePickerWidgetState extends State<DateRangePickerWidget> {
  late DateTime _fromDate;
  late DateTime _toDate;
  DateRangePreset? _selectedPreset;

  @override
  void initState() {
    super.initState();
    _fromDate = widget.initialFromDate;
    _toDate = widget.initialToDate;
    _checkForMatchingPreset();
  }

  void _checkForMatchingPreset() {
    final presets = ReportService.getDateRangePresets();
    for (final preset in presets) {
      if (_isSameDay(preset.from, _fromDate) && _isSameDay(preset.to, _toDate)) {
        _selectedPreset = preset;
        break;
      }
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _selectPreset(DateRangePreset preset) {
    setState(() {
      _selectedPreset = preset;
      _fromDate = preset.from;
      _toDate = preset.to;
    });
    widget.onDateRangeChanged(_fromDate, _toDate);
  }

  Future<void> _selectCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFFfa4e1c),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
        _selectedPreset = null; // Clear preset selection for custom range
      });
      widget.onDateRangeChanged(_fromDate, _toDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
              const Text(
                'Date Range',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222222),
                ),
              ),
              TextButton.icon(
                onPressed: _selectCustomDateRange,
                icon: const Icon(Icons.calendar_month, size: 16),
                label: const Text('Custom'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFfa4e1c),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Current selection display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFBEEE8).withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFfa4e1c).withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.date_range,
                  size: 16,
                  color: const Color(0xFFfa4e1c),
                ),
                const SizedBox(width: 8),
                Text(
                  _selectedPreset?.label ?? 'Custom Range',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFfa4e1c),
                  ),
                ),
                const Spacer(),
                Text(
                  '${DateFormat('MMM d').format(_fromDate)} - ${DateFormat('MMM d, y').format(_toDate)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8a7a70),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Preset options
          const Text(
            'Quick Select',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ReportService.getDateRangePresets().map((preset) {
              final isSelected = _selectedPreset?.label == preset.label;
              return GestureDetector(
                onTap: () => _selectPreset(preset),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? const Color(0xFFfa4e1c) 
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected 
                          ? const Color(0xFFfa4e1c) 
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    preset.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF8a7a70),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class ComparisonDateRangeWidget extends StatefulWidget {
  final DateTime initialFromDate;
  final DateTime initialToDate;
  final Function(DateTime from, DateTime to, DateTime? compareFrom, DateTime? compareTo) onDateRangeChanged;
  
  const ComparisonDateRangeWidget({
    super.key,
    required this.initialFromDate,
    required this.initialToDate,
    required this.onDateRangeChanged,
  });

  @override
  State<ComparisonDateRangeWidget> createState() => _ComparisonDateRangeWidgetState();
}

class _ComparisonDateRangeWidgetState extends State<ComparisonDateRangeWidget> {
  late DateTime _fromDate;
  late DateTime _toDate;
  DateTime? _compareFromDate;
  DateTime? _compareToDate;
  bool _enableComparison = false;

  @override
  void initState() {
    super.initState();
    _fromDate = widget.initialFromDate;
    _toDate = widget.initialToDate;
  }

  void _updateDates() {
    widget.onDateRangeChanged(
      _fromDate,
      _toDate,
      _enableComparison ? _compareFromDate : null,
      _enableComparison ? _compareToDate : null,
    );
  }

  void _selectPreviousPeriod() {
    final daysDifference = _toDate.difference(_fromDate).inDays;
    setState(() {
      _compareFromDate = _fromDate.subtract(Duration(days: daysDifference + 1));
      _compareToDate = _fromDate.subtract(const Duration(days: 1));
      _enableComparison = true;
    });
    _updateDates();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
          const Text(
            'Compare Periods',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 12),
          
          // Enable comparison toggle
          Row(
            children: [
              Switch(
                value: _enableComparison,
                onChanged: (value) {
                  setState(() {
                    _enableComparison = value;
                    if (value && _compareFromDate == null) {
                      _selectPreviousPeriod();
                    }
                  });
                  _updateDates();
                },
                activeColor: const Color(0xFFfa4e1c),
              ),
              const SizedBox(width: 8),
              const Text(
                'Compare with previous period',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF222222),
                ),
              ),
            ],
          ),
          
          if (_enableComparison) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Color(0xFFfa4e1c),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Current: ${DateFormat('MMM d').format(_fromDate)} - ${DateFormat('MMM d, y').format(_toDate)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF222222),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_compareFromDate != null && _compareToDate != null)
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade400,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Previous: ${DateFormat('MMM d').format(_compareFromDate!)} - ${DateFormat('MMM d, y').format(_compareToDate!)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _selectPreviousPeriod,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFfa4e1c),
                      side: const BorderSide(color: Color(0xFFfa4e1c)),
                    ),
                    child: const Text('Previous Period'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
                        lastDate: DateTime.now(),
                        initialDateRange: _compareFromDate != null && _compareToDate != null
                            ? DateTimeRange(start: _compareFromDate!, end: _compareToDate!)
                            : null,
                      );
                      
                      if (range != null) {
                        setState(() {
                          _compareFromDate = range.start;
                          _compareToDate = range.end;
                        });
                        _updateDates();
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFfa4e1c),
                      side: const BorderSide(color: Color(0xFFfa4e1c)),
                    ),
                    child: const Text('Custom Range'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}