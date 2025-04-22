import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talentspotfilmmaker/filmmaker_applications_page.dart';
import 'package:talentspotfilmmaker/jobcard.dart';
import 'package:talentspotfilmmaker/talentcard.dart';

class DashboardTabsSection extends StatelessWidget {
  final TabController tabController;
  final List<Map<String, dynamic>> recentJobs;
  final List<Map<String, dynamic>> topTalents;
  final int pendingApplications;
  final VoidCallback onPostJob;

  const DashboardTabsSection({
    super.key,
    required this.tabController,
    required this.recentJobs,
    required this.topTalents,
    required this.pendingApplications,
    required this.onPostJob,
  });

  static const Color primaryColor = Color(0xFF6200EE);
  static const Color textPrimaryColor = Color(0xFF1D1D1D);
  static const Color textSecondaryColor = Color(0xFF757575);

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      controller: tabController,
      children: [
        _buildRecentJobsTab(context),
        _buildTopTalentsTab(),
        _buildApplicationsTab(context),
        _buildManageJobsTab(context),
      ],
    );
  }

  Widget _buildRecentJobsTab(BuildContext context) {
    if (recentJobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.work_off_outlined,
              size: 48,
              color: textSecondaryColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No jobs posted yet',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textSecondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: onPostJob,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                'Post a Job',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: recentJobs.length,
      itemBuilder: (context, index) {
        final job = recentJobs[index];
        return JobCard(
          title: job['title'] ?? 'Untitled Job',
          location: job['location'] ?? 'Remote',
          budget: job['budget']?.toString() ?? 'Negotiable',
          date:
              job['created_at'] != null
                  ? DateTime.parse(job['created_at'])
                  : DateTime.now(),
          applicants: job['applicants_count'] ?? 0,
          onTap: () {},
        );
      },
    );
  }

  Widget _buildTopTalentsTab() {
    if (topTalents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 48,
              color: textSecondaryColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No talents available yet',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textSecondaryColor,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: topTalents.length,
      itemBuilder: (context, index) {
        final talent = topTalents[index];
        return TalentCard(
          name: talent['name'] ?? 'Unknown',
          profilePic: talent['profile_pic'] ?? '',
          skills: List<String>.from(talent['skills'] ?? []),
          rating: (talent['rating'] as num?)?.toDouble() ?? 0.0,
          onTap: () {},
        );
      },
    );
  }

  Widget _buildApplicationsTab(BuildContext context) {
    if (pendingApplications == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 48,
              color: textSecondaryColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No pending applications',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textSecondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FilmmakerApplicationsPage(),
                    ),
                  ),
              child: Text(
                'View All Applications',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: primaryColor,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'You have $pendingApplications pending applications',
          style: GoogleFonts.poppins(fontSize: 14, color: textSecondaryColor),
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton(
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FilmmakerApplicationsPage(),
                  ),
                ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Review Applications',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManageJobsTab(BuildContext context) {
    return _ManageJobsTab(onJobCreated: onPostJob);
  }
}

class _ManageJobsTab extends StatefulWidget {
  final VoidCallback onJobCreated;

  const _ManageJobsTab({required this.onJobCreated});

  @override
  State<_ManageJobsTab> createState() => _ManageJobsTabState();
}

class _ManageJobsTabState extends State<_ManageJobsTab>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _jobs = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchJobs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchJobs() async {
    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('tbl_job')
          .select('*, tbl_category(category_name)')
          .eq('filmmaker_id', userId)
          .order('job_lastdate', ascending: false);

      if (mounted) {
        setState(() {
          _jobs = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching jobs: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _jobs = [];
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching jobs: $e')));
      }
    }
  }

