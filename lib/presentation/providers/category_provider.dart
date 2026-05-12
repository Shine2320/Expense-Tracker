import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/models/category_model.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository();
});

final categoryProvider = StateNotifierProvider<CategoryNotifier, CategoryState>((ref) {
  return CategoryNotifier(ref.watch(categoryRepositoryProvider));
});

class CategoryState {
  final List<CategoryModel> categories;
  final bool isLoading;

  CategoryState({
    this.categories = const [],
    this.isLoading = false,
  });

  CategoryState copyWith({
    List<CategoryModel>? categories,
    bool? isLoading,
  }) {
    return CategoryState(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class CategoryNotifier extends StateNotifier<CategoryState> {
  final CategoryRepository _repository;

  CategoryNotifier(this._repository) : super(CategoryState()) {
    loadCategories();
  }

  void loadCategories() {
    state = state.copyWith(isLoading: true);
    final categories = _repository.getAllCategories();
    state = state.copyWith(categories: categories, isLoading: false);
  }

  Future<void> addCustomCategory(String name, String emoji) async {
    await _repository.addCustomCategory(name, emoji);
    loadCategories();
  }

  Future<void> deleteCategory(String id) async {
    await _repository.deleteCategory(id);
    loadCategories();
  }

  Future<void> updateCategory(String id, {String? name, String? emoji}) async {
    await _repository.updateCategory(id, name: name, emoji: emoji);
    loadCategories();
  }
}
