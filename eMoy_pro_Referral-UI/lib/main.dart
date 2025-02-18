import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:app_links/app_links.dart';
import 'package:emoy_pro_referral/services/auth_service.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'Components/screens/my_referral_list_view.dart';
import 'Components/screens/admin_referal_list.dart';
import 'Components/screens/superadmin_referal.dart';
import 'Components/views/employee_registration_form.dart';
import 'Components/views/add_referral_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const environment = String.fromEnvironment('ENV', defaultValue: 'dev');
  await dotenv.load(fileName: environment == 'prod' ? '.env.prod' : '.env.dev');

  final authService = AuthService();

  if (Uri.base.queryParameters.containsKey('code')) {
    await authService.handleRedirect(Uri.base);
  } else if (!Uri.base.queryParameters.containsKey('redirected')) {
    await authService.redirectToKeycloak();
  }

  runApp(const MyApp());
}

final String userManagementBaseUrl = dotenv.env['USER_MANAGEMENT_BASE_URL']!;

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AuthService authService = AuthService();
  AppLinks? _appLinks;
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();
    _initDeepLinkListener();
  }

  void _initDeepLinkListener() async {
    _appLinks = AppLinks();
    _sub = _appLinks!.uriLinkStream.listen((Uri uri) {
      print("Received Deep Link: ${uri.toString()}");
      _handleAuthRedirect(uri);
    }, onError: (err) {
      print("Error receiving deep link: $err");
    });

    final Uri? initialLink = await _appLinks!.getInitialAppLink();
    if (initialLink != null) {
      _handleAuthRedirect(initialLink);
    }
  }

  void _handleAuthRedirect(Uri uri) async {
    final code = uri.queryParameters['code'];
    if (code != null) {
      print("Authentication Code: \$code");
      await authService.exchangeCodeAndRefreshToken(code);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Emoy Pro Referral',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (context) => HomeScreen(),
        '/profile': (context) => EmployeeRegistrationForm(
              onSuccess: () {
                Navigator.pop(context, 'Employee added successfully');
              },
            ),
        '/addReferral': (context) => AddReferralPage(
              referrals: const [],
              isUpdate: false,
              employee: const [],
            ),
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  final AuthService authService = AuthService();

  HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchUserDetails(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SpinKitFadingCircle(
              color: Colors.blue,
              size: 50.0,
            ),
          );
        }

        if (snapshot.hasError) {
          print('Error fetching user details: ${snapshot.error}');
          return const Center(
              child: SpinKitFadingCircle(
            color: Color.fromARGB(255, 7, 228, 73),
            size: 50.0,
          ));
        } else if (snapshot.hasData) {
          final data = snapshot.data!;
          final roles = data['roles'] as List<String>;
          final userId = data['user_id'] as String?;
          final username = data['preferred_username'] as String?;
          // Send data to server
          _sendUserDataToServer(
            userId: userId,
            username: username,
            roleId: roles.contains('2') ? '1' : roles.join(','),
          );

          if (roles.contains('2')) {
            return adminView(profiles: const []);
          } else if (roles.contains('1')) {
            return SuperAdminView(profiles: const []);
          } else if (roles.contains('3') || roles.contains('4')) {
            return MyprofileView(
              profiles: const [],
            );
          } else {
            return const Center(child: Text('No access'));
          }
        }

        return const Center(child: Text('No user data found.'));
      },
    );
  }

  Future<Map<String, dynamic>> _fetchUserDetails() async {
    final token = await authService.getToken();

    if (token == null) {
      throw Exception('Token retrieval failed');
    }

    final roles = await authService.getRoles();
    final userId = await authService.getUserId();
    final username = await authService.getPreferredUsername();

    return {
      'roles': roles,
      'user_id': userId,
      'preferred_username': username,
    };
  }

  Future<void> _sendUserDataToServer({
    required String? userId,
    required String? username,
    required String roleId,
  }) async {
    // Validate userId
    if (userId == null || userId.trim().isEmpty) {
      print('Error: user_id is null or empty. Cannot proceed.');
      return;
    }

    final Uri checkUserApiUrl =
        Uri.parse('$userManagementBaseUrl/users/user/$userId');

    print(checkUserApiUrl);

    final Uri apiUrl = Uri.parse('$userManagementBaseUrl/users/user');

    final Map<String, dynamic> userData = {
      'user_id': userId,
      'user_name': username,
      'password': null,
      'role_id': roleId,
      'email': null,
      'date_of_registration': null,
      'last_login': null,
      'created_by': "KeyClock Admin",
      'created_date': DateTime.now().toIso8601String(),
      'updated_by': "KeyClock Admin",
      'updated_date': DateTime.now().toIso8601String(),
    };

    try {
      // Check if user exists
      final checkResponse = await http.get(
        checkUserApiUrl,
        headers: {
          'Authorization': 'Bearer ${await authService.getToken()}',
        },
      );

      final responseBody = jsonDecode(checkResponse.body);

      if (responseBody.isEmpty) {
        print('User record not found. Creating new user...');

        final createResponse = await http.post(
          apiUrl,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${await authService.getToken()}',
          },
          body: jsonEncode(userData),
        );

        if (createResponse.statusCode == 200 ||
            createResponse.statusCode == 201) {
          SpinKitFadingCircle(
            color: Colors.blue,
            size: 50.0,
          );

          print('User data created successfully: ${createResponse.body}');
        } else if (responseBody['user_id'] == userId) {
          print(
              'Failed to create user data. Status code: ${createResponse.statusCode}');
          print('Response body: ${createResponse.body}');
        }
      } else {
        print('User already exists. Updating user data...');

        final updateResponse = await http.put(
          checkUserApiUrl,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${await authService.getToken()}',
          },
          body: jsonEncode(userData),
        );

        if (updateResponse.statusCode == 200) {
          print('User data updated successfully: ${updateResponse.body}');
        } else {
          print(
              'Failed to update user data. Status code: ${updateResponse.statusCode}');
          print('Response body: ${updateResponse.body}');
        }
      }
    } catch (e) {
      print('Error in sending user data: $e');
    }
  }
}
