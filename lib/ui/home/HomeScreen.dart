// ignore_for_file: unused_field, avoid_init_to_null, unused_local_variable, unnecessary_null_comparison, unnecessary_statements, camel_case_types

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:clipboard/clipboard.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geoflutterfire/geoflutterfire.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gromartconsumer/AppGlobal.dart';
import 'package:gromartconsumer/constants.dart';
import 'package:gromartconsumer/main.dart';
import 'package:gromartconsumer/model/AddressModel.dart';
import 'package:gromartconsumer/model/BannerModel.dart';
import 'package:gromartconsumer/model/CuisineModel.dart';
import 'package:gromartconsumer/model/CurrencyModel.dart';
import 'package:gromartconsumer/model/FavouriteModel.dart';
import 'package:gromartconsumer/model/ProductModel.dart';
import 'package:gromartconsumer/model/User.dart';
import 'package:gromartconsumer/model/VendorModel.dart';
import 'package:gromartconsumer/model/offer_model.dart';
import 'package:gromartconsumer/services/FirebaseHelper.dart';
import 'package:gromartconsumer/services/helper.dart';
import 'package:gromartconsumer/services/localDatabase.dart';
import 'package:gromartconsumer/ui/auth/AuthScreen.dart';
import 'package:gromartconsumer/ui/categoryDetailsScreen/CategoryDetailsScreen.dart';
import 'package:gromartconsumer/ui/cuisinesScreen/CuisinesScreen.dart';
import 'package:gromartconsumer/ui/home/CurrentAddressChangeScreen.dart';
import 'package:gromartconsumer/ui/home/view_all_new_arrival_store_screen.dart';
import 'package:gromartconsumer/ui/home/view_all_offer_screen.dart';
import 'package:gromartconsumer/ui/home/view_all_popular_food_near_by_screen.dart';
import 'package:gromartconsumer/ui/home/view_all_popular_store_screen.dart';
import 'package:gromartconsumer/ui/home/view_all_store.dart';
import 'package:gromartconsumer/ui/vendorProductsScreen/VendorProductsScreen.dart';
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart';
import 'package:place_picker/place_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// import 'package:extended_list/extended_list.dart';
// import 'package:loadmore/loadmore.dart';
// import 'package:infinite_widgets/infinite_widgets.dart';

class HomeScreen extends StatefulWidget {
  final User? user;
  final String vendorId;

  HomeScreen({
    Key? key,
    required this.user,
    vendorId,
  })  : vendorId = vendorId ?? "",
        super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final fireStoreUtils = FireStoreUtils();
  late Future<List<CuisineModel>> cuisinesFuture;

  late Future<List<ProductModel>> productsFuture;
  PageController _controller = PageController(viewportFraction: 0.8, keepPage: true);
  List<VendorModel> vendors = [];
  List<VendorModel> allvendors = [];
  List<VendorModel> popularStoreLst = [];
  List<VendorModel> newArrivalLst = [];
  late Future<List<CurrencyModel>> futureCurrency;
  String? data, d;
  VendorModel? offerVendorModel = null;
  VendorModel? popularNearFoodVendorModel = null;
  late Future<Position> currenLocation;
  var currentlatitude, currentlongitude;
  Stream<List<VendorModel>>? lstVendor;
  Stream<List<VendorModel>>? lstNewArrivalStore;
  Stream<List<VendorModel>>? lstAllStore;
  List<ProductModel> lstNearByFood = [];
  bool showLoader = true, islocationGet = false;
  bool isVendorLoad = false;
  VendorModel? preVendorMOdel = null;

  //Stream<List<FavouriteModel>>? lstFavourites;
  late Future<List<FavouriteModel>> lstFavourites;
  List<String> lstFav = [];
  FavouriteModel? selectedFavourites;

  // List<ProductModel> product = [];
  String? name = "";

  String? currentLocation = "";

  String? selctedOrderTypeValue = "Delivery";
  Stream<List<OfferModel>>? lstOfferData;

  //Stream<List<OfferModel>>? lstOfferData1;

  List<OfferModel> lstOfferData1 = [];
  List<OfferModel> lst = [];
  List<VendorModel> vendorssssss = [];

  // Init firestore and geoFlutterFire
  final geo = Geoflutterfire();
  final _firestore = FirebaseFirestore.instance;

  _getLocation() async {
    islocationGet = true;
    if (MyAppState.selectedPosotion.longitude == 0 && MyAppState.selectedPosotion.latitude == 0) {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).whenComplete(() {});
      MyAppState.selectedPosotion = position;
      islocationGet = false;
    }

    debugPrint('location: ${MyAppState.selectedPosotion.latitude}');

