import 'dart:isolate';

import 'package:emoy_pro_referral/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'dart:io' as io;
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/employee_profile.dart';
import 'dart:convert';
// import 'package:image/image.dart' as img;
import 'package:flutter_image_compress/flutter_image_compress.dart';

class EmployeeRegistrationForm extends StatefulWidget {
  final Function onSuccess;
  final EmployeeProfile? employee;

  const EmployeeRegistrationForm({
    super.key,
    required this.onSuccess,
    this.employee,
  });

  @override
  _EmployeeRegistrationFormState createState() =>
      _EmployeeRegistrationFormState();
}

class _EmployeeRegistrationFormState extends State<EmployeeRegistrationForm> {
  List<Map<String, dynamic>> _branchList = [];
  bool _isLoadingBranches = true;

  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  int? userProfileId;
  DateTime? _selectedDate;
  String? _selectedGender;
  int? _selectedBranch;
  final picker = ImagePicker();
  io.File? profileImageUrl;
  io.File? identityProof;
  Uint8List? profileImageUrlBytes;
  Uint8List? identityProofBytes;
  bool identityProofUploaded = false;
  bool _isCompressing = false;

  final String userManagementBaseUrl = dotenv.env['USER_MANAGEMENT_BASE_URL']!;
  final String referralManagementBaseUrl =
      dotenv.env['REFERRAL_MANAGEMENT_BASE_URL']!;

  @override
  void initState() {
    super.initState();
    _fetchBranchData();

    if (widget.employee != null) {
      _firstNameController.text = widget.employee!.firstName;
      _lastNameController.text = widget.employee!.lastName;
      _selectedGender = widget.employee!.gender;
      _selectedDate = widget.employee!.dateOfBirth;
      _mobileController.text = widget.employee!.mobileNumber;
      _whatsappController.text = widget.employee!.whatsappNumber;
      _emailController.text = widget.employee!.email;
      _addressController.text = widget.employee!.address;

      if (widget.employee!.identityProof != null) {
        identityProofBytes = base64Decode(widget.employee!.identityProof!);
        identityProofUploaded = true;
      }
      if (widget.employee!.profileImageUrl != null) {
        profileImageUrlBytes = base64Decode(widget.employee!.profileImageUrl!);
      }

      _selectedBranch.toString();
    }
  }

Future<void> _pickImage({required bool isProfileImage}) async {
  try {
    setState(() {
      _isCompressing = true;
    });

    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();

      
      final compressedBytes = await compressImage(bytes);

      if (compressedBytes == null) {
        print("Error: Unable to compress image");
        setState(() {
          _isCompressing = false;
        });
        return;
      }

      setState(() {
        _isCompressing = false;
        if (isProfileImage) {
          profileImageUrlBytes = compressedBytes;
        } else {
          identityProofBytes = compressedBytes;
          identityProofUploaded = true;
        }
      });
    } else {
      setState(() {
        _isCompressing = false;
      });
    }
  } catch (e) {
    print("Error picking/compressing image: $e");
    setState(() {
      _isCompressing = false;
    });
  }
}



Future<Uint8List?> compressImageInIsolate(Uint8List imageBytes) async {
  final response = ReceivePort();

  await Isolate.spawn(_compressImageTask, [response.sendPort, imageBytes]);

  return await response.first as Uint8List?;
}