  Future<void> _deleteJob(int jobId) async {
    try {
      await supabase.from('tbl_job').delete().eq('job_id', jobId);
      await _fetchJobs();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Job deleted successfully')));
    } catch (e) {
      debugPrint('Error deleting job: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting job: $e')));
    }
  }

  Future<void> _toggleJobStatus(int jobId, String currentStatus) async {
    final newStatus = currentStatus == 'open' ? 'closed' : 'open';

    try {
      await supabase
          .from('tbl_job')
          .update({'job_status': newStatus})
          .eq('job_id', jobId);
      await _fetchJobs();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Job ${newStatus == 'open' ? 'opened' : 'closed'} successfully',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error updating job status: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: DashboardTabsSection.primaryColor,
            unselectedLabelColor: DashboardTabsSection.textSecondaryColor,
            indicatorColor: DashboardTabsSection.primaryColor,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.poppins(),
            tabs: const [Tab(text: 'My Jobs'), Tab(text: 'Create Job')],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMyJobsTab(context),
              CreateJobPage(
                onJobCreated: () {
                  _fetchJobs();
                  widget.onJobCreated();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyJobsTab(BuildContext context) {
    return _isLoading
        ? Center(
          child: CircularProgressIndicator(
            color: DashboardTabsSection.primaryColor,
          ),
        )
        : _jobs.isEmpty
        ? Center(
          child: Text(
            'You haven\'t posted any jobs yet',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: DashboardTabsSection.textSecondaryColor,
            ),
          ),
        )
        : RefreshIndicator(
          onRefresh: _fetchJobs,
          color: DashboardTabsSection.primaryColor,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children:
                      _jobs.map((job) {
                        return SizedBox(
                          width:
                              constraints.maxWidth > 900
                                  ? 400
                                  : constraints.maxWidth,
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          job['job_title'] ?? 'Untitled Job',
                                          style: GoogleFonts.poppins(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                DashboardTabsSection
                                                    .primaryColor,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Location: ${job['job_location'] ?? 'Not specified'}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color:
                                          DashboardTabsSection
                                              .textSecondaryColor,
                                    ),
                                  ),
                                  Text(
                                    'Category: ${job['tbl_category']?['category_name'] ?? 'Not specified'}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color:
                                          DashboardTabsSection
                                              .textSecondaryColor,
                                    ),
                                  ),
                                  Text(
                                    'Deadline: ${job['job_lastdate'] != null ? DateTime.parse(job['job_lastdate']).toString().substring(0, 10) : 'Not set'}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color:
                                          DashboardTabsSection
                                              .textSecondaryColor,
                                    ),
                                  ),
                                  Text(
                                    'Amount: ${job['job_amount'] ?? 'Not specified'}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color:
                                          DashboardTabsSection
                                              .textSecondaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      _buildActionButton(
                                        'View',
                                        Icons.visibility,
                                        () {},
                                      ),
                                      _buildActionButton(
                                        job['job_status'] == 'open'
                                            ? 'Close'
                                            : 'Open',
                                        job['job_status'] == 'open'
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                        () => _toggleJobStatus(
                                          job['job_id'],
                                          job['job_status'] ?? 'open',
                                        ),
                                      ),
                                      _buildActionButton(
                                        'Edit',
                                        Icons.edit,
                                        () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (_) => EditJobPage(job: job),
                                          ),
                                        ).then((_) => _fetchJobs()),
                                      ),
                                      _buildActionButton(
                                        'Delete',
                                        Icons.delete,
                                        () => showDialog(
                                          context: context,
                                          builder:
                                              (_) => AlertDialog(
                                                title: Text(
                                                  'Delete Job',
                                                  style: GoogleFonts.poppins(),
                                                ),
                                                content: Text(
                                                  'Are you sure you want to delete this job? This action cannot be undone.',
                                                  style: GoogleFonts.poppins(),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed:
                                                        () => Navigator.pop(
                                                          context,
                                                        ),
                                                    child: Text(
                                                      'Cancel',
                                                      style:
                                                          GoogleFonts.poppins(),
                                                    ),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                      _deleteJob(job['job_id']);
                                                    },
                                                    child: Text(
                                                      'Delete',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            color: Colors.red,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                        ),
                                        color: Colors.red,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                );
              },
            ),
          ),
        );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onPressed, {
    Color? color,
  }) {
    return TextButton.icon(
      icon: Icon(icon, color: color ?? DashboardTabsSection.textSecondaryColor),
      label: Text(
        label,
        style: GoogleFonts.poppins(
          color: color ?? DashboardTabsSection.textSecondaryColor,
        ),
      ),
      onPressed: onPressed,
    );
  }
}

class CreateJobPage extends StatefulWidget {
  final VoidCallback onJobCreated;

  const CreateJobPage({super.key, required this.onJobCreated});

  @override
  State<CreateJobPage> createState() => _CreateJobPageState();
}

class _CreateJobPageState extends State<CreateJobPage> {
  static const Color primaryColor = Color(0xFF6200EE);
  static const Color textSecondaryColor = Color(0xFF757575);
  static const Color accentColor = Colors.white;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _lastDate = DateTime.now().add(const Duration(days: 30));
  String? _selectedCategoryId;
  bool _isLoading = false;
  bool _isCategoryLoading = true;
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await supabase
          .from('tbl_category')
          .select('id, category_name');
      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(response);
          _selectedCategoryId =
              _categories.isNotEmpty ? _categories[0]['id'].toString() : null;
          _isCategoryLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      if (mounted) {
        setState(() => _isCategoryLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching categories: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _lastDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _lastDate) {
      setState(() => _lastDate = picked);
    }
  }

