import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiService {
  static const String endpoint =
      "https://script.google.com/macros/s/AKfycbxFZBq1_nbbYITEX0Yp3DQIvVfMWb-TaORgdpgvTMcUL18SMBEZnaPP8Xj09UJp0ejV/exec";

  // Fetch product catalog for retail sales & web storefront
  static Future<List<CatalogItem>> fetchCatalog() async {
    try {
      final response = await http.get(Uri.parse('$endpoint?action=getCatalog'));
      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List list = data['catalog'];
          return list.map((item) => CatalogItem.fromJson(item)).toList();
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

    final payload = {
      "action": "createOrder",
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

    try {
      final response = await http.post(
        Uri.parse(endpoint),
        body: json.encode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = json.decode(response.body);
        return data;
      } else {
        return {
          "success": false,
          "error": "Server returned status code: ${response.statusCode}"
        };
      }
    } catch (e) {
      print('Submit order error: $e');
      return {"success": false, "error": e.toString()};
    }
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
    final payload = {
      "action": "createOrder",
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

    try {
      final response = await http.post(
        Uri.parse(endpoint),
        body: json.encode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 302) {
        return json.decode(response.body);
      } else {
        return {
          "success": false,
          "error": "Server returned status code: ${response.statusCode}"
        };
      }
    } catch (e) {
      print('Submit web order error: $e');
      return {"success": false, "error": e.toString()};
    }
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

    try {
      final response = await http.post(
        Uri.parse(endpoint),
        body: json.encode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 302) {
        return json.decode(response.body);
      } else {
        return {
          "success": false,
          "error": "Server returned status code: ${response.statusCode}"
        };
      }
    } catch (e) {
      print('Submit UTR error: $e');
      return {"success": false, "error": e.toString()};
    }
  }

  // Fetch pending web orders for POS verification queue
  static Future<List<Map<String, dynamic>>> fetchIncomingOrders() async {
    try {
      final response = await http.get(Uri.parse('$endpoint?action=getNewOrders'));
      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List list = data['orders'];
          return List<Map<String, dynamic>>.from(list);
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
    try {
      final payload = {
        "action": "verifyPayment",
        "orderId": orderId,
      };

      final response = await http.post(
        Uri.parse(endpoint),
        body: json.encode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Verify payment error: $e');
      return false;
    }
  }
}