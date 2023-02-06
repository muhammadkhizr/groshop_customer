// ignore_for_file: unnecessary_statements, non_constant_identifier_names

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_facebook_keyhash/flutter_facebook_keyhash.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gromartconsumer/AppGlobal.dart';
import 'package:gromartconsumer/constants.dart';
import 'package:gromartconsumer/main.dart';
import 'package:gromartconsumer/model/User.dart';
import 'package:gromartconsumer/services/FirebaseHelper.dart';
import 'package:gromartconsumer/services/helper.dart';
import 'package:gromartconsumer/services/localDatabase.dart';
import 'package:gromartconsumer/ui/Language/language_choose_screen.dart';
import 'package:gromartconsumer/ui/QrCodeScanner/QrCodeScanner.dart';
import 'package:gromartconsumer/ui/auth/AuthScreen.dart';
import 'package:gromartconsumer/ui/cartScreen/CartScreen.dart';
import 'package:gromartconsumer/ui/cuisinesScreen/CuisinesScreen.dart';
import 'package:gromartconsumer/ui/home/HomeScreen.dart';
import 'package:gromartconsumer/ui/home/favourite_store.dart';
import 'package:gromartconsumer/ui/mapView/MapViewScreen.dart';
import 'package:gromartconsumer/ui/ordersScreen/OrdersScreen.dart';
import 'package:gromartconsumer/ui/profile/ProfileScreen.dart';
import 'package:gromartconsumer/ui/searchScreen/SearchScreen.dart';
import 'package:gromartconsumer/ui/wallet/walletScreen.dart';
import 'package:gromartconsumer/userPrefrence.dart';
import 'package:provider/provider.dart';

enum DrawerSelection { Home, Wallet, Cuisines, Search, Cart, Profile, Orders, MyBooking, chooseLanguage, Logout, LikedStore }

class ContainerScreen extends StatefulWidget {
  final User? user;
  final Widget currentWidget;
  final String appBarTitle;
  final DrawerSelection drawerSelection;

  ContainerScreen({Key? key, required this.user, currentWidget, appBarTitle, this.drawerSelection = DrawerSelection.Home})
      : this.appBarTitle = appBarTitle ?? 'Home'.tr(),
        this.currentWidget = currentWidget ??
            HomeScreen(
              user: MyAppState.currentUser,
            ),
        super(key: key);

  @override
  _ContainerScreen createState() {
    return _ContainerScreen();
  }
}

class _ContainerScreen extends State<ContainerScreen> {
  late GlobalKey<SearchScreenState> _searchScreenStateKey;
  var key = GlobalKey<ScaffoldState>();

  late CartDatabase cartDatabase;
  late User user;
  late String _appBarTitle;
  final fireStoreUtils = FireStoreUtils();

  late Widget _currentWidget;
  late DrawerSelection _drawerSelection;

  int cartCount = 0;
  bool? isWalletEnable;

