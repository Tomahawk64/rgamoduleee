import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../packages/models/package_model.dart';
import '../../packages/providers/packages_provider.dart';
import '../../packages/repository/supabase_package_repository.dart';

class AdminPackageCatalogState {
  const AdminPackageCatalogState({
    this.packages = const [],
    this.loading = false,
    this.error,
  });

  final List<PackageModel> packages;
  final bool loading;
  final String? error;

  AdminPackageCatalogState copyWith({
    List<PackageModel>? packages,
    bool? loading,
    String? error,
    bool clearError = false,
  }) =>
      AdminPackageCatalogState(
        packages: packages ?? this.packages,
        loading: loading ?? this.loading,
        error: clearError ? null : error,
      );
}

class AdminPackageCatalogController
    extends StateNotifier<AdminPackageCatalogState> {
  AdminPackageCatalogController(this._repo, this._onCatalogChanged)
      : super(const AdminPackageCatalogState()) {
    load();
  }

  final IPackageRepository _repo;
  final void Function() _onCatalogChanged;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final packages = await _repo.fetchAdminPackages(limit: 200);
      state = state.copyWith(
        packages: _sort(packages),
        loading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  Future<void> createPackage(PackageModel package) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final created = await _repo.createPackage(package);
      state = state.copyWith(
        packages: _sort([...state.packages, created]),
        loading: false,
        clearError: true,
      );
      _onCatalogChanged();
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> updatePackage(PackageModel package) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final updated = await _repo.updatePackage(package);
      state = state.copyWith(
        packages: _sort(
          state.packages
              .map((item) => item.id == updated.id ? updated : item)
              .toList(),
        ),
        loading: false,
        clearError: true,
      );
      _onCatalogChanged();
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> deletePackage(String id) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await _repo.deletePackage(id);
      state = state.copyWith(
        packages: state.packages.where((item) => item.id != id).toList(),
        loading: false,
        clearError: true,
      );
      _onCatalogChanged();
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> togglePackage(String id, {required bool isActive}) async {
    try {
      final updated = await _repo.togglePackage(id, isActive: isActive);
      state = state.copyWith(
        packages: _sort(
          state.packages
              .map((item) => item.id == updated.id ? updated : item)
              .toList(),
        ),
        clearError: true,
      );
      _onCatalogChanged();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  List<PackageModel> _sort(List<PackageModel> packages) {
    final sorted = List<PackageModel>.from(packages);
    sorted.sort((a, b) {
      final createdComparison =
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
      if (createdComparison != 0) return createdComparison;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return sorted;
  }
}

final adminPackageCatalogProvider = StateNotifierProvider.autoDispose<
    AdminPackageCatalogController, AdminPackageCatalogState>((ref) {
  final repo = ref.watch(packageRepositoryProvider);
  return AdminPackageCatalogController(
    repo,
    () {
      ref.invalidate(packagesFetchProvider);
      ref.invalidate(featuredPackagesProvider);
    },
  );
});