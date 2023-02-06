import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../constants.dart';

class MercadoPagoScreen extends StatefulWidget {
  final String initialURl;

  const MercadoPagoScreen({
    Key? key,
    required this.initialURl,
  }) : super(key: key);

  @override
  State<MercadoPagoScreen> createState() => _MercadoPagoScreenState();
}

class _MercadoPagoScreenState extends State<MercadoPagoScreen> {
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
            // title: const Text(
            //   "Payment",
            //   style: TextStyle(
            //     color: Colors.black,
            //   ),
            // ),
            centerTitle: false,
            leading: GestureDetector(
              onTap: () {
                _showMyDialog();
              },
              child: Icon(
                Icons.arrow_back,
                color: Color(COLOR_PRIMARY),
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
            print("--->2 ${navigation.url}");
            if (navigation.url.contains("${GlobalURL}payment/success")) {
              Navigator.pop(context, true);
            }
            if (navigation.url.contains("${GlobalURL}payment/failure") || navigation.url.contains("${GlobalURL}payment/pending")) {
              Navigator.pop(context, false);
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
          title: const Text('Cancel Payment'),
          content: const SingleChildScrollView(
            child: Text("cancelPayment?"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text(
                'Continue',
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
