import 'package:flutter/material.dart';
import 'package:talentspot/splashscreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talentspot/theam.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(

    url: 'https://nraoqkojrdbjsdtgpvsk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5yYW9xa29qcmRianNkdGdwdnNrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIxMzcyNzQsImV4cCI6MjA1NzcxMzI3NH0.q2cWyIrirQjKvOyVEidXiJ_zKWcIh1-EqojSadeknK0',
  );
  runApp(MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TalentSpot',
      theme: lightTheme(),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}