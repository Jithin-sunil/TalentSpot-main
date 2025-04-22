// ignore_for_file: unused_field, unused_import, unused_element

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ComplaintsPage extends StatefulWidget {
  const ComplaintsPage({super.key});

  @override
  State<ComplaintsPage> createState() => _ComplaintsPageState();
}

class _ComplaintsPageState extends State<ComplaintsPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _complaints = [];
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Pending', 'Replied'];
  int _currentPage = 1;
  final int _itemsPerPage = 5;

  @override
  void initState() {
    super.initState();
    _fetchComplaints();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchComplaints() async {
    setState(() {
      _isLoading = true;
    });

    try {
      var query = supabase
          .from('tbl_complaint')
          .select('*,tbl_user("*")')
          .order('created_at', ascending: false);

      final response = await query;
      if (mounted) {
        setState(() {
          _complaints = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching complaints: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching complaints: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF4361EE),
          ),
        );
      }
    }
  }

  Future<void> _updateComplaintStatus(int complaintId, int status) async {
    try {
      await supabase
          .from('tbl_complaint')
          .update({'complaint_status': status})
          .eq('complaint_id', complaintId);

      await _fetchComplaints();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Complaint status updated to ${status == 1 ? 'Replied' : 'Pending'}',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF4361EE),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF4361EE),
        ),
      );
    }
  }

  Future<void> _sendReply(int complaintId, String reply) async {
    try {
      await supabase
          .from('complaints')
          .update({'complaint_status': 1, 'admin_notes': reply})
          .eq('complaint_id', complaintId);

      await _fetchComplaints();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reply sent and status updated to Replied'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF4361EE),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending reply: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF4361EE),
        ),
      );
    }
  }

  List<Map<String, dynamic>> _getFilteredComplaints() {
    if (_searchQuery.isEmpty) return _complaints;

    return _complaints.where((complaint) {
      final subject = complaint['complaintant']?.toString().toLowerCase() ?? '';
      final description =
          complaint['complaint_content']?.toString().toLowerCase() ?? '';
      final user = complaint['users'] as Map<String, dynamic>;
      final userName = user['name']?.toString().toLowerCase() ?? '';
      final userEmail = user['email']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      return subject.contains(query) ||
          description.contains(query) ||
          userName.contains(query) ||
          userEmail.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> _getPaginatedComplaints() {
    final filteredComplaints = _getFilteredComplaints();
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    if (startIndex >= filteredComplaints.length) return [];
    final endIndex = (startIndex + _itemsPerPage).clamp(
      0,
      filteredComplaints.length,
    );
    return filteredComplaints.sublist(startIndex, endIndex);
  }

  int get _pageCount {
    return (_getFilteredComplaints().length / _itemsPerPage).ceil();
  }

  String _getStatusText(int status) {
    return status == 1 ? 'Replied' : 'Pending';
  }

  Color _getStatusColor(int status) {
    return status == 1 ? const Color(0xFF4CAF50) : Colors.orange.shade100;
  }

  Color _getStatusTextColor(int status) {
    return status == 1 ? const Color(0xFF4CAF50) : Colors.orange.shade800;
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    final date = DateTime.parse(dateString);
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _viewComplaintDetails(Map<String, dynamic> complaint) {
    final user = complaint['users'] as Map<String, dynamic>;
    String? adminNotes = complaint['admin_notes'] as String?;

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.6,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        complaint['complaintant'] ?? 'Complaint Details',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Reported By',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow('Name', user['name'] ?? 'Unknown'),
                            _buildInfoRow('Email', user['email'] ?? 'Unknown'),
                            _buildInfoRow(
                              'Date',
                              _formatDate(complaint['created_at']),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                  complaint['complaint_status'] ?? 0,
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _getStatusText(
                                  complaint['complaint_status'] ?? 0,
                                ),
                                style: TextStyle(
                                  color: _getStatusTextColor(
                                    complaint['complaint_status'] ?? 0,
                                  ),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Complaint Details',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              'Type',
                              complaint['post_id']?.toString() ?? 'General',
                            ),
                            _buildInfoRow(
                              'Subject',
                              complaint['complaintant'] ?? '',
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Description:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(complaint['complaint_content'] ?? ''),
                            ),
                            if (adminNotes != null) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Admin Notes:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(adminNotes),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (complaint['complaint_status'] == 0) ...[
                        OutlinedButton(
                          onPressed:
                              () => _showReplyDialog(
                                complaint['complaint_id'],
                                complaint['admin_notes'] as String?,
                              ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4361EE),
                          ),
                          child: const Text('Reply'),
                        ),
                      ] else ...[
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showReplyDialog(int complaintId, String? existingNotes) {
    String? reply = existingNotes;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Send Reply'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  maxLines: 3,
                  controller: TextEditingController(text: reply ?? ''),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter your reply...',
                  ),
                  onChanged: (value) {
                    reply = value;
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (reply != null && reply!.isNotEmpty) {
                    _sendReply(complaintId, reply!);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4361EE),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Send'),
              ),
            ],
          ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paginatedComplaints = _getPaginatedComplaints();
    final pendingComplaints =
        _getFilteredComplaints()
            .where((c) => c['complaint_status'] == 0)
            .length;
    final repliedComplaints =
        _getFilteredComplaints()
            .where((c) => c['complaint_status'] == 1)
            .length;

    return Scaffold(
      body: Container(
        color: const Color(0xFFF8F9FA),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              child: Row(
                children: [
                  const Text(
                    'Complaints Management',
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
                        hintText: 'Search complaints...',
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Complaints Overview',
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
                      title: 'Total Complaints',
                      value: _getFilteredComplaints().length.toString(),
                      icon: Icons.warning_amber_outlined,
                      iconColor: const Color(0xFF4361EE),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      title: 'Pending',
                      value: pendingComplaints.toString(),
                      icon: Icons.pending_actions,
                      iconColor: Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      title: 'Replied',
                      value: repliedComplaints.toString(),
                      icon: Icons.check_circle_outline,
                      iconColor: const Color(0xFF4CAF50),
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
                      flex: 2,
                      child: Text(
                        'Subject',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'User',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Date',
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
                  _isLoading && _complaints.isEmpty
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4361EE),
                        ),
                      )
                      : paginatedComplaints.isEmpty
                      ? Center(
                        child: Text(
                          'No complaints found',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      )
                      : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: paginatedComplaints.length,
                        separatorBuilder:
                            (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final complaint = paginatedComplaints[index];
                          final user =
                              complaint['users'] as Map<String, dynamic>;
                          final status = complaint['complaint_status'] ?? 0;

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
                                  child: Text(
                                    complaint['complaintant'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    user['name'] ?? '',
                                    style: TextStyle(color: Colors.grey[700]),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    _formatDate(complaint['created_at']),
                                    style: TextStyle(color: Colors.grey[700]),
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
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _getStatusText(status),
                                      style: TextStyle(
                                        color: _getStatusTextColor(status),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.visibility,
                                          color: Color(0xFF4361EE),
                                        ),
                                        onPressed:
                                            () => _viewComplaintDetails(
                                              complaint,
                                            ),
                                        tooltip: 'View Details',
                                      ),
                                      if (status == 0) ...[
                                        IconButton(
                                          icon: const Icon(
                                            Icons.reply,
                                            color: Color(0xFF4361EE),
                                          ),
                                          onPressed:
                                              () => _showReplyDialog(
                                                complaint['complaint_id'],
                                                complaint['admin_notes']
                                                    as String?,
                                              ),
                                          tooltip: 'Reply',
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
            ),
            if (!_isLoading && _getFilteredComplaints().isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${paginatedComplaints.length} of ${_getFilteredComplaints().length} complaints',
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
