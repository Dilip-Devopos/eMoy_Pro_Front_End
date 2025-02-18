import 'package:emoy_pro_referral/Components/models/employee_referral.dart';
import 'package:emoy_pro_referral/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;


class ReferralViewPage extends StatefulWidget {
  final EmployeeReferral referrals;

  const ReferralViewPage({super.key, required this.referrals});

  @override
  _ReferralViewPageState createState() => _ReferralViewPageState();
}

class _ReferralViewPageState extends State<ReferralViewPage> {
  List<Map<String, dynamic>> _branchList = [];
  List<Map<String, dynamic>> _functionList = [];

  bool _isLoadingBranches = true;

    final String referralManagementBaseUrl =
      dotenv.env['REFERRAL_MANAGEMENT_BASE_URL']!;

  @override
  void initState() {
    super.initState();
    _fetchBranchData();
    _fetchFunctionData();
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
        List<dynamic> data = json.decode(response.body);
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

  @override
  Widget build(BuildContext context) {
    final referrals = widget.referrals;

    return Scaffold(
      appBar: AppBar(
         backgroundColor: const Color.fromARGB(255, 94, 245, 120),
        title: const Text('Referral Details', style: TextStyle(
                  fontFamily: "BAMINI",
                  fontSize: 20,
                  // fontWeight: FontWeight.bold,
                ),),
      ),
      body: _isLoadingBranches
          ? const Center(child: SpinKitFadingCircle(
            color: Colors.blue,
            size: 50.0,
          )  )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: <Widget>[
                  _buildDetailBox('Customer Name', referrals.customerName),
                  _buildDetailBox('Address', referrals.address),
                  _buildDetailBox(
                      'Mobile Number', referrals.customerMobileNumber),
                  _buildDetailBox('Another Mobile Number',
                      referrals.customerWhatsappNumber),
                  _buildDetailBox(
                      'Number of Tables', referrals.noOfTable.toString()),
                  _buildDateField('Date of Function', referrals.dateOfFunction),
                  _buildDetailBox(
                      'Branch',
                      _branchList
                          .firstWhere(
                              (branch) =>
                                  branch['branch_id'] == referrals.branchId,
                              orElse: () =>
                                  {'branch_name': 'N/A'})['branch_name']
                          .toString()),
                  _buildDetailBox(
                      'Function Name',
                      _functionList
                          .firstWhere(
                              (Function) =>
                                  Function['event_id'] ==
                                  referrals.functionName,
                              orElse: () =>
                                  {'description': 'N/A'})['description']
                          .toString()),
                  _buildSelfProposalField(referrals.selfProposal),
                  _buildDetailBox('Description', referrals.description),
                  _buildImageView(referrals.eventPhoto, context),
                  const SizedBox(height: 40),
                 
                ],
              ),
            ),
    );
  }

  Widget _buildDetailBox(String label, String value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 30.0, vertical: 12.0),
        title: Text(
          label,
           style: const TextStyle(fontSize: 16,
            // fontWeight: FontWeight.bold,
            fontFamily: "BAMINI"),
        ),
        subtitle: Text(
          value.isEmpty ? 'N/A' : utf8.decode(value.codeUnits),
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black54,
            fontFamily: 'NotoSansTamil',
          ),
        ),
      ),
    );
  }

  Widget _buildDateField(String label, DateTime? date) {
    return _buildDetailBox(
        label, date == null ? 'N/A' : DateFormat('dd/MM/yyyy').format(date));
  }

  Widget _buildSelfProposalField(String proposal) {
    final proposalText =
        proposal.toUpperCase() == 'YES' ? 'Willing' : 'Not Willing';
    return _buildDetailBox('Self Proposal', proposalText);
  }

  Widget _buildImageView(String? imagePath, BuildContext context) {
    if (imagePath == null || imagePath.isEmpty) {
      return _buildNoImageView();
    }

    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return _buildNetworkImageView(imagePath, context);
    }

    return _buildBase64ImageView(imagePath, context);
  }

  Widget _buildNoImageView() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Text('No image available', style: TextStyle(fontSize: 16)),
    );
  }

  Widget _buildNetworkImageView(String imageUrl, BuildContext context) {
    return GestureDetector(
      onTap: () => _showFullScreenImage(context, NetworkImage(imageUrl)),
      child: Image.network(
        imageUrl,
        errorBuilder: (context, error, stackTrace) {
          return const Text('Failed to load image');
        },
      ),
    );
  }

  Widget _buildBase64ImageView(String imagePath, BuildContext context) {
    try {
      final imageBytes = base64Decode(imagePath);
      return GestureDetector(
        onTap: () => _showFullScreenImage(context, MemoryImage(imageBytes)),
        child: Image.memory(imageBytes),
      );
    } catch (e) {
      return const Text('Invalid image data');
    }
  }

  void _showFullScreenImage(BuildContext context, ImageProvider imageProvider) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            child: Image(image: imageProvider),
          ),
        ),
      ),
    );
  }

}
