import 'dart:typed_data';
import 'package:emoy_pro_referral/Components/views/add_referral_page.dart';
import 'package:emoy_pro_referral/Components/views/employee_referral_view.dart';
import 'package:emoy_pro_referral/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/employee_profile.dart';
import '../models/employee_referral.dart';
import '../views/employee_profile_view.dart';
import 'package:intl/intl.dart';

class MyprofileView extends StatefulWidget {
  final List<EmployeeProfile> profiles;
  const MyprofileView({super.key, required this.profiles});

  @override
  _MyprofileViewState createState() => _MyprofileViewState();
}

List<ReferralAndProfile> _referrals = [];

class _MyprofileViewState extends State<MyprofileView> {
  bool isLoading = true;
  int _currentPage = 0;
  final int _pageSize = 6;
  bool _isLoading = false;

  List<EmployeeProfile> _profiles = [];

  List<Map<String, dynamic>> _functionList = [];
  final String userManagementBaseUrl = dotenv.env['USER_MANAGEMENT_BASE_URL']!;
  final String referralManagementBaseUrl =
      dotenv.env['REFERRAL_MANAGEMENT_BASE_URL']!;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _profiles.addAll(widget.profiles);
    _checkProfiles();
    _fetchFunctionData();
    _scrollController.addListener(_scrollListener);
    _refreshPage();

    print("test1");
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    super.dispose();
  }

  Future<void> _scrollListener() async {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      authService.getUserId();
      final String? userId = await authService.getUserId();
      _fetchUserReferralList(userId!);
    }
  }

  //Check Profiles

  Future<void> _checkProfiles() async {
    try {
      List<EmployeeProfile>? fetchedProfiles = await _fetchProfileList();
      if (fetchedProfiles != null && fetchedProfiles.isNotEmpty) {
        setState(() {
          _profiles = fetchedProfiles;

          isLoading = false;
        });
      } else {
        _navigateToAddEmployee(context);
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Failed to fetch profiles. Please try again later.")),
      );
    }
  }

  String formatDate(String dateOfFunction) {
    DateTime date = DateTime.parse(dateOfFunction);

    return DateFormat('dd/MM/yyyy').format(date);
  }

  void _refreshPage() async {
    setState(() {
      isLoading = true;
      _referrals.clear();
      _currentPage = 0;
    });

    String? userId = await AuthService().getUserId();
    if (userId != null) {
      await _fetchUserReferralList(userId);
    }

    setState(() {
      isLoading = false;
    });
  }

