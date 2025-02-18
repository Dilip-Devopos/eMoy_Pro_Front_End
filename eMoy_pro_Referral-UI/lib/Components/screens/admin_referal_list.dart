import 'dart:typed_data';

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

class adminView extends StatefulWidget {
  final List<EmployeeProfile> profiles;
  const adminView({super.key, required this.profiles});
  @override
  _adminViewState createState() => _adminViewState();
}

List<ReferralAndProfile> _referrals = [];

class _adminViewState extends State<adminView> {
  bool isLoading = true;
  bool isbooked = false;
  bool isChecked = false;
  int _currentPage = 0;
  final int _pageSize = 6;
  bool _isLoading = false;
  String? startDateStr;
  String? endDateStr;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedActiveCompleted;
  bool isSearchButtonClicked = false;

  final DateFormat _dateFormat = DateFormat('dd-MM-yyyy');

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
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    super.dispose();
  }

  Future<void> _scrollListener() async {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      if (isSearchButtonClicked) {
        final String? branchIdStr = await authService.getBranchId();
        final int? branchId = int.tryParse(branchIdStr ?? '');

        _fetchDateReferralList(
          _startDate != null
              ? DateFormat('dd-MM-yyyy').format(_startDate!)
              : null,
          _endDate != null ? DateFormat('dd-MM-yyyy').format(_endDate!) : null,
          branchId,
          _selectedActiveCompleted,
        );
      } else {
        authService.getBranchId();
        final String? branchId = await authService.getBranchId();
        _fetchUserReferralList(branchId!);
      }
    }
  }

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

  //GET REFERRAL LIST

  Future<List<ReferralAndProfile>?> _fetchUserReferralList(
      String branchId) async {
    if (_isLoading) return null;
    _isLoading = true;

    final url =
        '$referralManagementBaseUrl/referrals/branch/$branchId/$_currentPage/$_pageSize';

    try {
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
        SpinKitFadingCircle(
          color: Colors.blue,
          size: 50.0,
        );
        final List<dynamic> jsonData = json.decode(response.body);
        final List<ReferralAndProfile> referralAndProfiles = jsonData
            .map<ReferralAndProfile>(
                (referralJson) => ReferralAndProfile.fromJson(referralJson))
            .toList();
        setState(() {
          _referrals.addAll(referralAndProfiles);
          _currentPage++;
        });

        _isLoading = false;

        return referralAndProfiles;
      } else if (response.statusCode == 401) {
        print('Error: Unauthorized (401). Token might be invalid or expired.');
      } else if (response.statusCode == 403) {
        print(
            'Error: Forbidden (403). You do not have access to this resource.');
      } else if (response.statusCode == 404) {
        print('Error: Not Found (404). API endpoint might be incorrect.');
      } else {
        print('Error: Unexpected status code ${response.statusCode}');
      }
      _isLoading = false;
      return null;
    } catch (e) {
      print('Error fetching referrals: $e');
      _isLoading = false;
      return null;
    }
  }

//search clear

  void _clearFields() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedActiveCompleted = null;
    });
  }

