// ignore_for_file: unnecessary_null_comparison

import 'dart:convert';

import 'package:gromartconsumer/model/FlutterWaveSettingDataModel.dart';
import 'package:gromartconsumer/model/PayFastSettingData.dart';
import 'package:gromartconsumer/model/PayStackSettingsModel.dart';
import 'package:gromartconsumer/model/paytmSettingData.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'model/MercadoPagoSettingsModel.dart';
import 'model/paypalSettingData.dart';
import 'model/razorpayKeyModel.dart';
import 'model/stripeSettingData.dart';

class UserPreference {
  static late SharedPreferences _preferences;

  static Future init() async {
    _preferences = await SharedPreferences.getInstance();
  }

  static const razorPayDataKey = "razorPayData";
  static const _userId = "userId";

  static setUserId({required String userID}) {
    print(userID);
    _preferences.setString(_userId, userID);
  }

  // static getUserId()async{
  //   final String? userID = _preferences.getString(_userId);
  //   print("User id");
  //   print(userID);
  //   return userID != null ? userID : "";
  // }

  static String walletKey = "walletKey";

  static setWalletData(bool isEnable) async {
    print(isEnable);
    print("set wallet data");
    print(isEnable);
    await _preferences.setBool(walletKey, isEnable);
  }

  static getWalletData() {
    final bool? isEnable = _preferences.getBool(walletKey);
    print("get wallet data");
    print(isEnable);
    return isEnable;
  }

  static setRazorPayData(RazorPayModel razorPayModel) async {
    print(razorPayModel);
    print("====hello3");
    print("set razorPay");
    print(razorPayModel.razorpayKey);
    final jsonData = jsonEncode(razorPayModel);
    await _preferences.setString(razorPayDataKey, jsonData);
  }

  static getRazorPayData() {
    final String? jsonData = _preferences.getString(razorPayDataKey);
    print("get razorPay");
    print(jsonData);
    if (jsonData != null) return RazorPayModel.fromJson(jsonDecode(jsonData));
  }

  static String paypalKey = "paypalKey";

  static setPayPalData(PaypalSettingData payPalSettingModel) async {
    print(payPalSettingModel);
    final jsonData = jsonEncode(payPalSettingModel);
    await _preferences.setString(paypalKey, jsonData);
  }

  static getPayPalData() {
    final String? jsonData = _preferences.getString(paypalKey);
    print(jsonDecode(jsonData!));
    if (jsonData != null) return PaypalSettingData.fromJson((jsonDecode(jsonData)));
  }

  static String payFast = "payFast";

  static setPayFastData(PayFastSettingData payFastSettingModel) async {
    print(payFastSettingModel);
    final jsonData = jsonEncode(payFastSettingModel);
    await _preferences.setString(payFast, jsonData);
  }

  static getPayFastData() {
    final String? jsonData = _preferences.getString(payFast);
    print(jsonDecode(jsonData!));
    if (jsonData != null) return PayFastSettingData.fromJson((jsonDecode(jsonData)));
  }

  static String mercadoPago = "mercadoPago";

  static setMercadoPago(MercadoPagoSettingData mercadoPagoSettingData) async {
    final jsonData = jsonEncode(mercadoPagoSettingData);
    await _preferences.setString(mercadoPago, jsonData);
  }

  static getMercadoPago() {
    final String? jsonData = _preferences.getString(mercadoPago);
    if (jsonData != null) return MercadoPagoSettingData.fromJson((jsonDecode(jsonData)));
  }

  static String stripeKey = "stripeKey";

  static setStripeData(StripeSettingData stripeSettingModel) async {
    print(stripeSettingModel);
    final jsonData = jsonEncode(stripeSettingModel);
    await _preferences.setString(stripeKey, jsonData);
  }

  static Future<StripeSettingData> getStripeData() async {
    final String? jsonData = _preferences.getString(stripeKey);
    final stripeData = jsonDecode(jsonData!);
    print(stripeData);
    return StripeSettingData.fromJson(stripeData);
  }

  static String flutterWaveStack = "flutterWaveStack";

  static setFlutterWaveData(FlutterWaveSettingData flutterWaveSettingData) async {
    print(flutterWaveSettingData);
    final jsonData = jsonEncode(flutterWaveSettingData);
    await _preferences.setString(flutterWaveStack, jsonData);
  }

  static Future<FlutterWaveSettingData> getFlutterWaveData() async {
    final String? jsonData = _preferences.getString(flutterWaveStack);
    final flutterWaveData = jsonDecode(jsonData!);
    print(flutterWaveData);
    return FlutterWaveSettingData.fromJson(flutterWaveData);
  }

  static String payStack = "payStack";

  static setPayStackData(PayStackSettingData payStackSettingModel) async {
    print("____>>>12");
    print(payStackSettingModel);
    final jsonData = jsonEncode(payStackSettingModel);
    await _preferences.setString(payStack, jsonData);
  }

  static Future<PayStackSettingData> getPayStackData() async {
    final String? jsonData = _preferences.getString(payStack);
    final payStackData = jsonDecode(jsonData!);
    print("____>>>");
    print(payStackData);
    return PayStackSettingData.fromJson(payStackData);
  }

  static String _paytmKey = "paytmKey";

  static setPaytmData(PaytmSettingData paytmSettingModel) async {
    print(paytmSettingModel);
    final jsonData = jsonEncode(paytmSettingModel);
    await _preferences.setString(_paytmKey, jsonData);
  }

  static getPaytmData() async {
    final String? jsonData = _preferences.getString(_paytmKey);
    final paytmData = jsonDecode(jsonData!);
    print(paytmData);
    return PaytmSettingData.fromJson(paytmData);
  }

  static const _orderId = "orderId";

  static setOrderId({required String orderId}) {
    print("set OrderId");
    print(orderId);
    print("set OrderId");
    _preferences.setString(_orderId, orderId);
  }

  static getOrderId() {
    final String? orderId = _preferences.getString(_orderId);
    return orderId != null ? orderId : "";
  }

  static const _paymentId = "paymentId";

  static setPaymentId({required String paymentId}) {
    print("set PaymentId");
    print(paymentId);
    print("set PaymentId");
    _preferences.setString(_paymentId, paymentId);
  }

  static getPaymentId() {
    final String? paymentId = _preferences.getString(_paymentId);
    return paymentId != null ? paymentId : "";
  }
}
