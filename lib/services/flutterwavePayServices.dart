// // ignore_for_file: unnecessary_null_comparison

// import 'package:flutter/material.dart';
// import 'package:flutterwave/flutterwave.dart';
// import 'package:flutterwave/models/responses/charge_response.dart';

// class FlutterWavePayService extends StatefulWidget {
//   const FlutterWavePayService({Key? key}) : super(key: key);

//   @override
//   _FlutterWavePayServiceState createState() => _FlutterWavePayServiceState();
// }

// class _FlutterWavePayServiceState extends State<FlutterWavePayService> {

//   final String txref = "My_unique_transaction_reference_123";
//   final String amount = "200";
//   final String currency = FlutterwaveCurrency.USD;
//   //currName == "US Dollar" ? "USD" : "INR",

//   @override
//   void initState() {

//     beginPayment();
//     super.initState();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//     );
//   }

//   beginPayment() async {
//     final Flutterwave flutterwave = Flutterwave.forUIPayment(
//         context: this.context,
//         encryptionKey: 'FLWSECK_TEST24fccf51f99d',
//         publicKey: 'FLWPUBK_TEST-ee590516181afe8308952edc6addf457-X',
//         currency: currency,
//         amount: amount,
//         email: "valid@email.com",
//         fullName: "Valid Full Name",
//         txRef: this.txref,
//         isDebugMode: false,
//         phoneNumber: "0123456789",
//         acceptCardPayment: true,
//         acceptUSSDPayment: false,
//         acceptAccountPayment: false,
//         acceptFrancophoneMobileMoney: false,
//         acceptGhanaPayment: false,
//         acceptMpesaPayment: false,
//         acceptRwandaMoneyPayment: true,
//         acceptUgandaPayment: false,
//         acceptZambiaPayment: false);

//     try {
//       final ChargeResponse response = await flutterwave.initializeForUiPayments();
//       if (response == null) {
//         // user didn't complete the transaction.
//       } else {
//         final isSuccessful = checkPaymentIsSuccessful(response);
//         if (isSuccessful) {
//           // provide value to customer
//         } else {
//           // check message
//           print(response.message);

//           // check status
//           print(response.status);

//           // check processor error
//           print(response.data!.processorResponse);
//         }
//       }
//     } catch (error) {
//       // handleError(error);
//     }
//   }

//   bool checkPaymentIsSuccessful(final ChargeResponse response) {
//     return response.data!.status == FlutterwaveConstants.SUCCESSFUL &&
//         response.data!.currency == this.currency &&
//         response.data!.amount == this.amount &&
//         response.data!.txRef == this.txref;
//   }
// }
