// ignore_for_file: non_constant_identifier_names, unnecessary_null_comparison

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_braintree/flutter_braintree.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe1;
import 'package:flutterwave_standard/flutterwave.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gromartconsumer/constants.dart';
import 'package:gromartconsumer/main.dart';
import 'package:gromartconsumer/model/CodModel.dart';
import 'package:gromartconsumer/model/FlutterWaveSettingDataModel.dart';
import 'package:gromartconsumer/model/PayFastSettingData.dart';
import 'package:gromartconsumer/model/PayPalCurrencyCodeErrorModel.dart'
as payPalCurrModel;
import 'package:gromartconsumer/model/PayStackSettingsModel.dart';
import 'package:gromartconsumer/model/TaxModel.dart';
import 'package:gromartconsumer/model/createRazorPayOrderModel.dart';
import 'package:gromartconsumer/model/payStackURLModel.dart';
import 'package:gromartconsumer/model/paypalPaymentSettle.dart' as payPalSettel;
import 'package:gromartconsumer/model/razorpayKeyModel.dart';
import 'package:gromartconsumer/model/stripeSettingData.dart';
import 'package:gromartconsumer/services/FirebaseHelper.dart';
import 'package:gromartconsumer/services/helper.dart';
import 'package:gromartconsumer/services/localDatabase.dart';
import 'package:gromartconsumer/services/paystack_url_genrater.dart';
import 'package:gromartconsumer/services/rozorpayConroller.dart';
import 'package:gromartconsumer/ui/checkoutScreen/CheckoutScreen.dart';
import 'package:gromartconsumer/ui/wallet/PayFastScreen.dart';
import 'package:gromartconsumer/ui/wallet/payStackScreen.dart';
import 'package:gromartconsumer/userPrefrence.dart';
import 'package:http/http.dart' as http;
import 'package:mercadopago_sdk/mercadopago_sdk.dart';
import 'package:paytm_allinonesdk/paytm_allinonesdk.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../model/MercadoPagoSettingsModel.dart';
import '../../model/OrderModel.dart';
import '../../model/RazorPayFailedModel.dart';
import '../../model/StripePayFailedModel.dart';
import '../../model/User.dart';
import '../../model/VendorModel.dart';
import '../../model/getPaytmTxtToken.dart';
import '../../model/paypalErrorSettle.dart';
import '../../model/paypalSettingData.dart';
import '../../model/paytmSettingData.dart';
import '../../services/paypalclientToken.dart';
import '../placeOrderScreen/PlaceOrderScreen.dart';
import '../wallet/MercadoPagoScreen.dart';

class PaymentScreen extends StatefulWidget {
  final double total;
  final double? discount;
  final String? couponCode;
  final String? couponId, notes;
  final List<CartProduct> products;

  final List<String>? extra_addons;
  final String? extra_size;
  final String? tipValue;
  final bool? take_away;
  final String? deliveryCharge;
  final TaxModel? taxModel;
  final Map<String, dynamic>? specialDiscountMap;

  const PaymentScreen({
    Key? key,
    required this.total,
    this.discount,
    this.couponCode,
    this.couponId,
    required this.products,
    this.extra_addons,
    this.extra_size,
    this.tipValue,
    this.take_away,
    this.deliveryCharge,
    this.notes,
    this.taxModel,
    this.specialDiscountMap,
  }) : super(key: key);

  @override
  PaymentScreenState createState() => PaymentScreenState();
}

class PaymentScreenState extends State<PaymentScreen> {
  String selectedCardID = '';
  final fireStoreUtils = FireStoreUtils();
  late Future<bool> hasNativePay;

  //List<PaymentMethod> _cards = [];
  late Future<CodModel?> futurecod;

  Stream<DocumentSnapshot<Map<String, dynamic>>>? userQuery;

  static FirebaseFirestore fireStore = FirebaseFirestore.instance;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String paymentOption = 'payViaWallet'.tr();
  RazorPayModel? razorPayData = UserPreference.getRazorPayData();

  Razorpay _razorPay = Razorpay();
  StripeSettingData? stripeData;
  PaytmSettingData? paytmSettingData;
  PaypalSettingData? paypalSettingData;
  PayStackSettingData? payStackSettingData;
  FlutterWaveSettingData? flutterWaveSettingData;
  PayFastSettingData? payFastSettingData;
  MercadoPagoSettingData? mercadoPagoSettingData;

  bool walletBalanceError = false;

  bool isStaging = true;
  String callbackUrl = "http://162.241.125.167/~foodie/payments/paytmpaymentcallback?ORDER_ID=";
  bool restrictAppInvoke = false;
  bool enableAssist = true;
  String result = "";
  String paymentType = "".tr();

  late Map<String, dynamic>? adminCommission;
  String? adminCommissionValue = "", addminCommissionType = "";
  bool? isEnableAdminCommission = false;

  getPaymentSettingData() async {
    userQuery = fireStore.collection(USERS).doc(MyAppState.currentUser!.userID).snapshots();
    await UserPreference.getStripeData().then((value) async {
      stripeData = value;
      stripe1.Stripe.publishableKey = stripeData!.clientpublishableKey;
      stripe1.Stripe.merchantIdentifier = 'Gromart';
      await stripe1.Stripe.instance.applySettings();
    });
    razorPayData = await UserPreference.getRazorPayData();
    paytmSettingData = await UserPreference.getPaytmData();
    paypalSettingData = await UserPreference.getPayPalData();
    payStackSettingData = await UserPreference.getPayStackData();
    flutterWaveSettingData = await UserPreference.getFlutterWaveData();
    payFastSettingData = await UserPreference.getPayFastData();
    mercadoPagoSettingData = await UserPreference.getMercadoPago();
    setRef();
  }