  Future<void> getKeyHash() async {
    String keyHash;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      keyHash = await FlutterFacebookKeyhash.getFaceBookKeyHash ?? 'Unknown platform KeyHash'.tr();
    } on PlatformException {
      keyHash = 'Failed to get Kay Hash.'.tr();
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      keyHash;
      print("::::KEYHASH::::");
      print(keyHash);
    });
  }

  @override
  void initState() {
    // FireStoreUtils.getWalletSettingData();
    super.initState();
    //FireStoreUtils.walletSettingData().then((value) => isWalletEnable = value);
    if (widget.user != null) {
      user = widget.user!;
    } else {
      user = new User();
    }
    _searchScreenStateKey = GlobalKey();
    _currentWidget = widget.currentWidget;
    _appBarTitle = widget.appBarTitle;
    _drawerSelection = widget.drawerSelection;
    //getKeyHash();
    /// On iOS, we request notification permissions, Does nothing and returns null on Android
    FireStoreUtils.firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    fireStoreUtils.getplaceholderimage().then((value) {
      AppGlobal.placeHolderImage = value;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    cartDatabase = Provider.of<CartDatabase>(context);
  }

  DateTime pre_backpress = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        print('current widget ${_currentWidget is HomeScreen} is home ${_currentWidget.toString() == HomeScreen(
              user: MyAppState.currentUser,
            ).toString()}  ${_currentWidget.key}');

        if (!(_currentWidget is HomeScreen)) {
          setState(() {
            _drawerSelection = DrawerSelection.Home;
            _appBarTitle = 'stores'.tr();
            _currentWidget = HomeScreen(
              user: MyAppState.currentUser,
            );
          });
          return false;
        } else {
          final timegap = DateTime.now().difference(pre_backpress);
          final cantExit = timegap >= Duration(seconds: 2);
          pre_backpress = DateTime.now();
          if (cantExit) {
            //show snackbar
            final snack = SnackBar(
              content: Text(
                'pressBackButtonAgainToExit'.tr(),
                style: TextStyle(color: Colors.white),
              ),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.black,
            );
            ScaffoldMessenger.of(context).showSnackBar(snack);
            return false; // false will do nothing when back press
          } else {
            return true; // true will exit the app
          }
        }
      },
      child: ChangeNotifierProvider.value(
        value: user,
        child: Consumer<User>(
          builder: (context, user, _) {
            return Scaffold(
              extendBodyBehindAppBar: _drawerSelection == DrawerSelection.Wallet ? true : false,
              key: key,
              drawer: Drawer(
                child: Container(
                    color: isDarkMode(context) ? Color(DARK_VIEWBG_COLOR) : null,
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        Consumer<User>(builder: (context, user, _) {
                          return DrawerHeader(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                displayCircleImage(user.profilePictureURL, 75, false),
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    user.fullName(),
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      user.email,
                                      style: TextStyle(color: Colors.white),
                                    )),
                              ],
                            ),
                            decoration: BoxDecoration(
                              color: Color(COLOR_PRIMARY),
                            ),
                          );
                        }),
                        ListTileTheme(
                          style: ListTileStyle.drawer,
                          selectedColor: Color(COLOR_PRIMARY),
                          child: ListTile(
                            selected: _drawerSelection == DrawerSelection.Home,
                            title: Text('stores').tr(),
                            onTap: () {
                              Navigator.pop(context);
                              setState(() {
                                _drawerSelection = DrawerSelection.Home;
                                _appBarTitle = 'stores'.tr();
                                _currentWidget = HomeScreen(
                                  user: MyAppState.currentUser,
                                );
                              });
                            },
                            leading: Icon(CupertinoIcons.home),
                          ),
                        ),
                        ListTileTheme(
                          style: ListTileStyle.drawer,
                          selectedColor: Color(COLOR_PRIMARY),
                          child: ListTile(
                              selected: _drawerSelection == DrawerSelection.Cuisines,
                              leading: Image.asset(
                                'assets/images/app_logo.png',
                                color: _drawerSelection == DrawerSelection.Cuisines
                                    ? Color(COLOR_PRIMARY)
                                    : isDarkMode(context)
                                        ? Colors.grey.shade200
                                        : Colors.grey.shade600,
                                width: 24,
                                height: 24,
                              ),
                              title: Text('categories').tr(),
                              onTap: () {
                                Navigator.pop(context);
                                setState(() {
                                  _drawerSelection = DrawerSelection.Cuisines;
                                  _appBarTitle = 'categories'.tr();
                                  _currentWidget = CuisinesScreen();
                                });
                              }),
                        ),
                        ListTileTheme(
                          style: ListTileStyle.drawer,
                          selectedColor: Color(COLOR_PRIMARY),
                          child: ListTile(
                              selected: _drawerSelection == DrawerSelection.Search,
                              title: Text('search').tr(),
                              leading: Icon(Icons.search),
                              onTap: () async {
                                Navigator.pop(context);
                                setState(() {
                                  _drawerSelection = DrawerSelection.Search;
                                  _appBarTitle = 'search'.tr();
                                  _currentWidget = SearchScreen(
                                    key: _searchScreenStateKey,
                                  );
                                });
                                await Future.delayed(Duration(seconds: 1), () {
                                  setState(() {});
                                });
                              }),
                        ),
                        ListTileTheme(
                          style: ListTileStyle.drawer,
                          selectedColor: Color(COLOR_PRIMARY),
                          child: ListTile(
                            selected: _drawerSelection == DrawerSelection.LikedStore,
                            title: Text('favouriteStores').tr(),
                            onTap: () {
                              if (MyAppState.currentUser == null) {
                                Navigator.pop(context);
                                push(context, AuthScreen());
                              } else {
                                Navigator.pop(context);
                                setState(() {
                                  _drawerSelection = DrawerSelection.LikedStore;
                                  _appBarTitle = 'favouriteStores'.tr();
                                  _currentWidget = FavouriteStoreScreen();
                                });
                              }
                            },
                            leading: Icon(CupertinoIcons.heart),
                          ),
                        ),
                        Visibility(
                          visible: UserPreference.getWalletData() ?? false,
                          child: ListTileTheme(
                            style: ListTileStyle.drawer,
                            selectedColor: Color(COLOR_PRIMARY),
                            child: ListTile(
                              selected: _drawerSelection == DrawerSelection.Wallet,
                              leading: Icon(Icons.account_balance_wallet_outlined),
                              title: Text('wallet').tr(),
                              onTap: () {
                                if (MyAppState.currentUser == null) {
                                  Navigator.pop(context);
                                  push(context, AuthScreen());
                                } else {
                                  Navigator.pop(context);
                                  setState(() {
                                    _drawerSelection = DrawerSelection.Wallet;
                                    _appBarTitle = 'wallet'.tr();
                                    _currentWidget = WalletScreen();
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        ListTileTheme(
                          style: ListTileStyle.drawer,
                          selectedColor: Color(COLOR_PRIMARY),
                          child: ListTile(
                            selected: _drawerSelection == DrawerSelection.Cart,
                            leading: Icon(CupertinoIcons.cart),
                            title: Text('cart').tr(),
                            onTap: () {
                              if (MyAppState.currentUser == null) {
                                Navigator.pop(context);
                                push(context, AuthScreen());
                              } else {
                                Navigator.pop(context);
                                setState(() {
                                  _drawerSelection = DrawerSelection.Cart;
                                  _appBarTitle = 'yourCart'.tr();
                                  _currentWidget = CartScreen(
                                    fromContainer: true,
                                  );
                                });
                              }
                            },
                          ),
                        ),
                        ListTileTheme(
                          style: ListTileStyle.drawer,
                          selectedColor: Color(COLOR_PRIMARY),
                          child: ListTile(
                            selected: _drawerSelection == DrawerSelection.Profile,
                            leading: Icon(CupertinoIcons.person),
                            title: Text('profile').tr(),
                            onTap: () {
                              if (MyAppState.currentUser == null) {
                                Navigator.pop(context);
                                push(context, AuthScreen());
                              } else {
                                Navigator.pop(context);
                                setState(() {
                                  _drawerSelection = DrawerSelection.Profile;
                                  _appBarTitle = 'myProfile'.tr();
                                  _currentWidget = ProfileScreen(
                                    user: user,
                                  );
                                });
                              }
                            },
                          ),
                        ),
                        ListTileTheme(
                          style: ListTileStyle.drawer,
                          selectedColor: Color(COLOR_PRIMARY),
                          child: ListTile(
                            selected: _drawerSelection == DrawerSelection.Orders,
                            leading: Image.asset(
                              'assets/images/truck.png',
                              color: _drawerSelection == DrawerSelection.Orders
                                  ? Color(COLOR_PRIMARY)
                                  : isDarkMode(context)
                                      ? Colors.grey.shade200
                                      : Colors.grey.shade600,
                              width: 24,
                              height: 24,
                            ),
                            title: Text('orders').tr(),
                            onTap: () {
                              if (MyAppState.currentUser == null) {
                                Navigator.pop(context);
                                push(context, AuthScreen());
                              } else {
                                Navigator.pop(context);
                                setState(() {
                                  _drawerSelection = DrawerSelection.Orders;
                                  _appBarTitle = 'orders'.tr();
                                  _currentWidget = OrdersScreen();
                                });
                              }
                            },
                          ),
                        ),
                        // !isDineInEnable
                        //     ? Container()
                        //     : ListTileTheme(
                        //         style: ListTileStyle.drawer,
                        //         selectedColor: Color(COLOR_PRIMARY),
                        //         child: ListTile(
                        //           selected: _drawerSelection ==
                        //               DrawerSelection.MyBooking,
                        //           leading: Image.asset(
                        //             'assets/images/your_booking.png',
                        //             color: _drawerSelection ==
                        //                     DrawerSelection.MyBooking
                        //                 ? Color(COLOR_PRIMARY)
                        //                 : isDarkMode(context)
                        //                     ? Colors.grey.shade200
                        //                     : Colors.grey.shade600,
                        //             width: 24,
                        //             height: 24,
                        //           ),
                        //           title: Text('Dine-In Bookings').tr(),
                        //           onTap: () {
                        //             if (MyAppState.currentUser == null) {
                        //               Navigator.pop(context);
                        //               push(context, AuthScreen());
                        //             } else {
                        //               Navigator.pop(context);
                        //               setState(() {
                        //                 _drawerSelection =
                        //                     DrawerSelection.MyBooking;
                        //                 _appBarTitle = 'Dine-In Bookings'.tr();
                        //                 _currentWidget = MyBookingScreen();
                        //               });
                        //             }
                        //           },
                        //         ),
                        //       ),
                        ListTileTheme(
                          style: ListTileStyle.drawer,
                          selectedColor: Color(COLOR_PRIMARY),
                          child: ListTile(
                            selected: _drawerSelection == DrawerSelection.chooseLanguage,
                            leading: Icon(
                              Icons.language,
                              color: _drawerSelection == DrawerSelection.chooseLanguage
                                  ? Color(COLOR_PRIMARY)
                                  : isDarkMode(context)
                                      ? Colors.grey.shade200
                                      : Colors.grey.shade600,
                            ),
                            title: const Text('language').tr(),
                            onTap: () {
                              Navigator.pop(context);
                              setState(() {
                                _drawerSelection = DrawerSelection.chooseLanguage;
                                _appBarTitle = 'language'.tr();
                                _currentWidget = LanguageChooseScreen(
                                  isContainer: true,
                                );
                              });
                            },
                          ),
                        ),
                        ListTileTheme(
                          style: ListTileStyle.drawer,
                          selectedColor: Color(COLOR_PRIMARY),
                          child: ListTile(
                              selected: _drawerSelection == DrawerSelection.Logout,
                              leading: Icon(Icons.logout),
                              title: Text(MyAppState.currentUser == null ? 'logIn' : 'logOut').tr(),
                              onTap: () async {
                                if (MyAppState.currentUser == null) {
                                  pushAndRemoveUntil(context, AuthScreen(), false);
                                } else {
                                  Navigator.pop(context);
                                  //user.active = false;
                                  user.lastOnlineTimestamp = Timestamp.now();
                                  user.fcmToken = "";
                                  await FireStoreUtils.updateCurrentUser(user);
                                  await auth.FirebaseAuth.instance.signOut();
                                  MyAppState.currentUser = null;
                                  MyAppState.selectedPosotion = Position.fromMap({'latitude': 0.0, 'longitude': 0.0});
                                  Provider.of<CartDatabase>(context, listen: false).deleteAllProducts();
                                  pushAndRemoveUntil(context, AuthScreen(), false);
                                }
                              }),
                        ),
                      ],
                    )),
              ),
              appBar: AppBar(
                elevation: 0,
                centerTitle: _drawerSelection == DrawerSelection.Wallet ? true : false,
                backgroundColor: _drawerSelection == DrawerSelection.Wallet
                    ? Colors.transparent
                    : isDarkMode(context)
                        ? Color(DARK_COLOR)
                        : Colors.white,
                //isDarkMode(context) ? Color(DARK_COLOR) : null,
                leading: IconButton(
                    visualDensity: VisualDensity(horizontal: -4),
                    padding: EdgeInsets.only(right: 5),
                    icon: Image(
                      image: AssetImage("assets/images/menu.png"),
                      width: 20,
                      color: _drawerSelection == DrawerSelection.Wallet
                          ? Colors.white
                          : isDarkMode(context)
                              ? Colors.white
                              : Color(DARK_COLOR),
                    ),
                    onPressed: () => key.currentState!.openDrawer()),
                // iconTheme: IconThemeData(color: Colors.blue),
                title: _currentWidget is SearchScreen
                    ? _buildSearchField()
                    : Text(
                        _appBarTitle,
                        style: TextStyle(
                            fontFamily: "Poppinsm",
                            color: _drawerSelection == DrawerSelection.Wallet
                                ? Colors.white
                                : isDarkMode(context)
                                    ? Colors.white
                                    : Color(DARK_COLOR),
                            //isDarkMode(context) ? Colors.white : Colors.black,
                            fontWeight: FontWeight.normal),
                      ),
                actions: _drawerSelection == DrawerSelection.Wallet || _drawerSelection == DrawerSelection.MyBooking
                    ? []
                    : [
                        IconButton(
                            padding: const EdgeInsets.only(right: 20),
                            visualDensity: VisualDensity(horizontal: -4),
                            tooltip: 'qrCode'.tr(),
                            icon: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Image(
                                  image: AssetImage("assets/images/qrscan.png"),
                                  width: 20,
                                  color: isDarkMode(context) ? Colors.white : Colors.black,
                                ),
                              ],
                            ),
                            onPressed: () {
                              push(
                                context,
                                QrCodeScanner(),
                              );
                            }),
                        IconButton(
                            visualDensity: const VisualDensity(horizontal: -4),
                            padding: EdgeInsets.only(right: 10),
                            icon: Image(
                              image: AssetImage("assets/images/search.png"),
                              width: 20,
                              color: isDarkMode(context) ? Colors.white : null,
                            ),
                            onPressed: () {
                              setState(() {
                                _drawerSelection = DrawerSelection.Search;
                                _appBarTitle = 'search'.tr();
                                _currentWidget = SearchScreen(
                                  key: _searchScreenStateKey,
                                );
                              });
                            }),
                        if (!(_currentWidget is CartScreen) || !(_currentWidget is ProfileScreen))
                          IconButton(
                            visualDensity: VisualDensity(horizontal: -4),
                            padding: EdgeInsets.only(right: 10),
                            icon: Image(
                              image: AssetImage("assets/images/map.png"),
                              width: 20,
                              color: isDarkMode(context) ? Colors.white : Color(0xFF333333),
                            ),
                            onPressed: () => push(
                              context,
                              MapViewScreen(),
                            ),
                          ),
                        if (!(_currentWidget is CartScreen) || !(_currentWidget is ProfileScreen))
                          IconButton(
                              padding: EdgeInsets.only(right: 20),
                              visualDensity: VisualDensity(horizontal: -4),
                              tooltip: 'cart'.tr(),
                              icon: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Image(
                                    image: AssetImage("assets/images/cart.png"),
                                    width: 20,
                                    color: isDarkMode(context) ? Colors.white : null,
                                  ),
                                  StreamBuilder<List<CartProduct>>(
                                    stream: cartDatabase.watchProducts,
                                    builder: (context, snapshot) {
                                      cartCount = 0;
                                      if (snapshot.hasData) {
                                        snapshot.data!.forEach((element) {
                                          cartCount += element.quantity;
                                        });
                                      }
                                      return Visibility(
                                        visible: cartCount >= 1,
                                        child: Positioned(
                                          right: -6,
                                          top: -8,
                                          child: Container(
                                            padding: EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Color(COLOR_PRIMARY),
                                            ),
                                            constraints: BoxConstraints(
                                              minWidth: 12,
                                              minHeight: 12,
                                            ),
                                            child: Center(
                                              child: new Text(
                                                cartCount <= 99 ? '$cartCount' : '+99',
                                                style: new TextStyle(
                                                  color: Colors.white,
                                                  // fontSize: 10,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                ],
                              ),
                              onPressed: () {
                                if (MyAppState.currentUser == null) {
                                  Navigator.pop(context);
                                  push(context, AuthScreen());
                                } else {
                                  setState(() {
                                    _drawerSelection = DrawerSelection.Cart;
                                    _appBarTitle = 'yourCart'.tr();
                                    _currentWidget = CartScreen(
                                      fromContainer: true,
                                    );
                                  });
                                }
                              }),
                      ],
              ),
              body: _currentWidget,
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchField() => TextField(
        controller: searchController,
        onChanged: _searchScreenStateKey.currentState == null
            ? (str) {
                setState(() {});
              }
            : _searchScreenStateKey.currentState!.onSearchTextChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.all(10),
          isDense: true,
          fillColor: isDarkMode(context) ? Colors.grey[700] : Colors.grey[200],
          filled: true,
          prefixIcon: Icon(
            CupertinoIcons.search,
            color: Colors.black,
          ),
          suffixIcon: IconButton(
              icon: Icon(
                CupertinoIcons.clear,
                color: Colors.black,
              ),
              onPressed: () {
                setState(() {
                  _searchScreenStateKey.currentState?.clearSearchQuery();
                });
              }),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(10),
              ),
              borderSide: BorderSide(style: BorderStyle.none)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(10),
              ),
              borderSide: BorderSide(style: BorderStyle.none)),
          hintText: tr('search'),
        ),
      );
}
