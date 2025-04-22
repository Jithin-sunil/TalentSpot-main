import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FilmmakersPage extends StatefulWidget {
  const FilmmakersPage({super.key});

  @override
  State<FilmmakersPage> createState() => _FilmmakersPageState();
}

class _FilmmakersPageState extends State<FilmmakersPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _filmmakers = [];
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentPage = 1;
  final int _itemsPerPage = 5;

  @override
  void initState() {
    super.initState();
    _fetchFilmmakers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchFilmmakers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await supabase
          .from('tbl_filmmakers')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _filmmakers = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching filmmakers: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching filmmakers: $e')),
        );
      }
    }
  }

  Future<void> _toggleStatus(
    String filmmakerId,
    int currentStatus,
    String action,
  ) async {
    try {
      int newStatus = currentStatus;
      String message = '';

      if (action == 'verify') {
        newStatus =
            currentStatus == 1
                ? 0
                : 1; // Toggle between verified (1) and pending (0)
        message =
            newStatus == 1
                ? 'Filmmaker verified successfully'
                : 'Filmmaker verification removed';
      } else if (action == 'block') {
        newStatus =
            currentStatus == 2
                ? 0
                : 2; // Toggle between blocked (2) and pending (0)
        message =
            newStatus == 2
                ? 'Filmmaker blocked successfully'
                : 'Filmmaker unblocked';
      }

      await supabase
          .from('tbl_filmmakers')
          .update({'flimmaker_status': newStatus})
          .eq('filmmaker_id', filmmakerId);

      await _fetchFilmmakers();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF4361EE),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  List<Map<String, dynamic>> _getFilteredFilmmakers() {
    if (_searchQuery.isEmpty) return _filmmakers;

    return _filmmakers.where((filmmaker) {
      final name = filmmaker['filmmaker_name']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> _getPaginatedFilmmakers() {
    final filteredFilmmakers = _getFilteredFilmmakers();
    final startIndex = (_currentPage - 1) * _itemsPerPage;

    if (startIndex >= filteredFilmmakers.length) {
      return [];
    }

    final endIndex =
        startIndex + _itemsPerPage > filteredFilmmakers.length
            ? filteredFilmmakers.length
            : startIndex + _itemsPerPage;

    return filteredFilmmakers.sublist(startIndex, endIndex);
  }

  int get _pageCount {
    return (_getFilteredFilmmakers().length / _itemsPerPage).ceil();
  }

  String _getStatusText(int status) {
    switch (status) {
      case 1:
        return 'Verified';
      case 2:
        return 'Blocked';
      case 0:
      default:
        return 'Pending';
    }
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 1:
        return const Color(0xFF4CAF50);
      case 2:
        return const Color(0xFFF44336);
      case 0:
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final paginatedFilmmakers = _getPaginatedFilmmakers();
    final verifiedFilmmakers =
        _getFilteredFilmmakers()
            .where((f) => f['flimmaker_status'] == 1)
            .length;
    final blockedFilmmakers =
        _getFilteredFilmmakers()
            .where((f) => f['flimmaker_status'] == 2)
            .length;

    return Scaffold(
      body:
          _isLoading && _filmmakers.isEmpty
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF4361EE)),
              )
              : Container(
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
                            'Filmmakers Management',
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
                                hintText: 'Search by name...',
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
                                          icon: Icon(
                                            Icons.clear,
                                            color: Colors.grey[500],
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _searchController.clear();
                                              _searchQuery = '';
                                              _currentPage = 1;
                                            });
                                          },
                                        )
                                        : null,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                  _currentPage = 1;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Overview
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Filmmakers Overview',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Stats Cards
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              title: 'Total Filmmakers',
                              value: _getFilteredFilmmakers().length.toString(),
                              icon: Icons.people_alt_outlined,
                              iconColor: const Color(0xFF4361EE),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _StatCard(
                              title: 'Verified Filmmakers',
                              value: verifiedFilmmakers.toString(),
                              icon: Icons.verified_user_outlined,
                              iconColor: const Color(0xFF4CAF50),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _StatCard(
                              title: 'Blocked Filmmakers',
                              value: blockedFilmmakers.toString(),
                              icon: Icons.block_outlined,
                              iconColor: const Color(0xFFF44336),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Table Header
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
                              flex: 2,
                              child: Text(
                                'Name',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Email',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Phone',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                'Status',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                'Action',
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
                    // Table Content
                    Expanded(
                      child:
                          _isLoading
                              ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF4361EE),
                                ),
                              )
                              : paginatedFilmmakers.isEmpty
                              ? Center(
                                child: Text(
                                  'No filmmakers found',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              )
                              : ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                itemCount: paginatedFilmmakers.length,
                                separatorBuilder:
                                    (context, index) =>
                                        const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final filmmaker = paginatedFilmmakers[index];
                                  final status =
                                      filmmaker['flimmaker_status'] ?? 0;

                                  return Container(
                                    color: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF4361EE,
                                                  ).withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  (filmmaker['filmmaker_name']
                                                                  as String? ??
                                                              '')
                                                          .isNotEmpty
                                                      ? (filmmaker['filmmaker_name']
                                                              as String)
                                                          .substring(0, 1)
                                                          .toUpperCase()
                                                      : '?',
                                                  style: const TextStyle(
                                                    color: Color(0xFF4361EE),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                filmmaker['filmmaker_name'] ??
                                                    '',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            filmmaker['filmmaker_email'] ?? '',
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            filmmaker['filmmaker_phone'] ?? '',
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(
                                                status,
                                              ).withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              _getStatusText(status),
                                              style: TextStyle(
                                                color: _getStatusColor(status),
                                                fontWeight: FontWeight.w500,
                                                fontSize: 12,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              OutlinedButton(
                                                onPressed:
                                                    () => _toggleStatus(
                                                      filmmaker['filmmaker_id'],
                                                      status,
                                                      'verify',
                                                    ),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor:
                                                      status == 1
                                                          ? Colors.grey
                                                          : const Color(
                                                            0xFF4CAF50,
                                                          ),
                                                  side: BorderSide(
                                                    color:
                                                        status == 1
                                                            ? Colors.grey
                                                            : const Color(
                                                              0xFF4CAF50,
                                                            ),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                      ),
                                                  minimumSize: const Size(
                                                    0,
                                                    32,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                ),
                                                child: Text(
                                                  status == 1
                                                      ? 'Unverify'
                                                      : 'Verify',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              OutlinedButton(
                                                onPressed:
                                                    () => _toggleStatus(
                                                      filmmaker['filmmaker_id'],
                                                      status,
                                                      'block',
                                                    ),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor:
                                                      status == 2
                                                          ? Colors.grey
                                                          : const Color(
                                                            0xFFF44336,
                                                          ),
                                                  side: BorderSide(
                                                    color:
                                                        status == 2
                                                            ? Colors.grey
                                                            : const Color(
                                                              0xFFF44336,
                                                            ),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                      ),
                                                  minimumSize: const Size(
                                                    0,
                                                    32,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                ),
                                                child: Text(
                                                  status == 2
                                                      ? 'Unblock'
                                                      : 'Block',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
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
                    // Pagination
                    if (!_isLoading && _getFilteredFilmmakers().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.white,
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Showing ${paginatedFilmmakers.length} of ${_getFilteredFilmmakers().length} filmmakers',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left),
                                  onPressed:
                                      _currentPage > 1
                                          ? () {
                                            setState(() {
                                              _currentPage--;
                                            });
                                          }
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
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
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
                                      onTap: () {
                                        setState(() {
                                          _currentPage = i;
                                        });
                                      },
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '$i',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                    ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right),
                                  onPressed:
                                      _currentPage < _pageCount
                                          ? () {
                                            setState(() {
                                              _currentPage++;
                                            });
                                          }
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
