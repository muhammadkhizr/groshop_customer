// ignore_for_file: deprecated_member_use, unused_local_variable

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gromartconsumer/constants.dart';
import 'package:gromartconsumer/model/ConversationModel.dart';
import 'package:gromartconsumer/model/CurrencyModel.dart';
import 'package:gromartconsumer/model/HomeConversationModel.dart';
import 'package:gromartconsumer/services/FirebaseHelper.dart';
import 'package:gromartconsumer/services/helper.dart';
import 'package:gromartconsumer/services/localDatabase.dart';
import 'package:gromartconsumer/ui/auth/AuthScreen.dart';
import 'package:gromartconsumer/ui/chat/ChatScreen.dart';
import 'package:gromartconsumer/ui/container/ContainerScreen.dart';
import 'package:gromartconsumer/ui/onBoarding/OnBoardingScreen.dart';
import 'package:gromartconsumer/ui/signUp/SignUpScreen.dart';
import 'package:gromartconsumer/userPrefrence.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'model/User.dart';

void main() async {
  //Stripe.publishableKey = "pk_test_51Kaaj9SE3HQdbrEJneDaJ2aqIyX1SBpYhtcMKfwchyohSZGp53F75LojfdGTNDUwsDV5p6x5BnbATcrerModlHWa00WWm5Yf5h";
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await UserPreference.init();
  if (Platform.isIOS) {
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: "Replace with your project details",
            appId: "Replace with your project details",
            messagingSenderId: "Replace with your project details",
            projectId: "Replace with your project details"));
  } else {
    await Firebase.initializeApp();
  }
  Future.delayed(Duration(seconds: 3), () {
    runApp(
      MultiProvider(
        providers: [
          Provider<CartDatabase>(
            create: (_) => CartDatabase(),
          )
        ],
        child: EasyLocalization(
            supportedLocales: [Locale('en'), Locale('ar'),Locale('hi'), Locale('mr')],
            path: 'assets/translations',
            fallbackLocale: Locale('en'),
            saveLocale: false,
            useOnlyLangCode: true,
            useFallbackTranslations: true,
            child: MyApp()),
      ),
    );
  });
}

class MyApp extends StatefulWidget {
  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> with WidgetsBindingObserver {
  /// this key is used to navigate to the appropriate screen when the
  /// notification is clicked from the system tray
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey(debugLabel: 'Main Navigator');

  static User? currentUser;
  static Position selectedPosotion = Position.fromMap({'latitude': 0.0, 'longitude': 0.0});
  late StreamSubscription tokenStream;

  // Set default `_initialized` and `_error` state to false
  bool _initialized = false, isColorLoad = false;
  bool _error = false;

  //  late Stream<StripeKeyModel> futureStirpe;
  //  String? data,d;

  // Define an async function to initialize FlutterFire
  void initializeFlutterFire() async {
    try {
      /// Wait for Firebase to initialize and set `_initialized` state to true

      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
      FirebaseFirestore.instance.collection(Setting).doc("globalSettings").get().then((dineinresult) {
        if (dineinresult.exists && dineinresult.data() != null && dineinresult.data()!.containsKey("website_color")) {
          COLOR_PRIMARY = int.parse(dineinresult.data()!["website_color"].replaceFirst("#", "0xff"));

        }
        setState(() {
          isColorLoad = true;
        });
      });
      // FirebaseFirestore.instance
      //     .collection(Setting)
      //     .doc("DineinForRestaurant")
      //     .get()
      //     .then((dineinresult) {
      //   if (dineinresult.exists) {
      //     isDineInEnable = dineinresult.data()!["isEnabledForCustomer"];
      //   }
      // });
      // await FireStoreUtils.getWalletSettingData();

      RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleNotification(initialMessage.data, navigatorKey);
      }

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage? remoteMessage) {
        if (remoteMessage != null) {
          _handleNotification(remoteMessage.data, navigatorKey);
        }
      });

      /// configure the firebase messaging , required for notifications handling
      if (!Platform.isIOS) {
        FirebaseMessaging.onBackgroundMessage(backgroundMessageHandler);
      }

      /// listen to firebase token changes and update the user object in the
      /// database with it's new token
      ///

      tokenStream = FireStoreUtils.firebaseMessaging.onTokenRefresh.listen((event) {
        if (currentUser != null) {
          print('token $event');
          currentUser!.fcmToken = event;
          FireStoreUtils.updateCurrentUser(currentUser!);
        }
      });

