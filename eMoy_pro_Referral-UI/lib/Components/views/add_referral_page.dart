import 'dart:isolate';

import 'package:emoy_pro_referral/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/employee_referral.dart';
import 'package:permission_handler/permission_handler.dart';

class AddReferralPage extends StatefulWidget {
  final List<EmployeeReferral> referrals;
  final bool isUpdate;

  const AddReferralPage({
    super.key,
    required this.referrals,
    required this.isUpdate,
    required List employee,
  });

  @override
  AddReferralPageState createState() => AddReferralPageState();
}

class AddReferralPageState extends State<AddReferralPage> {
  List<Map<String, dynamic>> _branchList = [];
  List<Map<String, dynamic>> _functionList = [];
  bool _isLoadingBranches = true;
  bool _isLoadingFunctions = true;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _anotherMobileController = TextEditingController();
  final _numberOfTablesController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  DateTime? _selectedDate;
  int? _selectedBranchId;
  int? _selectedFunction;
  String? _selfProposal;
  final picker = ImagePicker();
  bool _proofImageUploaded = false;
  Uint8List? _invitationImageBase64;

  late stt.SpeechToText _speech;
  bool _isListening = false;

  final String referralManagementBaseUrl =
      dotenv.env['REFERRAL_MANAGEMENT_BASE_URL']!;

  @override
  void initState() {
    super.initState();
    _fetchBranchData();
    _fetchFunctionData();

    _speech = stt.SpeechToText();

    if (widget.referrals.isNotEmpty) {
      _nameController.text = widget.referrals[0].customerName;
      _mobileController.text = widget.referrals[0].customerMobileNumber;
      _anotherMobileController.text =
          widget.referrals[0].customerWhatsappNumber;
      _selectedDate = widget.referrals[0].dateOfFunction ?? DateTime.now();
      _addressController.text = widget.referrals[0].address;
      _numberOfTablesController.text = widget.referrals[0].noOfTable.toString();
      _selfProposal = widget.referrals[0].selfProposal;
      _descriptionController.text =
          utf8.decode((widget.referrals[0].description).codeUnits);

      if (widget.referrals[0].eventPhoto != null) {
        _invitationImageBase64 = base64Decode(widget.referrals[0].eventPhoto!);
        _proofImageUploaded = true;
      }
    }
  }

  // Future<void> _pickImage() async {
  //   final pickedFile = await picker.pickImage(source: ImageSource.gallery);
  //   if (pickedFile != null) {
  //     setState(() {
  //       _convertFileToBytes(pickedFile);
  //       _proofImageUploaded = true;
  //     });
  //   }
  // }

