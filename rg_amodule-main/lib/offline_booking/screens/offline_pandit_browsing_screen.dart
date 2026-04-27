// lib/offline_booking/screens/offline_pandit_browsing_screen.dart
// Screen for browsing and filtering offline pandits

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../models/offline_booking_models.dart';
import '../providers/offline_booking_provider.dart';

class OfflinePanditBrowsingScreen extends ConsumerStatefulWidget {
  const OfflinePanditBrowsingScreen({super.key});

  @override
  ConsumerState<OfflinePanditBrowsingScreen> createState() =>
      _OfflinePanditBrowsingScreenState();
}

class _OfflinePanditBrowsingScreenState
    extends ConsumerState<OfflinePanditBrowsingScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  
  String? _selectedCity;
  String? _selectedSpecialty;
  double? _minRating;
  double? _maxPrice;
  String? _selectedLanguage;
  bool _showFilters = false;

  final _cities = ['Mumbai', 'Delhi', 'Pune', 'Bangalore', 'Chennai', 'Kolkata'];
  final _specialties = [
    'Satyanarayan Puja',
    'Griha Pravesh',
    'Navgraha Shanti',
    'Jyotish',
    'Vastu',
    'Kundali',
    'Havan',
    'Sunderkand',
    'Kanya Puja',
  ];
  final _languages = ['Hindi', 'English', 'Marathi', 'Tamil', 'Telugu', 'Kannada'];
  final _priceRanges = [
    {'label': 'Under ₹1000', 'max': 1000.0},
    {'label': '₹1000 - ₹2000', 'min': 1000.0, 'max': 2000.0},
    {'label': '₹2000 - ₹5000', 'min': 2000.0, 'max': 5000.0},
    {'label': 'Above ₹5000', 'min': 5000.0},
  ];
  final _ratingOptions = [4.5, 4.0, 3.5, 3.0];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() => _loadPandits());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMorePandits();
    }
  }

  void _loadPandits({bool reset = true}) {
    ref.read(panditSearchProvider.notifier).searchPandits(
      city: _selectedCity,
      specialty: _selectedSpecialty,
      minRating: _minRating,
      maxPrice: _maxPrice,
      language: _selectedLanguage,
      reset: reset,
    );
  }

  void _loadMorePandits() {
    final state = ref.read(panditSearchProvider);
    if (!state.loading && state.hasMore) {
      ref.read(panditSearchProvider.notifier).searchPandits(
        city: _selectedCity,
        specialty: _selectedSpecialty,
        minRating: _minRating,
        maxPrice: _maxPrice,
        language: _selectedLanguage,
        reset: false,
      );
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedCity = null;
      _selectedSpecialty = null;
      _minRating = null;
      _maxPrice = null;
      _selectedLanguage = null;
    });
    _loadPandits();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(panditSearchProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Offline Pandit Booking'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          _buildSearchBar(),
          
          // Filters
          if (_showFilters) _buildFilters(),
          
          // Active Filters Chips
          if (_hasActiveFilters()) _buildActiveFilters(),
          
          // Results
          Expanded(
            child: _buildResults(state),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search pandits by name or specialty...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _loadPandits();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onSubmitted: (value) {
          _loadPandits();
        },
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: _clearFilters,
                child: const Text('Clear All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // City Filter
          _buildDropdownFilter(
            label: 'City',
            value: _selectedCity,
            items: _cities,
            onChanged: (value) {
              setState(() {
                _selectedCity = value;
              });
              _loadPandits();
            },
          ),
          
          const SizedBox(height: 12),
          
          // Specialty Filter
          _buildDropdownFilter(
            label: 'Specialty',
            value: _selectedSpecialty,
            items: _specialties,
            onChanged: (value) {
              setState(() {
                _selectedSpecialty = value;
              });
              _loadPandits();
            },
          ),
          
          const SizedBox(height: 12),
          
          // Language Filter
          _buildDropdownFilter(
            label: 'Language',
            value: _selectedLanguage,
            items: _languages,
            onChanged: (value) {
              setState(() {
                _selectedLanguage = value;
              });
              _loadPandits();
            },
          ),
          
          const SizedBox(height: 12),
          
          // Rating Filter
          const Text(
            'Minimum Rating',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _ratingOptions.map((rating) {
              return FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(rating.toStringAsFixed(1)),
                  ],
                ),
                selected: _minRating == rating,
                onSelected: (selected) {
                  setState(() {
                    _minRating = selected ? rating : null;
                  });
                  _loadPandits();
                },
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                checkmarkColor: AppColors.primary,
              );
            }).toList(),
          ),
          
          const SizedBox(height: 12),
          
          // Price Filter
          const Text(
            'Price Range',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _priceRanges.map((range) {
              final isSelected = _minRating != null &&
                  range['min'] != null &&
                  _maxPrice == range['max'];
              return FilterChip(
                label: Text(range['label'] as String),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _maxPrice = range['max'] as double?;
                    } else {
                      _maxPrice = null;
                    }
                  });
                  _loadPandits();
                },
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                checkmarkColor: AppColors.primary,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('All'),
            ),
            ...items.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(item),
              );
            }),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }

  bool _hasActiveFilters() {
    return _selectedCity != null ||
        _selectedSpecialty != null ||
        _minRating != null ||
        _maxPrice != null ||
        _selectedLanguage != null;
  }

  Widget _buildActiveFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.primary.withValues(alpha: 0.05),
      child: Wrap(
        spacing: 8,
        children: [
          if (_selectedCity != null) _buildFilterChip(_selectedCity!, () {
            setState(() => _selectedCity = null);
            _loadPandits();
          }),
          if (_selectedSpecialty != null) _buildFilterChip(_selectedSpecialty!, () {
            setState(() => _selectedSpecialty = null);
            _loadPandits();
          }),
          if (_selectedLanguage != null) _buildFilterChip(_selectedLanguage!, () {
            setState(() => _selectedLanguage = null);
            _loadPandits();
          }),
          if (_minRating != null) _buildFilterChip('$_minRating★+', () {
            setState(() => _minRating = null);
            _loadPandits();
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Chip(
      label: Text(label),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onRemove,
      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
      deleteIconColor: AppColors.primary,
      labelStyle: const TextStyle(fontSize: 12),
    );
  }

  Widget _buildResults(PanditSearchState state) {
    if (state.loading && state.pandits.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              state.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadPandits(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.pandits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No pandits found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try adjusting your filters',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: state.pandits.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.pandits.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final pandit = state.pandits[index];
        return _PanditCard(pandit: pandit);
      },
    );
  }
}

class _PanditCard extends StatelessWidget {
  const _PanditCard({required this.pandit});

  final OfflinePanditProfile pandit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/offline-pandits/${pandit.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  image: pandit.avatarUrl != null
                      ? DecorationImage(
                          image: NetworkImage(pandit.avatarUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: pandit.avatarUrl == null
                    ? Center(
                        child: Text(
                          pandit.name.substring(0, 2).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            pandit.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (pandit.isVerified)
                          const Icon(
                            Icons.verified,
                            color: Colors.blue,
                            size: 18,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pandit.location,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: pandit.specialties.take(3).map((specialty) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            specialty,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          pandit.rating > 0 
                              ? pandit.rating.toStringAsFixed(1) 
                              : 'New',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (pandit.totalReviews > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(${pandit.totalReviews})',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(width: 12),
                        Icon(
                          Icons.work_outline,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${pandit.experienceYears} yrs',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '₹${pandit.basePrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
