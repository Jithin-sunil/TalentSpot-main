import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:talentspot/payment.dart'; // Import PaymentGatewayScreen

class SubscriptionPlansPage extends StatefulWidget {
  const SubscriptionPlansPage({super.key});

  @override
  State<SubscriptionPlansPage> createState() => _SubscriptionPlansPageState();
}

class _SubscriptionPlansPageState extends State<SubscriptionPlansPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> plans = [];
  Map<String, dynamic>? currentSubscription;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
    _fetchCurrentSubscription();
  }

  Future<void> _fetchPlans() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase.from('tbl_plan').select();
      if (mounted) {
        setState(() {
          plans = List<Map<String, dynamic>>.from(response);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching plans: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load plans')),
      );
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchCurrentSubscription() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => currentSubscription = null);
        return;
      }

      final response = await supabase
          .from('tbl_subscriptions')
          .select('plan_id, start_date, end_date, user_id')
          .eq('user_id', userId)
          .order('end_date', ascending: false)
          .maybeSingle();

      if (mounted) {
        setState(() {
          currentSubscription = response;
        });
      }
    } catch (e) {
      debugPrint('Error fetching subscription: $e');
      if (mounted) setState(() => currentSubscription = null);
    }
  }

  String _formatDate(String? date) {
    if (date == null) return 'N/A';
    try {
      final parsedDate = DateTime.parse(date);
      return DateFormat('dd MMMM yyyy').format(parsedDate);
    } catch (e) {
      return date;
    }
  }

  String _formatAmount(String? amount) {
    if (amount == null) return 'N/A';
    try {
      final numericAmount = double.parse(amount.replaceAll(RegExp(r'[^\d.]'), ''));
      return '\$${numericAmount.toStringAsFixed(2)}';
    } catch (e) {
      return amount;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF4361EE);
    const Color secondaryColor = Color(0xFF64748B);
    const Color accentColor = Colors.white;
    const Color backgroundColor = Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Subscription Plans',
          style: GoogleFonts.poppins(
            fontSize: MediaQuery.of(context).size.width < 600 ? 18 : 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D3748),
          ),
        ),
        backgroundColor: accentColor,
        elevation: 2,
        shadowColor: const Color(0x0D000000).withOpacity(0.05),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: primaryColor),
            onPressed: () {
              _fetchPlans();
              _fetchCurrentSubscription();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: () async {
          await _fetchPlans();
          await _fetchCurrentSubscription();
        },
        child: isLoading
            ? Center(child: CircularProgressIndicator(color: primaryColor))
            : plans.isEmpty && currentSubscription == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.subscriptions_outlined,
                          size: 64,
                          color: secondaryColor.withOpacity(0.7),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No subscription plans available',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: secondaryColor,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Check back later for new plans',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: secondaryColor,
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.05,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current Subscription Section
                        if (currentSubscription != null)
                          Card(
                            color: accentColor,
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            margin: EdgeInsets.only(bottom: 24),
                            child: Padding(
                              padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your Current Plan',
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF2D3748),
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Plan:',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          color: secondaryColor,
                                        ),
                                      ),
                                      Text(
                                        plans.isNotEmpty
                                            ? plans.firstWhere(
                                                (plan) => plan['plan_id'] == currentSubscription!['plan_id'],
                                                orElse: () => {'plan_name': 'Unknown'},
                                              )['plan_name']
                                            : 'Unknown',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF2D3748),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Expires:',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          color: secondaryColor,
                                        ),
                                      ),
                                      Text(
                                        _formatDate(currentSubscription!['end_date']),
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF2D3748),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // Available Plans Section
                        Text(
                          'Available Plans',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2D3748),
                          ),
                        ),
                        SizedBox(height: 16),
                        plans.isEmpty
                            ? Center(
                                child: Text(
                                  'No plans available at the moment',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: secondaryColor,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemCount: plans.length,
                                itemBuilder: (context, index) {
                                  final plan = plans[index];
                                  return Card(
                                    color: accentColor,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    margin: EdgeInsets.only(bottom: 16),
                                    child: Padding(
                                      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            plan['plan_name']?.trim().isNotEmpty ?? false
                                                ? plan['plan_name']
                                                : 'Unknown Plan',
                                            style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF2D3748),
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            plan['plan_description']?.trim().isNotEmpty ?? false
                                                ? plan['plan_description']
                                                : 'No description provided',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: secondaryColor,
                                            ),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Duration: ${plan['plan_duration']?.toString() ?? 'N/A'} days',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  color: secondaryColor,
                                                ),
                                              ),
                                              Text(
                                                'Price: ${_formatAmount(plan['plan_amount']?.toString())}',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  color: secondaryColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 16),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: ElevatedButton(
                                              onPressed: currentSubscription != null
                                                  ? null
                                                  : () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) => PaymentGatewayScreen(
                                                            id: plan['plan_id'],
                                                            amt: int.parse(
                                                              plan['plan_amount'].toString().replaceAll(RegExp(r'[^\d.]'), ''),
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: primaryColor,
                                                foregroundColor: accentColor,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                              ),
                                              child: Text(
                                                'Subscribe',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
      ),
    );
  }
}