//Refresh

  void _refreshPage() async {
    setState(() {
      isLoading = true;
      _referrals.clear();
      _currentPage = 0;
    });

    if (isSearchButtonClicked) {
      final String? branchIdStr = await authService.getBranchId();
      final int? branchId = int.tryParse(branchIdStr ?? '');

      _fetchDateReferralList(
        _startDate != null
            ? DateFormat('dd-MM-yyyy').format(_startDate!)
            : null,
        _endDate != null ? DateFormat('dd-MM-yyyy').format(_endDate!) : null,
        branchId,
        _selectedActiveCompleted,
      );
    } else {
      authService.getBranchId();
      final String? branchId = await authService.getBranchId();
      _fetchUserReferralList(branchId!);
    }

    setState(() {
      isLoading = false;
    });
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

  Future<List<EmployeeProfile>?> _fetchProfileList() async {
    try {
      final String? userId = await authService.getUserId();
      if (userId == null || userId.isEmpty) {
        print('Error: User ID is null or empty');
        return null;
      }

      final String url = '$userManagementBaseUrl/profiles/profile/$userId';

      final String? token = await authService.getToken();
      if (token == null || token.isEmpty) {
        print('Error: Token is null or empty');
        return null;
      }

      final String? branchId = await authService.getBranchId();

      if (branchId == null || branchId.isEmpty) {
        print('Error: branch_id is null or empty');
        return null;
      }

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        SpinKitFadingCircle(
          color: Colors.blue,
          size: 50.0,
        );
        final dynamic responseData = json.decode(response.body);

        if (responseData is List && responseData.isNotEmpty) {
          _refreshPage();

          final List<EmployeeProfile> profiles = responseData
              .map<EmployeeProfile>(
                  (profileJson) => EmployeeProfile.fromJson(profileJson))
              .toList();
          return profiles;
        } else {
          print('Error: API response is empty or not a list');
          return null;
        }
      } else if (response.statusCode == 401) {
        print('Error: Unauthorized (401). Token might be invalid or expired.');
      } else if (response.statusCode == 403) {
        print('Error: Forbidden (403). Access is restricted.');
      } else if (response.statusCode == 404) {
        print('Error: Not Found (404). API endpoint might be incorrect.');
      } else {
        print('Error: Unexpected status code ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching profiles: $e');
    }
    return null;
  }

  //function book update

  Future<void> updateApi(int referralInfoId, String referralbooked) async {
    print('Updating referral: $referralInfoId');

    setState(() {
      isbooked = true;
    });

    final url = Uri.parse(
        '$referralManagementBaseUrl/referrals/referral/booked/$referralInfoId');

    try {
      String? token = await AuthService().getToken();

      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authorization token not found.'),
          ),
        );
        return;
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      String updatedStatus = referralbooked == "Y" ? "N" : "Y";
      final body = jsonEncode({'is_referral_booked': updatedStatus});

      final response = await http.put(
        url,
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        SpinKitFadingCircle(
          color: Colors.blue,
          size: 50.0,
        );
        setState(() {
          isChecked = updatedStatus == "Y";
        });

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            Future.delayed(const Duration(seconds: 1), () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/');
            });
            return AlertDialog(
              title: const Text('Success'),
              content: const Text('successfully key Upladed!'),
            );
          },
        );
      } else if (response.statusCode == 400) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Bad Request: Check the request body and API structure.')),
        );
      } else if (response.statusCode == 405) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Method Not Allowed: Check the API method.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update referral status.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        isbooked = false;
      });
    }
  }

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

  //search

  Future<void> _fetchDateReferralList(String? startDate, String? endDate,
      int? branch, String? selectedActiveCompleted) async {
    try {
      String? formattedStartDate;
      String? formattedEndDate;

      DateFormat inputFormat = DateFormat('dd-MM-yyyy');
      DateFormat outputFormat = DateFormat('yyyy-MM-dd');

      if (startDate != null) {
        try {
          formattedStartDate =
              outputFormat.format(inputFormat.parse(startDate));
        } catch (e) {
          print('Error parsing startDate: $e');
        }
      }

      if (endDate != null) {
        try {
          formattedEndDate = outputFormat.format(inputFormat.parse(endDate));
        } catch (e) {
          print('Error parsing endDate: $e');
        }
      }

      String url = '$referralManagementBaseUrl/referrals/referral/search?';

      if (formattedStartDate != null) {
        url += 'startDate=$formattedStartDate&';
      }
      if (formattedEndDate != null) {
        url += 'endDate=$formattedEndDate&';
      }
      if (branch != null) {
        url += 'id=$branch&';
      }
      if (selectedActiveCompleted != null) {
        url += 'is_referral_booked=$selectedActiveCompleted&';
      }

      // Add pagination parameters
      url += 'offset=$_currentPage&limit=$_pageSize';

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
        final List<dynamic> jsonData = json.decode(response.body);
        final List<ReferralAndProfile> referralAndProfiles = jsonData
            .map<ReferralAndProfile>(
                (json) => ReferralAndProfile.fromJson(json))
            .toList();

        setState(() {
          _referrals.addAll(referralAndProfiles);
          _currentPage++;
        });
      } else {
        print('Failed to load referrals: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching referrals: $e');
    }
  }

  // start date
  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2124),
    );

    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  // End Date

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2124),
    );

    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  //profile Add Navigator

  void _navigateToAddEmployee(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/profile',
      (route) => false,
    );
  }

  //Profile view

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

  //base64 to image converter

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
        automaticallyImplyLeading: false,
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Referral List',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: "BAMINI",
                  fontSize: 20,
                  // fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color.fromARGB(255, 94, 245, 120),
        actions: [
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectStartDate(context),
                        child: AbsorbPointer(
                          child: SizedBox(
                            height: 35,
                            child: TextField(
                              controller: TextEditingController(
                                text: _startDate != null
                                    ? _dateFormat.format(_startDate!)
                                    : '',
                              ),
                              decoration: InputDecoration(
                                labelText: 'Start Date',
                                labelStyle: TextStyle(fontFamily: "BAMINI"),
                                filled: true,
                                fillColor: Colors.blueGrey[50],
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 0.0, horizontal: 10.0),
                              ),
                              style: const TextStyle(
                                fontSize: 16.0,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectEndDate(context),
                        child: AbsorbPointer(
                          child: SizedBox(
                            height: 35,
                            child: TextField(
                              controller: TextEditingController(
                                text: _endDate != null
                                    ? _dateFormat.format(_endDate!)
                                    : '',
                              ),
                              decoration: InputDecoration(
                                labelText: 'End Date',
                                labelStyle: TextStyle(fontFamily: "BAMINI"),
                                filled: true,
                                fillColor: Colors.blueGrey[50],
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 0.0, horizontal: 10.0),
                              ),
                              style: const TextStyle(
                                fontSize: 16.0,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: DropdownButtonFormField<String>(
                    value: _selectedActiveCompleted,
                    decoration: InputDecoration(
                      labelText: 'Status',
                      labelStyle: TextStyle(fontFamily: "BAMINI"),
                      filled: true,
                      fillColor: Colors.blueGrey[50],
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 0.0, horizontal: 10.0),
                    ),
                    items: const [
                      DropdownMenuItem<String>(
                        value: 'N',
                        child: Text(
                          'Not Booked',
                          style: TextStyle(
                              fontSize: 16.0,
                              color: Color.fromARGB(255, 8, 8, 8)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      DropdownMenuItem<String>(
                        value: 'Y',
                        child: Text(
                          'Booked',
                          style: TextStyle(
                              fontSize: 16.0,
                              color: Color.fromARGB(255, 8, 8, 8)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    style: const TextStyle(
                      fontSize: 16.0,
                      height: 1.5,
                    ),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedActiveCompleted = newValue;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        width: 100,
                        child: ElevatedButton(
                          onPressed: () async {
                            isSearchButtonClicked = true;
                            _refreshPage();
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.search),
                              SizedBox(width: 5),
                              Text('Search'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _clearFields,
                          child: const Text('Clear'),
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          Expanded(
            child: Stack(
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
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: Text('Referred User Details'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          referralAndProfile
                                                      .profile.profilePicture !=
                                                  null
                                              ? Container(
                                                  width: 200,
                                                  height: 200,
                                                  decoration: BoxDecoration(
                                                    image: DecorationImage(
                                                      image: _decodeBase64Image(
                                                          referralAndProfile
                                                              .profile
                                                              .profilePicture!),
                                                      fit: BoxFit.cover,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                )
                                              : Container(
                                                  width: 100,
                                                  height: 100,
                                                  color: Colors.grey[300],
                                                  child: Icon(Icons.person,
                                                      size: 60.0),
                                                ),
                                          SizedBox(height: 16),
                                          Row(
                                            children: [
                                              Text(
                                                'Employee Name: ',
                                                style: TextStyle(
                                                    // fontWeight: FontWeight.bold,
                                                    fontFamily: "BAMINI"),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  referralAndProfile
                                                      .profile.firstName,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      color: Colors.black),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Text(
                                                'Mobile NO: ',
                                                style: TextStyle(
                                                    // fontWeight:
                                                    //     FontWeight.bold
                                                    ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  referralAndProfile
                                                      .profile.mobileNumber,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      color: Colors.black),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Text(
                                                'WhatsApp No: ',
                                                style: TextStyle(
                                                    // fontWeight:
                                                    //     FontWeight.bold
                                                    ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  referralAndProfile
                                                      .profile.whatsappNumber,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      color: Colors.black),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8),
                                          Row(
                                            children: [
                                              SizedBox(
                                                width: 120,
                                                child: Text(
                                                  'Created Date:',
                                                  style: TextStyle(
                                                    fontFamily: "BAMINI",
                                                    // fontWeight:
                                                    //     FontWeight.bold
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  referral.createdDate != null
                                                      ? DateFormat('dd-MM-yyyy')
                                                          .format(referral
                                                              .createdDate!)
                                                      : 'No date available',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      color: Colors.black),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
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
                              },
                              child: CircleAvatar(
                                backgroundImage:
                                    referralAndProfile.profile.profilePicture !=
                                            null
                                        ? _decodeBase64Image(referralAndProfile
                                            .profile.profilePicture!)
                                        : null,
                                radius: 24,
                                child:
                                    referralAndProfile.profile.profilePicture ==
                                            null
                                        ? Icon(
                                            Icons.person,
                                            size: 40.0,
                                            color: Colors.grey,
                                          )
                                        : null,
                              ),
                            ),
                            title: Text(
                              referral.customerName,
                              style: TextStyle(
                                fontSize: 16.0,
                                fontFamily: "BAMINI",
                                // fontWeight: FontWeight.bold,
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
                                    _getFunctionDescription(
                                        referral.functionName),
                                    style: TextStyle(fontSize: 13),
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
                                IconButton(
                                  icon: Icon(
                                    referral.isReferralBooked == "Y"
                                        ? Icons.check_box
                                        : Icons.check_box_outline_blank,
                                    color: referral.isReferralBooked == "Y"
                                        ? Colors.green
                                        : Colors.grey,
                                    size: 20,
                                  ),
                                  onPressed: referral.isReferralBooked == "N"
                                      ? () {
                                          showDialog(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return AlertDialog(
                                                title: Text("Confirm Booking"),
                                                content: Text(
                                                    "Are you successfully completed the function ?"),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.of(context)
                                                          .pop();
                                                    },
                                                    child: Text("No"),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      updateApi(
                                                          referral
                                                              .referralInfoId,
                                                          referral
                                                              .isReferralBooked);
                                                      Navigator.of(context)
                                                          .pop();
                                                    },
                                                    child: Text("Yes"),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        }
                                      : null,
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
          ),
        ],
      ),
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