      setState(() {
        _initialized = true;
      });
    } catch (e) {
      // Set `_error` state to true if Firebase initialization fails
      setState(() {
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show error message if initialization failed
    if (_error) {
      return MaterialApp(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          home: Scaffold(
            body: Container(
              color: Colors.white,
              child: Center(
                  child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 25,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Failed to initialise firebase!',
                    style: TextStyle(color: Colors.red, fontSize: 25),
                  ),
                ],
              )),
            ),
          ));
    }

    // Show a loader until FlutterFire is initialized
    if (!_initialized || !isColorLoad) {
      return Container(
        color: Colors.white,
        child: Center(
          child: CircularProgressIndicator.adaptive(
            valueColor: AlwaysStoppedAnimation(Color(COLOR_PRIMARY)),
          ),
        ),
      );
    } else {
      return MaterialApp(
          navigatorKey: navigatorKey,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          title: 'GroShop'.tr(),
          theme: ThemeData(
              appBarTheme: AppBarTheme(
                  centerTitle: true,
                  color: Colors.transparent,
                  elevation: 0,
                  actionsIconTheme: IconThemeData(color: Color(COLOR_PRIMARY)),
                  iconTheme: IconThemeData(color: Color(COLOR_PRIMARY)),
                  // textTheme: TextTheme(
                  //     headline6: TextStyle(
                  //         color: Colors.black,
                  //         fontSize: 17.0,
                  //         letterSpacing: 0,
                  //         fontWeight: FontWeight.w700)),
                  brightness: Brightness.light),
              bottomSheetTheme: BottomSheetThemeData(backgroundColor: Colors.white),
              // accentColor: Color(COLOR_PRIMARY),
              primaryColor: Color(COLOR_PRIMARY),
              brightness: Brightness.light),
          darkTheme: ThemeData(
              appBarTheme: AppBarTheme(
                  centerTitle: true,
                  color: Colors.transparent,
                  elevation: 0,
                  actionsIconTheme: IconThemeData(color: Color(COLOR_PRIMARY)),
                  iconTheme: IconThemeData(color: Color(COLOR_PRIMARY)),
                  // textTheme: TextTheme(
                  //     headline6: TextStyle(
                  //         color: Colors.grey[200],
                  //         fontSize: 17.0,
                  //         letterSpacing: 0,
                  //         fontWeight: FontWeight.w700)),
                  brightness: Brightness.dark),
              bottomSheetTheme: BottomSheetThemeData(backgroundColor: Colors.grey.shade900),
              // accentColor: Color(COLOR_PRIMARY),
              primaryColor: Color(COLOR_PRIMARY),
              brightness: Brightness.dark),
          debugShowCheckedModeBanner: false,
          color: Color(COLOR_PRIMARY),
          home: OnBoarding());
    }
  }

  @override
  void initState() {
    initializeFlutterFire();

    WidgetsBinding.instance.addObserver(this);

    super.initState();
  }

  @override
  void dispose() {
    tokenStream.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    /*if (auth.FirebaseAuth.instance.currentUser != null && currentUser != null) {
      if (state == AppLifecycleState.paused) {
        //user offline
        tokenStream.pause();
        currentUser!.active = false;
        currentUser!.lastOnlineTimestamp = Timestamp.now();
        FireStoreUtils.updateCurrentUser(currentUser!);
      } else if (state == AppLifecycleState.resumed) {
        //user online
        tokenStream.resume();
        currentUser!.active = true;
        FireStoreUtils.updateCurrentUser(currentUser!);
      }
    }*/
  }
}

class OnBoarding extends StatefulWidget {
  @override
  State createState() {
    return OnBoardingState();
  }
}

class OnBoardingState extends State<OnBoarding> {
  late Future<List<CurrencyModel>> futureCurrency;

  Future hasFinishedOnBoarding() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool finishedOnBoarding = (prefs.getBool(FINISHED_ON_BOARDING) ?? false);

    if (finishedOnBoarding) {
      auth.User? firebaseUser = auth.FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        User? user = await FireStoreUtils.getCurrentUser(firebaseUser.uid);

        print("====>");

        if (user != null && user.role == USER_ROLE_CUSTOMER) {
          if (user.active) {
            user.active = true;
            user.role = USER_ROLE_CUSTOMER;
            // user.fcmToken =
            //     await FireStoreUtils.firebaseMessaging.getToken() ?? '';
            await FireStoreUtils.updateCurrentUser(user);
            MyAppState.currentUser = user;
            //UserPreference.setUserId(userID: user.userID);
            //
            if (user.email == "" || user.email == null) {
              pushAndRemoveUntil(context, SignUpScreen(), false);
            } else {
            pushReplacement(context, ContainerScreen(user: user));
            }
          } else {
            user.lastOnlineTimestamp = Timestamp.now();
            user.fcmToken = "";
            await FireStoreUtils.updateCurrentUser(user);
            await auth.FirebaseAuth.instance.signOut();
            MyAppState.currentUser = null;
            Provider.of<CartDatabase>(context, listen: false).deleteAllProducts();
            pushAndRemoveUntil(context, AuthScreen(), false);
          }
        } else {
          pushReplacement(context, AuthScreen());
        }
      } else {
        pushReplacement(context, AuthScreen());
      }
    } else {
      pushReplacement(context, OnBoardingScreen());
    }
  }

  @override
  void initState() {
    super.initState();
    hasFinishedOnBoarding();
    // futureCurrency= FireStoreUtils().getCurrency();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator.adaptive(
          valueColor: AlwaysStoppedAnimation(Color(COLOR_PRIMARY)),
        ),
      ),
    );
  }
}

/// this faction is called when the notification is clicked from system tray
/// when the app is in the background or completely killed
void _handleNotification(Map<String, dynamic> message, GlobalKey<NavigatorState> navigatorKey) {
  /// right now we only handle click actions on chat messages only
  try {
    print("data is ${message.toString()}");
    if (message.containsKey('members') && message.containsKey('isGroup') && message.containsKey('conversationModel')) {
      List<User> members = List<User>.from((jsonDecode(message['members']) as List<dynamic>).map((e) => User.fromPayload(e))).toList();
      ConversationModel conversationModel = ConversationModel.fromPayload(jsonDecode(message['conversationModel']));
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            homeConversationModel: HomeConversationModel(members: members, conversationModel: conversationModel),
          ),
        ),
      );
    }
  } catch (e, s) {
    print('MyAppState._handleNotification $e $s');
  }
}

Future<dynamic> backgroundMessageHandler(RemoteMessage remoteMessage) async {
  await Firebase.initializeApp();
  Map<dynamic, dynamic> message = remoteMessage.data;
  if (message.containsKey('data')) {
    // Handle data message
    print('backgroundMessageHandler message.containsKey(data)');
    final dynamic data = message['data'];
  }

  if (message.containsKey('notification')) {
    // Handle notification message
    final dynamic notification = message['notification'];
  }
}
