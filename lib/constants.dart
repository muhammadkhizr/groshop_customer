import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gromartconsumer/model/CurrencyModel.dart';
import 'package:gromartconsumer/model/TaxModel.dart';
import 'package:gromartconsumer/model/VendorModel.dart';

const FINISHED_ON_BOARDING = 'finishedOnBoarding';
const COLOR_ACCENT = 0xFF8fd468;
const COLOR_PRIMARY_DARK = 0x00B761;
// ignore: non_constant_identifier_names
var COLOR_PRIMARY = 0xFF00B761;
const FACEBOOK_BUTTON_COLOR = 0xFF415893;
const DARK_CARD_BG_COLOR = 0xff35363A;
const DARK_COLOR = 0xff191A1C;
const DARK_VIEWBG_COLOR = 0xff191A1C;
const DARK_BG_COLOR = 0xff121212;
const COUPON_BG_COLOR = 0xFFFCF8F3;
const COUPON_DASH_COLOR = 0xFFCACFDA;
const GREY_TEXT_COLOR = 0xff5E5C5C;
const DARK_GREY_TEXT_COLOR = 0xff9F9F9F;

const PAYID = 'GroShop';
const USERS = 'users';
const CHANNEL_PARTICIPATION = 'channel_participation';
const CHANNELS = 'channels';
const THREAD = 'thread';
const REPORTS = 'reports';
const Deliverycharge = 6;
const CATEGORIES = 'vendor_categories';
const VENDORS = 'vendors';
const PRODUCTS = 'vendor_products';
const ORDERS = 'vendor_orders';
const ORDERS_TABLE = 'booked_table';
const COUPONS = "coupons";
const SECOND_MILLIS = 1000;
const MINUTE_MILLIS = 60 * SECOND_MILLIS;
const HOUR_MILLIS = 60 * MINUTE_MILLIS;
const SERVER_KEY =
    'AAAA7sTwPcc:APA91bEcUZrKpG1z_F4HEOWF410xfI6CB6jFQ-mZgpcTx-alT2PZ7fINDtvv3EHdqsDnNtwT2Zxk8MLU-eNu4w2d1DWmUhNgDPUN8fak-qt5tq-PGVUoxIjjQu8_PqU0qDkKawAIY0en';
const GOOGLE_API_KEY = 'AIzaSyCp1SD_okSBZW7r0hPzbyxGPmphZkR5yYU';

const ORDER_STATUS_PLACED = 'Order Placed';
const ORDER_STATUS_ACCEPTED = 'Order Accepted';
const ORDER_STATUS_REJECTED = 'Order Rejected';
const ORDER_STATUS_DRIVER_PENDING = 'Driver Pending';
const ORDER_STATUS_DRIVER_REJECTED = 'Driver Rejected';
const ORDER_STATUS_SHIPPED = 'Order Shipped';
const ORDER_STATUS_IN_TRANSIT = 'In Transit';
const ORDER_STATUS_COMPLETED = 'Order Completed';
const ORDERREQUEST = 'Order';
const BOOKREQUEST = 'TableBook';

const STRIPE_CURRENCY_CODE = 'USD';
const PAYMENT_SERVER_URL = 'https://murmuring-caverns-94283.herokuapp.com/';

const STRIPE_PUBLISHABLE_KEY = '';

const PAYSTACK_KEY = "";
const USER_ROLE_DRIVER = 'driver';
const USER_ROLE_CUSTOMER = 'customer';
const VENDORS_CATEGORIES = 'vendor_categories';
const Order_Rating = 'items_review';
const CONTACT_US = 'ContactUs';
const COUPON = 'coupons';
const Wallet = "wallet";
const MENU_ITEM = 'menu_items';

const Setting = 'settings';
const StripeSetting = 'stripeSettings';
const FavouriteStore = "favorite_vendor";

const COD = 'CODSettings';

const GlobalURL = "https://admin.groshop.in/";

const Currency = 'currencies';
String symbol = '';
bool isRight = false;
bool isDineInEnable = false;
int decimal = 0;
String currName = "";
CurrencyModel? currencyData;
List<VendorModel> allstoreList = [];

bool isRazorPayEnabled = false;
bool isRazorPaySandboxEnabled = false;
String razorpayKey = "";
String razorpaySecret = "";

String placeholderImage = '';

double getDoubleVal(dynamic input) {
  if (input == null) {
    return 0.1;
  }

  if (input is int) {
    return double.parse(input.toString());
  }

  if (input is double) {
    return input;
  }
  return 0.1;
}

double getTaxValue(TaxModel? taxModel, double amount) {
  double taxVal = 0;
  if (taxModel != null) {
    if (taxModel.type == "fix") {
      taxVal = taxModel.tax!.toDouble();
    } else {
      taxVal = (amount * taxModel.tax!.toDouble()) / 100;
    }
  }
  return double.parse(taxVal.toStringAsFixed(2));
}

Uri createCoordinatesUrl(double latitude, double longitude, [String? label]) {
  var uri;
  if (kIsWeb) {
    uri = Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': '$latitude,$longitude'});
  } else if (Platform.isAndroid) {
    var query = '$latitude,$longitude';
    if (label != null) query += '($label)';
    uri = Uri(scheme: 'geo', host: '0,0', queryParameters: {'q': query});
  } else if (Platform.isIOS) {
    var params = {'ll': '$latitude,$longitude'};
    if (label != null) params['q'] = label;
    uri = Uri.https('maps.apple.com', '/', params);
  } else {
    uri = Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': '$latitude,$longitude'});
  }

  return uri;
}

String getKm(Position pos1, Position pos2) {
  double distanceInMeters = Geolocator.distanceBetween(pos1.latitude, pos1.longitude, pos2.latitude, pos2.longitude);
  double kilometer = distanceInMeters / 1000;
  print("KiloMeter$kilometer");
  return kilometer.toStringAsFixed(2).toString();
}

String getImageVAlidUrl(String url) {
  String imageUrl = placeholderImage;
  if (url.isNotEmpty) {
    imageUrl = url;
  }
  return imageUrl;
}
