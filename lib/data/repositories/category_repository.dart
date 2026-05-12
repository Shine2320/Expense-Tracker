import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../datasources/hive_storage.dart';
import '../models/category_model.dart';

class CategoryRepository {
  static const _uuid = Uuid();

  Box<CategoryModel> get _box => HiveStorage.categoriesBoxRef;

  List<CategoryModel> getAllCategories() {
    return _box.values.toList()
      ..sort((a, b) {
        if (a.isCustom == b.isCustom) return a.name.compareTo(b.name);
        return a.isCustom ? 1 : -1;
      });
  }

  CategoryModel? getCategoryById(String id) {
    return _box.get(id);
  }

  Future<CategoryModel> addCustomCategory(String name, String emoji) async {
    final id = _uuid.v4();
    final category = CategoryModel(
      id: id,
      name: name,
      emoji: emoji,
      isCustom: true,
    );
    await _box.put(id, category);
    return category;
  }

  Future<void> deleteCategory(String id) async {
    final category = _box.get(id);
    if (category?.isCustom == true) {
      await _box.delete(id);
    }
  }

  Future<void> updateCategory(String id, {String? name, String? emoji}) async {
    final category = _box.get(id);
    if (category != null && category.isCustom) {
      category.name = name ?? category.name;
      category.emoji = emoji ?? category.emoji;
      await category.save();
    }
  }
}