  Future<void> _pickImage() async {
    try {
      setState(() {});

      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        _proofImageUploaded = true;

        final bytes = await pickedFile.readAsBytes();

        final compressedBytes = await compressImage(bytes);

        if (compressedBytes == null) {
          print("Error: Unable to compress image");
          setState(() {});
          return;
        }

        setState(() {
          if (true) {
            _invitationImageBase64 = compressedBytes;
          }
        });
      } else {
        setState(() {});
      }
    } catch (e) {
      print("Error picking/compressing image: $e");
      setState(() {});
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
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (widget.referrals.isEmpty) {
        _createForm();
      } else {
        await _updateForm();
      }
    }
  }

  Future<void> _createForm() async {
    Map<String, dynamic> referralData = await referaldatas(isUpdate: false);

    try {
      String? token = await AuthService().getToken();

      if (token == null || token.isEmpty) {
        print('Error: Token is null or empty');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authorization token not found.'),
          ),
        );
        return;
      }

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=UTF-8',
      };

      final response = await http.post(
        Uri.parse('$referralManagementBaseUrl/referrals/referral'),
        headers: headers,
        body: jsonEncode(referralData),
      );

      // Check response status
      if (response.statusCode == 200) {
        SpinKitFadingCircle(
          color: Colors.blue,
          size: 50.0,
        );
        showDialog(
          context: context,
          builder: (BuildContext context) {
            Future.delayed(const Duration(milliseconds: 500), () {
              Navigator.of(context).pop();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/',
                (route) => false,
              );
            });

            return AlertDialog(
              title: const Text('Success'),
              content: const Text('Referral submitted successfully!'),
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error submitting referral!'),
          ),
        );
      }
    } catch (e) {
      // Handle exceptions
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
    }
  }

  Future<void> _updateForm() async {
    if (widget.referrals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid referral data')),
      );
      return;
    }

    final referralId = widget.referrals[0].referralInfoId;
    Map<String, dynamic> referralData = await referaldatas(isUpdate: true);

    try {
      String? token = await AuthService().getToken();

      if (token == null || token.isEmpty) {
        print('Error: Token is null or empty');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authorization token not found.'),
          ),
        );
        return;
      }

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=UTF-8',
      };

      final response = await http.put(
        Uri.parse('$referralManagementBaseUrl/referrals/referral/$referralId'),
        headers: headers,
        body: jsonEncode(referralData),
      );

      if (response.statusCode == 200) {
        SpinKitFadingCircle(
          color: Colors.blue,
          size: 50.0,
        );

        showDialog(
          context: context,
          builder: (BuildContext context) {
            Future.delayed(const Duration(seconds: 1), () {
              Navigator.of(context).pop();
              Navigator.pushNamedAndRemoveUntil(
                  context, '/', (Route<dynamic> route) => false);
            });
            return AlertDialog(
              title: const Text('Success'),
              content: const Text('Referral updated successfully!'),
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating referral: ${response.body}')),
        );
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exception occurred: $e')),
      );
    }
  }

  final authService = AuthService();

  Future<Map<String, dynamic>> referaldatas({required bool isUpdate}) async {
    return {
      "referral_info_id": widget.referrals.isNotEmpty
          ? widget.referrals[0].referralInfoId
          : null,
      "branch_id": _selectedBranchId,
      "user_id": isUpdate
          ? widget.referrals[0].userId
          : await authService.getUserId() ?? "",
      "event_id": _selectedFunction,
      "customer_name": _nameController.text,
      "address": _addressController.text,
      "date_of_function": DateFormat('yyyy-MM-dd').format(_selectedDate!),
      "customer_mobile_number": _mobileController.text,
      "customer_whatsapp_number": _anotherMobileController.text,
      "no_of_table": _numberOfTablesController.text,
      "self_proposal": _selfProposal,
      "description": _descriptionController.text,
      // "event_photo": _invitationImageBase64,
      'event_photo': _invitationImageBase64 != null
          ? base64Encode(_invitationImageBase64! as List<int>)
          : null,

      "created_by": "suresh",
    };
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
        SpinKitFadingCircle(
          color: Colors.blue,
          size: 50.0,
        );

        List<dynamic> data = json.decode(response.body);
        setState(() {
          _branchList = data
              .map((e) => {
                    'branch_id': e['branch_id'],
                    'branch_name': e['branch_name']
                  })
              .toList();
          _selectedBranchId =
              widget.referrals.isNotEmpty ? widget.referrals[0].branchId : null;
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
        final decodedResponse = utf8.decode(response.bodyBytes);
        List<dynamic> data = json.decode(decodedResponse);

        if (data.isEmpty) {
          print('Empty function data received');
          throw Exception('Received empty function data');
        }

        if (mounted) {
          setState(() {
            _functionList = data
                .map((e) => {
                      'event_id': e['event_id'],
                      'description': e['description'],
                    })
                .toList();

            _selectedFunction = widget.referrals.isNotEmpty
                ? widget.referrals[0].functionName
                : null;

            _isLoadingFunctions = false;
          });
        }
      } else {
        throw Exception('Failed to load functions');
      }
    } catch (e) {
      print('Error fetching function data: $e');
      if (mounted) {
        setState(() {
          _isLoadingFunctions = false;
        });
      }
    }
  }

  Future<void> _startListening() async {
    var status = await Permission.microphone.request();

    if (status.isGranted) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() {
          _isListening = true;
        });
        _speech.listen(
          onResult: (val) => setState(() {
            _descriptionController.text = val.recognizedWords;
          }),
          localeId: "ta-IN",
        );
      }
    } else {
      print("Microphone permission denied");
    }
  }

  void _stopListening() {
    setState(() {
      _isListening = false;
    });
    _speech.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 94, 245, 120),
        title: Text(
          widget.isUpdate ? 'Update Referral' : 'Add Referral',
          style: const TextStyle(
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
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  label: RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Customer Name',
                          style: TextStyle(
                            color: Colors.black,
                            fontFamily: "BAMINI",
                            fontSize: 16,
                          ),
                        ),
                        TextSpan(
                          text: ' *',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  errorStyle: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _mobileController,
                decoration: InputDecoration(
                  label: RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Mobile Number',
                          style: TextStyle(
                            color: Colors.black,
                            fontFamily: "BAMINI",
                            fontSize: 16,
                          ),
                        ),
                        TextSpan(
                          text: ' *',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  errorStyle: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
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
                controller: _anotherMobileController,
                decoration: const InputDecoration(
                  labelText: 'Another Mobile Number',
                  labelStyle: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontFamily: "BAMINI",
                  ),
                  errorStyle: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (value) {
                  if (value != null && value.isNotEmpty && value.length != 10) {
                    return 'Please enter a valid mobile number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const Text(
                      'Date of Function: ',
                      style: TextStyle(
                        // fontWeight: FontWeight.bold,
                        fontFamily: "BAMINI",
                      ),
                    ),
                    TextButton(
                      onPressed: _pickDate,
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: _selectedDate == null
                                  ? 'Select Date'
                                  : DateFormat('dd/MM/yyyy')
                                      .format(_selectedDate!),
                              style: const TextStyle(
                                color: Colors.black,
                                fontFamily: "BAMINI",
                                fontSize: 16,
                              ),
                            ),
                            TextSpan(
                              text: _selectedDate == null ? ' *' : '',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_selectedDate == null)
                      const Text(
                        '',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                  ],
                ),
              ),
              const Divider(
                color: Colors.black,
                thickness: 0.30,
              ),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  label: RichText(
                    text: TextSpan(
                      children: const [
                        TextSpan(
                          text: 'Address',
                          style: TextStyle(
                            color: Colors.black,
                            fontFamily: "BAMINI",
                            fontSize: 16,
                          ),
                        ),
                        TextSpan(
                          text: ' *',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  errorStyle: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 0.30),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue, width: 0.10),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _numberOfTablesController,
                decoration: InputDecoration(
                  label: RichText(
                    text: TextSpan(
                      children: const [
                        TextSpan(
                          text: 'Number of Tables',
                          style: TextStyle(
                            color: Colors.black,
                            fontFamily: "BAMINI",
                            fontSize: 16,
                          ),
                        ),
                        TextSpan(
                          text: ' *',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  errorStyle: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 0.30),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue, width: 0.10),
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(
                      2), // Restricts to 2 characters
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the number of tables';
                  }

                  final intValue = int.tryParse(value);
                  if (intValue == null || intValue < 1 || intValue > 99) {
                    return 'Please enter a valid two-digit number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _isLoadingBranches
                  ? SpinKitFadingCircle(
                      color: Colors.blue,
                      size: 50.0,
                    )
                  : DropdownButtonFormField<int>(
                      value: _selectedBranchId,
                      decoration: InputDecoration(
                        label: RichText(
                          text: TextSpan(
                            children: const [
                              TextSpan(
                                text: 'Branch',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontFamily: "BAMINI",
                                ),
                              ),
                              TextSpan(
                                text: ' *',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
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
                          _selectedBranchId = newValue;
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
              _isLoadingFunctions
                  ? SpinKitFadingCircle(
                      color: Colors.blue,
                      size: 50.0,
                    )
                  : DropdownButtonFormField<int>(
                      value: _selectedFunction,
                      decoration: InputDecoration(
                        label: RichText(
                          text: TextSpan(
                            children: const [
                              TextSpan(
                                text: 'Function Name',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontFamily: "BAMINI",
                                  fontSize: 16,
                                ),
                              ),
                              TextSpan(
                                text: ' *',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
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
                      items: _functionList.isNotEmpty
                          ? _functionList
                              .map<DropdownMenuItem<int>>((functions) {
                              return DropdownMenuItem<int>(
                                value: functions['event_id'],
                                child: Text(functions['description']),
                              );
                            }).toList()
                          : [],
                      onChanged: (int? newValue) {
                        setState(() {
                          _selectedFunction = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a Function name';
                        }
                        return null;
                      },
                    ),
              const SizedBox(height: 20),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text(
                      'Self Proposal:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        // fontFamily: "BAMINI",
                      ),
                    ),
                    const SizedBox(width: 20),
                    const Text('Willing'),
                    Radio<String>(
                      value: 'YES',
                      groupValue: _selfProposal,
                      onChanged: (String? value) {
                        setState(() {
                          _selfProposal = value;
                        });
                      },
                    ),
                    const SizedBox(width: 20),
                    const Text('Not Willing'),
                    Radio<String>(
                      value: 'NO',
                      groupValue: _selfProposal,
                      onChanged: (String? value) {
                        setState(() {
                          _selfProposal = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const Divider(
                color: Colors.black,
                thickness: 0.30,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(
                    fontFamily: "BAMINI",
                    fontSize: 16,
                  ),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 0.30),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue, width: 0.10),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                    onPressed: _isListening ? _stopListening : _startListening,
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Upload Invitation Image:',
                    style: TextStyle(
                      // fontWeight: FontWeight.bold,
                      fontFamily: "BAMINI",
                    ),
                  ),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Row(
                      children: [
                        if (_proofImageUploaded)
                          Row(
                            children: [
                              const Icon(
                                Icons.check,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _proofImageUploaded = false;
                                    _invitationImageBase64 = null;
                                  });
                                },
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          )
                        else
                          const Icon(
                            Icons.upload_file,
                            color: Colors.blue,
                          ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 12, 78, 131),
                  foregroundColor: Colors.white,
                ),
                child: Text(widget.isUpdate ? 'Update' : 'Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Uint8List?> compressImage(Uint8List imageBytes) async {
    const int targetSize = 30 * 1024;
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

    while (compressedBytes != null &&
        compressedBytes.length > targetSize &&
        minQuality <= maxQuality) {
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
