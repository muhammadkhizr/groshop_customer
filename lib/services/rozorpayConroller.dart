import 'dart:convert';

import 'package:gromartconsumer/constants.dart';
import 'package:gromartconsumer/model/createRazorPayOrderModel.dart';
import 'package:gromartconsumer/model/razorpayKeyModel.dart';
import 'package:gromartconsumer/userPrefrence.dart';
import 'package:http/http.dart' as http;

class RazorPayController {
  Future<CreateRazorPayOrderModel?> createOrderRazorPay({required int amount, bool isTopup = false}) async {
    final String orderId = isTopup ? UserPreference.getPaymentId() : UserPreference.getOrderId();
    RazorPayModel razorPayData = UserPreference.getRazorPayData();
    print(razorPayData.razorpayKey);

    final url = "${GlobalURL}payments/razorpay/createorder";
    print(orderId);
    print("currencyData?.code");
    print(currencyData?.code);
    final response = await http.post(
      Uri.parse(url),
      body: {
        "amount": (amount * 100).toString(),
        "receipt_id": orderId,
        "currency": currencyData?.code,
        "razorpaykey": razorPayData.razorpayKey,
        "razorPaySecret": razorPayData.razorpaySecret,
        "isSandBoxEnabled": razorPayData.isSandboxEnabled.toString(),
      },
      // headers: {
      //   "Content-Type" : "application/json",
      // },
    );
    print(response.statusCode);
    print(response.body);

    if (response.statusCode == 200) {
      print(response.statusCode);
      print(response.body);

      try {
        final data = jsonDecode(response.body);
        print(data);

        return CreateRazorPayOrderModel.fromJson(data);
      } catch (e) {
        return null;
      }
    } else {
      return null;
    }
  }
}