  Future<void> _createJob() async {
    if (!_formKey.currentState!.validate() || _selectedCategoryId == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await supabase.from('tbl_job').insert({
        'filmmaker_id': userId,
        'job_title': _titleController.text.trim(),
        'job_description': _descriptionController.text.trim(),
        'category_id': _selectedCategoryId,
        'job_location': _locationController.text.trim(),
        'job_amount':
            _amountController.text.isEmpty
                ? null
                : _amountController.text.trim(),
        'job_lastdate': _lastDate.toIso8601String(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job created successfully!')),
      );
      widget.onJobCreated();

      _titleController.clear();
      _descriptionController.clear();
      _locationController.clear();
      _amountController.clear();
      setState(() {
        _lastDate = DateTime.now().add(const Duration(days: 30));
        _selectedCategoryId =
            _categories.isNotEmpty ? _categories[0]['id'].toString() : null;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error creating job: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating job: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child:
          _isCategoryLoading
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create New Job',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      _titleController,
                      'Job Title',
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      _descriptionController,
                      'Job Description',
                      maxLines: 5,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      value: _selectedCategoryId,
                      items:
                          _categories
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c['id'].toString(),
                                  child: Text(
                                    c['category_name'] ?? 'Unknown Category',
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged:
                          (value) =>
                              setState(() => _selectedCategoryId = value),
                      style: GoogleFonts.poppins(color: textSecondaryColor),
                      validator:
                          (value) =>
                              value == null ? 'Please select a category' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      _locationController,
                      'Location',
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      _amountController,
                      'Amount (Optional)',
                      hintText: 'e.g., 500, Negotiable',
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Last Date',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _lastDate.toString().substring(0, 10),
                              style: GoogleFonts.poppins(
                                color: textSecondaryColor,
                              ),
                            ),
                            Icon(
                              Icons.calendar_today,
                              color: textSecondaryColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createJob,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: accentColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child:
                            _isLoading
                                ? CircularProgressIndicator(color: accentColor)
                                : Text(
                                  'Create Job',
                                  style: GoogleFonts.poppins(fontSize: 16),
                                ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    String? hintText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      maxLines: maxLines,
      style: GoogleFonts.poppins(color: textSecondaryColor),
      validator: validator,
    );
  }
}

class EditJobPage extends StatefulWidget {
  final Map<String, dynamic> job;

  const EditJobPage({super.key, required this.job});

  @override
  State<EditJobPage> createState() => _EditJobPageState();
}

class _EditJobPageState extends State<EditJobPage> {
  static const Color primaryColor = Color(0xFF6200EE);
  static const Color textSecondaryColor = Color(0xFF757575);
  static const Color accentColor = Colors.white;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _amountController;
  late DateTime _lastDate;
  late String _selectedCategoryId;
  bool _isLoading = false;
  bool _isCategoryLoading = true;
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.job['job_title'] ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.job['job_description'] ?? '',
    );
    _locationController = TextEditingController(
      text: widget.job['job_location'] ?? '',
    );
    _amountController = TextEditingController(
      text: widget.job['job_amount']?.toString() ?? '',
    );
    _lastDate = DateTime.parse(
      widget.job['job_lastdate'] ?? DateTime.now().toIso8601String(),
    );
    _selectedCategoryId = widget.job['category_id'].toString();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await supabase
          .from('tbl_category')
          .select('id, category_name');
      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(response);
          _isCategoryLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      if (mounted) {
        setState(() => _isCategoryLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching categories: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _lastDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _lastDate) {
      setState(() => _lastDate = picked);
    }
  }

  Future<void> _updateJob() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await supabase
          .from('tbl_job')
          .update({
            'filmmaker_id': userId,
            'job_title': _titleController.text.trim(),
            'job_description': _descriptionController.text.trim(),
            'category_id': _selectedCategoryId,
            'job_location': _locationController.text.trim(),
            'job_amount':
                _amountController.text.isEmpty
                    ? null
                    : _amountController.text.trim(),
            'job_lastdate': _lastDate.toIso8601String(),
          })
          .eq('job_id', widget.job['job_id']);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job updated successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error updating job: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating job: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Edit Job', style: GoogleFonts.poppins(color: accentColor)),
        backgroundColor: primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child:
            _isCategoryLoading
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Job',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildTextField(
                        _titleController,
                        'Job Title',
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        _descriptionController,
                        'Job Description',
                        maxLines: 5,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        value: _selectedCategoryId,
                        items:
                            _categories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c['id'].toString(),
                                    child: Text(c['category_name']),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (value) =>
                                setState(() => _selectedCategoryId = value!),
                        style: GoogleFonts.poppins(color: textSecondaryColor),
                        validator:
                            (value) =>
                                value == null
                                    ? 'Please select a category'
                                    : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        _locationController,
                        'Location',
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        _amountController,
                        'Amount (Optional)',
                        hintText: 'e.g., 500, Negotiable',
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () => _selectDate(context),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Last Date',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _lastDate.toString().substring(0, 10),
                                style: GoogleFonts.poppins(
                                  color: textSecondaryColor,
                                ),
                              ),
                              Icon(
                                Icons.calendar_today,
                                color: textSecondaryColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _updateJob,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: accentColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child:
                              _isLoading
                                  ? CircularProgressIndicator(
                                    color: accentColor,
                                  )
                                  : Text(
                                    'Update Job',
                                    style: GoogleFonts.poppins(fontSize: 16),
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    String? hintText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      maxLines: maxLines,
      style: GoogleFonts.poppins(color: textSecondaryColor),
      validator: validator,
    );
  }
}
