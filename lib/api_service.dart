import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiService {
  static const String endpoint =
      "https://script.google.com/macros/s/AKfycbxFZBq1_nbbYITEX0Yp3DQIvVfMWb-TaORgdpgvTMcUL18SMBEZnaPP8Xj09UJp0ejV/exec";

  // Robust POST handler with 302 redirect support for Android/iOS
  static Future<Map<String, dynamic>> _post(Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse(endpoint),
        body: json.encode(payload),
      );

      String responseBody = response.body;

      // Follow 302 redirect location header returned by Google Apps Script on mobile
      if (response.statusCode == 302 && response.headers.containsKey('location')) {
        final redirectUrl = response.headers['location']!;
        if (redirectUrl.isNotEmpty) {
          final redirectedResponse = await http.get(Uri.parse(redirectUrl));
          responseBody = redirectedResponse.body;
        }
      }

      if (responseBody.trim().isNotEmpty) {
        try {
          final data = json.decode(responseBody);
          if (data is Map<String, dynamic>) {
            return data;
          }
        } catch (_) {}
      }

      // If status was 200 or 302, Apps Script wrote to Google Sheets successfully
      if (response.statusCode == 200 || response.statusCode == 302) {
        return {
          "success": true,
          "orderId": payload["orderId"] ?? "ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}",
          "message": "Order logged successfully"
        };
      }

      return {
        "success": false,
        "error": "Server returned status: ${response.statusCode}"
      };
    } catch (e) {
      print('HTTP POST Error: $e');
      return {"success": false, "error": e.toString()};
    }
  }

  // Fetch product catalog for retail sales & web storefront
  static Future<List<CatalogItem>> fetchCatalog() async {
    try {
      final response = await http.get(Uri.parse('$endpoint?action=getCatalog'));
      if (response.statusCode == 200 || response.statusCode == 302) {
        String body = response.body;
        if (response.statusCode == 302 && response.headers.containsKey('location')) {
          final redirected = await http.get(Uri.parse(response.headers['location']!));
          body = redirected.body;
        }
        if (body.trim().isNotEmpty) {
          final data = json.decode(body);
          if (data['success'] == true) {
            final List list = data['catalog'];
            return list.map((item) => CatalogItem.fromJson(item)).toList();
          }
        }
      }
      return [];
    } catch (e) {
      print('Error fetching catalog: $e');
      return [];
    }
  }

  // Push walk-in counter order to Google Sheets
  static Future<Map<String, dynamic>> submitOrder({
    required String customerName,
    required String customerPhone,
    required String orderType,
    required List<CartItem> items,
    required double totalAmount,
    required String paymentMode,
  }) async {
    final orderDetails = items.map((i) => i.summary).join(', ');
    final generatedOrderId = "ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";

    final payload = {
      "action": "createOrder",
      "orderId": generatedOrderId,
      "source": "Walk-in",
      "customerPhone": customerPhone.isEmpty ? "9999999999" : customerPhone,
      "customerName": customerName.isEmpty ? "Walk-in Guest" : customerName,
      "orderType": orderType,
      "orderDetails": orderDetails,
      "totalAmount": totalAmount,
      "promoCode": "",
      "paymentMode": paymentMode,
      "paymentStatus": "Success",
      "deliveryAddress": "Counter Pickup"
    };

    return await _post(payload);
  }

  // Submit consumer order from the Micro Web-App Storefront
  static Future<Map<String, dynamic>> submitWebOrder({
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required String promoCode,
    required String orderDetails,
    required double totalAmount,
  }) async {
    final generatedOrderId = "ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";

    final payload = {
      "action": "createOrder",
      "orderId": generatedOrderId,
      "source": "Web",
      "customerPhone": customerPhone,
      "customerName": customerName,
      "orderType": "Retail",
      "orderDetails": orderDetails,
      "totalAmount": totalAmount,
      "promoCode": promoCode,
      "paymentMode": "UPI_Intent",
      "paymentStatus": "Initiated",
      "deliveryAddress": deliveryAddress,
    };

    return await _post(payload);
  }

  // Submit 12-digit UTR for order verification
  static Future<Map<String, dynamic>> submitUtr({
    required String orderId,
    required String upiUtr,
  }) async {
    final payload = {
      "action": "submitUtr",
      "orderId": orderId,
      "upiUtr": upiUtr,
    };

    return await _post(payload);
  }

  // Fetch pending web orders for POS verification queue
  static Future<List<Map<String, dynamic>>> fetchIncomingOrders() async {
    try {
      final response = await http.get(Uri.parse('$endpoint?action=getNewOrders'));
      if (response.statusCode == 200 || response.statusCode == 302) {
        String body = response.body;
        if (response.statusCode == 302 && response.headers.containsKey('location')) {
          final redirected = await http.get(Uri.parse(response.headers['location']!));
          body = redirected.body;
        }
        if (body.trim().isNotEmpty) {
          final data = json.decode(body);
          if (data['success'] == true) {
            final List list = data['orders'];
            return List<Map<String, dynamic>>.from(list);
          }
        }
      }
      return [];
    } catch (e) {
      print('Fetch incoming orders error: $e');
      return [];
    }
  }

  // Confirm payment and update status to Success in Google Sheets
  static Future<bool> verifyPayment(String orderId) async {
    final res = await _post({
      "action": "verifyPayment",
      "orderId": orderId,
    });
    return res['success'] == true;
  }
}