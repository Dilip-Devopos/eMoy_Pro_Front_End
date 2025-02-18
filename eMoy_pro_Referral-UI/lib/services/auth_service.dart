// import 'package:flutter_custom_tabs/flutter_custom_tabs.dart' as custom_tabs;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AuthService {
  final String baseUrl = dotenv.env['KEYCLOAK_URL']!;
  final String clientId = dotenv.env['CLIENT_ID']!;
  final String clientSecret = dotenv.env['CLIENT_SECRET']!;

  // Use platform-specific redirect URIs
  late final String redirectUri;

  final FlutterSecureStorage storage = FlutterSecureStorage();

  bool _isRedirecting = false;

  AuthService() {
    if (true) {
      redirectUri = "emoyproreferral://callback";
    }
  }

  String get authUrl {
    return '$baseUrl/auth?client_id=$clientId'
        '&redirect_uri=$redirectUri'
        '&response_type=code'
        '&scope=openid';
  }

  Future<void> redirectToKeycloak() async {
    if (_isRedirecting) return;

    _isRedirecting = true;
    final Uri url = Uri.parse(authUrl);
    print('Redirecting to Keycloak: $authUrl');

    try {
      bool canOpen = await canLaunchUrl(url);
      if (canOpen) {
        await launchUrl(
          url,
        );
      } else {
        print('Error: Could not launch URL: $authUrl');
      }
    } catch (e) {
      print('Error launching Keycloak URL: $e');
    } finally {
      _isRedirecting = false;
    }
  }

  // Future<void> redirectToKeycloak() async {
  //   if (_isRedirecting) return;

  //   _isRedirecting = true;
  //   final Uri url = Uri.parse(authUrl);
  //   print('Redirecting to Keycloak: $authUrl');

  //   try {
  //     bool canOpen = await canLaunchUrl(url);
  //     if (canOpen) {
  //       await custom_tabs.launchUrl(
  //         url,
  //         customTabsOptions: const custom_tabs.CustomTabsOptions(
  //           showTitle: false,
  //           urlBarHidingEnabled: true,
  //         ),
  //       );
  //     } else {
  //       print('Error: Could not launch URL: $authUrl');
  //     }
  //   } catch (e) {
  //     print('Error launching Keycloak URL: $e');
  //   } finally {
  //     _isRedirecting = false;
  //   }
  // }

  Future<void> handleRedirect(Uri uri) async {
    final code = _extractCode(uri.toString());
    if (code != null) {
      await exchangeCodeAndRefreshToken(code);
    } else {
      print("No code found in URL, redirecting...");
      // redirectToKeycloak();
    }
  }

  String? _extractCode(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['code'];
    } catch (e) {
      print('Error extracting code from URL: $e');
      return null;
    }
  }

  Future<String?> exchangeCodeAndRefreshToken(String code) async {
    final tokenUrl = Uri.parse('$baseUrl/token');

    final body = {
      'client_id': clientId,
      'client_secret': clientSecret,
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': redirectUri,
    };

    try {
      final response = await http.post(
        tokenUrl,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );

      if (response.statusCode == 200) {
        final tokenData = jsonDecode(response.body);
        await _storeTokens(tokenData);

        final bool isExpired = await isTokenExpired();
        if (isExpired) {
          print("Token expired immediately after exchange, refreshing...");
          await refreshToken();
        }

        return await storage.read(key: 'access_token');
      } else {
        print('Token exchange failed: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error during token exchange: $e');
    }
    return null;
  }

  Future<void> _storeTokens(Map<String, dynamic> tokenData) async {
    final int expiresIn = tokenData['expires_in'];
    final DateTime expiryTime =
        DateTime.now().add(Duration(seconds: expiresIn));

    await storage.write(key: 'access_token', value: tokenData['access_token']);
    await storage.write(
        key: 'refresh_token', value: tokenData['refresh_token']);
    await storage.write(key: 'id_token', value: tokenData['id_token']);
    await storage.write(
        key: 'access_token_expiry', value: expiryTime.toIso8601String());
  }

  /// Checks if the token is expired or about to expire
  Future<bool> isTokenExpired() async {
    final expiryTimeStr = await storage.read(key: 'access_token_expiry');
    if (expiryTimeStr != null) {
      final expiryTime = DateTime.parse(expiryTimeStr);
      return DateTime.now().isAfter(expiryTime);
    }
    return true;
  }

  /// Gets the access token, refreshing it if necessary
  Future<String?> getToken() async {
    try {
      final bool expired = await isTokenExpired();
      if (expired) {
        await refreshToken();
      }
      return await storage.read(key: 'access_token');
    } catch (e) {
      print('Error fetching token: $e');
      return null;
    }
  }

  /// Extracts roles from the ID token
  Future<List<String>> getRoles() async {
    final String? idToken = await storage.read(key: 'id_token');
    if (idToken != null) {
      try {
        final jwt = JWT.decode(idToken);

        final realmRoles = jwt.payload['realm_access']?['roles'] ?? [];
        final resourceRoles =
            jwt.payload['resource_access']?[clientId]?['roles'] ?? [];
        final roleIds = jwt.payload['role_id'] ?? [];

        return [
          ...List<String>.from(realmRoles),
          ...List<String>.from(resourceRoles),
          if (roleIds is List)
            // ...List<String>.from(roleIds.map((id) => 'role_$id')),
            ...List<String>.from(roleIds.map((id) => '$id')),
        ];
      } catch (e) {
        print('Error decoding token: $e');
      }
    }
    return [];
  }

  /// Gets the user ID from the ID token
  Future<String?> getUserId() async {
    final String? idToken = await storage.read(key: 'id_token');
    if (idToken != null) {
      try {
        final jwt = JWT.decode(idToken);
        return jwt.payload['user_id'];
      } catch (e) {
        print('Error decoding ID token to get user_id: $e');
      }
    }
    return null;
  }

  /// Gets the preferred username from the ID token
  Future<String?> getPreferredUsername() async {
    final String? idToken = await storage.read(key: 'id_token');
    if (idToken != null) {
      try {
        final jwt = JWT.decode(idToken);
        return jwt.payload['preferred_username'];
      } catch (e) {
        print('Error decoding ID token to get preferred_username: $e');
      }
    }
    return null;
  }

  Future<String?> getBranchId() async {
    final String? idToken = await storage.read(key: 'id_token');
    if (idToken != null) {
      try {
        final jwt = JWT.decode(idToken);
        return jwt.payload['branch_id'];
      } catch (e) {
        print('Error decoding ID token to get branch_id: $e');
      }
    }
    return null;
  }

  /// Refreshes the access token using the refresh token
  Future<void> refreshToken() async {
    try {
      final refreshToken = await storage.read(key: 'refresh_token');

      if (refreshToken != null) {
        final refreshUrl = Uri.parse('$baseUrl/token');

        final body = {
          'client_id': clientId,
          'client_secret': clientSecret,
          'refresh_token': refreshToken,
          'grant_type': 'refresh_token',
        };

        final response = await http.post(
          refreshUrl,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: body,
        );

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          await storage.write(
              key: 'access_token', value: responseData['access_token']);
        } else {
          print('Failed to refresh token: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error refreshing token: $e');
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = await storage.read(key: 'refresh_token');

      if (refreshToken != null) {
        final logoutUrl = Uri.parse('$baseUrl/logout');

        final body = {
          'client_id': clientId,
          'client_secret': clientSecret,
          'refresh_token': refreshToken,
        };

        final response = await http.post(
          logoutUrl,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: body,
        );

        if (response.statusCode == 200) {
          print('Successfully logged out from Keycloak');
        } else {
          print('Failed to log out from Keycloak: ${response.statusCode}');
          print('Response body: ${response.body}');
        }
      }

      await storage.deleteAll();

      // Clear shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Redirect to login page
      redirectToKeycloak();

      // Close the app (optional, for Android)
      SystemNavigator.pop();
    } catch (e) {
      print('Error during logout: $e');
    }
  }
}