//GET REFERRAL LIST
  Future<List<ReferralAndProfile>?> _fetchUserReferralList(
      String userId) async {
    if (_isLoading) return null;
    _isLoading = true;

    final url =
        '$referralManagementBaseUrl/referrals/referral/$userId/$_currentPage/$_pageSize';
    try {
      String? token = await AuthService().getToken();
      if (token == null || token.isEmpty) {
        print('Error: Token is null or empty');
        _isLoading = false;
        return null;
      }

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        final List<ReferralAndProfile> referralAndProfiles = jsonData
            .map<ReferralAndProfile>(
                (referralJson) => ReferralAndProfile.fromJson(referralJson))
            .toList();

        setState(() {
          _referrals.addAll(referralAndProfiles);
        });

        _isLoading = false;
        _currentPage++;
        return referralAndProfiles;
      } else {
        print('Error: ${response.statusCode}');
        _isLoading = false;
        return null;
      }
    } catch (e) {
      print('Error fetching referrals: $e');
      _isLoading = false;
      return null;
    }
  }

  //Get Function Data

  Future<void> _fetchFunctionData() async {
    final String url = '$referralManagementBaseUrl/referrals/events';
    try {
      String? token = await AuthService().getToken();

      if (token == null || token.isEmpty) {
        print('Error: Token is null or empty');
        return;
      }

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));

        setState(() {
          _functionList = data
              .map((e) =>
                  {'event_id': e['event_id'], 'description': e['description']})
              .toList();
        });
      } else {
        throw Exception('Failed to load functions');
      }
    } catch (e) {
      print('Error fetching function data: $e');
      setState(() {});
    }
  }

  //Get profile list

  final AuthService authService = AuthService();

  get totalPoints => _referrals[0].referral.totalPoints;

  Future<List<EmployeeProfile>?> _fetchProfileList() async {
    try {
      final userId = await authService.getUserId();
      if (userId == null || userId.isEmpty) {
        print('Error: User ID is null or empty');
        return null;
      }
      final url = '$userManagementBaseUrl/profiles/profile/$userId';

      String? token = await AuthService().getToken();
      if (token == null || token.isEmpty) {
        print('Error: Token is null or empty');
        return null;
      }

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);

        if (jsonData.isNotEmpty && jsonData[0].containsKey('user_id')) {
          // _fetchUserReferralList(jsonData[0]['user_id']);
          _refreshPage();
        } else {
          print('Error: user_id not found in the API response');
        }

        final List<EmployeeProfile> profiles = jsonData
            .map<EmployeeProfile>(
                (profileJson) => EmployeeProfile.fromJson(profileJson))
            .toList();
        return profiles;
      } else if (response.statusCode == 401) {
        print('Error: Unauthorized (401). Token might be invalid or expired.');
      } else if (response.statusCode == 403) {
        print('Error: Forbidden (403). Access is restricted.');
      } else if (response.statusCode == 404) {
        print('Error: Not Found (404). API endpoint might be incorrect.');
      } else {
        print('Error: Unexpected status code ${response.statusCode}');
      }
      return null;
    } catch (e) {
      print('Error fetching profiles: $e');
      return null;
    }
  }

  //Function Description

  String _getFunctionDescription(int functionId) {
    try {
      var function = _functionList.firstWhere(
          (e) => e['event_id'] == functionId,
          orElse: () => {'description': 'Unknown Function'});
      return function['description'];
    } catch (e) {
      return 'Error finding function description';
    }
  }

  //Delete Referal

  Future<void> _deleteReferral(
      EmployeeReferral referral, EmployeeProfile profile) async {
    final url =
        '$referralManagementBaseUrl/referrals/referral/${referral.referralInfoId}/${profile.firstName}';
    try {
      String? token = await AuthService().getToken();

      if (token == null || token.isEmpty) {
        print('Error: Token is null or empty');
        return;
      }

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final response = await http.delete(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        setState(() {
          _referrals.remove(referral);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Referral deleted successfully.')),
        );
        // Navigate to the desired page
        Navigator.pushNamed(context, '/');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to delete referral: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting referral: $e')),
      );
    }
  }

  void _navigateToAddEmployee(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/profile',
      (route) => false,
    );
  }

  void _navigateToReferral(BuildContext context) {
    Navigator.pushNamed(context, '/addReferral').then((result) {
      if (result != null && result == 'Employee added successfully') {}
    });
  }

  //Profile view Navigator

  void _showProfileDetails(EmployeeProfile profile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmployeeProfileView(
          employee: profile,
        ),
      ),
    );
  }

  //Base64 to Image Convert

  ImageProvider _decodeBase64Image(String base64String) {
    try {
      Uint8List bytes = base64Decode(base64String);
      return MemoryImage(bytes);
    } catch (e) {
      return AssetImage('lib/assets/placeholder.png') as ImageProvider;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sharedImageProvider =
        _profiles.isNotEmpty && _profiles[0].profileImageUrl != null
            ? _decodeBase64Image(_profiles[0].profileImageUrl!)
            : null;

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(' MY Referral'),
        ),
        body: Center(
            child: SpinKitFadingCircle(
          color: Colors.blue,
          size: 50.0,
        )),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'My Referral',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: "BAMINI",
                  fontSize: 20,
                  // fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: AssetImage('lib/assets/GoldCoin.jpg'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Text(
                      _referrals.isNotEmpty && totalPoints != null
                          ? totalPoints.toString()
                          : '0',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        // fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 5),
                PopupMenuButton<String>(
                  icon: Icon(Icons.person),
                  onSelected: (String choice) async {
                    if (choice == 'ProfileView') {
                      if (_profiles.isNotEmpty) {
                        _showProfileDetails(_profiles.last);
                      }
                    } else if (choice == 'Logout') {
                      _showLogoutConfirmationDialog(context);
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return [
                      PopupMenuItem(
                        value: 'ProfileView',
                        child: Text('Profile View'),
                      ),
                      PopupMenuItem(
                        value: 'Logout',
                        child: Text('Logout'),
                      ),
                    ];
                  },
                )
              ],
            ),
          ],
        ),
        backgroundColor: const Color.fromARGB(255, 94, 245, 120),
      ),

      body: Stack(
        children: [
          _referrals.isEmpty
              ? Center(child: Text('No referrals available.'))
              : ListView.separated(
                  controller: _scrollController,
                  itemCount: _referrals.length,
                  itemBuilder: (context, index) {
                    final referralAndProfile = _referrals[index];
                    final referral = referralAndProfile.referral;

                    final dateOfFunction = referral.dateOfFunction != null
                        ? DateFormat('dd-MM-yyyy')
                            .format(referral.dateOfFunction!)
                        : 'No date available';

                    return ListTile(
                      leading: GestureDetector(
                        onTap: () {
                          _showProfileDetails(_profiles.last);
                        },
                        child: CircleAvatar(
                          backgroundImage: sharedImageProvider,
                          radius: 24,
                          child: sharedImageProvider == null
                              ? Icon(Icons.person, size: 50, color: Colors.grey)
                              : null,
                        ),
                      ),
                      title: Text(
                        referral.customerName,
                        style: TextStyle(
                          fontSize: 16.0,
                          // fontWeight: FontWeight.bold,
                          fontFamily: "BAMINI",
                          color: Colors.black,
                        ),
                      ),
                      subtitle: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ReferralViewPage(referrals: referral),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getFunctionDescription(referral.functionName),
                              style:
                                  TextStyle(fontFamily: "BAMINI", fontSize: 13),
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    size: 16, color: Colors.grey),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    dateOfFunction,
                                    style: TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  Icon(Icons.phone,
                                      size: 16, color: Colors.grey),
                                  SizedBox(width: 4),
                                  Text(
                                    referral.customerMobileNumber,
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            referral.isReferralBooked.toUpperCase() == 'N'
                                ? Icons.edit_calendar_rounded
                                : Icons.event_available_rounded,
                            color:
                                referral.isReferralBooked.toUpperCase() == 'N'
                                    ? Colors.black
                                    : const Color.fromARGB(255, 5, 177, 11),
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert),
                            onSelected: (value) {
                              if (value == 'Edit') {
                                _onEdit(referral);
                              } else if (value == 'Delete') {
                                if (_profiles.isNotEmpty) {
                                  _confirmDelete(referral, _profiles.last);
                                } else {
                                  print(
                                      "No profiles available for this referral.");
                                }
                              }
                            },
                            itemBuilder: (BuildContext context) {
                              return [
                                PopupMenuItem<String>(
                                    value: 'Edit', child: Text('Edit')),
                                PopupMenuItem<String>(
                                    value: 'Delete', child: Text('Delete')),
                              ];
                            },
                          ),
                        ],
                      ),
                    );
                  },
                  separatorBuilder: (context, index) {
                    return Divider(height: 20, thickness: 1);
                  },
                ),
        ],
      ),

      //Referal Add Button

      floatingActionButton: FloatingActionButton(
        child: Icon(
          Icons.add_comment,
          color: Colors.black,
        ),
        onPressed: () => _navigateToReferral(context),
      ),
    );
  }

  void _onEdit(EmployeeReferral referral) {
    if (referral.isReferralBooked == "Y") {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Action Not Allowed'),
            content: Text('Edit not allowed: Referral is already booked.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddReferralPage(
            referrals: [referral],
            isUpdate: true,
            employee: const [],
          ),
        ),
      );
    }
  }

//Conform delete check

  void _confirmDelete(EmployeeReferral referral, EmployeeProfile profile) {
    // Check if the referral is booked
    if (referral.isReferralBooked == "Y") {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Action Not Allowed'),
            content: Text('Deletion not allowed: Referral is already booked.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
      return; // Exit the function early
    }

    print('name is: $profile');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete this referral?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteReferral(referral, profile);
                print('on pressed is $profile');
              },
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

void _showLogoutConfirmationDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Confirm Logout'),
        content: Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final authService = AuthService();
              await authService.logout();
            },
            child: Text('Yes'),
          ),
        ],
      );
    },
  );
}
