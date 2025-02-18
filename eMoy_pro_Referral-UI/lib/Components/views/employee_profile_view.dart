import 'package:emoy_pro_referral/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/employee_profile.dart';
import 'package:intl/intl.dart';
import 'employee_registration_form.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:typed_data';

class EmployeeProfileView extends StatefulWidget {
  final EmployeeProfile employee;

  const EmployeeProfileView({super.key, required this.employee});

  @override
 
  _EmployeeProfileViewState createState() => _EmployeeProfileViewState();
}

class _EmployeeProfileViewState extends State<EmployeeProfileView> {
  List<Map<String, dynamic>> _branchList = [];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  String? _selectedGender;
  DateTime? _selectedDate;

   final String referralManagementBaseUrl =
      dotenv.env['REFERRAL_MANAGEMENT_BASE_URL']!;

  @override
  void initState() {
    super.initState();
    _fetchBranchData();
    _firstNameController.text = widget.employee.firstName;
    _lastNameController.text = widget.employee.lastName;
    _mobileController.text = widget.employee.mobileNumber;
    _whatsappController.text = widget.employee.whatsappNumber;
    _emailController.text = widget.employee.email;
    _addressController.text = widget.employee.address;
    _selectedGender = widget.employee.gender;
    _selectedDate = widget.employee.dateOfBirth;
  }

  Future<void> _fetchBranchData() async {
    final String url = '$referralManagementBaseUrl/referrals/branch';
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
        List<dynamic> data = json.decode(response.body);
        setState(() {
          _branchList = data
              .map((e) => {
                    'branch_id': e['branch_id'],
                    'branch_name': e['branch_name']
                  })
              .toList();
        });
      } else {
        throw Exception('Failed to load branches');
      }
    } catch (e) {
      print('Error fetching branch data: $e');
      setState(() {});
    }
  }

  Future<void> _submitForm() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmployeeRegistrationForm(
          employee: widget.employee,
          onSuccess: () {},
        ),
      ),
    );
  }

  ImageProvider _getImageProvider(String imageData) {
    if (imageData.startsWith('http') || imageData.startsWith('https')) {
      return NetworkImage(imageData);
    } else {
      try {
        Uint8List decodedBytes = base64Decode(imageData);
        return MemoryImage(decodedBytes);
      } catch (e) {
        print("Error decoding base64 image: $e");

        return const AssetImage('assets/default_profile.png');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
         backgroundColor: const Color.fromARGB(255, 94, 245, 120),
        title: Text(' My Profile',style: TextStyle(
                  fontFamily: "BAMINI",
                  fontSize: 20,
                  // fontWeight: FontWeight.bold,
                ),),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: _submitForm,
                ),
              ),
             Center(
  child: Stack(
    children: [
      GestureDetector(
        onTap: () {
          if (widget.employee.profileImageUrl?.isNotEmpty ?? false) {
            showDialog(
              context: context,
              builder: (context) => Dialog(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8, 
                  height: MediaQuery.of(context).size.height * 0.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    image: DecorationImage(
                      image: _getImageProvider(widget.employee.profileImageUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            );
          }
        },
        child: CircleAvatar(
          radius: 70,
          backgroundImage: (widget.employee.profileImageUrl?.isNotEmpty ?? false)
              ? _getImageProvider(widget.employee.profileImageUrl!)
              : null,
          child: (widget.employee.profileImageUrl?.isEmpty ?? true)
              ? const Icon(
                  Icons.camera_alt,
                  size: 40,
                  color: Colors.grey,
                )
              : null,
        ),
      ),
    ],
  ),
),

              const SizedBox(height: 8),
              Center(
                child: Text(
                  '${_firstNameController.text} ${_lastNameController.text}',
                  style: const TextStyle(
                      fontSize: 20, fontFamily: "BAMINI"),
                ),
              ),
              const SizedBox(height: 16),
              _buildProfileField('Mobile', _mobileController.text),
              _buildProfileField('WhatsApp', _whatsappController.text),
              _buildProfileField('Email', _emailController.text),
              _buildProfileField('Address', _addressController.text),
              _buildProfileField(
                'Date of Birth',
                _selectedDate != null
                    ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                    : 'Select Date',
              ),
              _buildProfileField('Gender', _selectedGender ?? 'Not specified'),
              
              _buildProfileField(
                  'Branch',
                  _branchList
                      .firstWhere(
                          (branch) =>
                              branch['branch_id'] == widget.employee.branchId,
                          orElse: () => {'branch_name': 'N/A'})['branch_name']
                      .toString()),
              _buildProofField('Identity Proof', widget.employee.identityProof),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900],
                  foregroundColor: Colors.white,
                ),
                child: const Text('Edit'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileField(String label, String value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(
          label,
          style: const TextStyle(fontSize: 16, 
          // fontWeight: FontWeight.bold,
          fontFamily: "BAMINI"),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 16,),
        ),
      ),
    );
  }

  Widget _buildProofField(String label, String? imageData) {
    Uint8List? decodedImage;

    if (imageData != null && imageData.isNotEmpty) {
      try {
        decodedImage = base64Decode(imageData);
      } catch (e) {
        print("Error decoding image: $e");
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(
          label,
          style: const TextStyle(fontSize: 16, 
          // fontWeight: FontWeight.bold,
          fontFamily: "BAMINI"),
        ),
        subtitle: decodedImage != null
            ? Image.memory(decodedImage)
            : const Text('No proof image available'),
      ),
    );
  }
}
