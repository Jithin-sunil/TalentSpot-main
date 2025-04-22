import 'package:flutter/material.dart';
import 'package:flutter_credit_card/flutter_credit_card.dart';
import 'package:talentspot/main.dart';
import 'package:talentspot/success.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // For date formatting

class PaymentGatewayScreen extends StatefulWidget {
  final int id; // Assuming this is plan_id
  final int amt; // Assuming this is plan_price
  const PaymentGatewayScreen({super.key, required this.id, required this.amt});

  @override
  _PaymentGatewayScreenState createState() => _PaymentGatewayScreenState();
}

class _PaymentGatewayScreenState extends State<PaymentGatewayScreen> {
  final supabase = Supabase.instance.client;
  String cardNumber = '';
  String expiryDate = '';
  String cardHolderName = '';
  String cvvCode = '';
  bool isCvvFocused = false;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  Future<void> _processPayment() async {
    if (!formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields correctly!')),
      );
      return;
    }

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
        return;
      }

      final startDate = DateTime.now();
      final endDate = startDate.add(const Duration(days: 30)); // Assuming 30-day duration; adjust based on plan

      await supabase.from('tbl_subscriptions').insert({
        'user_id': userId,
        'plan_id': widget.id,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'payment_status': 1,
        'created_at': DateTime.now().toIso8601String(),
      });

      await supabase.from('tbl_user').update({
        'user_status': 1,
      }).eq('user_id', userId);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) =>  PaymentSuccessPage()),
      );
    } catch (e) {
      debugPrint('Error processing payment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing payment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Gateway'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.purpleAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              CreditCardWidget(
                cardNumber: cardNumber,
                expiryDate: expiryDate,
                cardHolderName: cardHolderName,
                cvvCode: cvvCode,
                showBackView: isCvvFocused,
                onCreditCardWidgetChange: (creditCardBrand) {},
                isHolderNameVisible: true,
                enableFloatingCard: true,
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      CreditCardForm(
                        cardNumber: cardNumber,
                        expiryDate: expiryDate,
                        cardHolderName: cardHolderName,
                        cvvCode: cvvCode,
                        isHolderNameVisible: true,
                        onCreditCardModelChange: (creditCardModel) {
                          setState(() {
                            cardNumber = creditCardModel.cardNumber;
                            expiryDate = creditCardModel.expiryDate;
                            cardHolderName = creditCardModel.cardHolderName;
                            cvvCode = creditCardModel.cvvCode;
                            isCvvFocused = creditCardModel.isCvvFocused;
                          });
                        },
                        formKey: formKey,
                        cardNumberValidator: (String? value) {
                          if (value == null || value.isEmpty) {
                            return 'This field is required';
                          }
                          if (value.length != 19) {
                            return 'Invalid card number';
                          }
                          return null;
                        },
                        expiryDateValidator: (String? value) {
                          if (value == null || value.isEmpty) {
                            return 'This field is required';
                          }

                          if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(value)) {
                            return 'Invalid expiry date format';
                          }

                          final List<String> parts = value.split('/');
                          final int month = int.tryParse(parts[0]) ?? 0;
                          final int year = int.tryParse(parts[1]) ?? 0;

                          final DateTime now = DateTime.now();
                          final int currentYear = now.year % 100;
                          final int currentMonth = now.month;

                          if (month < 1 || month > 12) {
                            return 'Invalid month';
                          }

                          if (year < currentYear || (year == currentYear && month < currentMonth)) {
                            return 'Card has expired';
                          }

                          return null;
                        },
                        cvvValidator: (String? value) {
                          if (value == null || value.isEmpty) {
                            return 'This field is required';
                          }
                          if (value.length < 3) {
                            return 'Invalid CVV';
                          }
                          return null;
                        },
                        cardHolderValidator: (String? value) {
                          if (value == null || value.isEmpty) {
                            return 'This field is required';
                          }
                          if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(value)) {
                            return 'Invalid cardholder name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                        ),
                        onPressed: _processPayment,
                        child: const Text(
                          'Pay Now',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}