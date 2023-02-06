// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:bluetooth_thermal_printer/bluetooth_thermal_printer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:gromartconsumer/AppGlobal.dart';
import 'package:gromartconsumer/constants.dart';
import 'package:gromartconsumer/model/ConversationModel.dart';
import 'package:gromartconsumer/model/HomeConversationModel.dart';
import 'package:gromartconsumer/model/OrderModel.dart';
import 'package:gromartconsumer/model/User.dart';
import 'package:gromartconsumer/services/FirebaseHelper.dart';
import 'package:gromartconsumer/services/helper.dart';
import 'package:gromartconsumer/ui/chat/ChatScreen.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart' as lottie;
import 'package:percent_indicator/percent_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/localDatabase.dart';

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';

class OrderDetailsScreen extends StatefulWidget {
  final OrderModel orderModel;

  const OrderDetailsScreen({Key? key, required this.orderModel})
      : super(key: key);

  @override
  _OrderDetailsScreenState createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  FireStoreUtils fireStoreUtils = FireStoreUtils();
  int estimatedSecondsFromDriverToStore = 900;
  late String orderStatus;
  bool isTakeAway = false;
  late String storeName;
  late String phoneNumberStore;
  String currentEvent = '';
  int estimatedTime = 0;
  Timer? timerCountDown;
  String? latestArrivalTime;
  double total = 0.0;
  var discount;
  GoogleMapController? _mapController;
  StreamController<String> arrivalTimeStreamController = StreamController();
  var tipAmount = "0.0";

  //latlng of the vendor
  LatLng? vendorLocation;

  //latlng of the user
  LatLng? userLocation;

  List<LatLng> polylineCoordinates = [];

  // Future<PolylineResult>? polyLinesFuture;
  late bool orderDelivered;
  late bool orderRejected;

  List<Polyline> polylines = [];
  List<Marker> mapMarkers = [];

  @override
  void initState() {
    setMarkerIcon();

    getCurrentOrder();

    orderStatus = widget.orderModel.status;
    isTakeAway = widget.orderModel.takeAway!;
    orderRejected = orderStatus == ORDER_STATUS_REJECTED;
    orderDelivered = orderStatus == ORDER_STATUS_COMPLETED;
    if (!orderDelivered && !orderRejected) {
      vendorLocation = LatLng(widget.orderModel.vendor.latitude,
          widget.orderModel.vendor.longitude);
      userLocation = LatLng(widget.orderModel.author.location.latitude,
          widget.orderModel.author.location.longitude);
      estimateTime();

      latestArrivalTime = DateFormat('h:mm a').format(
        DateTime.now().add(
          Duration(hours: 1),
        ),
      );
    }

    widget.orderModel.products.forEach((element) {
      if (element.extras_price != null &&
          element.extras_price!.isNotEmpty &&
          double.parse(element.extras_price!) != 0.0) {
        total += element.quantity * double.parse(element.extras_price!);
      }
      total += element.quantity * double.parse(element.price);

      //     var price =  (element.extras_price == null || element.extras_price == "" || element.extras_price == "0.0")
      //     ? ((element.discountPrice == "" || element.discountPrice == "0" || element.discountPrice == null)
      //         ? element.price
      //         : element.discountPrice)
      //     : element.extras_price;
      // total += element.quantity * double.parse(price!);
      discount = widget.orderModel.discount;
    });
    super.initState();
  }

