import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import '../../models/prescription/prescription_model.dart';
import '../../services/prescription_service/prescription_service.dart';
import '../../utils/responsive_helper.dart';
import '../color/colors.dart';

// M-5 GETTING THE MEDICINES FROM PRESCRIPTION
class PrescriptionsScreen extends StatefulWidget {
  final bool showBackButton;

  const PrescriptionsScreen({
    super.key,
    this.showBackButton = true,
  });

  @override
  State<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends State<PrescriptionsScreen>
    with TickerProviderStateMixin {
  final PrescriptionService _prescriptionService = PrescriptionService();
  bool _isLoading = true;
  List<SavedPrescription> _prescriptions = [];
  String? _errorMessage;

  TabController? _tabController;
  List<String> _specialties = [];
  final Map<String, List<SavedPrescription>> _prescriptionsBySpecialty = {};

  @override
  void initState() {
    super.initState();
    if (mounted) {
      _loadPrescriptions();
    }
  }

  @override
  void dispose() {
    // _tabController?.dispose();
    super.dispose();
  }

  void _organizePrescriptionsBySpecialty() {
    _prescriptionsBySpecialty.clear();
    _specialties.clear();

    // Add "All" category first
    _prescriptionsBySpecialty['All'] = List.from(_prescriptions);

    // Group prescriptions by doctor specialty
    for (var prescription in _prescriptions) {
      final specialty = _normalizeSpecialty(prescription.doctorSpecialty);
      if (specialty.isNotEmpty && specialty != 'All') {
        if (!_prescriptionsBySpecialty.containsKey(specialty)) {
          _prescriptionsBySpecialty[specialty] = [];
        }
        _prescriptionsBySpecialty[specialty]!.add(prescription);
      }
    }

    // Sort each category by date (most recent first) - already sorted from API
    // but ensure it's correct
    for (var key in _prescriptionsBySpecialty.keys) {
      _prescriptionsBySpecialty[key]!.sort((a, b) {
        final dateA = a.createdAt ?? DateTime(1900);
        final dateB = b.createdAt ?? DateTime(1900);
        return dateB.compareTo(dateA); // Most recent first
      });
    }

    // Create ordered list of specialties (All first, then alphabetical)
    _specialties = ['All'];
    final otherSpecialties = _prescriptionsBySpecialty.keys
        .where((s) => s != 'All')
        .toList()
      ..sort();
    _specialties.addAll(otherSpecialties);

    // Initialize or update TabController
    _tabController?.dispose();
    _tabController = TabController(
      length: _specialties.length,
      vsync: this,
    );
  }

  String _normalizeSpecialty(String? specialty) {
    if (specialty == null || specialty.isEmpty) return 'Other';

    final lower = specialty.toLowerCase().trim();

    // Normalize common variations
    if (lower.contains('ocularist')) return 'Ocularist';
    if (lower.contains('optician')) return 'Optician';
    if (lower.contains('optometrist')) return 'Optometrist';
    if (lower.contains('ophthalmologist')) return 'Ophthalmologist';
    if (lower.contains('eye') && lower.contains('surgeon')) {
      return 'Eye Surgeon';
    }
    if (lower.contains('retina')) return 'Retina Specialist';
    if (lower.contains('glaucoma')) return 'Glaucoma Specialist';
    if (lower.contains('cornea')) return 'Cornea Specialist';
    if (lower.contains('pediatric')) return 'Pediatric Eye Specialist';

    // Return original with proper capitalization
    return specialty.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Future<void> _loadPrescriptions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('Loading prescriptions...');
      final response = await _prescriptionService.getMyPrescriptions();
      debugPrint(
          'Response: success=${response.success}, count=${response.data.length}, message=${response.message}');

      if (response.success) {
        setState(() {
          _prescriptions = response.data;
          _organizePrescriptionsBySpecialty();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.message ?? 'Failed to load prescriptions';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading prescriptions: $e');
      setState(() {
        _errorMessage = 'An error occurred while loading prescriptions';
        _isLoading = false;
      });
    }
  }

  Future<void> _openPrescription(String? url) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prescription URL not available')),
      );
      return;
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open prescription')),
        );
      }
    }
  }

  // Parse medicines text into structured display widgets
  List<Widget> _parseMedicines(String medicinesText, bool isWeb) {
    final lines = medicinesText
        .split(RegExp(r'[\n\r]+'))
        .where((line) => line.trim().isNotEmpty)
        .toList();

    return lines.map((line) {
      // Try to parse structured format: "Name - X tablet(s) - Timing | Instructions"
      String name = line;
      String quantity = '';
      String timing = '';
      String instructions = '';

      final parts = line.split(' - ');
      if (parts.isNotEmpty) {
        name = parts[0].trim();

        if (parts.length >= 2) {
          // Extract quantity from second part (e.g., "2 tablet(s)")
          final qtyMatch =
              RegExp(r'(\d+)\s*tablet').firstMatch(parts[1].toLowerCase());
          if (qtyMatch != null) {
            quantity = '${qtyMatch.group(1)} tablet(s)';
          } else {
            quantity = parts[1].trim();
          }
        }

        if (parts.length >= 3) {
          final timingPart = parts[2];
          // Check if there are instructions after |
          if (timingPart.contains('|')) {
            final splitTiming = timingPart.split('|');
            timing = splitTiming[0].trim();
            instructions = splitTiming.length > 1 ? splitTiming[1].trim() : '';
          } else {
            timing = timingPart.trim();
          }
        }
      }

      return Container(
        margin: EdgeInsets.only(bottom: isWeb ? 8 : 1.h),
        padding: EdgeInsets.all(isWeb ? 10 : 2.5.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Medicine name
            Row(
              children: [
                Icon(Icons.medication_liquid,
                    size: isWeb ? 16 : 13.sp, color: Colors.orange[700]),
                SizedBox(width: isWeb ? 6 : 1.w),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: isWeb ? 14 : 13.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[900],
                    ),
                  ),
                ),
              ],
            ),
            if (quantity.isNotEmpty || timing.isNotEmpty) ...[
              SizedBox(height: isWeb ? 6 : 0.5.h),
              Row(
                children: [
                  if (quantity.isNotEmpty) ...[
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isWeb ? 8 : 2.w,
                        vertical: isWeb ? 2 : 0.3.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.confirmation_number,
                              size: isWeb ? 12 : 13.sp,
                              color: Colors.green[700]),
                          SizedBox(width: isWeb ? 4 : 0.5.w),
                          Text(
                            quantity,
                            style: TextStyle(
                              fontSize: isWeb ? 11 : 13.sp,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: isWeb ? 8 : 1.5.w),
                  ],
                  if (timing.isNotEmpty)
                    Expanded(
                      child: Wrap(
                        spacing: isWeb ? 4 : 1.w,
                        runSpacing: isWeb ? 4 : 0.5.h,
                        children: _buildTimingChips(timing, isWeb),
                      ),
                    ),
                ],
              ),
            ],
            if (instructions.isNotEmpty) ...[
              SizedBox(height: isWeb ? 6 : 0.5.h),
              Row(
                children: [
                  Icon(Icons.info_outline,
                      size: isWeb ? 12 : 13.sp, color: Colors.grey[600]),
                  SizedBox(width: isWeb ? 4 : 0.5.w),
                  Expanded(
                    child: Text(
                      instructions,
                      style: TextStyle(
                        fontSize: isWeb ? 11 : 13.sp,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }).toList();
  }

  // Build timing chips for morning, afternoon, evening, night
  List<Widget> _buildTimingChips(String timing, bool isWeb) {
    final chips = <Widget>[];
    final timingLower = timing.toLowerCase();

    if (timingLower.contains('morning')) {
      chips.add(
          _buildTimingChip('Morning', Icons.wb_sunny, Colors.amber, isWeb));
    }
    if (timingLower.contains('afternoon')) {
      chips.add(_buildTimingChip(
          'Afternoon', Icons.light_mode, Colors.orange, isWeb));
    }
    if (timingLower.contains('evening')) {
      chips.add(_buildTimingChip(
          'Evening', Icons.wb_twilight, Colors.deepOrange, isWeb));
    }
    if (timingLower.contains('night')) {
      chips.add(_buildTimingChip(
          'Night', Icons.nightlight_round, Colors.indigo, isWeb));
    }

    // If no specific timing found, show the raw timing text
    if (chips.isEmpty && timing.isNotEmpty) {
      chips.add(Container(
        padding: EdgeInsets.symmetric(
          horizontal: isWeb ? 6 : 1.5.w,
          vertical: isWeb ? 2 : 0.3.h,
        ),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          timing,
          style: TextStyle(
            fontSize: isWeb ? 10 : 13.sp,
            color: Colors.grey[700],
          ),
        ),
      ));
    }

    return chips;
  }

  Widget _buildTimingChip(
      String label, IconData icon, Color color, bool isWeb) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWeb ? 6 : 1.5.w,
        vertical: isWeb ? 2 : 0.3.h,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isWeb ? 10 : 13.sp, color: color),
          SizedBox(width: isWeb ? 2 : 0.5.w),
          Text(
            label,
            style: TextStyle(
              fontSize: isWeb ? 10 : 13.sp,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSpecialtyIcon(String specialty) {
    switch (specialty.toLowerCase()) {
      case 'all':
        return Icons.list_alt;
      case 'ocularist':
        return Icons.remove_red_eye_outlined;
      case 'optician':
        return Icons.face_retouching_natural;
      case 'optometrist':
        return Icons.visibility;
      case 'ophthalmologist':
        return Icons.medical_services;
      case 'eye surgeon':
        return Icons.healing;
      case 'retina specialist':
        return Icons.center_focus_strong;
      case 'glaucoma specialist':
        return Icons.blur_on;
      case 'cornea specialist':
        return Icons.blur_circular;
      default:
        return Icons.local_hospital;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = ResponsiveHelper.isWeb(context);
    final contentMaxWidth = ResponsiveHelper.getContentWidth(context);

    return Scaffold(
      backgroundColor: lightTealColor,
      body: Container(
        decoration: const BoxDecoration(
          gradient: appGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isWeb ? 24 : 4.w,
                  vertical: isWeb ? 16 : 2.h,
                ),
                child: Row(
                  children: [
                    if (widget.showBackButton)
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            padding: EdgeInsets.all(isWeb ? 10 : 2.w),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: isWeb ? 24 : 20.sp,
                            ),
                          ),
                        ),
                      ),
                    if (widget.showBackButton)
                      SizedBox(width: isWeb ? 16 : 3.w),
                    Text(
                      'My Prescriptions',
                      style: TextStyle(
                        fontSize: isWeb ? 24 : 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    // Refresh button
                    GestureDetector(
                      onTap: _loadPrescriptions,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          padding: EdgeInsets.all(isWeb ? 10 : 2.w),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.refresh,
                            color: Colors.white,
                            size: isWeb ? 24 : 20.sp,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Category Tabs - Glassmorphic style
              if (!_isLoading &&
                  _prescriptions.isNotEmpty &&
                  _tabController != null)
                _buildCategoryTabs(isWeb),

              // Content
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentMaxWidth),
                    child: _buildBody(isWeb),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs(bool isWeb) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isWeb ? 24 : 4.w,
        vertical: isWeb ? 8 : 1.h,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.all(isWeb ? 6 : 1.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _specialties.asMap().entries.map((entry) {
                  final index = entry.key;
                  final specialty = entry.value;
                  final count =
                      _prescriptionsBySpecialty[specialty]?.length ?? 0;
                  final isSelected = _tabController!.index == index;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _tabController!.animateTo(index);
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(right: isWeb ? 8 : 1.5.w),
                      padding: EdgeInsets.symmetric(
                        horizontal: isWeb ? 16 : 3.w,
                        vertical: isWeb ? 10 : 1.h,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: tealColor.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getSpecialtyIcon(specialty),
                            size: isWeb ? 18 : 14.sp,
                            color: isSelected ? tealColor : Colors.white,
                          ),
                          SizedBox(width: isWeb ? 6 : 1.w),
                          Text(
                            specialty,
                            style: TextStyle(
                              fontSize: isWeb ? 14 : 14.sp,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected ? tealColor : Colors.white,
                            ),
                          ),
                          SizedBox(width: isWeb ? 6 : 1.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isWeb ? 8 : 1.5.w,
                              vertical: isWeb ? 2 : 0.3.h,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? tealColor.withOpacity(0.15)
                                  : Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: isWeb ? 12 : 14.sp,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? tealColor : Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool isWeb) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            SizedBox(height: isWeb ? 16 : 2.h),
            Text(
              'Loading prescriptions...',
              style: TextStyle(
                color: Colors.white,
                fontSize: isWeb ? 16 : 14.sp,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.all(isWeb ? 32 : 6.w),
              margin: EdgeInsets.all(isWeb ? 24 : 4.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: isWeb ? 64 : 50.sp,
                    color: Colors.white,
                  ),
                  SizedBox(height: isWeb ? 16 : 2.h),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isWeb ? 16 : 14.sp,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isWeb ? 20 : 3.h),
                  ElevatedButton.icon(
                    onPressed: _loadPrescriptions,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: tealColor,
                      padding: EdgeInsets.symmetric(
                        horizontal: isWeb ? 24 : 6.w,
                        vertical: isWeb ? 12 : 1.5.h,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_prescriptions.isEmpty) {
      return Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.all(isWeb ? 32 : 6.w),
              margin: EdgeInsets.all(isWeb ? 24 : 4.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: isWeb ? 80 : 60.sp,
                    color: Colors.white,
                  ),
                  SizedBox(height: isWeb ? 16 : 2.h),
                  Text(
                    'No prescriptions found',
                    style: TextStyle(
                      fontSize: isWeb ? 20 : 16.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: isWeb ? 8 : 1.h),
                  Text(
                    'Your prescriptions will appear here\nafter your appointments.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: isWeb ? 14 : 12.sp,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: _specialties.map((specialty) {
        final prescriptions = _prescriptionsBySpecialty[specialty] ?? [];
        return _buildPrescriptionList(prescriptions, specialty, isWeb);
      }).toList(),
    );
  }

  Widget _buildPrescriptionList(
      List<SavedPrescription> prescriptions, String specialty, bool isWeb) {
    if (prescriptions.isEmpty) {
      return Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.all(isWeb ? 32 : 6.w),
              margin: EdgeInsets.all(isWeb ? 24 : 4.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getSpecialtyIcon(specialty),
                    size: isWeb ? 64 : 50.sp,
                    color: Colors.white,
                  ),
                  SizedBox(height: isWeb ? 16 : 2.h),
                  Text(
                    'No $specialty prescriptions',
                    style: TextStyle(
                      fontSize: isWeb ? 18 : 14.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPrescriptions,
      color: Colors.white,
      child: ListView.builder(
        padding: EdgeInsets.only(
          left: isWeb ? 24 : 4.w,
          right: isWeb ? 24 : 4.w,
          top: isWeb ? 16 : 2.h,
          bottom:
              widget.showBackButton ? (isWeb ? 24 : 4.h) : (isWeb ? 120 : 14.h),
        ),
        itemCount: prescriptions.length,
        itemBuilder: (context, index) {
          final prescription = prescriptions[index];
          return _buildPrescriptionCard(prescription, index + 1, isWeb);
        },
      ),
    );
  }

  Widget _buildPrescriptionCard(
      SavedPrescription prescription, int index, bool isWeb) {
    return Container(
      margin: EdgeInsets.only(bottom: isWeb ? 16 : 2.h),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: tealColor.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openPrescription(prescription.prescriptionUrl),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: EdgeInsets.all(isWeb ? 20 : 4.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with date and index
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(isWeb ? 10 : 2.w),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      tealColor.withOpacity(0.15),
                                      tealAccent.withOpacity(0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '#$index',
                                  style: TextStyle(
                                    color: tealColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isWeb ? 14 : 14.sp,
                                  ),
                                ),
                              ),
                              SizedBox(width: isWeb ? 12 : 2.w),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: isWeb ? 14 : 14.sp,
                                        color: tealColor,
                                      ),
                                      SizedBox(width: isWeb ? 4 : 1.w),
                                      Text(
                                        prescription.prescriptionDate ??
                                            'No date',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: isWeb ? 13 : 14.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isWeb ? 12 : 2.5.w,
                              vertical: isWeb ? 6 : 0.8.h,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [tealColor, tealColor.withOpacity(0.8)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              prescription.fileType?.toUpperCase() ?? 'IMAGE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isWeb ? 11 : 14.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Divider(
                          height: isWeb ? 24 : 3.h, color: Colors.grey[200]),

                      // Doctor info
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(isWeb ? 10 : 2.w),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [tealColor, tealColor.withOpacity(0.8)],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getSpecialtyIcon(
                                  prescription.doctorSpecialty ?? ''),
                              color: Colors.white,
                              size: isWeb ? 20 : 16.sp,
                            ),
                          ),
                          SizedBox(width: isWeb ? 12 : 2.5.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prescription.doctorName ?? 'Doctor',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: isWeb ? 16 : 15.sp,
                                    color: darkTealColor,
                                  ),
                                ),
                                if (prescription.doctorSpecialty != null &&
                                    prescription.doctorSpecialty!.isNotEmpty)
                                  Container(
                                    margin:
                                        EdgeInsets.only(top: isWeb ? 4 : 0.5.h),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isWeb ? 10 : 2.w,
                                      vertical: isWeb ? 3 : 0.4.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: tealColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      prescription.doctorSpecialty!,
                                      style: TextStyle(
                                        color: tealColor,
                                        fontSize: isWeb ? 12 : 14.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Diagnosis preview
                      if (prescription.diagnosis != null &&
                          prescription.diagnosis!.isNotEmpty &&
                          prescription.diagnosis != 'NIL') ...[
                        SizedBox(height: isWeb ? 16 : 2.h),
                        Container(
                          padding: EdgeInsets.all(isWeb ? 12 : 3.w),
                          decoration: BoxDecoration(
                            color: lightTealColor.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: tealColor.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.medical_information,
                                    size: isWeb ? 16 : 14.sp,
                                    color: tealColor,
                                  ),
                                  SizedBox(width: isWeb ? 6 : 1.w),
                                  Text(
                                    'Diagnosis',
                                    style: TextStyle(
                                      color: tealColor,
                                      fontSize: isWeb ? 12 : 14.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: isWeb ? 6 : 0.8.h),
                              Text(
                                prescription.diagnosis!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: isWeb ? 14 : 14.sp,
                                  color: darkTealColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Medicines section
                      if (prescription.medicines != null &&
                          prescription.medicines!.isNotEmpty &&
                          prescription.medicines != 'NIL') ...[
                        SizedBox(height: isWeb ? 12 : 1.5.h),
                        Container(
                          padding: EdgeInsets.all(isWeb ? 12 : 3.w),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.medication,
                                    size: isWeb ? 16 : 14.sp,
                                    color: Colors.orange[700],
                                  ),
                                  SizedBox(width: isWeb ? 6 : 1.w),
                                  Text(
                                    'Medicines',
                                    style: TextStyle(
                                      color: Colors.orange[700],
                                      fontSize: isWeb ? 12 : 14.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: isWeb ? 8 : 1.h),
                              ..._parseMedicines(
                                  prescription.medicines!, isWeb),
                            ],
                          ),
                        ),
                      ],

                      // Advice section
                      if (prescription.advice != null &&
                          prescription.advice!.isNotEmpty &&
                          prescription.advice != 'NIL') ...[
                        SizedBox(height: isWeb ? 12 : 1.5.h),
                        Container(
                          padding: EdgeInsets.all(isWeb ? 12 : 3.w),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: Colors.blue.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline,
                                    size: isWeb ? 16 : 14.sp,
                                    color: Colors.blue[700],
                                  ),
                                  SizedBox(width: isWeb ? 6 : 1.w),
                                  Text(
                                    'Advice',
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontSize: isWeb ? 12 : 14.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: isWeb ? 6 : 0.8.h),
                              Text(
                                prescription.advice!,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: isWeb ? 13 : 13.sp,
                                  color: Colors.blue[900],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Follow-up section
                      if (prescription.followUp != null &&
                          prescription.followUp!.isNotEmpty &&
                          prescription.followUp != 'NIL') ...[
                        SizedBox(height: isWeb ? 12 : 1.5.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isWeb ? 12 : 3.w,
                            vertical: isWeb ? 8 : 1.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.purple.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: isWeb ? 16 : 14.sp,
                                color: Colors.purple[700],
                              ),
                              SizedBox(width: isWeb ? 6 : 1.w),
                              Text(
                                'Follow-up: ',
                                style: TextStyle(
                                  color: Colors.purple[700],
                                  fontSize: isWeb ? 12 : 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  prescription.followUp!,
                                  style: TextStyle(
                                    fontSize: isWeb ? 13 : 13.sp,
                                    color: Colors.purple[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      SizedBox(height: isWeb ? 16 : 2.h),

                      // View button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _openPrescription(prescription.prescriptionUrl),
                          icon:
                              Icon(Icons.visibility, size: isWeb ? 18 : 14.sp),
                          label: Text(
                            'View Prescription',
                            style: TextStyle(fontSize: isWeb ? 14 : 14.sp),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tealColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: isWeb ? 14 : 1.5.h,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
