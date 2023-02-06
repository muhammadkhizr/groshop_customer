import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gromartconsumer/constants.dart';
import 'package:gromartconsumer/services/paystack_url_genrater.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PayStackScreen extends StatefulWidget {
  final String initialURl;
  final String reference;
  final String amount;
  final String secretKey;
  final String callBackUrl;

  const PayStackScreen({Key? key, required this.initialURl, required this.reference, required this.amount, required this.secretKey, required this.callBackUrl})
      : super(key: key);

  @override
  State<PayStackScreen> createState() => _PayStackScreenState();
}

class _PayStackScreenState extends State<PayStackScreen> {
  final Completer<WebViewController> _controller = Completer<WebViewController>();
  WebViewController? controllerGlobal;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _showMyDialog();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
            backgroundColor: Color(COLOR_PRIMARY),
            title: Text("payment".tr()),
            centerTitle: false,
            leading: GestureDetector(
              onTap: () {
                _showMyDialog();
              },
              child: Icon(
                Icons.arrow_back,
                color: Colors.white,
              ),
            )),
        body: WebView(
          initialUrl: widget.initialURl,
          javascriptMode: JavascriptMode.unrestricted,
          gestureNavigationEnabled: true,
          userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 9_3 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13E233 Safari/601.1',
          onWebViewCreated: (WebViewController webViewController) {
            _controller.future.then((value) => controllerGlobal = value);
            _controller.complete(webViewController);
          },
          navigationDelegate: (navigation) async {
            print("--->2" + navigation.url);
            print("--->2" + "${widget.callBackUrl}?trxref=${widget.reference}&reference=${widget.reference}");
            if (navigation.url == 'https://foodieweb.siswebapp.com/success?trxref=${widget.reference}&reference=${widget.reference}' ||
                navigation.url == '${widget.callBackUrl}?trxref=${widget.reference}&reference=${widget.reference}') {
              final isDone = await PayStackURLGen.verifyTransaction(secretKey: widget.secretKey, reference: widget.reference, amount: widget.amount);
              Navigator.pop(context, isDone); //close webview
            }
            if ((navigation.url == '${widget.callBackUrl}?trxref=${widget.reference}&reference=${widget.reference}') ||
                (navigation.url == "https://hello.pstk.xyz/callback") ||
                (navigation.url == 'https://standard.paystack.co/close')) {
              final isDone = await PayStackURLGen.verifyTransaction(secretKey: widget.secretKey, reference: widget.reference, amount: widget.amount);
              Navigator.pop(context, isDone);
              //close webview
            }
            return NavigationDecision.navigate;
          },
        ),
      ),
    );
  }

  Future<void> _showMyDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('cancelPayment'.tr()),
          content: SingleChildScrollView(
            child: Text('areYouWantToCancelPayment'.tr()),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'cancel'.tr(),
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: Text(
                'continue'.tr(),
                style: TextStyle(color: Colors.green),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
