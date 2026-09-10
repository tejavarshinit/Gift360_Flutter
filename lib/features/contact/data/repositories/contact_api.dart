import 'package:dio/dio.dart';

class ContactLeadRequest {
  final String role;
  final String? fullName;
  final String? email;
  final String? companyName;
  final String? phoneNumber;
  final String? contactNo;
  final String? organizationName;
  final String? city;
  final String? state;
  final String? pan;
  final String? gst;
  final String? message;
  final String? sampleInvoiceUrl;

  const ContactLeadRequest({
    required this.role,
    this.fullName,
    this.email,
    this.companyName,
    this.phoneNumber,
    this.contactNo,
    this.organizationName,
    this.city,
    this.state,
    this.pan,
    this.gst,
    this.message,
    this.sampleInvoiceUrl,
  });

  Map<String, dynamic> toJson() => {
    'role': role,
    if (fullName != null) 'fullName': fullName,
    if (email != null) 'email': email,
    if (companyName != null) 'companyName': companyName,
    if (phoneNumber != null) 'phoneNumber': phoneNumber,
    if (contactNo != null) 'contactNo': contactNo,
    if (organizationName != null) 'organizationName': organizationName,
    if (city != null) 'city': city,
    if (state != null) 'state': state,
    if (pan != null) 'pan': pan,
    if (gst != null) 'gst': gst,
    if (message != null) 'message': message,
    if (sampleInvoiceUrl != null) 'sampleInvoiceUrl': sampleInvoiceUrl,
  };
}

class ContactApi {
  final Dio _dio;

  ContactApi(this._dio);

  Future<Map<String, dynamic>> submitLead(ContactLeadRequest request) async {
    final response = await _dio.post('/v1/new-lead-contacts', data: request.toJson());
    return response.data as Map<String, dynamic>;
  }
}