  showAlert(context, {required String response, required Color colors}) {
    return ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(response),
      backgroundColor: colors,
    ));
  }

  @override
  void initState() {
    getPaymentSettingData();
    FireStoreUtils.createOrder();
    futurecod = fireStoreUtils.getCod();
    _razorPay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorPay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWaller);
    _razorPay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    print("delvery charge ${widget.deliveryCharge}");
    fireStoreUtils.getAdminCommission().then((value) {
      if (value != null) {
        setState(() {
          adminCommission = value;
          adminCommissionValue = adminCommission!["adminCommission"].toString();
          addminCommissionType = adminCommission!["adminCommissionType"].toString();
          isEnableAdminCommission = adminCommission!["isAdminCommission"];
          print(adminCommission!["adminCommission"].toString() + "===____");
          print(adminCommission!["isAdminCommission"].toString() + "===____" + isEnableAdminCommission.toString());
        });
      }
    });

    super.initState();
  }


  @override
  void dispose() {

    super.dispose();
  }

  @override
  void didChangeDependencies() {

    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: false,
      key: _scaffoldKey,
      appBar: AppBar(),
      body: ListView(
        physics: BouncingScrollPhysics(),
        padding: EdgeInsets.all(16),
        children: [
          Visibility(
            visible: UserPreference.getWalletData() ?? false,
            child: Column(
              children: [
                Divider(),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: userQuery,
                    builder: (context, AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> asyncSnapshot) {
                      if (asyncSnapshot.hasError) {
                        return Text(
                          "error".tr(),
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        );
                      }
                      if (asyncSnapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 0.8,
                              color: Colors.white,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                        );
                      }
                      if (asyncSnapshot == null || asyncSnapshot.data == null) {
                        return Container();
                      }
                      User userData = User.fromJson(asyncSnapshot.data!.data()!);

                      walletBalanceError = userData.wallet_amount < widget.total ? true : false;
                      return Column(
                        children: [
                          CheckboxListTile(
                            onChanged: (bool? value) {
                              setState(() {
                                if (!walletBalanceError) {
                                  wallet = true;
                                } else {
                                  wallet = false;
                                }
                                mercadoPago = false;
                                payStack = false;
                                flutterWave = false;
                                razorPay = false;
                                codPay = false;
                                payTm = false;
                                pay = false;
                                payFast = false;
                                paypal = false;
                                stripe = false;
                                selectedCardID = '';
                                paymentOption = "payOnlineViaWallet".tr();
                              });
                            },
                            value: wallet,
                            contentPadding: EdgeInsets.all(0),
                            secondary: FaIcon(FontAwesomeIcons.wallet),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('wallet'.tr()),
                                Column(
                                  children: [
                                    Text(
                                      currencyData != null
                                          ? currencyData!.symbol + " " + double.parse(userData.wallet_amount.toString()).toStringAsFixed(decimal)
                                          : "" + double.parse(userData.wallet_amount.toString()).toStringAsFixed(decimal),
                                      style: TextStyle(color: walletBalanceError ? Colors.red : Colors.green, fontWeight: FontWeight.w600, fontSize: 18),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Visibility(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 0.0),
                                  child: walletBalanceError
                                      ? Text(
                                          'yourWalletDoesnotHaveSufficientBalance'.tr(),
                                          style: TextStyle(fontSize: 14, color: Colors.red),
                                        )
                                      : Text(
                                          'sufficientBalance'.tr(),
                                          style: TextStyle(fontSize: 14, color: Colors.green),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }),
              ],
            ),
          ),
          Visibility(
            visible: true,
            child: Column(
              children: [
                Divider(),
                FutureBuilder<CodModel?>(
                    future: futurecod,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting)
                        return Center(
                          child: CircularProgressIndicator.adaptive(
                            valueColor: AlwaysStoppedAnimation(Color(COLOR_PRIMARY)),
                          ),
                        );
                      if (snapshot.hasData) {
                        return snapshot.data!.cod == true
                            ? CheckboxListTile(
                                onChanged: (bool? value) {
                                  setState(() {
                                    mercadoPago = false;
                                    payStack = false;
                                    flutterWave = false;
                                    razorPay = false;
                                    wallet = false;
                                    codPay = true; //codPay ? false : true;
                                    selectedCardID = '';
                                    payTm = false;
                                    payFast = false;
                                    pay = false;
                                    paypal = false;
                                    stripe = false;
                                    paymentOption = 'cashOnDelivery'.tr();
                                  });
                                },
                                value: codPay,
                                contentPadding: EdgeInsets.all(0),
                                secondary: FaIcon(FontAwesomeIcons.handHoldingUsd),
                                title: Text('cashOnDelivery'.tr()),
                              )
                            : Center();
                      }
                      return Center();
                    }),
              ],
            ),
          ),
          Visibility(
            visible: razorPayData!.isEnabled,
            child: Column(
              children: [
                Divider(),
                CheckboxListTile(
                  onChanged: (bool? value) {
                    setState(() {
                      mercadoPago = false;
                      payStack = false;
                      flutterWave = false;
                      wallet = false;
                      razorPay = true; //razorPay ? false : true;
                      codPay = false;
                      payTm = false;
                      pay = false;
                      paypal = false;
                      payFast = false;
                      stripe = false;
                      selectedCardID = '';
                      paymentOption = "payOnlineViaRazorPay".tr();
                    });
                  },
                  value: razorPay,
                  contentPadding: EdgeInsets.all(0),
                  secondary: FaIcon(FontAwesomeIcons.amazonPay),
                  title: Text('razorPay'.tr()),
                ),
              ],
            ),
          ),
          Visibility(
            visible: (stripeData == null) ? false : stripeData!.isEnabled,
            child: Column(
              children: [
                Divider(),
                CheckboxListTile(
                  onChanged: (bool? value) {
                    setState(() {
                      mercadoPago = false;
                      payStack = false;
                      flutterWave = false;
                      stripe = true;
                      wallet = false;
                      razorPay = false; //razorPay ? false : true;
                      codPay = false;
                      payTm = false;
                      payFast = false;
                      pay = false;
                      paypal = false;
                      selectedCardID = '';
                      paymentOption = "payOnlineViaStripe".tr();
                    });
                  },
                  value: stripe,
                  contentPadding: EdgeInsets.all(0),
                  secondary: FaIcon(FontAwesomeIcons.stripe),
                  title: Text('Stripe'.tr()),
                ),
              ],
            ),
          ),
          Visibility(
            visible: (paytmSettingData == null) ? false : paytmSettingData!.isEnabled,
            child: Column(
              children: [
                Divider(),
                CheckboxListTile(
                  onChanged: (bool? value) {
                    setState(() {
                      mercadoPago = false;
                      payStack = false;
                      flutterWave = false;
                      razorPay = false;
                      wallet = false; //razorPay ? false : true;
                      codPay = false;
                      payTm = true;
                      payFast = false;
                      pay = false;
                      paypal = false;
                      stripe = false;
                      selectedCardID = '';
                      paymentOption = "payOnlineViaPayTm".tr();
                    });
                  },
                  value: payTm,
                  contentPadding: EdgeInsets.all(0),
                  secondary: FaIcon(FontAwesomeIcons.alipay),
                  title: Text('payTm'.tr()),
                ),
              ],
            ),
          ),
          Visibility(
            visible: (paypalSettingData == null) ? false : paypalSettingData!.isEnabled,
            child: Column(
              children: [
                Divider(),
                CheckboxListTile(
                  onChanged: (bool? value) {
                    setState(() {
                      mercadoPago = false;
                      payStack = false;
                      flutterWave = false;
                      paypal = true;
                      wallet = false;
                      razorPay = false;
                      codPay = false;
                      payTm = false;
                      pay = false;
                      payFast = false;
                      stripe = false;
                      selectedCardID = '';
                      paymentOption = "payOnlinePayPal".tr();
                    });
                  },
                  value: paypal,
                  contentPadding: EdgeInsets.all(0),
                  secondary: FaIcon(FontAwesomeIcons.paypal),
                  title: Text('paypal'.tr()),
                ),
              ],
            ),
          ),
          Visibility(
            visible: false,
            child: Column(
              children: [
                Divider(),
                CheckboxListTile(
                  onChanged: (bool? value) {
                    setState(() {
                      mercadoPago = false;
                      payStack = false;
                      flutterWave = false;
                      razorPay = false; //razorPay ? false : true;
                      codPay = false;
                      payTm = false;
                      wallet = false;
                      pay = true;
                      payFast = false;
                      paypal = false;
                      stripe = false;
                      selectedCardID = '';
                      paymentOption = "payOnlineViaPay".tr();
                    });
                  },
                  value: pay,
                  contentPadding: EdgeInsets.all(0),
                  secondary: FaIcon(FontAwesomeIcons.googlePay),
                  title: Text('pay'.tr()),
                ),
              ],
            ),
          ),
          Visibility(
            visible: (payFastSettingData == null) ? false : payFastSettingData!.isEnable,
            child: Column(
              children: [
                Divider(),
                CheckboxListTile(
                  onChanged: (bool? value) {
                    setState(() {
                      mercadoPago = false;
                      payFast = true;
                      paypal = false;
                      wallet = false;
                      razorPay = false;
                      payStack = false;
                      codPay = false;
                      payTm = false;
                      pay = false;
                      flutterWave = false;
                      stripe = false;
                      selectedCardID = '';
                      paymentOption = "payOnlinePayFast".tr();
                    });
                  },
                  value: payFast,
                  contentPadding: EdgeInsets.all(0),
                  secondary: Image.asset(
                    'assets/images/payfastmini.png',
                    width: 25,
                    height: 25,
                    color: isDarkMode(context) ? Colors.white : Colors.grey,
                  ),
                  title: Text('payFast'.tr()),
                ),
              ],
            ),
          ),
          Visibility(
            visible: (payStackSettingData == null) ? false : payStackSettingData!.isEnabled,
            child: Column(
              children: [
                Divider(),
                CheckboxListTile(
                  onChanged: (bool? value) {
                    setState(() {
                      mercadoPago = false;
                      payStack = true;
                      paypal = false;
                      flutterWave = false;
                      wallet = false;
                      payFast = false;
                      razorPay = false;
                      codPay = false;
                      payTm = false;
                      pay = false;
                      stripe = false;
                      selectedCardID = '';
                      paymentOption = "payOnlinePayStack".tr();
                    });
                  },
                  value: payStack,
                  contentPadding: EdgeInsets.all(0),
                  secondary: Image.asset(
                    'assets/images/paystackmini.png',
                    width: 25,
                    height: 25,
                    color: isDarkMode(context) ? Colors.white : Colors.grey,
                  ),
                  title: Text('payStack'.tr()),
                ),
              ],
            ),
          ),
          Visibility(
            visible: (flutterWaveSettingData == null) ? false : flutterWaveSettingData!.isEnable,
            child: Column(
              children: [
                Divider(),
                CheckboxListTile(
                  onChanged: (bool? value) {
                    setState(() {
                      mercadoPago = false;
                      payStack = false;
                      flutterWave = true;
                      razorPay = false; //razorPay ? false : true;
                      codPay = false;
                      payTm = false;
                      payFast = false;
                      wallet = false;
                      pay = false;
                      paypal = false;
                      stripe = false;
                      selectedCardID = '';
                      paymentOption = "payOnlineViaFlutterWave".tr();
                    });
                  },
                  value: flutterWave,
                  contentPadding: EdgeInsets.all(0),
                  secondary: FaIcon(FontAwesomeIcons.moneyBillWave),
                  title: Text('flutterWave'.tr()),
                ),
              ],
            ),
          ),
          Visibility(
            visible: (mercadoPagoSettingData == null) ? false : mercadoPagoSettingData!.isEnabled,
            child: Column(
              children: [
                Divider(),
                CheckboxListTile(
                  onChanged: (bool? value) {
                    setState(() {
                      mercadoPago = true;
                      payFast = false;
                      paypal = false;
                      wallet = false;
                      razorPay = false;
                      payStack = false;
                      codPay = false;
                      payTm = false;
                      pay = false;
                      flutterWave = false;
                      stripe = false;
                      selectedCardID = '';
                      paymentOption = "Pay Online Via".tr() + "Mercado Pago";
                    });
                  },
                  value: mercadoPago,
                  contentPadding: EdgeInsets.all(0),
                  secondary: Image.asset(
                    'assets/images/mercadopago.png',
                    width: 25,
                    height: 25,
                  ),
                  title: Text(' Mercado Pago'.tr()),
                ),
              ],
            ),
          ),
          Divider(),
          SizedBox(
            height: 24,
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(20),
              backgroundColor: Color(COLOR_PRIMARY),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              await FireStoreUtils.createPaymentId();

              if (razorPay) {
                paymentType = 'razorpay';
                showLoadingAlert();
                RazorPayController().createOrderRazorPay(amount: widget.total.toInt()).then((value) {
                  if (value == null) {
                    Navigator.pop(context);
                    showAlert(_scaffoldKey.currentContext!, response: "somethingWentWrongPleaseContactAdmin".tr(), colors: Colors.red);
                  } else {
                    CreateRazorPayOrderModel result = value;
                    openCheckout(
                      amount: widget.total,
                      orderId: result.id,
                    );
                  }
                });
              } else if (payFast) {
                paymentType = 'payfast';
                showLoadingAlert();
                PayStackURLGen.getPayHTML(payFastSettingData: payFastSettingData!, amount: widget.total.toString()).then((value) async {
                  bool isDone = await Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => PayFastScreen(
                            htmlData: value,
                            payFastSettingData: payFastSettingData!,
                          )));

                  print(isDone);
                  if (isDone) {
                    if (widget.take_away!) {
                      placeOrder(_scaffoldKey.currentContext!);
                    } else {
                      push(
                        _scaffoldKey.currentContext!,
                        CheckoutScreen(
                          isPaymentDone: true,
                          total: widget.total,
                          discount: widget.discount!,
                          paymentType: this.paymentType,
                          couponCode: widget.couponCode!,
                          couponId: widget.couponId!,
                          paymentOption: paymentOption,
                          products: widget.products,
                          deliveryCharge: widget.deliveryCharge,
                          tipValue: widget.tipValue,
                          take_away: widget.take_away,
                          taxModel: widget.taxModel,
                          notes: widget.notes,
                          extra_size: widget.extra_size,
                          extra_addons: widget.extra_addons,
                          specialDiscountMap: widget.specialDiscountMap,
                        ),
                      );
                    }

                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                        "paymentSuccessful".tr() + "\n",
                      ),
                      backgroundColor: Colors.green.shade400,
                      duration: Duration(seconds: 6),
                    ));
                  } else {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                        "paymentUnSuccessful".tr() + "\n",
                      ),
                      backgroundColor: Colors.red.shade400,
                      duration: Duration(seconds: 6),
                    ));
                  }
                });
              } else if (payTm) {
                paymentType = 'paytm';
                showLoadingAlert();
                getPaytmCheckSum(context, amount: widget.total);
              } else if (mercadoPago) {
                paymentType = 'mercadoPago';
                showLoadingAlert();
                mercadoPagoMakePayment();
              } else if (stripe) {
                paymentType = 'stripe';
                showLoadingAlert();
                stripeMakePayment(amount: widget.total.toString());
              } else if (pay) {
                // Navigator.push(
                //     context,
                //     MaterialPageRoute(
                //         builder: (context) =>
                //             FlutterWavePayService() //UniPaymentService()
                //         ));
              } else if (payStack) {
                paymentType = 'paystack';
                showLoadingAlert();
                payStackPayment(context);
              } else if (flutterWave) {
                paymentType = 'flutterwave';
                _flutterWaveInitiatePayment(context);
              } else if (paypal) {
                paymentType = 'paypal';
                showLoadingAlert();
                _makePaypalPayment(amount: widget.total.toString());
              } else if (wallet && walletBalanceError == false) {
                paymentType = 'wallet';
                print("hello payment via Wallet  ${widget.total}");
                showLoadingAlert();
                FireStoreUtils.createPaymentId().then((value) {
                  final paymentID = value;
                  String orderId = UserPreference.getOrderId();
                  FireStoreUtils.topUpWalletAmount(paymentMethod: "Wallet", isTopup: false, orderId: orderId, amount: widget.total, id: paymentID)
                      .then((value) {
                    FireStoreUtils.updateWalletAmount(amount: -widget.total).then((value) {
                      if (widget.take_away!) {
                        placeOrder(_scaffoldKey.currentContext!, oid: orderId);
                      } else {
                        Navigator.pop(context);
                        toCheckOutScreen(true, context);
                      }
                    }).whenComplete(() {
                      showAlert(_scaffoldKey.currentContext!, response: "paymentSuccessfulViaWallet".tr(), colors: Colors.green);
                    });
                  });
                });
              } else if (codPay) {
                paymentType = 'cod';
                print(DateTime.now().millisecondsSinceEpoch.toString());
                if (widget.take_away!) {
                  placeOrder(_scaffoldKey.currentContext!);
                } else {
                  toCheckOutScreen(false, context);
                }
              } else {
                final SnackBar snackBar = SnackBar(
                  content: Text(
                    "selectPaymentMethod".tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Color(COLOR_PRIMARY),
                );
                ScaffoldMessenger.of(context).showSnackBar(snackBar);
              }
            },
            child: Text(
              'proceed'.tr(),
              style: TextStyle(color: isDarkMode(context) ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  bool payStack = false;
  bool flutterWave = false;
  bool wallet = false;
  bool razorPay = false;
  bool payFast = false;
  bool mercadoPago = false;
  bool codPay = false;
  bool payTm = false;
  bool pay = false;
  bool stripe = false;
  bool paypal = false;

  ///RazorPay payment function
  void openCheckout({required amount, required orderId}) async {
    var options = {
      'key': razorPayData!.razorpayKey,
      'amount': amount * 100,
      'name': 'Groshop',
      'order_id': orderId,
      "currency": currencyData?.code,
      'description': 'wallet Topup',
      'retry': {'enabled': true, 'max_count': 1},
      'send_sms_hash': true,
      'prefill': {
        'contact': MyAppState.currentUser!.phoneNumber,
        'email': MyAppState.currentUser!.email,
      },
      'external': {
        'wallets': ['paytm']
      }

    };

    try {
      _razorPay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    Navigator.pop(_scaffoldKey.currentContext!);
    print(response.orderId);
    print(response.paymentId);
    if (widget.take_away!) {
      placeOrder(_scaffoldKey.currentContext!);
    } else {
      toCheckOutScreen(true, _scaffoldKey.currentContext!);
    }

    ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(
      content: Text(
        "paymentSuccessful".tr() + "\n" + response.orderId!,
      ),
      backgroundColor: Colors.green.shade400,
      duration: Duration(seconds: 6),
    ));
  }

  void _handleExternalWaller(ExternalWalletResponse response) {
    Navigator.pop(_scaffoldKey.currentContext!);
    ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(
      content: Text(
        "paymentProccessingVia".tr() + "\n" + response.walletName!,
      ),
      backgroundColor: Colors.blue.shade400,
      duration: Duration(seconds: 8),
    ));
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    Navigator.pop(_scaffoldKey.currentContext!);
    print(response.code);
    RazorPayFailedModel lom = RazorPayFailedModel.fromJson(jsonDecode(response.message!.toString()));
    ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(
      content: Text(
        "paymentFailed".tr() + "\n" + lom.error.description,
      ),
      backgroundColor: Colors.red.shade400,
      duration: Duration(seconds: 8),
    ));
  }

  ///Stripe payment function
  Map<String, dynamic>? paymentIntentData;

  Future<void> stripeMakePayment({required String amount}) async {
    try {
      paymentIntentData = await createStripeIntent(amount);
      if (paymentIntentData!.containsKey("error")) {
        Navigator.pop(context);
        showAlert(_scaffoldKey.currentContext!, response: "somethingWentWrongPleaseContactAdmin".tr(), colors: Colors.red);
      } else {
        await stripe1.Stripe.instance
            .initPaymentSheet(
                paymentSheetParameters: stripe1.SetupPaymentSheetParameters(
              paymentIntentClientSecret: paymentIntentData!['client_secret'],
              applePay: true,
              allowsDelayedPaymentMethods: false,
              googlePay: true,
              testEnv: false,
              //!stripeData!.isSandboxEnabled,
              style: ThemeMode.system,
              merchantCountryCode: 'US',
              currencyCode: currencyData!.code,
              // appearance: stripe1.PaymentSheetAppearance(
              //   colors: stripe1.PaymentSheetAppearanceColors(
              //     primary: Color(COLOR_PRIMARY),
              //   ),
              // ),
              merchantDisplayName: 'Gromart',
            ))
            .then((value) {});
        setState(() {});
        displayStripePaymentSheet(amount: amount);
      }
    } catch (e, s) {
      print('exception:$e$s');
    }
  }

  displayStripePaymentSheet({required amount}) async {
    try {
      await stripe1.Stripe.instance.presentPaymentSheet().then((value) {
        print("we are in");
        print(_scaffoldKey.currentWidget);
        if (widget.take_away!) {
          placeOrder(context);
        } else {
          toCheckOutScreen(true, _scaffoldKey.currentContext!);
        }
        ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(
          content: Text("paidSuccessfully".tr()),
          duration: Duration(seconds: 8),
          backgroundColor: Colors.green,
        ));
        paymentIntentData = null;
      }).onError((error, stackTrace) {
        print(error.toString());
        Navigator.pop(context);
       // var lo1 = jsonEncode(error);
        //var lo2 = jsonDecode(lo1);
        StripePayFailedModel lom = StripePayFailedModel.fromJson(jsonDecode(error.toString()));
        showDialog(
            context: context,
            builder: (_) => AlertDialog(
                  content: Text("${lom.error.message}"),
                ));
      });
    } on stripe1.StripeException catch (e) {
      Navigator.pop(context);
      var lo1 = jsonEncode(e);
      var lo2 = jsonDecode(lo1);
      StripePayFailedModel lom = StripePayFailedModel.fromJson(lo2);
      print("demo test 12");
      showDialog(
          context: context,
          builder: (_) => AlertDialog(
                content: Text("${lom.error.message}"),
              ));
    } catch (e) {
      print("demo test");
      print('$e');
      Navigator.pop(context);
      showDialog(
          context: context,
          builder: (_) => AlertDialog(
            content: Text("$e"),
          ));
      // ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(
      //   content: Text("$e"),
      //   duration: Duration(seconds: 8),
      //   backgroundColor: Colors.red,
      // ));
    }
  }

  createStripeIntent(
    String amount,
  ) async {
    try {
      Map<String, dynamic> body = {
        'amount': calculateAmount(amount),
        'currency': currencyData!.code,
        'payment_method_types[0]': 'card',
        // 'payment_method_types[1]': 'ideal',
        "description": "${MyAppState.currentUser?.userID} Wallet Topup",
        "shipping[name]": "${MyAppState.currentUser?.firstName} ${MyAppState.currentUser?.lastName}",
        "shipping[address][line1]": "510 Townsend St",
        "shipping[address][postal_code]": "98140",
        "shipping[address][city]": "San Francisco",
        "shipping[address][state]": "CA",
        "shipping[address][country]": "US",
      };
      print(body);
      var response = await http.post(Uri.parse('https://api.stripe.com/v1/payment_intents'), body: body, headers: {
        'Authorization': 'Bearer ${stripeData?.stripeSecret}',
        //$_paymentIntentClientSecret',
        'Content-Type': 'application/x-www-form-urlencoded'
      });
      print('Create Intent response ===> ${response.body.toString()}');

      return jsonDecode(response.body);
    } catch (err) {
      print('error charging user: ${err.toString()}');
    }
  }

  calculateAmount(String amount) {
    final a = ((double.parse(amount)) * 100).toInt();
    print(a);
    return a.toString();
  }

  ///PayPal payment function
  _makePaypalPayment({required amount}) async {
    PayPalClientTokenGen.paypalClientToken(paypalSettingData: paypalSettingData!).then((value) async {
      final String tokenizationKey = paypalSettingData!.braintree_tokenizationKey;

      var request =
          BraintreePayPalRequest(amount: amount, currencyCode: currencyData!.code, billingAgreementDescription: "djsghxghf", displayName: 'Gromart company');

      BraintreePaymentMethodNonce? resultData;
      try {
        resultData = await Braintree.requestPaypalNonce(tokenizationKey, request);
      } on Exception {
        print("Stripe error");
        showAlert(_scaffoldKey.currentContext!, response: "somethingWentWrongPleaseContactAdmin".tr(), colors: Colors.red);
      }
      print(resultData?.nonce);
      print(resultData?.paypalPayerId);
      if (resultData?.nonce != null) {
        PayPalClientTokenGen.paypalSettleAmount(
          paypalSettingData: paypalSettingData!,
          nonceFromTheClient: resultData?.nonce,
          amount: amount,
          deviceDataFromTheClient: resultData?.typeLabel,
        ).then((value) {
          print('payment done!!');
          if (value['success'] == "true" || value['success'] == true) {
            if (value['data']['success'] == "true" || value['data']['success'] == true) {
              payPalSettel.PayPalClientSettleModel settleResult = payPalSettel.PayPalClientSettleModel.fromJson(value);

              if (widget.take_away!) {
                placeOrder(_scaffoldKey.currentContext!);
              } else {
                toCheckOutScreen(true, _scaffoldKey.currentContext!);
              }

              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                  "Status : ${settleResult.data.transaction.status}\n"
                  "Transaction id : ${settleResult.data.transaction.id}\n"
                  "Amount : ${settleResult.data.transaction.amount}",
                ),
                duration: Duration(seconds: 8),
                backgroundColor: Colors.green,
              ));
            } else {
              print(value);
              payPalCurrModel.PayPalCurrencyCodeErrorModel settleResult = payPalCurrModel.PayPalCurrencyCodeErrorModel.fromJson(value);
              Navigator.pop(_scaffoldKey.currentContext!);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text("status".tr() + " ${settleResult.data.message}"),
                duration: Duration(seconds: 8),
                backgroundColor: Colors.red,
              ));
            }
          } else {
            PayPalErrorSettleModel settleResult = PayPalErrorSettleModel.fromJson(value);
            Navigator.pop(_scaffoldKey.currentContext!);
            ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(
              content: Text("status".tr() + " ${settleResult.data.message}"),
              duration: Duration(seconds: 8),
              backgroundColor: Colors.red,
            ));
          }
        });
      } else {
        Navigator.pop(_scaffoldKey.currentContext!);
        ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(
          content: Text("statusPaymentIncomplete".tr()),
          duration: Duration(seconds: 8),
          backgroundColor: Colors.red,
        ));
      }
    });
  }

  showLoadingAlert() {
    return showDialog<void>(
      context: _scaffoldKey.currentContext!,
      useRootNavigator: true,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CircularProgressIndicator(),
              Text('pleaseWait'.tr()),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                SizedBox(
                  height: 15,
                ),
                Text(
                  'pleaseWaitWhileCompletingTransaction'.tr(),
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(
                  height: 15,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  ///Paytm payment function
  getPaytmCheckSum(
    context, {
    required double amount,
  }) async {
    final String orderId = await UserPreference.getPaymentId();
    print(orderId);
    print('here order ID');
    String getChecksum = "${GlobalURL}payments/getpaytmchecksum";
    final response = await http.post(
        Uri.parse(
          getChecksum,
        ),
        headers: {},
        body: {
          "mid": paytmSettingData?.PaytmMID,
          "order_id": orderId,
          "key_secret": paytmSettingData?.PAYTM_MERCHANT_KEY,
        });

    final data = jsonDecode(response.body);
    print(data);
    await verifyCheckSum(checkSum: data["code"], amount: amount, orderId: orderId).then((value) {
      initiatePayment(amount: amount, orderId: orderId).then((value) {
        if (value != null) {
          GetPaymentTxtTokenModel result = value;
          String callback = "";
          if (paytmSettingData!.isSandboxEnabled) {
            callback = callback + "https://securegw-stage.paytm.in/theia/paytmCallback?ORDER_ID=$orderId";
          } else {
            callback = callback + "https://securegw.paytm.in/theia/paytmCallback?ORDER_ID=$orderId";
          }

          _startTransaction(context, txnTokenBy: result.body.txnToken, orderId: orderId, amount: amount, callBackURL: callback);
        }
      });
    });
  }

  Future<void> _startTransaction(
    context, {
    required String txnTokenBy,
    required orderId,
    required double amount,
    required callBackURL,
  }) async {
    try {
      var response = AllInOneSdk.startTransaction(
        paytmSettingData!.PaytmMID,
        orderId,
        amount.toString(),
        txnTokenBy,
        callbackUrl,
        //"https://securegw-stage.paytm.in/theia/paytmCallback?ORDER_ID=$orderId",
        isStaging,
        true,
        enableAssist,
      );

      response.then((value) {
        if (value!["RESPMSG"] == "Txn Success") {
          print("txt done!!");
          print(amount);
          if (widget.take_away!) {
            placeOrder(_scaffoldKey.currentContext!);
          } else {
            toCheckOutScreen(true, context);
            print(amount);
          }
          showAlert(context, response: "Payment Successful!!\n ${value['RESPMSG']}", colors: Colors.green);
        }
      }).catchError((onError) {
        if (onError is PlatformException) {
          print("======>>1");
          Navigator.pop(_scaffoldKey.currentContext!);

          print("Error124 : $onError");
          result = onError.message.toString() + " \n  " + onError.code.toString();
          showAlert(_scaffoldKey.currentContext!, response: onError.message.toString(), colors: Colors.red);
        } else {
          print("======>>2");

          result = onError.toString();
          Navigator.pop(_scaffoldKey.currentContext!);
          showAlert(_scaffoldKey.currentContext!, response: result, colors: Colors.red);
        }
      });
    } catch (err) {
      print("======>>3");
      result = err.toString();
      Navigator.pop(_scaffoldKey.currentContext!);
      showAlert(_scaffoldKey.currentContext!, response: result, colors: Colors.red);
    }
  }

  Future verifyCheckSum({required String checkSum, required double amount, required orderId}) async {
    String getChecksum = "${GlobalURL}payments/validatechecksum";
    final response = await http.post(
        Uri.parse(
          getChecksum,
        ),
        headers: {},
        body: {
          "mid": paytmSettingData?.PaytmMID,
          "order_id": orderId,
          "key_secret": paytmSettingData?.PAYTM_MERCHANT_KEY,
          "checksum_value": checkSum,
        });
    final data = jsonDecode(response.body);
    print(data);
    print('here one');
    print(checkSum);
    print(data['status']);
    return data['status'];
  }

  Future<GetPaymentTxtTokenModel?> initiatePayment({required double amount, required orderId}) async {
    String initiateURL = "${GlobalURL}payments/initiatepaytmpayment";
    print('payment initiated now!@!');
    String callback = "";
    if (paytmSettingData!.isSandboxEnabled) {
      callback = callback + "https://securegw-stage.paytm.in/theia/paytmCallback?ORDER_ID=$orderId";
    } else {
      callback = callback + "https://securegw.paytm.in/theia/paytmCallback?ORDER_ID=$orderId";
    }
    print("uday");
    print(initiateURL);
    final response = await http.post(Uri.parse(initiateURL), headers: {}, body: {
      "mid": paytmSettingData?.PaytmMID,
      "order_id": orderId,
      "key_secret": paytmSettingData?.PAYTM_MERCHANT_KEY.toString(),
      "amount": amount.toString(),
      "currency": currencyData!.code,
      "callback_url": callback,
      "custId": MyAppState.currentUser!.userID,
      "issandbox": paytmSettingData!.isSandboxEnabled ? "1" : "2",
    });
    print("uday");
    print(response.body);
    final data = jsonDecode(response.body);
    print(data);
    if (data["body"]["txnToken"] == null || data["body"]["resultMsg"] == "System error" || data["body"]["txnToken"].toString().isEmpty) {
      Navigator.pop(_scaffoldKey.currentContext!);
      showAlert(_scaffoldKey.currentContext!, response: "somethingWentWrongPleaseContactAdmin".tr(), colors: Colors.red);
    }
    if (data["body"]["txnToken"].toString().isNotEmpty) {
      return GetPaymentTxtTokenModel.fromJson(data);
    } else {
      return null;
    }
  }

  ///PayStack Payment Method
  payStackPayment(BuildContext context) async {
    await PayStackURLGen.payStackURLGen(
      amount: (widget.total * 100).toString(),
      currency: currencyData!.code,
      secretKey: payStackSettingData!.secretKey,
    ).then((value) async {
      if (value != null) {
        PayStackUrlModel _payStackModel = value;
        bool isDone = await Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => PayStackScreen(
                  secretKey: payStackSettingData!.secretKey,
                  callBackUrl: payStackSettingData!.callbackURL,
                  initialURl: _payStackModel.data.authorizationUrl,
                  amount: widget.total.toString(),
                  reference: _payStackModel.data.reference,
                )));
        //Navigator.pop(_globalKey.currentContext!);

        if (isDone) {
          if (widget.take_away!) {
            placeOrder(_scaffoldKey.currentContext!);
          } else {
            toCheckOutScreen(true, _scaffoldKey.currentContext!);
          }
          ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(
            content: Text("paymentSuccessful".tr() + "\n"),
            backgroundColor: Colors.green,
          ));
        } else {
          Navigator.pop(_scaffoldKey.currentContext!);
          ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(
            content: Text("paymentUnSuccessful".tr() + "\n"),
            backgroundColor: Colors.red,
          ));
        }
      } else {
        Navigator.pop(_scaffoldKey.currentContext!);
        showAlert(_scaffoldKey.currentContext!, response: "somethingWentWrongPleaseContactAdmin".tr(), colors: Colors.red);
      }
    });
  }

  ///MercadoPago Payment Method

  mercadoPagoMakePayment() {
    makePreference().then((result) async {
      if (result.isNotEmpty || result['response']['init_point'] == null) {
        var client_id = result['response']['client_id'];
        var preferenceId = result['response']['id'];
        print("uday");
        print(result);
        print(result['response']['init_point']);

        final bool isDone =
            await Navigator.push(context, MaterialPageRoute(builder: (context) => MercadoPagoScreen(initialURl: result['response']['init_point'])));
        print(isDone);
        print(result.toString());
        print(preferenceId);

        if (isDone) {
          if (widget.take_away!) {
            placeOrder(_scaffoldKey.currentContext!);
          } else {
            toCheckOutScreen(true, _scaffoldKey.currentContext!);
          }
          ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(
            content: Text("Payment Successful!!".tr() + "\n"),
            backgroundColor: Colors.green,
          ));
        } else {
          Navigator.pop(_scaffoldKey.currentContext!);
          ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(
            content: Text("Payment UnSuccessful!!".tr() + "\n"),
            backgroundColor: Colors.red,
          ));
        }
      } else {
        Navigator.pop(_scaffoldKey.currentContext!);
        ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(
          content: Text("Error while transaction!".tr() + "\n"),
          backgroundColor: Colors.red,
        ));
      }
    });
  }

  Future<Map<String, dynamic>> makePreference() async {
    final mp = MP.fromAccessToken(mercadoPagoSettingData!.accessToken);
    var pref = {
      "items": [
        {"title": "Wallet TopUp", "quantity": 1, "unit_price": double.parse(widget.total.toString().trim())}
      ],
      "auto_return": "all",
      "back_urls": {"failure": "${GlobalURL}payment/failure", "pending": "${GlobalURL}payment/pending", "success": "${GlobalURL}payment/success"},
    };

    var result = await mp.createPreference(pref);
    return result;
  }

  ///FlutterWave Payment Method
  String? _ref;

  setRef() {
    Random numRef = Random();
    int year = DateTime.now().year;
    int refNumber = numRef.nextInt(20000);
    if (Platform.isAndroid) {
      setState(() {
        _ref = "AndroidRef$year$refNumber";
      });
    } else if (Platform.isIOS) {
      setState(() {
        _ref = "IOSRef$year$refNumber";
      });
    }
  }

  _flutterWaveInitiatePayment(
    BuildContext context,
  ) async {
    final style = FlutterwaveStyle(
      appBarText: "appName".tr(),
      buttonColor: Color(COLOR_PRIMARY),
      buttonTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
      ),
      appBarColor: Color(COLOR_PRIMARY),
      dialogCancelTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 18,
      ),
      dialogContinueTextStyle: TextStyle(
        color: Color(COLOR_PRIMARY),
        fontSize: 18,
      ),
      mainTextStyle: TextStyle(color: Colors.black, fontSize: 19, letterSpacing: 2),
      dialogBackgroundColor: Colors.white,
      appBarTitleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
      ),
    );

    final flutterwave = Flutterwave(
      amount: widget.total.toString().trim(),
      currency: currencyData!.code,
      style: style,
      customer: Customer(
          name: MyAppState.currentUser!.firstName, phoneNumber: MyAppState.currentUser!.phoneNumber.trim(), email: MyAppState.currentUser!.email.trim()),
      context: context,
      publicKey: flutterWaveSettingData!.publicKey.trim(),
      paymentOptions: "card, payattitude",
      customization: Customization(title: "appName".tr()),
      txRef: _ref!,
      isTestMode: flutterWaveSettingData!.isSandbox,
      redirectUrl: '${GlobalURL}success',
    );
    final ChargeResponse response = await flutterwave.charge();
    if (response.success!) {
      ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(
        content: Text("paymentSuccessful".tr() + "\n"),
        backgroundColor: Colors.green,
      ));
      if (widget.take_away!) {
        placeOrder(_scaffoldKey.currentContext!);
      } else {
        toCheckOutScreen(true, _scaffoldKey.currentContext!);
      }
    } else {
      this.showLoading(message: response.status!);
    }
    print("${response.toJson()}");
  }

  Future<void> showLoading({required String message, Color txtColor = Colors.black}) {
    return showDialog(
      context: this.context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Container(
            margin: EdgeInsets.fromLTRB(30, 20, 30, 20),
            width: double.infinity,
            height: 30,
            child: Text(
              message,
              style: TextStyle(color: txtColor),
            ),
          ),
        );
      },
    );
  }

  placeOrder(BuildContext buildContext, {String? oid}) async {
    FireStoreUtils fireStoreUtils = FireStoreUtils();
    List<CartProduct> tempProduc = [];

    if (paymentType.isEmpty) {
      ShowDialogToDismiss(
        title: "emptyPaymentType".tr(),
        buttonText: "ok".tr(),
        content: "selectPaymentType".tr(),
      );
      return;
    }

    for (CartProduct cartProduct in widget.products) {
      CartProduct tempCart = cartProduct;
      tempProduc.add(tempCart);
    }
    //place order
    showProgress(buildContext, 'placingOrder'.tr(), false);
    VendorModel vendorModel = await fireStoreUtils.getVendorByVendorID(widget.products.first.vendorID).whenComplete(() => setPrefData());
    print(vendorModel.fcmToken.toString() + "{}{}{}{======TOKENADD" + vendorModel.toJson().toString());
    OrderModel orderModel = OrderModel(
      address: MyAppState.currentUser!.shippingAddress,
      author: MyAppState.currentUser,
      authorID: MyAppState.currentUser!.userID,
      createdAt: Timestamp.now(),
      products: tempProduc,
      status: ORDER_STATUS_PLACED,
      vendor: vendorModel,
      payment_method: paymentType,
      notes: widget.notes,
      taxModel: widget.taxModel,
      vendorID: widget.products.first.vendorID,
      discount: widget.discount,
      specialDiscount: widget.specialDiscountMap,
      couponCode: widget.couponCode,
      couponId: widget.couponId,
      adminCommission: isEnableAdminCommission! ? adminCommissionValue : "0",
      adminCommissionType: isEnableAdminCommission! ? addminCommissionType : "",
      takeAway: true,
    );

    if (oid != null && oid.isNotEmpty) {
      orderModel.id = oid;
    }
    OrderModel placedOrder = await fireStoreUtils.placeOrderWithTakeAWay(orderModel);
    print("||||{}" + orderModel.toJson().toString());
    hideProgress();
    print('_CheckoutScreenState.placeOrder ${placedOrder.id}');
    showModalBottomSheet(
      isScrollControlled: true,
      isDismissible: false,
      context: buildContext,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => PlaceOrderScreen(orderModel: placedOrder),
    );
  }

  Future<void> setPrefData() async {
    SharedPreferences sp = await SharedPreferences.getInstance();

    sp.setString("musics_key", "");
    sp.setString("addsize", "");
  }

  toCheckOutScreen(bool val, BuildContext context) {
    push(
      context,
      CheckoutScreen(
        isPaymentDone: val,
        paymentType: this.paymentType,
        total: widget.total,
        discount: widget.discount!,
        couponCode: widget.couponCode!,
        couponId: widget.couponId!,
        notes: widget.notes!,
        paymentOption: paymentOption,
        products: widget.products,
        deliveryCharge: widget.deliveryCharge,
        tipValue: widget.tipValue,
        take_away: widget.take_away,
        taxModel: widget.taxModel,
        extra_size: widget.extra_size,
        extra_addons: widget.extra_addons,
        specialDiscountMap: widget.specialDiscountMap,
      ),
    );
  }
}
