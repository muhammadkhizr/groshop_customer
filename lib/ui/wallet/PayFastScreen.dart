import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gromartconsumer/model/PayFastSettingData.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PayFastScreen extends StatefulWidget {
  final String htmlData;
  final PayFastSettingData payFastSettingData;

  const PayFastScreen({Key? key, required this.htmlData, required this.payFastSettingData}) : super(key: key);

  @override
  State<PayFastScreen> createState() => _PayFastScreenState();
}

class _PayFastScreenState extends State<PayFastScreen> {
  WebViewController? _webViewController;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _showMyDialog();
        return false;
      },
      child: Scaffold(
          appBar: AppBar(
            leading: GestureDetector(
              onTap: () {
                _showMyDialog();
              },
              child: Icon(
                Icons.arrow_back,
              ),
            ),
          ),
          body: Center(
            child: WebView(
              initialUrl: 'about:blank',
              javascriptMode: JavascriptMode.unrestricted,
              gestureNavigationEnabled: true,
              userAgent:
                  'Mozilla/5.0 (iPhone; CPU iPhone OS 9_3 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13E233 Safari/601.1',
              onWebViewCreated: (WebViewController webViewController) async {
                _webViewController = webViewController;
                String fileContent = widget.htmlData; //await rootBundle.loadString('assets/json file/payFast.html');
                _webViewController?.loadUrl(Uri.dataFromString(fileContent, mimeType: 'text/html', encoding: Encoding.getByName('utf-8')).toString());
              },
              navigationDelegate: (navigation) async {
                if (kDebugMode) {
                  print("--->2" + navigation.toString());
                }
                if (navigation.url == widget.payFastSettingData.return_url) {
                  Navigator.pop(context, true);
                } else if (navigation.url == widget.payFastSettingData.notify_url) {
                  Navigator.pop(context, false);
                } else if (navigation.url == widget.payFastSettingData.cancel_url) {
                  _showMyDialog();
                }
                return NavigationDecision.navigate;
              },
            ),
          )),
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
            child: Text(
              'areYouWantToCancelPayment'.tr(),
            ),
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
                'continuePayment'.tr(),
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