    List<Placemark> placemarks =
        await placemarkFromCoordinates(MyAppState.selectedPosotion.latitude, MyAppState.selectedPosotion.longitude).catchError((error) {
      print("error in location $error");
      return Future.error(error);
    });
    Placemark placeMark = placemarks[0];
    if (mounted) {
      getData();
      setState(() {
        currentLocation = placeMark.name.toString() +
            ", " +
            placeMark.subLocality.toString() +
            ", " +
            placeMark.locality.toString() +
            ", " +
            placeMark.administrativeArea.toString() +
            ", " +
            placeMark.postalCode.toString() +
            ", " +
            placeMark.country.toString();
      });
    }
    if (MyAppState.currentUser != null) {
      if (MyAppState.currentUser!.location.longitude == 0.01 && MyAppState.currentUser!.location.longitude == 0.01) {
        await _firestore.collection(USERS).doc(MyAppState.currentUser!.userID).update(
          {"location": new UserLocation(latitude: MyAppState.selectedPosotion.latitude, longitude: MyAppState.selectedPosotion.longitude).toJson()},
        );
      }
      MyAppState.currentUser!.location = new UserLocation(latitude: MyAppState.selectedPosotion.latitude, longitude: MyAppState.selectedPosotion.longitude);
      AddressModel userAddress = AddressModel(
          name: MyAppState.currentUser!.fullName(),
          postalCode: placeMark.postalCode.toString(),
          line1: placeMark.name.toString() + ", " + placeMark.subLocality.toString(),
          line2: placeMark.administrativeArea.toString(),
          country: placeMark.country.toString(),
          city: placeMark.locality.toString(),
          location: MyAppState.currentUser!.location,
          email: MyAppState.currentUser!.email);
      MyAppState.currentUser!.shippingAddress = userAddress;
      await FireStoreUtils.updateCurrentUserAddress(userAddress);
    }
    print(currentLocation.toString() + "======={}{}{}{}{}{{" + placeMark.country.toString());
  }

  bool isLocationPermissionAllowed = false;
  loc.Location location = new loc.Location();

  getLoc() async {
    bool _serviceEnabled;
    loc.PermissionStatus _permissionGranted;

    _serviceEnabled = await location.requestService();
    if (_serviceEnabled) {
      var status = await Permission.location.status;
      if (status.isDenied) {
        if (Platform.isIOS) {
          status = await Permission.locationWhenInUse.request();
        } else {
          status = await Permission.location.request();
        }

        if (status.isGranted) {
          _getLocation();
        } else if (status.isPermanentlyDenied) {
          if (Platform.isIOS) {
            openAppSettings();
          } else {
            await Permission.contacts.shouldShowRequestRationale;
            if (status.isPermanentlyDenied) {
              getTempLocation();
            }
          }
        }
      } else if (status.isRestricted) {
        getTempLocation();
      } else if (status.isPermanentlyDenied) {
        if (Platform.isIOS) {
          openAppSettings();
        } else {
          await Permission.contacts.shouldShowRequestRationale;
        }
      } else {
        _getLocation();
      }
      return;
    } else {
      getTempLocation();
    }
    //_currentPosition = await location.getLocation();
  }

  List<BannerModel> bannerHome = [];

  bool isHomeBannerLoading = true;

  getBanner() {
    fireStoreUtils.getHomeBanner().then((value) {
      print('\x1b[92m Banner Loading : $value =====');
      print('\x1b[92m Banner Loading : $isHomeBannerLoading');
      setState(
        () {
          bannerHome = value;
          isHomeBannerLoading = false;
        },
      );
    });
  }

  // Database db;
  @override
  void initState() {
    super.initState();
    cuisinesFuture = fireStoreUtils.getCuisines();
    setCurrency();
    getBanner();
    fireStoreUtils.getVendors().then((value) {
      if (value != null) {
        allvendors.clear();
        allvendors.addAll(value);
      }
    });
    // print("USERID---->>11"+MyAppState.currentUser!.userID);
    FireStoreUtils().getRazorPayDemo();
    FireStoreUtils.getPaypalSettingData();
    FireStoreUtils.getStripeSettingData();
    FireStoreUtils.getPayStackSettingData();
    FireStoreUtils.getFlutterWaveSettingData();
    FireStoreUtils.getPaytmSettingData();
    FireStoreUtils.getWalletSettingData();
    FireStoreUtils.getPayFastSettingData();
    FireStoreUtils.getMercadoPagoSettingData();
    // if (isLocationPermissionAllowed == false) {
    getLoc();
    //} else {}
  }

  setCurrency() async {
    await FireStoreUtils().getCurrency().then((value) {
      // curcy(value.first);
      for (CurrencyModel currencyModel in value) {
        curcy(currencyModel);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isLocationAvail = (MyAppState.selectedPosotion.latitude == 0 && MyAppState.selectedPosotion.longitude == 0);
    return Scaffold(
        backgroundColor: isDarkMode(context) ? Color(DARK_VIEWBG_COLOR) : Color(0xffFFFFFF),
        body: isLocationAvail
            ? showEmptyState("weDontHaveYourLocation".tr(), 'setYourLocationToStartedSearchingForStoresInYourArea'.tr(), action: () async {
                if (islocationGet) {
                } else {
                  LocationResult result = await Navigator.of(context).push(MaterialPageRoute(builder: (context) => PlacePicker(GOOGLE_API_KEY)));

                  setState(() {
                    MyAppState.selectedPosotion = Position.fromMap({'latitude': result.latLng!.latitude, 'longitude': result.latLng!.longitude});

                    currentLocation = result.formattedAddress;
                    getData();
                  });
                }
              }, buttonTitle: 'Select'.tr(), isDarkMode: isDarkMode(context))
            : SingleChildScrollView(
                child: Container(
                  color: isDarkMode(context) ? Color(DARK_COLOR) : Color(0xffFFFFFF),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                color: isDarkMode(context) ? Colors.white : Colors.black,
                              ),
                              SizedBox(
                                width: 20,
                              ),
                              Expanded(
                                child: Text(currentLocation.toString(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 14, color: Color(COLOR_PRIMARY), fontFamily: "Poppinsr"))
                                    .tr(),
                              ),
                              InkWell(
                                onTap: () {
                                  Navigator.of(context)
                                      .push(PageRouteBuilder(
                                    pageBuilder: (context, animation, secondaryAnimation) => CurrentAddressChangeScreen(),
                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                      return child;
                                    },
                                  ))
                                      .then((value) {
                                    if (value != null && mounted) {
                                      setState(() {
                                        currentLocation = value;
                                        getData();
                                      });
                                    }
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.fromLTRB(5, 5, 5, 5),
                                  decoration: BoxDecoration(borderRadius: new BorderRadius.circular(10), color: Color(COLOR_PRIMARY), boxShadow: [
                                    // BoxShadow(
                                    //   color: Colors.grey.withOpacity(0.5),
                                    //   spreadRadius: 5,
                                    //   blurRadius: 7,
                                    //   offset: Offset(0, 3), // changes position of shadow
                                    // ),
                                  ]),
                                  child: Text("Change", style: TextStyle(fontSize: 14, color: Colors.white, fontFamily: "Poppinsr")).tr(),
                                ),
                              ),
                            ],
                          )),
                      // Container(
                      //     padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
                      //     child:
                      //         Text("hello".tr() + " " + name! + ",", style: TextStyle(fontSize: 24, color: Color(COLOR_PRIMARY), fontFamily: "Poppinsr")).tr()),
                      Container(
                          padding: const EdgeInsets.only(top: 0, left: 16, bottom: 20, right: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text("findYouritem",
                                        style: TextStyle(fontSize: 26, color: isDarkMode(context) ? Colors.white : Color(0xFF333333), fontFamily: "Poppinssb"))
                                    .tr(),
                              ),
                              Container(
                                child: DropdownButton(
                                  // Not necessary for Option 1
                                  value: selctedOrderTypeValue,
                                  onChanged: (newValue) async {
                                    int cartProd = 0;
                                    await Provider.of<CartDatabase>(context, listen: false).allCartProducts.then((value) {
                                      if (value != null) {
                                        cartProd = value.length;
                                      }
                                    });

                                    if (cartProd > 0) {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) => ShowDialogToDismiss(
                                          title: '',
                                          content: 'doYouReallyWantToChangeTheDeliveryOptionYourCartWiilBeEmpty'.tr(),
                                          buttonText: 'close'.tr().toUpperCase(),
                                          secondaryButtonText: 'ok'.tr(),
                                          action: () {
                                            Navigator.of(context).pop();
                                            Provider.of<CartDatabase>(context, listen: false).deleteAllProducts();
                                            setState(() {
                                              selctedOrderTypeValue = newValue.toString();
                                              saveFoodTypeValue();
                                              getData();
                                            });
                                          },
                                        ),
                                      );
                                    } else {
                                      setState(() {
                                        selctedOrderTypeValue = newValue.toString();

                                        saveFoodTypeValue();
                                        getData();
                                      });
                                    }
                                  },
                                  icon: Icon(Icons.keyboard_arrow_down),
                                  items: [
                                    'delivery'.tr(),
                                    'takeaway'.tr(),
                                  ].map((location) {
                                    return DropdownMenuItem(
                                      child: new Text(location).tr(),
                                      value: location,
                                    );
                                  }).toList(),
                                ),
                              )
                            ],
                          )),
                      Container(
                          color: isDarkMode(context) ? Color(DARK_COLOR) : Color(0xffFFFFFF),
                          padding: EdgeInsets.only(bottom: 25),
                          child: isHomeBannerLoading
                              ? Center(child: CircularProgressIndicator())
                              : bannerHome.isNotEmpty
                                  ? Container(
                                      height: MediaQuery.of(context).size.height * 0.23,
                                      child: PageView.builder(
                                          itemCount: bannerHome.length,
                                          scrollDirection: Axis.horizontal,
                                          controller: _controller,
                                          allowImplicitScrolling: true,
                                          itemBuilder: (context, index) => buildBestDealPage(bannerHome[index])))
                                  : showEmptyState('No Deals'.tr(), 'Start by adding best deals to firebase.'.tr())),
                      buildTitleRow(
                        titleValue: "categories".tr(),
                        onClick: () {
                          push(
                            context,
                            CuisinesScreen(
                              isPageCallFromHomeScreen: true,
                            ),
                          );
                        },
                      ),
                      Container(
                        color: isDarkMode(context) ? Color(DARK_COLOR) : Color(0xffFFFFFF),
                        child: FutureBuilder<List<CuisineModel>>(
                            future: cuisinesFuture,
                            initialData: [],
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting)
                                return Center(
                                  child: CircularProgressIndicator.adaptive(
                                    valueColor: AlwaysStoppedAnimation(Color(COLOR_PRIMARY)),
                                  ),
                                );

                              if ((snapshot.hasData || (snapshot.data?.isNotEmpty ?? false)) && mounted) {
                                return Container(
                                    //padding: EdgeInsets.only(left: 10),
                                    height: 150,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: snapshot.data!.length >= 15 ? 15 : snapshot.data!.length,
                                      itemBuilder: (context, index) {
                                        print('\x1b[92m ========== ${snapshot.data![index].title}');
                                        return buildCategoryItem(snapshot.data![index]);
                                      },
                                    ));
                              } else {
                                return showEmptyState('noCategories'.tr(), 'startByAddingCategoriesToFirebase'.tr());
                              }
                            }),
                      ),
                      buildTitleRow(
                        titleValue: "topSelling".tr(),
                        onClick: () {
                          push(
                            context,
                            ViewAllPopularFoodNearByScreen(),
                          );
                        },
                      ),
                      Container(
                        height: 120,
                        child: showLoader && mounted
                            ? Center(
                                child: CircularProgressIndicator.adaptive(
                                  valueColor: AlwaysStoppedAnimation(Color(COLOR_PRIMARY)),
                                ),
                              )
                            : lstNearByFood.length == 0
                                ? showEmptyState('noTopSellingFound'.tr(), 'startByAddingItemsToFirebase'.tr())
                                : ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: lstNearByFood.length >= 15 ? 15 : lstNearByFood.length,
                                    itemBuilder: (context, index) {
                                      if (vendors.length != 0) {
                                        popularNearFoodVendorModel = null;
                                        for (int a = 0; a < vendors.length; a++) {
                                          if (vendors[a].id == lstNearByFood[index].vendorID) {
                                            popularNearFoodVendorModel = vendors[a];
                                          }
                                        }
                                      }

                                      return popularNearFoodVendorModel == null
                                          ? Container()
                                          : popularFoodItem(context, lstNearByFood[index], popularNearFoodVendorModel!);
                                    }),
                      ),
                      buildTitleRow(
                        titleValue: "newArrivals".tr(),
                        onClick: () {
                          push(
                            context,
                            ViewAllNewArrivalStoreScreen(),
                          );
                        },
                      ),
                      StreamBuilder<List<VendorModel>>(
                          stream: lstNewArrivalStore,
                          initialData: [],
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting)
                              return Center(
                                child: CircularProgressIndicator.adaptive(
                                  valueColor: AlwaysStoppedAnimation(Color(COLOR_PRIMARY)),
                                ),
                              );

                            if ((snapshot.hasData || (snapshot.data?.isNotEmpty ?? false)) && mounted) {
                              newArrivalLst = snapshot.data!;

                              return Container(
                                  width: MediaQuery.of(context).size.width,
                                  height: 260,
                                  margin: EdgeInsets.fromLTRB(0, 0, 0, 10),
                                  child: ListView.builder(
                                      shrinkWrap: true,
                                      scrollDirection: Axis.horizontal,
                                      physics: BouncingScrollPhysics(),
                                      itemCount: newArrivalLst.length >= 15 ? 15 : newArrivalLst.length,
                                      itemBuilder: (context, index) => buildNewArrivalItem(newArrivalLst[index])));
                            } else {
                              return showEmptyState('NoVendors'.tr(), 'startByAddingVendorsToFirebase'.tr());
                            }
                          }),
                      buildTitleRow(
                        titleValue: "Offers For You".tr(),
                        onClick: () {
                          push(
                            context,
                            OffersScreen(
                              vendors: allvendors,
                            ),
                          );
                        },
                      ),
                      StreamBuilder<List<OfferModel>>(
                          stream: lstOfferData,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting)
                              return Container(
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            /* if (!snapshot.hasData ||
                          (snapshot.data?.isEmpty ?? true)) {
                        return Container(
                          height: MediaQuery.of(context).size.height * 0.9,
                          alignment: Alignment.center,
                          child: showEmptyState('No Coupons'.tr(),
                              'All your coupons will show up here'.tr()),
                        );
                      } else {
                        return Container(
                            width: MediaQuery.of(context).size.width,
                            height: 300,
                            margin: EdgeInsets.fromLTRB(10, 0, 0, 10),
                            child: ListView.builder(
                                shrinkWrap: true,
                                scrollDirection: Axis.horizontal,
                                physics: BouncingScrollPhysics(),
                                itemCount: snapshot.data!.length,
                                itemBuilder: (context, index) {

                                  for (int a = 0; a < vendors.length; a++) {
                                    for (int offa = 0;
                                        offa < snapshot.data!.length;
                                        offa++) {
                                      if (vendors[a].id ==
                                          snapshot.data![offa].restaurantId) {
                                        //setState(() {

                                        offerVendorModel = vendors[a];
                                        print(offerVendorModel!.id.toString() +
                                            "{}{{}{}{}}{}");

                                        //});
                                      }
                                    }
                                  }
                                  return offerVendorModel == null?Container():buildCouponsForYouItem(offerVendorModel!,
                                      snapshot.data![index]);
                                }));
                      }  */ /* else {
                        return showEmptyState('No Vendors'.tr(),
                            'Start by adding vendors to firebase.'.tr());
                      } */
                            if ((snapshot.hasData || (snapshot.data?.isNotEmpty ?? false)) && mounted) {
                              return Container(
                                  width: MediaQuery.of(context).size.width,
                                  height: 300,
                                  margin: EdgeInsets.fromLTRB(0, 0, 0, 10),
                                  child: ListView.builder(
                                      shrinkWrap: true,
                                      scrollDirection: Axis.horizontal,
                                      physics: BouncingScrollPhysics(),
                                      itemCount: snapshot.data!.length >= 15 ? 15 : snapshot.data!.length,
                                      itemBuilder: (context, index) {
                                        offerVendorModel = null;
                                        if (allvendors.length != 0) {
                                          for (int a = 0; a < allvendors.length; a++) {
                                            if (allvendors[a].id == snapshot.data![index].storeId) {
                                              offerVendorModel = allvendors[a];
                                            }
                                          }
                                        }
                                        return offerVendorModel == null
                                            ? Container()
                                            : buildCouponsForYouItem(context, offerVendorModel!, snapshot.data![index]);
                                      }));
                            } else {
                              return showEmptyState('NoVendors'.tr(), 'startByAddingVendorsToFirebase'.tr());
                            }
                          }),
                      buildTitleRow(
                        titleValue: "popularStores".tr(),
                        onClick: () {
                          push(
                            context,
                            ViewAllPopularStoreScreen(),
                          );
                        },
                      ),
                      popularStoreLst.length == 0
                          ? showEmptyState('noPopularStore'.tr(), 'noPopularStoreFound'.tr())
                          : Container(
                              width: MediaQuery.of(context).size.width,
                              height: 260,
                              margin: EdgeInsets.fromLTRB(10, 0, 0, 10),
                              child: ListView.builder(
                                  shrinkWrap: true,
                                  scrollDirection: Axis.horizontal,
                                  physics: BouncingScrollPhysics(),
                                  itemCount: popularStoreLst.length >= 5 ? 5 : popularStoreLst.length,
                                  itemBuilder: (context, index) => buildPopularsItem(popularStoreLst[index]))),
                      buildTitleRow(
                        titleValue: "allStores".tr(),
                        onClick: () {},
                        isViewAll: true,
                      ),
                      // SizedBox(
                      //   width: MediaQuery.of(context).size.width,
                      //   child: PaginateFirestore(
                      //     //item builder type is compulsory.
                      //     itemBuilder: (context, documentSnapshots, index) {
                      //       return buildAllRestaurantsData(
                      //             VendorModel.fromJson(documentSnapshots[index].data() as Map<String, dynamic>));
                      //     },
                      //     // orderBy is compulsory to enable pagination
                      //     query: FireStoreUtils().getStoreQuery(),
                      //     itemsPerPage: 10,
                      //     shrinkWrap: true,
                      //     itemBuilderType: PaginateBuilderType.listView,
                      //     scrollDirection: Axis.vertical,
                      //     physics: BouncingScrollPhysics(),
                      //     isLive: true,
                      //   ),
                      // ),
                      StreamBuilder<List<VendorModel>>(
                          stream: lstAllStore,
                          initialData: [],
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting)
                              return Center(
                                child: CircularProgressIndicator.adaptive(
                                  valueColor: AlwaysStoppedAnimation(Color(COLOR_PRIMARY)),
                                ),
                              );

                            if ((snapshot.hasData || (snapshot.data?.isNotEmpty ?? false)) && mounted) {
                              return Container(
                                width: MediaQuery.of(context).size.width,
                                margin: EdgeInsets.fromLTRB(10, 0, 0, 10),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  scrollDirection: Axis.vertical,
                                  physics: BouncingScrollPhysics(),
                                  itemCount: vendors.length > 15 ? 15 : vendors.length,
                                  itemBuilder: (context, index) {
                                    return buildAllRestaurantsData(vendors[index]);

                                  }
                                ),
                              );
                            } else {
                              return showEmptyState('No Vendors'.tr(), 'Start by adding vendors to firebase.'.tr());
                            }
                          }),

                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width,
                            height: MediaQuery.of(context).size.height * 0.06,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(COLOR_PRIMARY),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                  side: BorderSide(
                                    color: Color(COLOR_PRIMARY),
                                  ),
                                ),
                              ),
                              child: Text(
                                'See All store around you',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white),
                              ).tr(),
                              onPressed: () {
                                push(
                                  context,
                                  ViewAllStore(),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ));
  }

  Widget buildVendorItemData(
    BuildContext context,
    ProductModel product,
  ) {
    return Container(
      decoration: new BoxDecoration(
        borderRadius: new BorderRadius.circular(10),
        color: Colors.white,
      ),
      width: MediaQuery.of(context).size.width * 0.8,
      margin: EdgeInsets.fromLTRB(10, 10, 10, 0),
      padding: EdgeInsets.all(5),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: new BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: getImageVAlidUrl(product.photo),
              height: 100,
              width: 100,
              memCacheHeight: 100,
              memCacheWidth: 100,
              imageBuilder: (context, imageProvider) => Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
                ),
              ),
              placeholder: (context, url) => Center(
                  child: CircularProgressIndicator.adaptive(
                valueColor: AlwaysStoppedAnimation(Color(COLOR_PRIMARY)),
              )),
              errorWidget: (context, url, error) => ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  AppGlobal.placeHolderImage!,
                  cacheHeight: 100,
                  cacheWidth: 100,
                ),
              ),
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(
            width: 10,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 10,
                ),
                Text(
                  product.name,
                  style: TextStyle(
                    fontFamily: "Poppinssm",
                    fontSize: 18,
                    color: Color(0xff000000),
                  ),
                  maxLines: 1,
                ),
                SizedBox(
                  height: 10,
                ),
                Text(
                  product.description,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: "Poppinssm",
                    fontSize: 16,
                    color: Color(0xff9091A4),
                  ),
                ),
                SizedBox(
                  height: 10,
                ),
                Text(
                  "$symbol${product.price}",
                  style: TextStyle(
                    fontFamily: "Poppinssm",
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(COLOR_PRIMARY),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget popularFoodItem(
    BuildContext context,
    ProductModel product,
    VendorModel popularNearFoodVendorModel,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => push(
        context,
        VendorProductsScreen(vendorModel: popularNearFoodVendorModel),
      ),
      child: Container(
        decoration: new BoxDecoration(
          borderRadius: new BorderRadius.circular(10),
          color: isDarkMode(context) ? Color(DARK_CARD_BG_COLOR) : Colors.white,
        ),
        width: MediaQuery.of(context).size.width * 0.8,
        margin: EdgeInsets.fromLTRB(10, 10, 10, 0),
        padding: EdgeInsets.all(5),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: new BorderRadius.circular(20),
              child: CachedNetworkImage(
                imageUrl: getImageVAlidUrl(product.photo),
                height: 100,
                width: 100,
                memCacheHeight: 100,
                memCacheWidth: 100,
                imageBuilder: (context, imageProvider) => Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
                  ),
                ),
                placeholder: (context, url) => Center(
                    child: CircularProgressIndicator.adaptive(
                  valueColor: AlwaysStoppedAnimation(Color(COLOR_PRIMARY)),
                )),
                errorWidget: (context, url, error) => ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      AppGlobal.placeHolderImage!,
                      fit: BoxFit.cover,
                      cacheHeight: 100,
                      cacheWidth: 100,
                    )),
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(
              width: 10,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 10,
                  ),
                  Text(
                    product.name,
                    style: TextStyle(
                      fontFamily: "Poppinssm",
                      fontSize: 18,
                      color: isDarkMode(context) ? Colors.white : Colors.black,
                    ),
                    maxLines: 1,
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Text(
                    product.description,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: "Poppinssm",
                      fontSize: 16,
                      color: Color(0xff9091A4),
                    ),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  /*Text(
                    product.disPrice=="" || product.disPrice =="0"?"\$${product.price}":"\$${product.disPrice}",
                    style: TextStyle(
                      fontFamily: "Poppinssm",
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xffE87034),
                    ),
                  ),*/
                  product.disPrice == "" || product.disPrice == "0"
                      ? Text(
                          "$symbol${product.price}",
                          style: TextStyle(fontSize: 18, fontFamily: "Poppinssm", letterSpacing: 0.5, color: Color(COLOR_PRIMARY)),
                        )
                      : Row(
                          children: [
                            Text(
                              '$symbol${product.price}',
                              style: TextStyle(
                                  fontFamily: "Poppinssm",
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  decoration: TextDecoration.lineThrough),
                            ),
                            SizedBox(
                              width: 10,
                            ),
                            Text(
                              "$symbol${product.disPrice}",
                              style: TextStyle(
                                fontFamily: "Poppinssm",
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(COLOR_PRIMARY),
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  void checkMemory() {
    ImageCache _imagecache = PaintingBinding.instance.imageCache;
    if (_imagecache.currentSizeBytes >= 55 << 22 || _imagecache.liveImageCount >= 25) {
      _imagecache.clear();
      _imagecache.clearLiveImages();
    }
  }

  Widget buildAllRestaurantsData(VendorModel vendorModel) {
    // checkMemory();
    return GestureDetector(
      onTap: () => push(
        context,
        VendorProductsScreen(vendorModel: vendorModel),
      ),
      child: Container(
        decoration: new BoxDecoration(
          borderRadius: new BorderRadius.circular(10),
          color: isDarkMode(context) ? Color(DARK_CARD_BG_COLOR) : Colors.white,
        ),
        width: MediaQuery.of(context).size.width * 0.8,
        margin: EdgeInsets.fromLTRB(10, 10, 10, 0),
        padding: EdgeInsets.all(5),
        child: Row(
          children: [
            CachedNetworkImage(
              imageUrl: getImageVAlidUrl(vendorModel.photo),
              height: 100,
              width: 100,
              imageBuilder: (context, imageProvider) => Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
                ),
              ),
              placeholder: (context, url) => Center(
                  child: CircularProgressIndicator.adaptive(
                valueColor: AlwaysStoppedAnimation(Color(COLOR_PRIMARY)),
              )),
              errorWidget: (context, url, error) => ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    AppGlobal.placeHolderImage!,
                    fit: BoxFit.cover,
                    cacheHeight: 100,
                    cacheWidth: 100,
                  )),
              fit: BoxFit.cover,
            ),
            SizedBox(
              width: 10,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          vendorModel.title,
                          style: TextStyle(
                            fontFamily: "Poppinssm",
                            fontSize: 18,
                            color: isDarkMode(context) ? Colors.white : Colors.black,
                          ),
                          maxLines: 1,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (MyAppState.currentUser == null) {
                            push(context, AuthScreen());
                          } else {
                            setState(() {
                              if (lstFav.contains(vendorModel.id) == true) {
                                FavouriteModel favouriteModel = FavouriteModel(store_id: vendorModel.id, user_id: MyAppState.currentUser!.userID);
                                lstFav.removeWhere((item) => item == vendorModel.id);
                                fireStoreUtils.removeFavouriteStore(favouriteModel);
                              } else {
                                FavouriteModel favouriteModel = FavouriteModel(store_id: vendorModel.id, user_id: MyAppState.currentUser!.userID);
                                fireStoreUtils.setFavouriteStore(favouriteModel);
                                lstFav.add(vendorModel.id);
                              }
                            });
                          }
                        },
                        child: lstFav.contains(vendorModel.id) == true
                            ? Icon(
                                Icons.favorite,
                                color: Color(COLOR_PRIMARY),
                              )
                            : Icon(
                                Icons.favorite_border,
                                color: isDarkMode(context) ? Colors.white38 : Colors.black38,
                              ),
                      )
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Text(
                    vendorModel.location,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: "Poppinssm",
                      fontSize: 16,
                      color: isDarkMode(context) ? Colors.white70 : Color(0xff9091A4),
                    ),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star,
                        size: 20,
                        color: Color(COLOR_PRIMARY),
                      ),
                      SizedBox(width: 3),
                      Text(vendorModel.reviewsCount != 0 ? '${(vendorModel.reviewsSum / vendorModel.reviewsCount).toStringAsFixed(1)}' : 0.toString(),
                          style: TextStyle(
                            fontFamily: "Poppinssr",
                            letterSpacing: 0.5,
                            color: isDarkMode(context) ? Colors.white : Color(0xff000000),
                          )),
                      SizedBox(width: 3),
                      Text('(${vendorModel.reviewsCount.toStringAsFixed(1)})',
                          style: TextStyle(
                            fontFamily: "Poppinssr",
                            letterSpacing: 0.5,
                            color: isDarkMode(context) ? Colors.white60 : Color(0xff666666),
                          )),
                      SizedBox(width: 5),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  buildCategoryItem(CuisineModel model) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GestureDetector(
        onTap: () {
          push(
            context,
            CategoryDetailsScreen(
              category: model,
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CachedNetworkImage(
              imageUrl: getImageVAlidUrl(model.photo),
              imageBuilder: (context, imageProvider) => Container(
                height: MediaQuery.of(context).size.height * 0.11,
                width: MediaQuery.of(context).size.width * 0.23,
                decoration: BoxDecoration(border: Border.all(width: 6, color: Color(COLOR_PRIMARY)), borderRadius: BorderRadius.circular(30)),
                child: Container(
                  // height: 80,width: 80,
                  decoration: BoxDecoration(
                      border: Border.all(
                        width: 4,
                        color: isDarkMode(context) ? Color(DARK_COLOR) : Color(0xffE0E2EA),
                      ),
                      borderRadius: BorderRadius.circular(30)),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        image: DecorationImage(
                          image: imageProvider,
                          fit: BoxFit.cover,
                        )),
                  ),
                ),
              ),
              memCacheHeight: (MediaQuery.of(context).size.height * 0.11).toInt(),
              memCacheWidth: (MediaQuery.of(context).size.width * 0.23).toInt(),
              placeholder: (context, url) => ClipOval(
                child: Container(
                  // padding: EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(75 / 1)),
                    border: Border.all(
                      color: Color(COLOR_PRIMARY),
                      style: BorderStyle.solid,
                      width: 2.0,
                    ),
                  ),
                  width: 75,
                  height: 75,
                  child: Icon(
                    Icons.fastfood,
                    color: Color(COLOR_PRIMARY),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    AppGlobal.placeHolderImage!,
                    fit: BoxFit.cover,
                  )),
            ),
            // displayCircleImage(model.photo, 90, false),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Center(
                  child: Text(model.title,
                      style: TextStyle(
                        color: isDarkMode(context) ? Colors.white : Color(0xFF000000),
                        fontFamily: "Poppinsr",
                      )).tr()),
            )
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // TODO: implement dispose

    // ImageCache _imageCache = PaintingBinding.instance.imageCache;
    // _imageCache.clear();
    // _imageCache.clearLiveImages();

    fireStoreUtils.closeOfferStream();
    fireStoreUtils.closeVendorStream();
    fireStoreUtils.closeNewArrivalStream();
    super.dispose();
  }

  Widget buildBestDealPage(BannerModel categoriesModel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        child: CachedNetworkImage(
          imageUrl: getImageVAlidUrl(categoriesModel.photo.toString()),
          imageBuilder: (context, imageProvider) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
            ),
          ),
          color: Colors.black.withOpacity(0.5),
          placeholder: (context, url) => Center(
              child: CircularProgressIndicator.adaptive(
            valueColor: AlwaysStoppedAnimation(Color(COLOR_PRIMARY)),
          )),
          errorWidget: (context, url, error) => ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                AppGlobal.placeHolderImage!,
                width: MediaQuery.of(context).size.width * 0.75,
                fit: BoxFit.fitWidth,
              )),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  openCouponCode(
    BuildContext context,
    OfferModel offerModel,
  ) {
    return Container(
      height: 250,
      decoration: new BoxDecoration(
        borderRadius: new BorderRadius.circular(20),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
              margin: EdgeInsets.only(
                left: 40,
                right: 40,
              ),
              padding: EdgeInsets.only(
                left: 50,
                right: 50,
              ),
              decoration: BoxDecoration(image: DecorationImage(image: AssetImage("assets/images/offer_code_bg.png"))),
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Text(
                  offerModel.offerCode!,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, letterSpacing: 0.9),
                ),
              )),
          GestureDetector(
            onTap: () {
              FlutterClipboard.copy(offerModel.offerCode!).then((value) {
                final SnackBar snackBar = SnackBar(
                  content: Text(
                    "couponCodeCopied".tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.black38,
                );
                ScaffoldMessenger.of(context).showSnackBar(snackBar);
                return Navigator.pop(context);
              });
            },
            child: Container(
              margin: EdgeInsets.only(top: 30, bottom: 30),
              child: Text(
                "copyCode".tr(),
                style: TextStyle(color: Color(COLOR_PRIMARY), fontWeight: FontWeight.w500, letterSpacing: 0.1),
              ),
            ),
          ),
          Container(
            margin: EdgeInsets.only(bottom: 30),
            child: RichText(
              text: TextSpan(
                text: "useCode".tr(),
                style: TextStyle(fontSize: 16.0, color: Colors.grey, fontWeight: FontWeight.w700),
                children: <TextSpan>[
                  TextSpan(
                    text: offerModel.offerCode,
                    style: TextStyle(color: Color(COLOR_PRIMARY), fontWeight: FontWeight.w500, letterSpacing: 0.1),
                  ),
                  TextSpan(
                    text:
                        " & get ${offerModel.discountTypeOffer == "Fix Price" ? "$symbol" : ""}${offerModel.discountOffer}${offerModel.discountTypeOffer == "Percentage" ? "%off".tr() : " off".tr()} ",
                    style: TextStyle(fontSize: 16.0, color: Colors.grey, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildNewArrivalItem(VendorModel vendorModel) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: () => push(
          context,
          VendorProductsScreen(vendorModel: vendorModel),
        ),
        child: Container(
          // margin: EdgeInsets.all(5),
          width: MediaQuery.of(context).size.width * 0.75,
          child: Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade100, width: 0.1),
                boxShadow: [
                  isDarkMode(context)
                      ? BoxShadow()
                      : BoxShadow(
                          color: Colors.grey.shade400,
                          blurRadius: 8.0,
                          spreadRadius: 1.2,
                          offset: Offset(0.2, 0.2),
                        ),
                ],
                color: isDarkMode(context) ? Color(DARK_CARD_BG_COLOR) : Colors.white),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                    child: CachedNetworkImage(
                  imageUrl: getImageVAlidUrl(vendorModel.photo),
                  width: MediaQuery.of(context).size.width * 0.75,
                  memCacheWidth: (MediaQuery.of(context).size.width * 0.75).toInt(),
                  imageBuilder: (context, imageProvider) => Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
                    ),
                  ),
                  placeholder: (context, url) => Center(
                      child: CircularProgressIndicator.adaptive(
                    valueColor: AlwaysStoppedAnimation(Color(COLOR_PRIMARY)),
                  )),
                  errorWidget: (context, url, error) => ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        AppGlobal.placeHolderImage!,
                        width: MediaQuery.of(context).size.width * 0.75,
                        fit: BoxFit.fitWidth,
                      )),
                  fit: BoxFit.cover,
                )),
                SizedBox(height: 8),
                Container(
                  margin: EdgeInsets.fromLTRB(15, 0, 5, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vendorModel.title,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: "Poppinssm",
                            letterSpacing: 0.5,
                            color: isDarkMode(context) ? Colors.white : Colors.black,
                          )).tr(),
                      SizedBox(
                        height: 10,
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ImageIcon(
                            AssetImage('assets/images/location3x.png'),
                            size: 15,
                            color: isDarkMode(context) ? Colors.white60 : Color(0xff9091A4),
                          ),
                          SizedBox(
                            width: 5,
                          ),
                          Expanded(
                            child: Text(vendorModel.location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: "Poppinssr",
                                  letterSpacing: 0.5,
                                  color: isDarkMode(context) ? Colors.white60 : Color(0xff555353),
                                )),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 10),
                        child: Column(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 20,
                                  color: Color(COLOR_PRIMARY),
                                ),
                                SizedBox(width: 3),
                                Text(vendorModel.reviewsCount != 0 ? '${(vendorModel.reviewsSum / vendorModel.reviewsCount).toStringAsFixed(1)}' : 0.toString(),
                                    style: TextStyle(
                                      fontFamily: "Poppinssr",
                                      letterSpacing: 0.5,
                                      color: isDarkMode(context) ? Colors.white : Color(0xff000000),
                                    )),
                                SizedBox(width: 3),
                                Text('(${vendorModel.reviewsCount.toStringAsFixed(1)})',
                                    style: TextStyle(
                                      fontFamily: "Poppinssr",
                                      letterSpacing: 0.5,
                                      color: isDarkMode(context) ? Colors.white70 : Color(0xff666666),
                                    )),
                              ],
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildPopularsItem(VendorModel vendorModel) {
    if (!mounted) {
      return Container();
    }
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: () => push(
          context,
          VendorProductsScreen(vendorModel: vendorModel),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.75,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade100, width: 0.1),
              boxShadow: [
                isDarkMode(context)
                    ? BoxShadow()
                    : BoxShadow(
                        color: Colors.grey.shade400,
                        blurRadius: 8.0,
                        spreadRadius: 1.2,
                        offset: Offset(0.2, 0.2),
                      ),
              ],
              color: isDarkMode(context) ? Color(DARK_CARD_BG_COLOR) : Colors.white),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                  child: CachedNetworkImage(
                imageUrl: getImageVAlidUrl(vendorModel.photo),
                memCacheWidth: (MediaQuery.of(context).size.width * 0.75).toInt(),
                memCacheHeight: 250,
                imageBuilder: (context, imageProvider) => Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
                  ),
                ),
                placeholder: (context, url) => Center(
                    child: CircularProgressIndicator.adaptive(
                  valueColor: AlwaysStoppedAnimation(Color(COLOR_PRIMARY)),
                )),
                errorWidget: (context, url, error) => ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    AppGlobal.placeHolderImage!,
                    width: MediaQuery.of(context).size.width * 0.75,
                    fit: BoxFit.fitHeight,
                  ),
                ),
                fit: BoxFit.cover,
              )),
              SizedBox(height: 8),
              Container(
                margin: EdgeInsets.fromLTRB(15, 0, 5, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vendorModel.title,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: "Poppinssm",
                          letterSpacing: 0.5,
                          color: isDarkMode(context) ? Colors.white : Color(0xff000000),
                        )).tr(),
                    SizedBox(
                      height: 10,
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ImageIcon(
                          AssetImage('assets/images/location3x.png'),
                          size: 15,
                          color: isDarkMode(context) ? Colors.white60 : Color(0xff9091A4),
                        ),
                        SizedBox(
                          width: 5,
                        ),
                        Expanded(
                          child: Text(vendorModel.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: "Poppinssr",
                                letterSpacing: 0.5,
                                color: isDarkMode(context) ? Colors.white70 : Color(0xff555353),
                              )),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 10),
                      child: Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star,
                                size: 20,
                                color: Color(COLOR_PRIMARY),
                              ),
                              SizedBox(width: 3),
                              Text(vendorModel.reviewsCount != 0 ? '${(vendorModel.reviewsSum / vendorModel.reviewsCount).toStringAsFixed(1)}' : 0.toString(),
                                  style: TextStyle(
                                    fontFamily: "Poppinssr",
                                    letterSpacing: 0.5,
                                    color: isDarkMode(context) ? Colors.white70 : Color(0xff000000),
                                  )),
                              SizedBox(width: 3),
                              Text('(${vendorModel.reviewsCount.toStringAsFixed(1)})',
                                  style: TextStyle(
                                    fontFamily: "Poppinssr",
                                    letterSpacing: 0.5,
                                    color: isDarkMode(context) ? Colors.white60 : Color(0xff666666),
                                  )),
                            ],
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget buildCouponsForYouItem(BuildContext context1, VendorModel vendorModel, OfferModel offerModel) {
    return vendorModel == null
        ? Container()
        : Container(
            margin: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: GestureDetector(
              onTap: () {
                //print(offerModel.offerCode+"====<><><>====");
                if (vendorModel.id.toString() == offerModel.storeId.toString()) {
                  push(
                    context,
                    VendorProductsScreen(vendorModel: vendorModel),
                  );
                } else {
                  showModalBottomSheet(
                    isScrollControlled: true,
                    isDismissible: true,
                    context: context,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    backgroundColor: Colors.transparent,
                    enableDrag: true,
                    builder: (context) => openCouponCode(context, offerModel),
                  );
                }
              },
              child: Container(
                height: MediaQuery.of(context).size.height,
                child: Stack(
                  alignment: AlignmentDirectional.bottomStart,
                  children: [
                    Container(
                      width: MediaQuery.of(context).size.width * 0.75,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade100, width: 0.1),
                          boxShadow: [
                            isDarkMode(context)
                                ? BoxShadow()
                                : BoxShadow(
                                    color: Colors.grey.shade400,
                                    blurRadius: 8.0,
                                    spreadRadius: 1.2,
                                    offset: Offset(0.2, 0.2),
                                  ),
                          ],
                          color: isDarkMode(context) ? Color(DARK_CARD_BG_COLOR) : Colors.white),
                      child: Column(
                        children: [
                          Expanded(
                              child: CachedNetworkImage(
                            imageUrl: getImageVAlidUrl(offerModel.imageOffer!),
                            memCacheWidth: (MediaQuery.of(context).size.width * 0.75).toInt(),
                            memCacheHeight: MediaQuery.of(context).size.width.toInt(),
                            imageBuilder: (context, imageProvider) => Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
                              ),
                            ),
                            placeholder: (context, url) => Center(
                                child: CircularProgressIndicator.adaptive(
                              valueColor: AlwaysStoppedAnimation(Color(COLOR_PRIMARY)),
                            )),
                            errorWidget: (context, url, error) => ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(
                                AppGlobal.placeHolderImage!,
                                width: MediaQuery.of(context).size.width * 0.75,
                                fit: BoxFit.fitHeight,
                              ),
                            ),
                            fit: BoxFit.cover,
                          )),
                          SizedBox(height: 8),
                          vendorModel == null
                              ? Container()
                              : vendorModel.id.toString() == offerModel.storeId.toString()
                                  ? Container(
                                      margin: EdgeInsets.fromLTRB(15, 0, 5, 0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(vendorModel.title,
                                              maxLines: 1,
                                              style: TextStyle(
                                                fontFamily: "Poppinssm",
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                                color: isDarkMode(context) ? Colors.white : Color(0xff000000),
                                              )).tr(),
                                          SizedBox(
                                            height: 10,
                                          ),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              ImageIcon(
                                                AssetImage('assets/images/location3x.png'),
                                                size: 15,
                                                color: isDarkMode(context) ? Colors.white70 : Color(0xff9091A4),
                                              ),
                                              SizedBox(
                                                width: 5,
                                              ),
                                              Expanded(
                                                child: Text(vendorModel.location,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontFamily: "Poppinssr",
                                                      letterSpacing: 0.5,
                                                      color: isDarkMode(context) ? Colors.white70 : Color(0xff555353),
                                                    )),
                                              ),
                                            ],
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8.0, bottom: 10),
                                            child: Column(
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      offerModel.offerCode!,
                                                      style: TextStyle(
                                                        fontFamily: "Poppinssm",
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(COLOR_PRIMARY),
                                                      ),
                                                    ),
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.star,
                                                          size: 20,
                                                          color: Color(COLOR_PRIMARY),
                                                        ),
                                                        SizedBox(width: 3),
                                                        Text(
                                                            vendorModel.reviewsCount != 0
                                                                ? '${(vendorModel.reviewsSum / vendorModel.reviewsCount).toStringAsFixed(1)}'
                                                                : 0.toString(),
                                                            style: TextStyle(
                                                              fontFamily: "Poppinssr",
                                                              letterSpacing: 0.5,
                                                              color: isDarkMode(context) ? Colors.white : Color(0xff000000),
                                                            )),
                                                        SizedBox(width: 3),
                                                        Text('(${vendorModel.reviewsCount.toStringAsFixed(1)})',
                                                            style: TextStyle(
                                                              fontFamily: "Poppinssr",
                                                              letterSpacing: 0.5,
                                                              color: isDarkMode(context) ? Colors.white60 : Color(0xff666666),
                                                            )),
                                                        SizedBox(width: 5),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          )
                                        ],
                                      ),
                                    )
                                  : Container(
                                      margin: EdgeInsets.fromLTRB(15, 0, 5, 8),
                                      width: MediaQuery.of(context).size.width,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("gromartsOffer".tr(),
                                              maxLines: 1,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: "Poppinssm",
                                                letterSpacing: 0.5,
                                                color: Color(0xff000000),
                                              )),
                                          SizedBox(
                                            height: 10,
                                          ),
                                          Text("applyOffer".tr(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: "Poppinssr",
                                                letterSpacing: 0.5,
                                                color: Color(0xff555353),
                                              )),
                                          SizedBox(
                                            height: 10,
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              FlutterClipboard.copy(offerModel.offerCode!).then((value) => print('copied'));
                                            },
                                            child: Text(
                                              offerModel.offerCode!,
                                              style: TextStyle(
                                                fontFamily: "Poppinssm",
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Color(COLOR_PRIMARY),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                        ],
                      ),
                    ),
                    /* vendorModel.id.toString()==offerModel.restaurantId.toString()?*/
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Container(
                        margin: EdgeInsets.only(top: 150),
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.topCenter,
                              children: [
                                Container(width: 120, margin: EdgeInsets.only(bottom: 10), child: Image(image: AssetImage("assets/images/offer_badge.png"))),
                                Container(
                                  margin: EdgeInsets.only(top: 10),
                                  child: Text(
                                    "${offerModel.discountTypeOffer == "Fix Price" ? "$symbol" : ""}${offerModel.discountOffer}${offerModel.discountTypeOffer == "Percentage" ? "% Off" : " Off"} ",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.7),
                                  ),
                                )
                              ],
                            ),
                          ],
                        ),
                      ),
                    ) /*:Container()*/
                  ],
                ),
              ),
            ),
          );
  }

  Widget buildVendorItem(VendorModel vendorModel) {
    return GestureDetector(
      onTap: () => push(
        context,
        VendorProductsScreen(vendorModel: vendorModel),
      ),
      child: Container(
        height: 120,
        width: MediaQuery.of(context).size.width,
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100, width: 0.1),
            boxShadow: [
              isDarkMode(context)
                  ? BoxShadow()
                  : BoxShadow(
                      color: Colors.grey.shade400,
                      blurRadius: 8.0,
                      spreadRadius: 1.2,
                      offset: Offset(0.2, 0.2),
                    ),
            ],
            color: Colors.white),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
                child: CachedNetworkImage(
              imageUrl: getImageVAlidUrl(vendorModel.photo),
              memCacheWidth: (MediaQuery.of(context).size.width).toInt(),
              memCacheHeight: 120,
              imageBuilder: (context, imageProvider) => Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
                ),
              ),
              placeholder: (context, url) => Center(
                  child: CircularProgressIndicator.adaptive(
                valueColor: AlwaysStoppedAnimation(Color(COLOR_PRIMARY)),
              )),
              errorWidget: (context, url, error) => ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(AppGlobal.placeHolderImage!)),
              fit: BoxFit.cover,
            )),
            SizedBox(height: 8),
            ListTile(
              title: Text(vendorModel.title,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: "Poppinssm",
                    letterSpacing: 0.5,
                    color: Color(0xff000000),
                  )).tr(),
              subtitle: Row(
                children: [
                  ImageIcon(
                    AssetImage('assets/images/location3x.png'),
                    size: 15,
                    color: Color(0xff9091A4),
                  ),
                  SizedBox(
                    width: 200,
                    child: Text(vendorModel.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: "Poppinssr",
                          letterSpacing: 0.5,
                          color: Color(0xff555353),
                        )),
                  ),
                ],
              ),
              trailing: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          size: 20,
                          color: Color(COLOR_PRIMARY),
                        ),
                        SizedBox(width: 3),
                        Text(vendorModel.reviewsCount != 0 ? '${(vendorModel.reviewsSum / vendorModel.reviewsCount).toStringAsFixed(1)}' : 0.toString(),
                            style: TextStyle(
                              fontFamily: "Poppinssr",
                              letterSpacing: 0.5,
                              color: Color(0xff000000),
                            )),
                        SizedBox(width: 3),
                        Text('(${vendorModel.reviewsCount.toStringAsFixed(1)})',
                            style: TextStyle(
                              fontFamily: "Poppinssr",
                              letterSpacing: 0.5,
                              color: Color(0xff666666),
                            )),
                      ],
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  curcy(CurrencyModel currency) {
    if (currency.isactive == true) {
      print("--->" + currency.code.toString());
      symbol = currency.symbol;
      isRight = currency.symbolatright;
      decimal = currency.decimal;
      currName = currency.code;
      currencyData = currency;

      // return Center();
    }
    // return Center();
  }

  Future<void> saveFoodTypeValue() async {
    SharedPreferences sp = await SharedPreferences.getInstance();

    sp.setString('foodType', selctedOrderTypeValue!);
  }

  getFoodType() async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        selctedOrderTypeValue = sp.getString("foodType") == "" || sp.getString("foodType") == null ? "Delivery" : sp.getString("foodType");
      });
    }
    if (selctedOrderTypeValue == "Takeaway") {
      productsFuture = fireStoreUtils.getAllTakeAWayProducts();
    } else {
      productsFuture = fireStoreUtils.getAllProducts();
    }
  }

  void getData() {
    print("data calling ");
    if (!mounted) {
      return;
    }
    lstNearByFood.clear();
    fireStoreUtils.getStoreNearBy().whenComplete(() {
      lstOfferData = fireStoreUtils.getOfferStream().asBroadcastStream();

      lstAllStore = fireStoreUtils.getAllStores().asBroadcastStream();
      lstNewArrivalStore = fireStoreUtils.getVendorsForNewArrival().asBroadcastStream();

      getFoodType();
      if (MyAppState.currentUser != null) {
        lstFavourites = fireStoreUtils.getFavouriteStore(MyAppState.currentUser!.userID);
        lstFavourites.then((event) {
          lstFav.clear();
          for (int a = 0; a < event.length; a++) {
            lstFav.add(event[a].store_id!);
          }
        });
        name = toBeginningOfSentenceCase(widget.user!.firstName);
      }

      lstAllStore!.listen((event) {
        popularStoreLst.clear();
        vendors.clear();
        vendors.addAll(event);
        allstoreList.clear();
        allstoreList.addAll(event);
        productsFuture.then((value) {
          for (int a = 0; a < event.length; a++) {
            for (int d = 0; d < (value.length > 20 ? 20 : value.length); d++) {
              if (event[a].id == value[d].vendorID && !lstNearByFood.contains(value[d])) {
                lstNearByFood.add(value[d]);
              }
            }
          }
          if (mounted) {
            setState(() {
              showLoader = false;
            });
          }
        });

        for (int a = 0; a < event.length; a++) {
          if ((event[a].reviewsSum / event[a].reviewsCount) >= 4.0) {
            popularStoreLst.add(event[a]);
          }
        }
      });
    });
  }

  // void getData() {
  //   print("data calling ");
  //   if (!mounted) {
  //     return;
  //   }
  //   lstNearByFood.clear();
  //   fireStoreUtils.getStoreNearBy().whenComplete(() {
  //     lstOfferData = fireStoreUtils.getOfferStream().asBroadcastStream();
  //     lstVendor = fireStoreUtils.getVendors1().asBroadcastStream();
  //
  //     lstAllStore = fireStoreUtils.getAllStores().asBroadcastStream();
  //     lstNewArrivalStore = fireStoreUtils.getVendorsForNewArrival().asBroadcastStream();
  //
  //     getFoodType();
  //     if (MyAppState.currentUser != null) {
  //       lstFavourites = fireStoreUtils.getFavouriteStore(MyAppState.currentUser!.userID);
  //       lstFavourites.then((event) {
  //         lstFav.clear();
  //         for (int a = 0; a < event.length; a++) {
  //           lstFav.add(event[a].store_id!);
  //         }
  //       });
  //       name = toBeginningOfSentenceCase(widget.user!.firstName);
  //     }
  //
  //     lstVendor!.listen((event) {
  //       if (event != null) {
  //         if (mounted) {
  //           setState(() {
  //             vendors.clear();
  //             vendors.addAll(event);
  //           });
  //         }
  //         for (int a = 0; a < event.length; a++) {
  //           if ((event[a].reviewsSum / event[a].reviewsCount) >= 4.0) {
  //             popularStoreLst.add(event[a]);
  //           }
  //         }
  //         print(popularStoreLst.length.toString() + "PR+++");
  //       }
  //     });
  //
  //     lstAllStore!.listen((event) {
  //       if (event != null) {
  //         vendors.clear();
  //         vendors.addAll(event);
  //
  //         print(vendors);
  //         allstoreList.clear();
  //         allstoreList.addAll(event);
  //       }
  //       productsFuture.then((value) {
  //         print(value.length.toString() + "==={}{}===value");
  //         for (int a = 0; a < event.length; a++) {
  //           for (int d = 0; d < (value.length > 20 ? 20 : value.length); d++) {
  //             if (event[a].id == value[d].vendorID && !lstNearByFood.contains(value[d])) {
  //               lstNearByFood.add(value[d]);
  //             }
  //           }
  //         }
  //         if (mounted) {
  //           setState(() {
  //             showLoader = false;
  //           });
  //         }
  //       });
  //     });
  //   });
  // }

  Future<void> getTempLocation() async {
    debugPrint(' temp location: ${MyAppState.selectedPosotion}');
    if (MyAppState.currentUser == null && MyAppState.selectedPosotion.longitude != 0 && MyAppState.selectedPosotion.latitude != 0) {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(MyAppState.selectedPosotion.latitude, MyAppState.selectedPosotion.longitude).catchError((error) {
        print("error in location $error");
        return Future.error(error);
      });
      Placemark placeMark = placemarks[0];
      if (mounted) {
        setState(() {
          currentLocation = placeMark.name.toString() +
              ", " +
              placeMark.subLocality.toString() +
              ", " +
              placeMark.locality.toString() +
              ", " +
              placeMark.administrativeArea.toString() +
              ", " +
              placeMark.postalCode.toString() +
              ", " +
              placeMark.country.toString();
        });
      }
      getData();
    }
    if (MyAppState.currentUser != null) {
      if (MyAppState.currentUser!.location.latitude != null &&
          MyAppState.currentUser!.location.longitude != null &&
          MyAppState.currentUser!.location.latitude != 0 &&
          MyAppState.currentUser!.location.longitude != 0) {
        MyAppState.selectedPosotion =
            Position.fromMap({'latitude': MyAppState.currentUser!.location.latitude, 'longitude': MyAppState.currentUser!.location.longitude});
        List<Placemark> placemarks =
            await placemarkFromCoordinates(MyAppState.selectedPosotion.latitude, MyAppState.selectedPosotion.longitude).catchError((error) {
          print("error in location $error");
          return Future.error(error);
        });
        Placemark placeMark = placemarks[0];
        if (mounted) {
          setState(() {
            currentLocation = placeMark.name.toString() +
                ", " +
                placeMark.subLocality.toString() +
                ", " +
                placeMark.locality.toString() +
                ", " +
                placeMark.administrativeArea.toString() +
                ", " +
                placeMark.postalCode.toString() +
                ", " +
                placeMark.country.toString();
          });
        }
        getData();
      }
      if (mounted) {
        setState(() {});
      }
    }
  }
}

class buildTitleRow extends StatelessWidget {
  final String titleValue;
  final Function? onClick;
  final bool? isViewAll;

  const buildTitleRow({
    Key? key,
    required this.titleValue,
    this.onClick,
    this.isViewAll = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDarkMode(context) ? Color(DARK_COLOR) : Color(0xffFFFFFF),
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(titleValue.tr(), style: TextStyle(color: isDarkMode(context) ? Colors.white : Color(0xFF000000), fontFamily: "Poppinsm", fontSize: 18)),
              isViewAll!
                  ? Container()
                  : GestureDetector(
                      onTap: () {
                        onClick!.call();
                      },
                      child: Text('viewAll'.tr(), style: TextStyle(color: Color(COLOR_PRIMARY), fontFamily: "Poppinsm")),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
