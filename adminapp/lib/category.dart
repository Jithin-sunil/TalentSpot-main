import 'package:adminapp/main.dart';
import 'package:flutter/material.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> categoryList = [];
  final TextEditingController _categoryController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Edit mode
  int? _editingCategoryId;

  // Search
  final _searchController = TextEditingController();
  String _searchQuery = '';

  int _currentPage = 1;
  final int _itemsPerPage = 5;

  @override
  void initState() {
    super.initState();
    fetchCategories();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      var query = supabase.from('tbl_category').select().order('category_name');
      if (_searchQuery.isNotEmpty) {
        // query = query.like('category_name', '%${_searchQuery.toLowerCase()}%');
      }
      final response = await query;
      setState(() {
        categoryList = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print("ERROR FETCHING DATA: $e");
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching categories: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF4361EE),
        ),
      );
    }
  }

  Future<void> insertCategory() async {
    try {
      String name = _categoryController.text.trim();
      await supabase.from('tbl_category').insert({'category_name': name});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Category Added Successfully",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );
      _resetForm();
      fetchCategories();
    } catch (e) {
      print("ERROR INSERTING DATA: $e");
    }
  }

  Future<void> editCategory() async {
    try {
      await supabase
          .from('tbl_category')
          .update({'category_name': _categoryController.text.trim()})
          .eq('id', _editingCategoryId!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Category Updated Successfully",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );
      _resetForm();
      fetchCategories();
    } catch (e) {
      print("ERROR UPDATING DATA: $e");
    }
  }

  Future<void> deleteCategory(String cid) async {
    try {
      await supabase.from("tbl_category").delete().eq("id", cid);
      fetchCategories();
    } catch (e) {
      print("ERROR: $e");
    }
  }

  void _resetForm() {
    _categoryController.clear();
    _editingCategoryId = null;
  }

  Future<void> _showFormDialog({Map<String, dynamic>? category}) async {
    _resetForm();
    if (category != null) {
      _categoryController.text = category['category_name'] ?? '';
      _editingCategoryId = category['id'];
    }

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              _editingCategoryId == null ? 'Add New Category' : 'Edit Category',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _categoryController,
                      decoration: const InputDecoration(
                        labelText: "Category Name",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a category name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              if (_editingCategoryId == null) {
                                await insertCategory();
                              } else {
                                await editCategory();
                              }
                              Navigator.of(context).pop();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4361EE),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            _editingCategoryId == null
                                ? "Add Category"
                                : "Update Category",
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  List<Map<String, dynamic>> _getFilteredCategories() {
    return categoryList.where((category) {
      final name = category['category_name']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> _getPaginatedCategories() {
    final filteredCategories = _getFilteredCategories();
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    if (startIndex >= filteredCategories.length) return [];
    final endIndex = (startIndex + _itemsPerPage).clamp(
      0,
      filteredCategories.length,
    );
    return filteredCategories.sublist(startIndex, endIndex);
  }

  int get _pageCount {
    return (_getFilteredCategories().length / _itemsPerPage).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final paginatedCategories = _getPaginatedCategories();
    final totalCategories = _getFilteredCategories().length;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        color: const Color(0xFFF8F9FA),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              child: Row(
                children: [
                  const Text(
                    'Manage Categories',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 300,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search categories...',
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey[500],
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        suffixIcon:
                            _searchQuery.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                      _currentPage = 1;
                                      fetchCategories();
                                    });
                                  },
                                )
                                : null,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                          _currentPage = 1;
                          fetchCategories();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'Add Category',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4361EE),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () => _showFormDialog(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Categories Overview',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Total Categories',
                      value: totalCategories.toString(),
                      icon: Icons.list_alt,
                      iconColor: const Color(0xFF4361EE),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Text(
                        'Sl No',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Category Name',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'Actions',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child:
                  _isLoading && categoryList.isEmpty
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4361EE),
                        ),
                      )
                      : paginatedCategories.isEmpty
                      ? Center(
                        child: Text(
                          'No categories found',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      )
                      : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: paginatedCategories.length,
                        separatorBuilder:
                            (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final category = paginatedCategories[index];
                          return Container(
                            color: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    (index +
                                            1 +
                                            (_currentPage - 1) * _itemsPerPage)
                                        .toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    category['category_name'] ?? '',
                                    style: TextStyle(color: Colors.grey[700]),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Color(0xFF4361EE),
                                        ),
                                        onPressed:
                                            () => _showFormDialog(
                                              category: category,
                                            ),
                                        tooltip: 'Edit',
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed:
                                            () => deleteCategory(
                                              category['id'].toString(),
                                            ),
                                        tooltip: 'Delete',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
            ),
            if (!_isLoading && _getFilteredCategories().isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${paginatedCategories.length} of ${_getFilteredCategories().length} categories',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed:
                              _currentPage > 1
                                  ? () => setState(() => _currentPage--)
                                  : null,
                          color:
                              _currentPage > 1
                                  ? const Color(0xFF4361EE)
                                  : Colors.grey[400],
                        ),
                        for (int i = 1; i <= _pageCount; i++)
                          if (i == _currentPage)
                            Container(
                              width: 32,
                              height: 32,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4361EE),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$i',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else
                            InkWell(
                              onTap: () => setState(() => _currentPage = i),
                              child: Container(
                                width: 32,
                                height: 32,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '$i',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ),
                            ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed:
                              _currentPage < _pageCount
                                  ? () => setState(() => _currentPage++)
                                  : null,
                          color:
                              _currentPage < _pageCount
                                  ? const Color(0xFF4361EE)
                                  : Colors.grey[400],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