void _compressImageTask(List<dynamic> args) async {
  final sendPort = args[0] as SendPort;
  final imageBytes = args[1] as Uint8List;

  // Perform the compression
  final compressedImage = await compressImage(imageBytes);

  // Send the result back
  sendPort.send(compressedImage);
}
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (widget.employee == null) {
        _submitAddForm();
      } else {
        await submitEditForm(widget.employee!.userProfileId);
      }
    }
  }

  Future<void> _submitAddForm() async {
    if (_formKey.currentState!.validate()) {
      var url = Uri.parse('$userManagementBaseUrl/profiles/profile');

      var formData = {
        "userprofile_id": widget.employee?.isNotEmpty == true
            ? widget.employee?.userProfileId
            : null,
        "user_id": await authService.getUserId() ?? "",
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'gender': _selectedGender!,
        'date_of_birth': _selectedDate != null
            ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
            : null,
        'mobile_number': _mobileController.text,
        'whatsapp_number': _whatsappController.text,
        'email': _emailController.text,
        'address': _addressController.text,
        'branch_id': _selectedBranch!,
        // 'identity_proof': identityProofBytes != null
        //     ? base64Encode(identityProofBytes!)
        //     : null,
       'identity_proof': null,
        'profile_picture': profileImageUrlBytes != null
            ? base64Encode(profileImageUrlBytes!)
            : null,
        "created_by": "EGAISOFT",
        "created_date": null,
        "updated_by": "EGAISOFT",
        "updated_date": null
      };

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

        final response = await http.post(
          url,
          body: jsonEncode(formData),
          headers: headers,
        );

        if (response.statusCode == 200) {
          SpinKitFadingCircle(
            color: Colors.blue,
            size: 50.0,
          );

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              Future.delayed(const Duration(seconds: 1), () {
                Navigator.pop(context);
                widget.onSuccess();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );
              });
              return AlertDialog(
                title: const Text('Success'),
                content: const Text('Employee registered successfully!'),
              );
            },
          );
        } else {
          final responseBody = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Error registering employee: ${responseBody['error']}'),
          ));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
        ));
      }
    }
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

          _selectedBranch = widget.employee!.branchId;
          _isLoadingBranches = false;
        });
      } else {
        throw Exception('Failed to load branches');
      }
    } catch (e) {
      print('Error fetching branch data: $e');
      setState(() {
        _isLoadingBranches = false;
      });
    }
  }

  final authService = AuthService();
  Future<void> submitEditForm(int userProfileId) async {
    if (_formKey.currentState!.validate()) {
      var url =
          Uri.parse('$userManagementBaseUrl/profiles/profile/$userProfileId');

      var formData = {
        "userprofile_id": userProfileId,
        "user_id": await authService.getUserId() ?? "",
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'gender': _selectedGender!,
        'date_of_birth': _selectedDate != null
            ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
            : null,
        'mobile_number': _mobileController.text,
        'whatsapp_number': _whatsappController.text,
        'email': _emailController.text,
        'address': _addressController.text,
        'branch_id': _selectedBranch,
        // 'identity_proof': identityProofBytes != null
        //     ? base64Encode(identityProofBytes!)
        //     : null,
        'identity_proof':null,
        'profile_picture': profileImageUrlBytes != null
            ? base64Encode(profileImageUrlBytes!)
            : null,
        "created_by": "EGAISOFT",
        "created_date": null,
        "updated_by": "EGAISOFT",
        "updated_date": null,
      };

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

        final response = await http.put(
          url,
          body: jsonEncode(formData),
          headers: headers,
        );

        if (response.statusCode == 200) {
          SpinKitFadingCircle(
            color: Colors.blue,
            size: 50.0,
          );
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              Future.delayed(const Duration(seconds: 1), () {
                Navigator.pop(context);
                widget.onSuccess();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );
              });
              return AlertDialog(
                title: const Text('Success'),
                content: const Text('profile update success!...'),
              );
            },
          );
        } else {
          final responseBody = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error updating employee: ${responseBody['error']}'),
          ));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 94, 245, 120),
        title: Text(
          'Add Profile',
          style: TextStyle(
            fontFamily: "BAMINI",
            fontSize: 20,
            // fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _pickImage(isProfileImage: true),
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[200],
                              image: profileImageUrlBytes != null
                                  ? DecorationImage(
                                      image: MemoryImage(profileImageUrlBytes!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: (profileImageUrlBytes == null)
                                ? const Icon(Icons.photo, size: 60)
                                : null,
                          ),
                        ),
                        if (_isCompressing)
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black87.withOpacity(0.5),
                            ),
                            child: const Center(
                              child: SpinKitFadingCircle(
                                color: Colors.blue,
                                size: 50.0,
                              ),
                            ),
                          ),
                        if (profileImageUrlBytes != null)
                          Positioned(
                            top: 70,
                            right: -15,
                            child: IconButton(
                              icon: Icon(Icons.delete,
                                  color: const Color.fromARGB(255, 10, 10, 10)),
                              onPressed: () {
                                setState(() {
                                  profileImageUrlBytes = null;
                                });
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name ',
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 0.10),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue, width: 0.10),
                  ),
                  errorStyle:
                      TextStyle(color: Color.fromARGB(255, 233, 14, 14)),
                  labelStyle: TextStyle(
                      color: Color.fromARGB(255, 8, 8, 8),
                      fontFamily: "BAMINI",
                      // fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter first name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name (Father Name)',
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 0.10),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue, width: 0.10),
                  ),
                  errorStyle: TextStyle(color: Colors.red),
                  labelStyle: TextStyle(
                      color: Colors.black,
                      fontFamily: "BAMINI",
                      // fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter last name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _mobileController,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 0.10),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue, width: 0.10),
                  ),
                  errorStyle: TextStyle(color: Colors.red),
                  labelStyle: TextStyle(
                      color: Colors.black,
                      fontFamily: "BAMINI",
                      // fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty || value.length != 10) {
                    return 'Please enter a valid mobile number';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _whatsappController,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp Number',
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 0.10),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue, width: 0.10),
                  ),
                  errorStyle: TextStyle(color: Colors.red),
                  labelStyle: TextStyle(
                      color: Colors.black,
                      fontFamily: "BAMINI",
                      // fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty || value.length != 10) {
                    return 'Please enter a valid WhatsApp number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email ID',
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 0.10),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue, width: 0.10),
                  ),
                  errorStyle: TextStyle(color: Colors.red),
                  labelStyle: TextStyle(
                      color: Colors.black,
                      fontFamily: "BAMINI",
                      // fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter email ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 0.10),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue, width: 0.10),
                  ),
                  errorStyle: TextStyle(color: Colors.red),
                  labelStyle: TextStyle(
                      color: Colors.black,
                      fontFamily: "BAMINI",
                      // fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
     FormField<DateTime>(
  validator: (value) {
    if (_selectedDate == null) {
      return 'Please select your date';
    }
    return null;
  },
  builder: (FormFieldState<DateTime> field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Date of Birth:',
              style: TextStyle(
                  fontSize: 16,
                  fontFamily: "BAMINI",
                  // fontWeight: FontWeight.bold
                  ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () async {
                await _pickDate();
                field.didChange(_selectedDate);
              },
              child: Text(
                _selectedDate == null
                    ? 'Select Date'
                    : DateFormat('dd/MM/yyyy').format(_selectedDate!),
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
        if (field.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 5.0),
            child: Text(
              field.errorText!,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          ),
      ],
    );
  },
),

              const Divider(
                color: Colors.black,
                thickness: 0.10,
              ),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text(
                      'Gender :  ',
                      style: TextStyle(
                          fontFamily: "BAMINI",
                          // fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                    Radio<String>(
                      value: 'Male',
                      groupValue: _selectedGender,
                      onChanged: (value) {
                        setState(() {
                          _selectedGender = value!;
                        });
                      },
                    ),
                    const Text('Male'),
                    Radio<String>(
                      value: 'Female',
                      groupValue: _selectedGender,
                      onChanged: (value) {
                        setState(() {
                          _selectedGender = value!;
                        });
                      },
                    ),
                    const Text('Female'),
                    Radio<String>(
                      value: 'Other',
                      groupValue: _selectedGender,
                      onChanged: (value) {
                        setState(() {
                          _selectedGender = value!;
                        });
                      },
                    ),
                    const Text('Other'),
                  ],
                ),
              ),
              const Divider(
                color: Colors.black,
                thickness: 0.10,
              ),
              const SizedBox(height: 20),
              _isLoadingBranches
                  ? SpinKitFadingCircle(
                      color: Colors.blue,
                      size: 50.0,
                    )
                  : DropdownButtonFormField<int>(
                      value: _selectedBranch,
                      decoration: const InputDecoration(
                        labelText: 'Branch',
                        labelStyle: TextStyle(
                          fontSize: 16,
                          // fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 115, 124, 250),
                          fontFamily: "BAMINI",
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide:
                              BorderSide(color: Colors.black, width: 0.30),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide:
                              BorderSide(color: Colors.blue, width: 0.10),
                        ),
                      ),
                      items: _branchList.isNotEmpty
                          ? _branchList.map<DropdownMenuItem<int>>((branch) {
                              return DropdownMenuItem<int>(
                                value: branch['branch_id'],
                                child: Text(branch['branch_name']),
                              );
                            }).toList()
                          : [],
                      onChanged: (int? newValue) {
                        setState(() {
                          _selectedBranch = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a branch';
                        }
                        return null;
                      },
                    ),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Upload Any One Proof',
                      style: TextStyle(
                          fontFamily: "BAMINI",
                          // fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _pickImage(isProfileImage: false),
                          icon: identityProofUploaded
                              ? const Icon(Icons.check_circle,
                                  color: Colors.green)
                              : const Icon(Icons.upload, color: Colors.blue),
                          iconSize: 40,
                        ),
                        if (identityProofUploaded) 
                          IconButton(
                            onPressed: () {
                              setState(() {
                                identityProofUploaded = false;
                                identityProofBytes = null;
                              });
                            },
                            icon: const Icon(Icons.delete, color: Colors.red),
                            iconSize: 40,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Text('(Aadhar/driving licence/smartcard)'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
Future<Uint8List?> compressImage(Uint8List imageBytes) async {
  const int targetSize = 25 * 1024; 
  int minWidth = 150; 
  int minHeight = 150;

  // Step 1: Aggressively resize the image
  Uint8List? resizedBytes = await FlutterImageCompress.compressWithList(
    imageBytes,
    minWidth: minWidth,
    minHeight: minHeight,
    quality: 85, 
    keepExif: false,
  );

 
  if (resizedBytes.length <= targetSize) {
    return resizedBytes; 
  }

  
  int minQuality = 10;
  int maxQuality = 85;
  Uint8List? compressedBytes = resizedBytes;

  while (compressedBytes != null && compressedBytes.length > targetSize && minQuality <= maxQuality) {
    final int midQuality = ((minQuality + maxQuality) / 2).floor();

    compressedBytes = await FlutterImageCompress.compressWithList(
      resizedBytes,
      quality: midQuality,
      keepExif: false,
    );

    if (compressedBytes.length > targetSize) {
      minQuality = midQuality + 1; 
    } else {
      maxQuality = midQuality - 1; 
    }
  }

  
  if (compressedBytes != null && compressedBytes.length <= targetSize) {
    return compressedBytes;
  } else {
    print("Error: Could not compress image to 15 KB");
    return null;
  }
}



}