  @override
  void dispose() {
    timerCountDown?.cancel();
    arrivalTimeStreamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          isDarkMode(context) ? Color(DARK_VIEWBG_COLOR) : Colors.white,
      appBar: AppGlobal.buildSimpleAppBar(context, 'Your Order'.tr()),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: fireStoreUtils.watchOrderStatus(widget.orderModel.id),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              OrderModel orderModel =
                  OrderModel.fromJson(snapshot.data!.data()!);
              orderStatus = orderModel.status;
              storeName = orderModel.vendor.title;
              phoneNumberStore = orderModel.vendor.phonenumber;
              print('_PlaceOrderScreenState.initState $orderStatus');
              switch (orderStatus) {
                case ORDER_STATUS_PLACED:
                  currentEvent = 'weSentYourOrderTo'
                      .tr(args: ['${orderModel.vendor.title}']);
                  break;
                case ORDER_STATUS_ACCEPTED:
                  currentEvent = 'preparingYourOrder'.tr();
                  break;
                case ORDER_STATUS_REJECTED:
                  orderRejected = true;
                  break;
                case ORDER_STATUS_DRIVER_PENDING:
                  currentEvent = 'lookingForADriver'.tr();
                  break;
                case ORDER_STATUS_DRIVER_REJECTED:
                  currentEvent = 'lookingForADriver'.tr();
                  break;
                case ORDER_STATUS_SHIPPED:
                  currentEvent = 'hasPickedUpYourOrder'.tr(args: [
                    '${orderModel.driver?.firstName ?? 'ourDriver'.tr()}',
                    // '${orderModel.vendor.title}'
                  ]);
                  break;
                case ORDER_STATUS_IN_TRANSIT:
                  currentEvent = 'yourOrderIsOnTheWay'.tr();
                  break;
                case ORDER_STATUS_COMPLETED:
                  orderDelivered = true;
                  timerCountDown?.cancel();
                  break;
              }
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 12),
                      child: Card(
                        color: isDarkMode(context)
                            ? Color(DARK_CARD_BG_COLOR)
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  StreamBuilder<String>(
                                      stream:
                                          arrivalTimeStreamController.stream,
                                      initialData: '',
                                      builder: (context, snapshot) {
                                        return Text(
                                          orderDelivered || orderRejected
                                              ? orderDelivered
                                                  ? 'orderDelivered'.tr()
                                                  : 'orderRejected'.tr()
                                              : '${snapshot.data}',
                                          style: TextStyle(
                                              fontSize: 20,
                                              letterSpacing: 0.5,
                                              color: isDarkMode(context)
                                                  ? Colors.grey.shade200
                                                  : Color(0XFF000000),
                                              fontFamily: "Poppinsb"),
                                        );
                                      }),
                                  // if (estimatedTime != 0 ||
                                  //     !orderDelivered ||
                                  //     !orderRejected)
                                  estimatedTime == 0 ||
                                          orderDelivered ||
                                          orderRejected
                                      ? Container()
                                      : Text(
                                          'estimatedArrival'.tr(),
                                          style: TextStyle(
                                              // fontSize: 20,
                                              letterSpacing: 0.5,
                                              color: isDarkMode(context)
                                                  ? Colors.grey.shade200
                                                  : Color(0XFF000000),
                                              fontFamily: "Poppinsm"),
                                        )
                                ],
                              ),

                              // estimatedTime == 0 || orderDelivered || orderRejected
                              estimatedTime == 0 ||
                                      orderDelivered ||
                                      orderRejected
                                  ? Container()
                                  : Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      child: LinearPercentIndicator(
                                        animation: true,
                                        lineHeight: 8.0,
                                        animationDuration: estimatedTime * 1000,
                                        percent: 1,
                                        linearStrokeCap:
                                            LinearStrokeCap.roundAll,
                                        progressColor: Colors.green,
                                      ),
                                    ),
                              if (!orderRejected && !orderDelivered)
                                ListTile(
                                  title: Text(
                                    'orderID'.tr(),
                                    style: TextStyle(
                                      fontFamily: 'Poppinsm',
                                      fontSize: 16,
                                      letterSpacing: 0.5,
                                      color: isDarkMode(context)
                                          ? Colors.grey.shade300
                                          : Color(0xff9091A4),
                                    ),
                                  ),
                                  trailing: Text(
                                    widget.orderModel.id,
                                    style: TextStyle(
                                      fontFamily: 'Poppinsm',
                                      letterSpacing: 0.5,
                                      fontSize: 16,
                                      color: isDarkMode(context)
                                          ? Colors.grey.shade300
                                          : Color(0xff333333),
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(
                                    right: 0.0, left: 0.0, top: 6, bottom: 12),
                                child: RichText(
                                  text: TextSpan(children: [
                                    TextSpan(
                                      text: currentEvent,
                                      style: TextStyle(
                                        letterSpacing: 0.5,
                                        color: isDarkMode(context)
                                            ? Colors.grey.shade200
                                            : Color(0XFF2A2A2A),
                                        fontFamily: "Poppinsm",
                                        // fontWeight: FontWeight.w700,
                                        fontSize: 18,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'latestArrivalBy'.tr(args: [
                                        '${(latestArrivalTime != null) ? latestArrivalTime : ""}'
                                      ]),
                                      style: TextStyle(
                                        letterSpacing: 0.5,
                                        color: isDarkMode(context)
                                            ? Colors.grey.shade200
                                            : Colors.grey.shade700,
                                        fontFamily: "Poppinss",
                                      ),
                                    ),
                                  ]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Visibility(
                      visible: ((orderStatus == ORDER_STATUS_PLACED ||
                              orderStatus == ORDER_STATUS_ACCEPTED ||
                              orderStatus == ORDER_STATUS_DRIVER_PENDING ||
                              orderStatus == ORDER_STATUS_DRIVER_REJECTED) &&
                          !isTakeAway),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        margin: const EdgeInsets.symmetric(horizontal: 14),
                        child: lottie.Lottie.asset(
                          isDarkMode(context)
                              ? 'assets/images/chef_dark_bg.json'
                              : 'assets/images/chef_light_bg.json',
                        ),
                      ),
                    ),
                    Visibility(
                        visible: (orderStatus == ORDER_STATUS_SHIPPED ||
                            orderStatus == ORDER_STATUS_IN_TRANSIT),
                        child: buildDeliveryMap(orderModel)),
                    SizedBox(height: 10),
                    (orderStatus == ORDER_STATUS_ACCEPTED && isTakeAway)
                        ? buildDeliveryMap(orderModel)
                        : Container(),
                    Visibility(
                        visible: (orderStatus == ORDER_STATUS_SHIPPED ||
                            orderStatus == ORDER_STATUS_IN_TRANSIT),
                        child: buildDriverCard(orderModel)),
                    SizedBox(height: 16),
                    buildDeliveryDetailsCard(),
                    SizedBox(height: 16),
                    buildOrderSummaryCard(orderModel),
                  ],
                ),
              );
            } else if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                child: Center(
                  child: CircularProgressIndicator.adaptive(
                    valueColor: AlwaysStoppedAnimation(Color(COLOR_PRIMARY)),
                  ),
                ),
              );
            } else {
              return Center(
                child: showEmptyState(
                    'orderNotFound'.tr(), 'couldnotGetOrderInfo'.tr()),
              );
            }
          }),
    );
  }

  estimateTime() async {
    double originLat, originLong, destLat, destLong;
    originLat = widget.orderModel.vendor.latitude;
    originLong = widget.orderModel.vendor.longitude;
    destLat = widget.orderModel.author.location.latitude;
    destLong = widget.orderModel.author.location.longitude;

    String url = 'https://maps.googleapis.com/maps/api/distancematrix/json';
    http.Response storeToCustomerTime =
        await http.get(Uri.parse('$url?units=metric&origins=$originLat,'
            '$originLong&destinations=$destLat,$destLong&key=$GOOGLE_API_KEY'));
    print('_OrderDetailsScreenState.estimateTime ${storeToCustomerTime.body}');
    var decodedResponse = jsonDecode(storeToCustomerTime.body);
    if (decodedResponse['status'] == 'OK' &&
        decodedResponse['rows'].first['elements'].first['status'] == 'OK') {
      int secondsFromStoreToClient =
          decodedResponse['rows'].first['elements'].first['duration']['value'];
      if (orderStatus == ORDER_STATUS_SHIPPED) {
        http.Response driverToStoreTime = await http.get(Uri.parse(
            '$url?units=metric&origins=$originLat,'
            '$originLong&destinations=$destLat,$destLong&key=$GOOGLE_API_KEY'));
        var decodedDriverToStoreTimeResponse =
            jsonDecode(driverToStoreTime.body);
        if (decodedDriverToStoreTimeResponse['status'] == 'OK' &&
            decodedDriverToStoreTimeResponse['rows']
                    .first['elements']
                    .first['status'] ==
                'OK') {
          int secondsFromDriverToStore =
              decodedDriverToStoreTimeResponse['rows']
                  .first['elements']
                  .first['duration']['value'];
          estimatedTime = secondsFromStoreToClient + secondsFromDriverToStore;
        } else {
          estimatedTime =
              secondsFromStoreToClient + estimatedSecondsFromDriverToStore;
        }
      } else if (orderStatus == ORDER_STATUS_IN_TRANSIT) {
        estimatedTime = secondsFromStoreToClient;
      } else {
        estimatedTime =
            secondsFromStoreToClient + estimatedSecondsFromDriverToStore;
      }
      setState(() {});
      timerCountDown = Timer.periodic(
        Duration(seconds: 1),
        (timer) {
          if (estimatedTime == 0) {
            arrivalTimeStreamController.sink.add('');
            timer.cancel();
            setState(() {});
          } else {
            estimatedTime--;
            arrivalTimeStreamController.sink.add(
              _formatArrivalTimeDuration(
                Duration(seconds: estimatedTime),
              ),
            );
          }
        },
      );
    }
  }

  String _formatArrivalTimeDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    String formattedTime =
        '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds'
            .replaceAll('00:', '');
    return formattedTime.length == 2 ? '$formattedTime Seconds' : formattedTime;
  }

  Widget buildDeliveryDetailsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        color: isDarkMode(context) ? Color(DARK_CARD_BG_COLOR) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              widget.orderModel.takeAway == false
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'deliveryDetails'.tr(),
                          style: TextStyle(
                              fontSize: 20,
                              letterSpacing: 0.5,
                              color: isDarkMode(context)
                                  ? Colors.grey.shade200
                                  : Color(0XFF000000),
                              fontFamily: "Poppinsb"),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'address'.tr(),
                          style: TextStyle(
                              fontSize: 16,
                              letterSpacing: 0.5,
                              color: isDarkMode(context)
                                  ? Colors.grey.shade200
                                  : Color(COLOR_PRIMARY),
                              fontFamily: "Poppinsm"),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '${widget.orderModel.address.line1} ${widget.orderModel.address.line2}, ${widget.orderModel.address.city}, ${widget.orderModel.address.country}',
                          style: TextStyle(
                              fontFamily: "Poppinss",
                              fontSize: 18,
                              letterSpacing: 0.5,
                              color: isDarkMode(context)
                                  ? Colors.grey.shade200
                                  : Colors.grey.shade700),
                        ),
                        Divider(height: 40),
                      ],
                    )
                  : Container(),
              Text(
                'type'.tr(),
                style: TextStyle(
                    fontSize: 16,
                    letterSpacing: 0.5,
                    color: isDarkMode(context)
                        ? Colors.grey.shade200
                        : Color(COLOR_PRIMARY),
                    fontFamily: "Poppinsm"),
              ),
              SizedBox(height: 8),
              widget.orderModel.takeAway == false
                  ? Text(
                      'deliverToDoor'.tr(),
                      style: TextStyle(
                          fontFamily: "Poppinss",
                          fontSize: 18,
                          letterSpacing: 0.5,
                          color: isDarkMode(context)
                              ? Colors.grey.shade200
                              : Colors.grey.shade700),
                    )
                  : Text(
                      'takeaway'.tr(),
                      style: TextStyle(
                          fontFamily: "Poppinss",
                          fontSize: 18,
                          letterSpacing: 0.5,
                          color: isDarkMode(context)
                              ? Colors.grey.shade200
                              : Colors.grey.shade700),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildOrderSummaryCard(OrderModel orderModel) {
    print("order status ${widget.orderModel.id}");
    double tipValue = widget.orderModel.tipValue!.isEmpty
        ? 0.0
        : double.parse(widget.orderModel.tipValue!);
    print('\x1b[92m ${widget.orderModel.specialDiscount!.toString()}');
    double specialDiscountAmount = widget.orderModel.specialDiscount!.isNotEmpty
        ? double.parse(
            widget.orderModel.specialDiscount!['special_discount'].toString())
        : 0.0;
    var taxAmount = (widget.orderModel.taxModel == null)
        ? 0
        : getTaxValue(widget.orderModel.taxModel,
            total - discount - specialDiscountAmount);
    var totalamount = widget.orderModel.deliveryCharge == null ||
            widget.orderModel.deliveryCharge!.isEmpty
        ? total + taxAmount - discount - specialDiscountAmount
        : total +
            taxAmount +
            double.parse(widget.orderModel.deliveryCharge!) +
            tipValue -
            discount -
            specialDiscountAmount;
    //  total = total-Deliverycharge -discount;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Card(
        color: isDarkMode(context) ? Color(DARK_CARD_BG_COLOR) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 14, right: 14, top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'orderSummary'.tr(),
                style: TextStyle(
                  fontFamily: 'Poppinsm',
                  fontSize: 18,
                  letterSpacing: 0.5,
                  color: isDarkMode(context) ? Colors.white : Color(0XFF000000),
                ),
              ),
              SizedBox(height: 11),
              ListView.builder(
                  physics: NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: widget.orderModel.products.length,
                  itemBuilder: (context, index) {
                    return Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: 10, horizontal: 0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: CachedNetworkImage(
                                  height: 55,
                                  // width: 50,
                                  imageUrl: getImageVAlidUrl(
                                      widget.orderModel.products[index].photo),
                                  imageBuilder: (context, imageProvider) =>
                                      Container(
                                        decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            image: DecorationImage(
                                              image: imageProvider,
                                              fit: BoxFit.cover,
                                            )),
                                      ),
                                  errorWidget: (context, url, error) =>
                                      ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          child: Image.network(
                                            AppGlobal.placeHolderImage!,
                                            fit: BoxFit.cover,
                                            width: MediaQuery.of(context)
                                                .size
                                                .width,
                                            height: MediaQuery.of(context)
                                                .size
                                                .height,
                                          ))),
                            ),
                            Expanded(
                              flex: 10,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 14.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${widget.orderModel.products[index].name}',
                                            style: TextStyle(
                                                fontFamily: 'Poppinsr',
                                                fontSize: 16,
                                                letterSpacing: 0.5,
                                                color: isDarkMode(context)
                                                    ? Colors.grey.shade200
                                                    : Color(0xff333333)),
                                          ),
                                        ),
                                        Icon(Icons.close, size: 18),
                                        Text(
                                          '${widget.orderModel.products[index].quantity}',
                                          style: TextStyle(
                                              fontFamily: 'Poppinsr',
                                              fontSize: 16,
                                              letterSpacing: 0.5,
                                              color: isDarkMode(context)
                                                  ? Colors.grey.shade200
                                                  : Color(0xff333333)),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 5),
                                    /*Text(
                                        symbol +
                                            double.parse(widget.orderModel
                                                    .products[index].price)
                                                .toStringAsFixed(decimal),
                                        style: TextStyle(
                                          fontFamily: 'Poppinsm',
                                           fontSize: 16,
                                          letterSpacing: 0.5,
                                          color: isDarkMode(context)
                                              ? Color(COLOR_PRIMARY)
                                              : Color(0xffFF683A),
                                        ))*/

                                    getPriceTotalText(
                                        widget.orderModel.products[index]),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ));
                  }),
              SizedBox(height: 15),
              Divider(
                height: 0.5,
                color: isDarkMode(context) ? Color(0Xff35363A) : null,
              ),
              if(widget.orderModel.payment_method!=null)
              ListTile(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                title: Text(
                  'Payment Method'.tr(),
                  style: TextStyle(
                    fontFamily: 'Poppinsm',
                    fontSize: 16,
                    letterSpacing: 0.5,
                    color: isDarkMode(context)
                        ? Colors.grey.shade300
                        : Color(0xff9091A4),
                  ),
                ),
                trailing: Text(
                  "${widget.orderModel.payment_method?.toUpperCase()}",
                  style: TextStyle(
                    fontFamily: 'Poppinssm',
                    letterSpacing: 0.5,
                    fontSize: 16,
                    color: isDarkMode(context)
                        ? Colors.grey.shade300
                        : Color(0xff333333),
                  ),
                ),
              ),
              ListTile(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                title: Text(
                  'subtotal'.tr(),
                  style: TextStyle(
                    fontFamily: 'Poppinsm',
                    fontSize: 16,
                    letterSpacing: 0.5,
                    color: isDarkMode(context)
                        ? Colors.grey.shade300
                        : Color(0xff9091A4),
                  ),
                ),
                trailing: Text(
                  symbol + total.toDouble().toStringAsFixed(decimal),
                  style: TextStyle(
                    fontFamily: 'Poppinssm',
                    letterSpacing: 0.5,
                    fontSize: 16,
                    color: isDarkMode(context)
                        ? Colors.grey.shade300
                        : Color(0xff333333),
                  ),
                ),
              ),
              ListTile(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                title: Text(
                  'discount'.tr(),
                  style: TextStyle(
                    fontFamily: 'Poppinsm',
                    fontSize: 16,
                    letterSpacing: 0.5,
                    color: isDarkMode(context)
                        ? Colors.grey.shade300
                        : Color(0xff9091A4),
                  ),
                ),
                trailing: Text(
                  symbol + discount.toDouble().toStringAsFixed(decimal),
                  style: TextStyle(
                    fontFamily: 'Poppinssm',
                    letterSpacing: 0.5,
                    fontSize: 16,
                    color: isDarkMode(context)
                        ? Colors.grey.shade300
                        : Color(0xff333333),
                  ),
                ),
              ),
              if (widget.orderModel.specialDiscount!.isNotEmpty)
                Visibility(
                  visible: orderModel.vendor.specialDiscountEnable,
                  child: ListTile(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                    title: Text(
                      'special_discount'.tr() +
                          "(${widget.orderModel.specialDiscount!['special_discount_label']}${widget.orderModel.specialDiscount!['specialType'] == "amount" ? symbol : "%"})",
                      style: TextStyle(
                        fontFamily: 'Poppinssm',
                        fontSize: 16,
                        letterSpacing: 0.5,
                        color: isDarkMode(context)
                            ? Colors.grey.shade300
                            : Color(0xff9091A4),
                      ),
                    ),
                    trailing: Text(
                      symbol +
                          widget.orderModel.specialDiscount!['special_discount']
                              .toDouble()
                              .toStringAsFixed(decimal),
                      style: TextStyle(
                        fontFamily: 'Poppinssm',
                        letterSpacing: 0.5,
                        fontSize: 16,
                        color: isDarkMode(context)
                            ? Colors.grey.shade300
                            : Color(0xff333333),
                      ),
                    ),
                  ),
                ),
              widget.orderModel.takeAway == false
                  ? ListTile(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                      title: Text(
                        'deliveryCharges'.tr(),
                        style: TextStyle(
                          fontFamily: 'Poppinsm',
                          fontSize: 16,
                          letterSpacing: 0.5,
                          color: isDarkMode(context)
                              ? Colors.grey.shade300
                              : Color(0xff9091A4),
                        ),
                      ),
                      trailing: Text(
                        widget.orderModel.deliveryCharge == null
                            ? symbol + "0.0"
                            : symbol + widget.orderModel.deliveryCharge!,
                        style: TextStyle(
                          fontFamily: 'Poppinssm',
                          letterSpacing: 0.5,
                          fontSize: 16,
                          color: isDarkMode(context)
                              ? Colors.grey.shade300
                              : Color(0xff333333),
                        ),
                      ),
                    )
                  : Container(),
              widget.orderModel.takeAway == false
                  ? ListTile(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                      title: Text(
                        'tipAmount'.tr(),
                        style: TextStyle(
                          fontFamily: 'Poppinsm',
                          fontSize: 16,
                          letterSpacing: 0.5,
                          color: isDarkMode(context)
                              ? Colors.grey.shade300
                              : Color(0xff9091A4),
                        ),
                      ),
                      trailing: Text(
                        widget.orderModel.tipValue!.isEmpty
                            ? symbol + "0.0"
                            : symbol + widget.orderModel.tipValue!,
                        style: TextStyle(
                          fontFamily: 'Poppinssm',
                          letterSpacing: 0.5,
                          fontSize: 16,
                          color: isDarkMode(context)
                              ? Colors.grey.shade300
                              : Color(0xff333333),
                        ),
                      ),
                    )
                  : Container(),
              (widget.orderModel.taxModel != null && taxAmount > 0)
                  ? ListTile(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                      title: Text(
                        widget.orderModel.taxModel!.label!,
                        style: TextStyle(
                          fontFamily: 'Poppinsm',
                          fontSize: 17,
                          letterSpacing: 0.5,
                          color: isDarkMode(context)
                              ? Colors.grey.shade300
                              : Color(0xff9091A4),
                        ),
                      ),
                      trailing: Text(
                        symbol + taxAmount.toString(),
                        style: TextStyle(
                          fontFamily: 'Poppinssm',
                          letterSpacing: 0.5,
                          fontSize: 17,
                          color: isDarkMode(context)
                              ? Colors.grey.shade300
                              : Color(0xff333333),
                        ),
                      ),
                    )
                  : Container(),
              (widget.orderModel.notes != null &&
                      widget.orderModel.notes!.isNotEmpty)
                  ? ListTile(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                      title: Text(
                        "remarks",
                        style: TextStyle(
                          fontFamily: 'Poppinsm',
                          fontSize: 17,
                          letterSpacing: 0.5,
                          color: isDarkMode(context)
                              ? Colors.grey.shade300
                              : Color(0xff9091A4),
                        ),
                      ),
                      trailing: InkWell(
                        onTap: () {
                          showModalBottomSheet(
                              isScrollControlled: true,
                              isDismissible: true,
                              context: context,
                              backgroundColor: Colors.transparent,
                              enableDrag: true,
                              builder: (BuildContext context) =>
                                  viewNotesheet(widget.orderModel.notes!));
                        },
                        child: Text(
                          "view".tr(),
                          style: TextStyle(
                              fontSize: 18,
                              color: Color(COLOR_PRIMARY),
                              letterSpacing: 0.5,
                              fontFamily: 'Poppinsm'),
                        ),
                      ),
                    )
                  : Container(),
              widget.orderModel.couponCode!.trim().isNotEmpty
                  ? ListTile(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                      title: Text(
                        'couponCode'.tr(),
                        style: TextStyle(
                          fontFamily: 'Poppinsm',
                          fontSize: 16,
                          letterSpacing: 0.5,
                          color: isDarkMode(context)
                              ? Colors.grey.shade300
                              : Color(0xff9091A4),
                        ),
                      ),
                      trailing: Text(
                        widget.orderModel.couponCode!,
                        style: TextStyle(
                          fontFamily: 'Poppinsm',
                          letterSpacing: 0.5,
                          fontSize: 16,
                          color: isDarkMode(context)
                              ? Colors.grey.shade300
                              : Color(0xff333333),
                        ),
                      ),
                    )
                  : Container(),
              ListTile(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                title: Text(
                  'orderTotal'.tr(),
                  style: TextStyle(
                    fontFamily: 'Poppinsm',
                    fontSize: 16,
                    letterSpacing: 0.5,
                    color: isDarkMode(context)
                        ? Colors.grey.shade300
                        : Color(0xff333333),
                  ),
                ),
                trailing: Text(
                  symbol + totalamount.toDouble().toStringAsFixed(decimal),
                  style: TextStyle(
                    fontFamily: 'Poppinssm',
                    letterSpacing: 0.5,
                    fontSize: 16,
                    color: isDarkMode(context)
                        ? Colors.grey.shade300
                        : Color(0xff333333),
                  ),
                ),
              ),
              Visibility(
                visible: orderModel.status == ORDER_STATUS_ACCEPTED ||
                    orderModel.status == ORDER_STATUS_SHIPPED ||
                    orderModel.status == ORDER_STATUS_DRIVER_PENDING ||
                    orderModel.status == ORDER_STATUS_DRIVER_REJECTED ||
                    orderModel.status == ORDER_STATUS_SHIPPED ||
                    orderModel.status == ORDER_STATUS_IN_TRANSIT,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: InkWell(
                    child: Container(
                        padding: EdgeInsets.only(top: 8, bottom: 8),
                        decoration: BoxDecoration(
                            color: Color(COLOR_PRIMARY),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                                width: 0.8, color: Color(COLOR_PRIMARY))),
                        child: Center(
                          child: Text(
                            'semr'.tr(),
                            style: TextStyle(
                                color: isDarkMode(context)
                                    ? Color(0xffFFFFFF)
                                    : Colors.white,
                                fontFamily: "Poppinsm",
                                fontSize: 15
                                // fontWeight: FontWeight.bold,
                                ),
                          ),
                        )),
                    onTap: () async {
                      FirebaseFirestore.instance
                          .collection(USERS)
                          .doc(widget.orderModel.vendor.author)
                          .get()
                          .then((user) async {
                        try {
                          User userModel = User.fromJson(user.data() ?? {});
                          String channelID;
                          if (userModel.userID
                                  .compareTo(widget.orderModel.author.userID) <
                              0) {
                            channelID = userModel.userID +
                                widget.orderModel.author.userID;
                          } else {
                            channelID = widget.orderModel.author.userID +
                                userModel.userID;
                          }

                          ConversationModel? conversationModel =
                              await fireStoreUtils
                                  .getChannelByIdOrNull(channelID);
                          push(
                            context,
                            ChatScreen(
                              homeConversationModel: HomeConversationModel(
                                  members: [userModel],
                                  conversationModel: conversationModel),
                            ),
                          );
                        } catch (e) {
                          print(
                              'FireStoreUtils.getUserByID failed to parse user object ${user.id}');
                        }
                      });
                    },
                  ),
                ),
              ),
              Visibility(
                visible: orderModel.status != ORDER_STATUS_DRIVER_REJECTED,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: InkWell(
                    child: Container(
                        padding: EdgeInsets.only(top: 8, bottom: 8),
                        decoration: BoxDecoration(
                            color: Color(COLOR_PRIMARY),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                                width: 0.8, color: Color(COLOR_PRIMARY))),
                        child: Center(
                          child: Text(
                            'printInvoice'.tr(),
                            style: TextStyle(
                                color: isDarkMode(context)
                                    ? Color(0xffFFFFFF)
                                    : Colors.white,
                                fontFamily: "Poppinsm",
                                fontSize: 15
                                // fontWeight: FontWeight.bold,
                                ),
                          ),
                        )),
                    onTap: () async {
                      // printTicket();
                      await saveFile("${orderModel.id}");
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text("Invoice downloaded, successfully")));
                    },
                  ),
                ),
              ),
              if (img != null) Image.memory(img!),
            ],
          ),
        ),
      ),
    );
  }

  Uint8List? img;

  Future<void> saveFile(String fileName) async {
    var file;

    // Platform.isIOS comes from dart:io
    if (Platform.isIOS) {
      final dir = await getApplicationDocumentsDirectory();
      file = File('${dir.path}/$fileName.pdf');
    }
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (status != PermissionStatus.granted) {
        status = await Permission.storage.request();
      }
      if (status.isGranted) {
        const downloadsFolderPath = '/storage/emulated/0/Download';
        Directory dir = Directory(downloadsFolderPath);
        // final dir = await getApplicationDocumentsDirectory();
        file = File('${dir.path}/$fileName.pdf');
      }
    }

    // List<int> bytes = await getTicket();
    // log(bytes.toString());
    // String base64Image = base64Encode(bytes);

    dynamic slip = await generateInvoicePdf();
    try {
      await file.writeAsBytes(slip);
    } catch (e) {
      log("error file writing file: ${e}");
    } finally {
      OpenFile.open(file.path);
    }

    // log("slip generated: ${slip}");
    //
    // String base64Image = base64Encode(slip);
    // log("MK file base64 : ${base64Image}");

    // List<int> list = await getTicket();
    // Uint8List bytes = Uint8List.fromList(list);
    // log(bytes.toString());
    // String base64Image = base64Encode(bytes);
    // File f = await file.writeAsBytes(list);

    // Image.memory(base64Decode(base64Image));
    // setState(() {
    //   // img = base64Decode(base64Image);
    //   img = bytes;
    // });

    // log("MK file base64 : ${base64Image}");
  }

  Future<void> downloadPdf(Uint8List pdfData, String filename) async {
    final path = await getApplicationDocumentsDirectory();
    final file = File('${path.path}/$filename.pdf');
    await file.writeAsBytes(pdfData);
  }

  Future<void> printTicket() async {
    String? isConnected = await BluetoothThermalPrinter.connectionStatus;
    if (isConnected == "true") {
      List<int> bytes = await getTicket();
      // log(bytes.toString());
      String base64Image = base64Encode(bytes);

      // log(base64Image.toString());

      final result = await BluetoothThermalPrinter.writeBytes(bytes);
      if (result == "true") {
        showAlertDialog(context, "successfully".tr(),
            "invoicePrintSuccessfully".tr(), true);
      }
    } else {
      getBluetooth();
    }
  }

  Future<List<int>> getTicket() async {
    List<int> bytes = [];
    CapabilityProfile profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    bytes += generator.text("invoice".tr(),
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
        linesAfter: 1);

    bytes +=
        generator.text(storeName, styles: PosStyles(align: PosAlign.center));

    bytes += generator.text('Tel: $phoneNumberStore',
        styles: PosStyles(align: PosAlign.center));

    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(
          text: 'no'.tr(),
          width: 1,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: 'item'.tr(),
          width: 7,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: 'qty'.tr(),
          width: 2,
          styles: const PosStyles(align: PosAlign.center, bold: true)),
      PosColumn(
          text: 'total'.tr(),
          width: 2,
          styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]);

    List<CartProduct> products = widget.orderModel.products;
    for (int i = 0; i < products.length; i++) {
      bytes += generator.row([
        PosColumn(text: (i + 1).toString(), width: 1),
        PosColumn(
            text: products[i].name,
            width: 7,
            styles: const PosStyles(
              align: PosAlign.left,
            )),
        PosColumn(
            text: products[i].quantity.toString(),
            width: 2,
            styles: const PosStyles(align: PosAlign.center)),
        PosColumn(
            text: products[i].price.toString(),
            width: 2,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.hr();

    bytes += generator.row([
      PosColumn(
          text: 'subtotal'.tr(),
          width: 6,
          styles: const PosStyles(
            align: PosAlign.left,
            height: PosTextSize.size4,
            width: PosTextSize.size4,
          )),
      PosColumn(
          text: total.toDouble().toStringAsFixed(decimal),
          width: 6,
          styles: const PosStyles(
            align: PosAlign.right,
            height: PosTextSize.size4,
            width: PosTextSize.size4,
          )),
    ]);

    bytes += generator.row([
      PosColumn(
          text: 'discount'.tr(),
          width: 6,
          styles: const PosStyles(
            align: PosAlign.left,
            height: PosTextSize.size4,
            width: PosTextSize.size4,
          )),
      PosColumn(
          text: discount.toDouble().toStringAsFixed(decimal),
          width: 6,
          styles: const PosStyles(
            align: PosAlign.right,
            height: PosTextSize.size4,
            width: PosTextSize.size4,
          )),
    ]);

    bytes += generator.row([
      PosColumn(
          text: 'deliveryCharges'.tr(),
          width: 6,
          styles: const PosStyles(
            align: PosAlign.left,
            height: PosTextSize.size4,
            width: PosTextSize.size4,
          )),
      PosColumn(
          text: widget.orderModel.deliveryCharge == null
              ? symbol + "0.0"
              : /*symbol.toString()*/ "INR " +
                  widget.orderModel.deliveryCharge!,
          width: 6,
          styles: const PosStyles(
            align: PosAlign.right,
            height: PosTextSize.size4,
            width: PosTextSize.size4,
          )),
    ]);

    bytes += generator.row([
      PosColumn(
          text: 'tipAmount'.tr(),
          width: 6,
          styles: const PosStyles(
            align: PosAlign.left,
            height: PosTextSize.size4,
            width: PosTextSize.size4,
          )),
      PosColumn(
          text: widget.orderModel.tipValue!.isEmpty
              ? symbol + "0.0"
              : /*symbol*/ "INR " + widget.orderModel.tipValue!,
          width: 6,
          styles: const PosStyles(
            align: PosAlign.right,
            height: PosTextSize.size4,
            width: PosTextSize.size4,
          )),
    ]);
    bytes += generator.row([
      PosColumn(
          text: widget.orderModel.taxModel!.label!,
          width: 6,
          styles: const PosStyles(
            align: PosAlign.left,
            height: PosTextSize.size4,
            width: PosTextSize.size4,
          )),
      PosColumn(
          text: /*symbol*/ "INR " +
              ((widget.orderModel.taxModel == null)
                  ? "0"
                  : getTaxValue(widget.orderModel.taxModel, total - discount)
                      .toString()),
          width: 6,
          styles: const PosStyles(
            align: PosAlign.right,
            height: PosTextSize.size4,
            width: PosTextSize.size4,
          )),
    ]);

    if (widget.orderModel.notes != null &&
        widget.orderModel.notes!.isNotEmpty) {
      bytes += generator.row([
        PosColumn(
            text: "remarks".tr(),
            width: 6,
            styles: const PosStyles(
              align: PosAlign.left,
              height: PosTextSize.size4,
              width: PosTextSize.size4,
            )),
        PosColumn(
            text: widget.orderModel.notes!,
            width: 6,
            styles: const PosStyles(
              align: PosAlign.right,
              height: PosTextSize.size4,
              width: PosTextSize.size4,
            )),
      ]);
    }
    double tipValue = widget.orderModel.tipValue!.isEmpty
        ? 0.0
        : double.parse(widget.orderModel.tipValue!);
    var taxAmount = (widget.orderModel.taxModel == null)
        ? 0
        : getTaxValue(widget.orderModel.taxModel, total - discount);
    var totalamount = widget.orderModel.deliveryCharge == null ||
            widget.orderModel.deliveryCharge!.isEmpty
        ? total + taxAmount - discount
        : total +
            taxAmount +
            double.parse(widget.orderModel.deliveryCharge!) +
            tipValue -
            discount;

    bytes += generator.row([
      PosColumn(
          text: 'orderTotal'.tr(),
          width: 6,
          styles: const PosStyles(
            align: PosAlign.left,
            height: PosTextSize.size4,
            width: PosTextSize.size4,
          )),
      PosColumn(
          text: totalamount.toDouble().toStringAsFixed(decimal),
          width: 6,
          styles: const PosStyles(
            align: PosAlign.right,
            height: PosTextSize.size4,
            width: PosTextSize.size4,
          )),
    ]);

    bytes += generator.hr(ch: '=', linesAfter: 1);
    // ticket.feed(2);
    bytes += generator.text('thankYou'.tr(),
        styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.cut();

    return bytes;
  }

  Future<Uint8List> generateInvoicePdf() {
    double tipValue = widget.orderModel.tipValue!.isEmpty
        ? 0.0
        : double.parse(widget.orderModel.tipValue!);
    var taxAmount = (widget.orderModel.taxModel == null)
        ? 0
        : getTaxValue(widget.orderModel.taxModel, total - discount);
    var totalamount = widget.orderModel.deliveryCharge == null ||
            widget.orderModel.deliveryCharge!.isEmpty
        ? total + taxAmount - discount
        : total +
            taxAmount +
            double.parse(widget.orderModel.deliveryCharge!) +
            tipValue -
            discount;

    final pdf = pw.Document();

    pdf.addPage(pw.Page(
      build: (pw.Context context) {
        return pw.Column(
          children: <pw.Widget>[
            pw.Text("invoice".tr(),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 20)),
            pw.SizedBox(height: 10),
            pw.Text("[Id: ".tr() + "${widget.orderModel.id}]",
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 10),
            pw.Text(
                "Time: ".tr() +
                    "${DateFormat().format(DateTime.fromMillisecondsSinceEpoch(widget.orderModel.createdAt.millisecondsSinceEpoch))}",
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 20),
            if(widget.orderModel.payment_method!=null)
              pw.Text(
                  "Payment Method: ".tr() +
                      "${widget.orderModel.payment_method!.toUpperCase()}",
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 14)),
            if(widget.orderModel.payment_method!=null)
              pw.SizedBox(height: 20),
            pw.Text('Store: ${storeName}',
                textAlign: pw.TextAlign.left,
                style: pw.TextStyle(fontSize: 16)),
            pw.SizedBox(height: 10),
            pw.Text(
                'Name: ${widget.orderModel.author.firstName} ${widget.orderModel.author.lastName ?? ""}',
                textAlign: pw.TextAlign.left,
                style: pw.TextStyle(fontSize: 16)),
            pw.SizedBox(height: 10),
            pw.Text('Tel: $phoneNumberStore',
                textAlign: pw.TextAlign.left,
                style: pw.TextStyle(fontSize: 16)),
            pw.SizedBox(height: 10),
            pw.Text(
                'Address: ${widget.orderModel.address.line1}, ${widget.orderModel.address.city}, ${widget.orderModel.address.country}',
                textAlign: pw.TextAlign.left,
                style: pw.TextStyle(fontSize: 16)),
            pw.SizedBox(height: 10),
            pw.Divider(),
            pw.SizedBox(height: 20),
            pw.Text('Products',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(context: context, data: <List<String>>[
              <String>['no'.tr(), 'item'.tr(), 'qty'.tr(), 'total'.tr()],
              ...List.generate(widget.orderModel.products.length, (i) {
                CartProduct item = widget.orderModel.products[i];
                return <String>[
                  (i + 1).toString(),
                  item.name,
                  item.quantity.toString(),
                  item.price.toString()
                ];
              }),
            ]),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 20),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('subtotal'.tr(),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(fontSize: 15)),
                  pw.Text(total.toDouble().toStringAsFixed(decimal),
                      textAlign: pw.TextAlign.left,
                      style: pw.TextStyle(fontSize: 15)),
                ]),
            pw.SizedBox(height: 10),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('discount'.tr(),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(fontSize: 15)),
                  pw.Text(discount.toDouble().toStringAsFixed(decimal),
                      textAlign: pw.TextAlign.left,
                      style: pw.TextStyle(fontSize: 15)),
                ]),
            pw.SizedBox(height: 10),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('deliveryCharges'.tr(),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(fontSize: 15)),
                  pw.Text(
                      widget.orderModel.deliveryCharge == null
                          ? symbol + "0.0"
                          : /*symbol.toString()*/ "INR " +
                              widget.orderModel.deliveryCharge!,
                      textAlign: pw.TextAlign.left,
                      style: pw.TextStyle(fontSize: 15)),
                ]),
            pw.SizedBox(height: 10),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('tipAmount'.tr(),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(fontSize: 15)),
                  pw.Text(
                      widget.orderModel.tipValue!.isEmpty
                          ? symbol + "0.0"
                          : /*symbol*/ "INR " + widget.orderModel.tipValue!,
                      textAlign: pw.TextAlign.left,
                      style: pw.TextStyle(fontSize: 15)),
                ]),
            pw.SizedBox(height: 10),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(widget.orderModel.taxModel!.label!,
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(fontSize: 15)),
                  pw.Text(
                      /*symbol*/
                      "INR " +
                          ((widget.orderModel.taxModel == null)
                              ? "0"
                              : getTaxValue(widget.orderModel.taxModel,
                                      total - discount)
                                  .toString()),
                      textAlign: pw.TextAlign.left,
                      style: pw.TextStyle(fontSize: 15)),
                ]),
            if (widget.orderModel.notes != null &&
                widget.orderModel.notes!.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("remarks".tr(),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontSize: 15)),
                    pw.Text(widget.orderModel.notes!,
                        textAlign: pw.TextAlign.left,
                        style: pw.TextStyle(fontSize: 15)),
                  ]),
            ],
            pw.SizedBox(height: 10),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("orderTotal".tr(),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(fontSize: 15)),
                  pw.Text(totalamount.toDouble().toStringAsFixed(decimal),
                      textAlign: pw.TextAlign.left,
                      style: pw.TextStyle(fontSize: 15)),
                ]),
            pw.SizedBox(height: 10),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Text("thankYou".tr(),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 18)),
          ],
        );
      },
    ));

    return pdf.save();
  }

  List availableBluetoothDevices = [];

  Future<void> getBluetooth() async {
    final List? bluetooths = await BluetoothThermalPrinter.getBluetooths;
    print("Print $bluetooths");
    setState(() {
      availableBluetoothDevices = bluetooths!;
      showLoadingAlert();
    });
  }

  showLoadingAlert() {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'connectBluetoothDevice'.tr(),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: availableBluetoothDevices.length == 0
                ? Center(
                    child: Text(
                      "pleaseConnectDeviceFromYourBluetoothSetting".tr(),
                    ),
                  )
                : ListView.builder(
                    itemCount: availableBluetoothDevices.length,
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      return ListTile(
                        onTap: () {
                          Navigator.pop(context);
                          String select = availableBluetoothDevices[index];
                          List list = select.split("#");
                          // String name = list[0];
                          String mac = list[1];
                          setConnect(mac);
                        },
                        title: Text('${availableBluetoothDevices[index]}'),
                        subtitle: Text(
                          "clickToConnect".tr(),
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  Future<void> setConnect(String mac) async {
    final String? result = await BluetoothThermalPrinter.connect(mac);
    print("state conneected $result");
    if (result == "true") {
      printTicket();
    }
  }

  // Widget buildOrderSummaryCard() {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(horizontal: 8.0),
  //     child: Card(
  //       color: isDarkMode(context) ? Colors.grey.shade900 : Colors.white,
  //       child: Padding(
  //         padding: const EdgeInsets.all(16.0),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Text(
  //               'Order Summary'.tr(),
  //               style: TextStyle(
  //                   fontWeight: FontWeight.w700,
  //                   fontSize: 20,
  //                   color: isDarkMode(context)
  //                       ? Colors.grey.shade200
  //                       : Colors.grey.shade700),
  //             ),
  //             SizedBox(height: 16),
  //             Text(
  //               '${widget.orderModel.vendor.title}',
  //               style: TextStyle(
  //                   fontWeight: FontWeight.w400,
  //                    fontSize: 16,
  //                   color: isDarkMode(context)
  //                       ? Colors.grey.shade200
  //                       : Colors.grey.shade700),
  //             ),
  //             SizedBox(height: 16),
  //             ListView.builder(
  //               physics: NeverScrollableScrollPhysics(),
  //               shrinkWrap: true,
  //               itemCount: widget.orderModel.products.length,
  //               itemBuilder: (context, index) => Padding(
  //                 padding: EdgeInsets.symmetric(vertical: 12),
  //                 child: Row(
  //                   children: [
  //                     Container(
  //                       color: isDarkMode(context)
  //                           ? Colors.grey.shade700
  //                           : Colors.grey.shade200,
  //                       padding: EdgeInsets.all(6),
  //                       child: Text(
  //                         '${widget.orderModel.products[index].quantity}',
  //                         style: TextStyle(
  //                             fontSize: 18, fontWeight: FontWeight.bold),
  //                       ),
  //                     ),
  //                     SizedBox(width: 16),
  //                     Text(
  //                       '${widget.orderModel.products[index].name}',
  //                       style: TextStyle(
  //                           color: isDarkMode(context)
  //                               ? Colors.grey.shade300
  //                               : Colors.grey.shade800,
  //                           fontWeight: FontWeight.w500,
  //                           fontSize: 18),
  //                     )
  //                   ],
  //                 ),
  //               ),
  //             ),
  //             SizedBox(height: 16),
  //             ListTile(
  //               title: Text(
  //                 'Total'.tr(),
  //                 style: TextStyle(
  //                   fontSize: 25,
  //                   fontWeight: FontWeight.w700,
  //                   color: isDarkMode(context)
  //                       ? Colors.grey.shade300
  //                       : Colors.grey.shade700,
  //                 ),
  //               ),
  //               trailing: Text(
  //                 '\$${total.toStringAsFixed(2)}',
  //                 style: TextStyle(
  //                   fontSize: 25,
  //                   fontWeight: FontWeight.w400,
  //                   color: isDarkMode(context)
  //                       ? Colors.grey.shade300
  //                       : Colors.grey.shade700,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  BitmapDescriptor? departureIcon;
  BitmapDescriptor? destinationIcon;
  BitmapDescriptor? taxiIcon;

  void setMarkerIcon() async {
    BitmapDescriptor.fromAssetImage(
            const ImageConfiguration(
              size: Size(10, 10),
            ),
            "assets/images/pickup.png")
        .then((value) {
      departureIcon = value;
    });

    BitmapDescriptor.fromAssetImage(
            const ImageConfiguration(
              size: Size(10, 10),
            ),
            "assets/images/dropoff.png")
        .then((value) {
      destinationIcon = value;
    });

    BitmapDescriptor.fromAssetImage(
            const ImageConfiguration(
              size: Size(10, 10),
            ),
            "assets/images/bike_icon.png")
        .then((value) {
      taxiIcon = value;
    });
  }

  Map<PolylineId, Polyline> polyLines = {};
  PolylinePoints polylinePoints = PolylinePoints();
  final Map<String, Marker> _markers = {};

  late Stream<User> driverStream;
  User? _driverModel = User();

  getDriver() async {
    driverStream =
        FireStoreUtils().getDriver(currentOrder!.driverID.toString());
    driverStream.listen((event) {
      print("--->${event.location.latitude} ${event.location.longitude}");
      setState(() => _driverModel = event);
      getDirections();
    });
  }

  late Stream<OrderModel?> ordersFuture;
  OrderModel? currentOrder;

  getCurrentOrder() async {
    ordersFuture = FireStoreUtils().getOrderByID(widget.orderModel.id);
    ordersFuture.listen((event) {
      print("----?${event!.driverID}");
      setState(() {
        currentOrder = event;
        if (event.driverID!.isNotEmpty) {
          getDriver();
        }
      });
    });
  }

  getDirections() async {
    if (currentOrder != null) {
      if (currentOrder!.status == ORDER_STATUS_SHIPPED) {
        List<LatLng> polylineCoordinates = [];

        PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
          GOOGLE_API_KEY,
          PointLatLng(_driverModel!.location.latitude,
              _driverModel!.location.longitude),
          PointLatLng(
              currentOrder!.vendor.latitude, currentOrder!.vendor.longitude),
          travelMode: TravelMode.driving,
        );

        print("----?${result.points}");
        if (result.points.isNotEmpty) {
          for (var point in result.points) {
            polylineCoordinates.add(LatLng(point.latitude, point.longitude));
          }
        }
        setState(() {
          _markers.remove("Driver");
          _markers['Driver'] = Marker(
              markerId: const MarkerId('Driver'),
              infoWindow: const InfoWindow(title: "Driver"),
              position: LatLng(_driverModel!.location.latitude,
                  _driverModel!.location.longitude),
              icon: taxiIcon!,
              rotation: double.parse(_driverModel!.rotation.toString()));
        });

        _markers.remove("Destination");
        _markers['Destination'] = Marker(
          markerId: const MarkerId('Destination'),
          infoWindow: const InfoWindow(title: "Destination"),
          position: LatLng(
              currentOrder!.vendor.latitude, currentOrder!.vendor.longitude),
          icon: destinationIcon!,
        );
        addPolyLine(polylineCoordinates);
      } else if (currentOrder!.status == ORDER_STATUS_IN_TRANSIT) {
        List<LatLng> polylineCoordinates = [];

        PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
          GOOGLE_API_KEY,
          PointLatLng(_driverModel!.location.latitude,
              _driverModel!.location.longitude),
          PointLatLng(currentOrder!.author.shippingAddress.location.latitude,
              currentOrder!.author.shippingAddress.location.longitude),
          travelMode: TravelMode.driving,
        );

        print("----?${result.points}");
        if (result.points.isNotEmpty) {
          for (var point in result.points) {
            polylineCoordinates.add(LatLng(point.latitude, point.longitude));
          }
        }
        setState(() {
          _markers.remove("Driver");
          _markers['Driver'] = Marker(
            markerId: const MarkerId('Driver'),
            infoWindow: const InfoWindow(title: "Driver"),
            position: LatLng(_driverModel!.location.latitude,
                _driverModel!.location.longitude),
            rotation: double.parse(_driverModel!.rotation.toString()),
            icon: taxiIcon!,
          );
        });

        _markers.remove("Destination");
        _markers['Destination'] = Marker(
          markerId: const MarkerId('Destination'),
          infoWindow: const InfoWindow(title: "Destination"),
          position: LatLng(
              currentOrder!.author.shippingAddress.location.latitude,
              currentOrder!.author.shippingAddress.location.longitude),
          icon: destinationIcon!,
        );
        addPolyLine(polylineCoordinates);
      }
    }
  }

  addPolyLine(List<LatLng> polylineCoordinates) {
    PolylineId id = const PolylineId("poly");
    Polyline polyline = Polyline(
      polylineId: id,
      color: Color(COLOR_PRIMARY),
      points: polylineCoordinates,
      width: 4,
      geodesic: true,
    );
    polyLines[id] = polyline;
    updateCameraLocation(
        polylineCoordinates.first, polylineCoordinates.last, _mapController);
    setState(() {});
  }

  Future<void> updateCameraLocation(
    LatLng source,
    LatLng destination,
    GoogleMapController? mapController,
  ) async {
    if (mapController == null) return;

    LatLngBounds bounds;

    if (source.latitude > destination.latitude &&
        source.longitude > destination.longitude) {
      bounds = LatLngBounds(southwest: destination, northeast: source);
    } else if (source.longitude > destination.longitude) {
      bounds = LatLngBounds(
          southwest: LatLng(source.latitude, destination.longitude),
          northeast: LatLng(destination.latitude, source.longitude));
    } else if (source.latitude > destination.latitude) {
      bounds = LatLngBounds(
          southwest: LatLng(destination.latitude, source.longitude),
          northeast: LatLng(source.latitude, destination.longitude));
    } else {
      bounds = LatLngBounds(southwest: source, northeast: destination);
    }

    CameraUpdate cameraUpdate = CameraUpdate.newLatLngBounds(bounds, 100);

    return checkCameraLocation(cameraUpdate, mapController);
  }

  Future<void> checkCameraLocation(
      CameraUpdate cameraUpdate, GoogleMapController mapController) async {
    mapController.animateCamera(cameraUpdate);
    LatLngBounds l1 = await mapController.getVisibleRegion();
    LatLngBounds l2 = await mapController.getVisibleRegion();

    if (l1.southwest.latitude == -90 || l2.southwest.latitude == -90) {
      return checkCameraLocation(cameraUpdate, mapController);
    }
  }

  Widget buildDeliveryMap(OrderModel orderModel) {
    return SizedBox(
      height: MediaQuery.of(context).size.height / 2.7,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0.0),
          ),
          child: GoogleMap(
            onMapCreated: _onMapCreated,
            myLocationEnabled: false,
            myLocationButtonEnabled: true,
            mapType: MapType.normal,
            zoomControlsEnabled: true,
            polylines: Set<Polyline>.of(polyLines.values),
            markers: _markers.values.toSet(),
            initialCameraPosition: CameraPosition(
              zoom: 15,
              target: LatLng(currentOrder!.vendor.latitude,
                  currentOrder!.vendor.longitude),
            ),
          ),
        ),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (isDarkMode(context))
      _mapController!.setMapStyle('[{"featureType": "all","'
          'elementType": "'
          'geo'
          'met'
          'ry","stylers": [{"color": "#242f3e"}]},{"featureType": "all","elementType": "labels.text.stroke","stylers": [{"lightness": -80}]},{"featureType": "administrative","elementType": "labels.text.fill","stylers": [{"color": "#746855"}]},{"featureType": "administrative.locality","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "poi","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "poi.park","elementType": "geometry","stylers": [{"color": "#263c3f"}]},{"featureType": "poi.park","elementType": "labels.text.fill","stylers": [{"color": "#6b9a76"}]},{"featureType": "road","elementType": "geometry.fill","stylers": [{"color": "#2b3544"}]},{"featureType": "road","elementType": "labels.text.fill","stylers": [{"color": "#9ca5b3"}]},{"featureType": "road.arterial","elementType": "geometry.fill","stylers": [{"color": "#38414e"}]},{"featureType": "road.arterial","elementType": "geometry.stroke","stylers": [{"color": "#212a37"}]},{"featureType": "road.highway","elementType": "geometry.fill","stylers": [{"color": "#746855"}]},{"featureType": "road.highway","elementType": "geometry.stroke","stylers": [{"color": "#1f2835"}]},{"featureType": "road.highway","elementType": "labels.text.fill","stylers": [{"color": "#f3d19c"}]},{"featureType": "road.local","elementType": "geometry.fill","stylers": [{"color": "#38414e"}]},{"featureType": "road.local","elementType": "geometry.stroke","stylers": [{"color": "#212a37"}]},{"featureType": "transit","elementType": "geometry","stylers": [{"color": "#2f3948"}]},{"featureType": "transit.station","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "water","elementType": "geometry","stylers": [{"color": "#17263c"}]},{"featureType": "water","elementType": "labels.text.fill","stylers": [{"color": "#515c6d"}]},{"featureType": "water","elementType": "labels.text.stroke","stylers": [{"lightness": -20}]}]');
    if (orderStatus == ORDER_STATUS_IN_TRANSIT) {
      updateCameraLocation(vendorLocation!, userLocation!, _mapController);
    } else if (orderStatus == ORDER_STATUS_SHIPPED) {
      updateCameraLocation(
          LatLng(_driverModel?.location.latitude ?? 0,
              _driverModel!.location.longitude),
          vendorLocation!,
          _mapController);
    } else if (orderStatus == ORDER_STATUS_ACCEPTED && isTakeAway) {
      updateCameraLocation(vendorLocation!, userLocation!, _mapController);
    }
  }

  Widget buildDriverCard(OrderModel order) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        color: isDarkMode(context) ? Color(DARK_CARD_BG_COLOR) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                RichText(
                  text: TextSpan(children: [
                    TextSpan(
                        text: 'isIn'.tr(
                          args: [
                            '${order.driver?.firstName ?? 'ourDriver'.tr()}',
                            '${order.driver?.carName ?? 'hisCar'.tr()}'
                          ],
                        ),
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isDarkMode(context)
                                ? Colors.grey.shade200
                                : Colors.grey.shade600,
                            fontSize: 17)),
                    TextSpan(
                      text:
                          '\n${order.driver?.carNumber ?? 'noCarNumber'.tr() + " "
                              'provided'.tr()}',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: isDarkMode(context)
                              ? Colors.grey.shade200
                              : Colors.grey.shade800),
                    ),
                  ]),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    displayCircleImage(
                        order.driver?.carPictureURL ??
                            'https://firebasestorage.googleapis.com/v0/b/gromart-5dd93.appspot.com/o/images%2Fcar_default_image.png?alt=media&token=503e1888-2231-4621-a2d0-51f9bb7e7208',
                        80,
                        true),
                    Positioned.directional(
                        textDirection: Directionality.of(context),
                        start: -65,
                        child: displayCircleImage(
                            order.author.profilePictureURL, 80, true))
                  ],
                ),
              ]),
              SizedBox(height: 16),
              ListTile(
                leading: FloatingActionButton(
                  onPressed: order.driver == null
                      ? null
                      : () {
                          String url = 'tel:${order.driver!.phoneNumber}';
                          launch(url);
                        },
                  mini: true,
                  tooltip: 'callTo'.tr(
                    args: ['${order.driver?.firstName ?? 'driver'.tr()}'],
                  ),
                  backgroundColor:
                      // isDarkMode(context) ? Colors.grey.shade700 :
                      Colors.green,
                  elevation: 0,
                  child: Icon(Icons.phone, color: Color(0xFFFFFFFF)),
                ),
                title: GestureDetector(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDarkMode(context)
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.all(
                        Radius.circular(360),
                      ),
                    ),
                    child: Text(
                      'sendAMessage'.tr(),
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.start,
                    ),
                  ),
                  onTap: order.driver == null
                      ? null
                      : () async {
                          String channelID;
                          if (order.driver!.userID
                                  .compareTo(order.author.userID) <
                              0) {
                            channelID =
                                order.driver!.userID + order.author.userID;
                          } else {
                            channelID =
                                order.author.userID + order.driver!.userID;
                          }

                          ConversationModel? conversationModel =
                              await fireStoreUtils
                                  .getChannelByIdOrNull(channelID);
                          push(
                            context,
                            ChatScreen(
                              homeConversationModel: HomeConversationModel(
                                  members: [order.driver!],
                                  conversationModel: conversationModel),
                            ),
                          );
                        },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  getPriceTotalText(CartProduct s) {
    double total = 0.0;

    if (s.extras_price != null &&
        s.extras_price!.isNotEmpty &&
        double.parse(s.extras_price!) != 0.0) {
      total += s.quantity * double.parse(s.extras_price!);
    }
    total += s.quantity * double.parse(s.price);

    return Text(
      symbol + total.toString(),
      style: TextStyle(
          fontSize: 20, color: Color(COLOR_PRIMARY), fontFamily: "Poppinssm"),
    );
  }

  viewNotesheet(String notes) {
    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height / 4.3,
          left: 25,
          right: 25),
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(style: BorderStyle.none)),
      child: Column(
        children: [
          InkWell(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 45,
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 0.3),
                    color: Colors.transparent,
                    shape: BoxShape.circle),

                // radius: 20,
                child: Center(
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              )),
          SizedBox(
            height: 25,
          ),
          Expanded(
              child: Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: isDarkMode(context) ? Color(0XFF2A2A2A) : Colors.white),
            alignment: Alignment.center,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                      padding: EdgeInsets.only(top: 20),
                      child: Text(
                        'remark'.tr(),
                        style: TextStyle(
                            fontFamily: 'Poppinssb',
                            color: isDarkMode(context)
                                ? Colors.white70
                                : Colors.black,
                            fontSize: 16),
                      )),
                  Container(
                    padding: EdgeInsets.only(left: 20, right: 20, top: 20),
                    // height: 120,
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      child: Container(
                        padding: EdgeInsets.only(
                            left: 20, right: 20, top: 20, bottom: 20),
                        color: isDarkMode(context)
                            ? Color(DARK_BG_COLOR)
                            : Color(0XFFF1F4F7),
                        // height: 120,
                        alignment: Alignment.center,
                        child: Text(
                          notes,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDarkMode(context)
                                ? Colors.white70
                                : Colors.black,
                            fontFamily: 'Poppinsm',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}
