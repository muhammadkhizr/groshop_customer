import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart' as easyLocal;
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gromartconsumer/constants.dart';
import 'package:gromartconsumer/main.dart';
import 'package:gromartconsumer/model/User.dart';
import 'package:gromartconsumer/services/FirebaseHelper.dart';
import 'package:gromartconsumer/services/helper.dart';
import 'package:gromartconsumer/ui/container/ContainerScreen.dart';
import 'package:gromartconsumer/ui/phoneAuth/PhoneNumberInputScreen.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/localDatabase.dart';
import '../auth/AuthScreen.dart';
import 'package:provider/provider.dart';

File? _image;

class SignUpScreen extends StatefulWidget {
  @override
  State createState() => _SignUpState();
}

class _SignUpState extends State<SignUpScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  // TextEditingController _passwordController = TextEditingController();
  TextEditingController _emailController = TextEditingController();
  TextEditingController _phoneController = TextEditingController();
  TextEditingController _firstNameController = TextEditingController();
  TextEditingController _lastNameController = TextEditingController();
  GlobalKey<FormState> _key = GlobalKey();
  String? firstName, lastName, email, mobile, password, confirmPassword;
  AutovalidateMode _validate = AutovalidateMode.disabled;

  @override
  void initState() {
    if (MyAppState.currentUser != null) {
      _emailController.text = MyAppState.currentUser!.email;
      _phoneController.text = MyAppState.currentUser!.phoneNumber;
      _firstNameController.text = MyAppState.currentUser!.firstName;
      _lastNameController.text = MyAppState.currentUser!.lastName;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) {
      retrieveLostData();
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0.0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(
            color: isDarkMode(context) ? Colors.white : Colors.black),
      ),
      body: SingleChildScrollView(
        child: Container(
          margin: EdgeInsets.only(left: 16.0, right: 16, bottom: 16),
          child: Form(
            key: _key,
            autovalidateMode: _validate,
            child: formUI(),
          ),
        ),
      ),
    );
  }

  Future<void> retrieveLostData() async {
    final LostDataResponse? response = await _imagePicker.retrieveLostData();
    if (response == null) {
      return;
    }
    if (response.file != null) {
      setState(() {
        _image = File(response.file!.path);
      });
    }
  }

  _onCameraClick() {
    final action = CupertinoActionSheet(
      message: Text(
        'addProfilePicture',
        style: TextStyle(fontSize: 15.0),
      ).tr(),
      actions: <Widget>[
        CupertinoActionSheetAction(
          child: Text('chooseFromGallery').tr(),
          isDefaultAction: false,
          onPressed: () async {
            Navigator.pop(context);
            XFile? image =
                await _imagePicker.pickImage(source: ImageSource.gallery);
            if (image != null)
              setState(() {
                _image = File(image.path);
              });
          },
        ),
        CupertinoActionSheetAction(
          child: Text('takeAPicture').tr(),
          isDestructiveAction: false,
          onPressed: () async {
            Navigator.pop(context);
            XFile? image =
                await _imagePicker.pickImage(source: ImageSource.camera);
            if (image != null)
              setState(() {
                _image = File(image.path);
              });
          },
        )
      ],
      cancelButton: CupertinoActionSheetAction(
        child: Text('cancel').tr(),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
    );
    showCupertinoModalPopup(context: context, builder: (context) => action);
  }

  Widget formUI() {
    return Column(
      children: <Widget>[
        Align(
            alignment: Directionality.of(context) == TextDirection.ltr
                ? Alignment.topLeft
                : Alignment.topRight,
            child: Text(
              'completeSetUp',
              style: TextStyle(
                  color: Color(COLOR_PRIMARY),
                  fontWeight: FontWeight.bold,
                  fontSize: 25.0),
            ).tr()),
        Padding(
          padding:
              const EdgeInsets.only(left: 8.0, top: 32, right: 8, bottom: 8),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: <Widget>[
              CircleAvatar(
                radius: 65,
                backgroundColor: Colors.grey.shade400,
                child: ClipOval(
                  child: SizedBox(
                    width: 170,
                    height: 170,
                    child: _image == null
                        ? Image.asset(
                            'assets/images/placeholder.jpg',
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            _image!,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              ),
              Positioned(
                left: 80,
                right: 0,
                child: FloatingActionButton(
                    backgroundColor: Color(COLOR_ACCENT),
                    child: Icon(
                      CupertinoIcons.camera,
                      color: isDarkMode(context) ? Colors.black : Colors.white,
                    ),
                    mini: true,
                    onPressed: _onCameraClick),
              )
            ],
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: double.infinity),
          child: Padding(
            padding: const EdgeInsets.only(top: 16.0, right: 8.0, left: 8.0),
            child: TextFormField(
              controller: _firstNameController,
              cursorColor: Color(COLOR_PRIMARY),
              textAlignVertical: TextAlignVertical.center,
              validator: validateName,
              onSaved: (String? val) {
                firstName = val;
              },
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                fillColor: Colors.white,
                hintText: easyLocal.tr('firstName'),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                    borderSide:
                        BorderSide(color: Color(COLOR_PRIMARY), width: 2.0)),
                errorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).errorColor),
                  borderRadius: BorderRadius.circular(25.0),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).errorColor),
                  borderRadius: BorderRadius.circular(25.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(25.0),
                ),
              ),
            ),
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: double.infinity),
          child: Padding(
            padding: const EdgeInsets.only(top: 16.0, right: 8.0, left: 8.0),
            child: TextFormField(
              controller: _lastNameController,
              validator: validateName,
              textAlignVertical: TextAlignVertical.center,
              cursorColor: Color(COLOR_PRIMARY),
              onSaved: (String? val) {
                lastName = val;
              },
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                fillColor: Colors.white,
                hintText: 'lastName'.tr(),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                    borderSide:
                        BorderSide(color: Color(COLOR_PRIMARY), width: 2.0)),
                errorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).errorColor),
                  borderRadius: BorderRadius.circular(25.0),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).errorColor),
                  borderRadius: BorderRadius.circular(25.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(25.0),
                ),
              ),
            ),
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: double.infinity),
          child: Padding(
            padding: const EdgeInsets.only(top: 16.0, right: 8.0, left: 8.0),
            child: TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textAlignVertical: TextAlignVertical.center,
              textInputAction: TextInputAction.next,
              cursorColor: Color(COLOR_PRIMARY),
              validator: validateEmail,
              onSaved: (String? val) {
                email = val;
              },
              decoration: InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                fillColor: Colors.white,
                hintText: 'emailAddress'.tr(),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                    borderSide:
                        BorderSide(color: Color(COLOR_PRIMARY), width: 2.0)),
                errorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).errorColor),
                  borderRadius: BorderRadius.circular(25.0),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).errorColor),
                  borderRadius: BorderRadius.circular(25.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(25.0),
                ),
              ),
            ),
          ),
        ),

        /// user mobile text field, this is hidden in case of sign up with
        /// phone number
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: double.infinity),
          child: Padding(
            padding: const EdgeInsets.only(top: 16.0, right: 8.0, left: 8.0),
            child: TextFormField(
              controller: _phoneController,
              // enabled: false,
              readOnly: true,
              keyboardType: TextInputType.phone,
              textAlignVertical: TextAlignVertical.center,
              textInputAction: TextInputAction.next,
              cursorColor: Color(COLOR_PRIMARY),
              validator: validateMobile,
              onSaved: (String? val) {
                mobile = val;
              },
              decoration: InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                fillColor: Colors.grey.shade100,
                filled: true,
                hintText: 'mobile'.tr(),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                    borderSide:
                        BorderSide(color: Colors.grey.shade200, width: 2.0)),
                errorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).errorColor),
                  borderRadius: BorderRadius.circular(25.0),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).errorColor),
                  borderRadius: BorderRadius.circular(25.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(25.0),
                ),
              ),
            ),
          ),
        ),
        // ConstrainedBox(
        //   constraints: BoxConstraints(minWidth: double.infinity),
        //   child: Padding(
        //     padding: const EdgeInsets.only(top: 16.0, right: 8.0, left: 8.0),
        //     child: TextFormField(
        //       obscureText: true,
        //       textAlignVertical: TextAlignVertical.center,
        //       textInputAction: TextInputAction.next,
        //       controller: _passwordController,
        //       validator: validatePassword,
        //       onSaved: (String? val) {
        //         password = val;
        //       },
        //       style: TextStyle(fontSize: 18.0),
        //       cursorColor: Color(COLOR_PRIMARY),
        //       decoration: InputDecoration(
        //         contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        //         fillColor: Colors.white,
        //         hintText: 'password'.tr(),
        //         focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25.0), borderSide: BorderSide(color: Color(COLOR_PRIMARY), width: 2.0)),
        //         errorBorder: OutlineInputBorder(
        //           borderSide: BorderSide(color: Theme.of(context).errorColor),
        //           borderRadius: BorderRadius.circular(25.0),
        //         ),
        //         focusedErrorBorder: OutlineInputBorder(
        //           borderSide: BorderSide(color: Theme.of(context).errorColor),
        //           borderRadius: BorderRadius.circular(25.0),
        //         ),
        //         enabledBorder: OutlineInputBorder(
        //           borderSide: BorderSide(color: Colors.grey.shade200),
        //           borderRadius: BorderRadius.circular(25.0),
        //         ),
        //       ),
        //     ),
        //   ),
        // ),
        // ConstrainedBox(
        //   constraints: BoxConstraints(minWidth: double.infinity),
        //   child: Padding(
        //     padding: const EdgeInsets.only(top: 16.0, right: 8.0, left: 8.0),
        //     child: TextFormField(
        //       textAlignVertical: TextAlignVertical.center,
        //       textInputAction: TextInputAction.done,
        //       onFieldSubmitted: (_) => _signUp(),
        //       obscureText: true,
        //       validator: (val) => validateConfirmPassword(_passwordController.text, val),
        //       onSaved: (String? val) {
        //         confirmPassword = val;
        //       },
        //       style: TextStyle(fontSize: 18.0),
        //       cursorColor: Color(COLOR_PRIMARY),
        //       decoration: InputDecoration(
        //         contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        //         fillColor: Colors.white,
        //         hintText: 'confirmPassword'.tr(),
        //         focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25.0), borderSide: BorderSide(color: Color(COLOR_PRIMARY), width: 2.0)),
        //         errorBorder: OutlineInputBorder(
        //           borderSide: BorderSide(color: Theme.of(context).errorColor),
        //           borderRadius: BorderRadius.circular(25.0),
        //         ),
        //         focusedErrorBorder: OutlineInputBorder(
        //           borderSide: BorderSide(color: Theme.of(context).errorColor),
        //           borderRadius: BorderRadius.circular(25.0),
        //         ),
        //         enabledBorder: OutlineInputBorder(
        //           borderSide: BorderSide(color: Colors.grey.shade200),
        //           borderRadius: BorderRadius.circular(25.0),
        //         ),
        //       ),
        //     ),
        //   ),
        // ),
        Padding(
          padding: const EdgeInsets.only(right: 40.0, left: 40.0, top: 40.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: double.infinity),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.only(top: 12, bottom: 12),
                backgroundColor: Color(COLOR_PRIMARY),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  side: BorderSide(
                    color: Color(COLOR_PRIMARY),
                  ),
                ),
              ),
              child: Text(
                'finish'.tr(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode(context) ? Colors.black : Colors.white,
                ),
              ),
              onPressed: () => _signUp(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Text(
              'or',
              style: TextStyle(
                  color: isDarkMode(context) ? Colors.white : Colors.black),
            ).tr(),
          ),
        ),
        InkWell(
          onTap: () async {
            // push(context, PhoneNumberInputScreen(login: false));
            User user = MyAppState.currentUser!;
            if (user == null) {
              pushAndRemoveUntil(context, AuthScreen(), false);
            } else {
              // Navigator.pop(context);
              //user.active = false;
              user.lastOnlineTimestamp = Timestamp.now();
              user.fcmToken = "";
              await showProgress(context, 'Logging out'.tr(), false);
              await FireStoreUtils.updateCurrentUser(user);
              await auth.FirebaseAuth.instance.signOut();
              MyAppState.currentUser = null;
              MyAppState.selectedPosotion =
                  Position.fromMap({'latitude': 0.0, 'longitude': 0.0});
              Provider.of<CartDatabase>(context, listen: false)
                  .deleteAllProducts();
              await hideProgress();
              pushAndRemoveUntil(context, AuthScreen(), false);
            }
          },
          child: Padding(
            padding: EdgeInsets.only(top: 0, right: 40, left: 40),
            child: Container(
                alignment: Alignment.bottomCenter,
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Color(COLOR_PRIMARY), width: 1)),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Icon(Icons.logout),
                      Text(
                        'logout'.tr(),
                        style: TextStyle(
                            color: Color(COLOR_PRIMARY),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1),
                      ),
                    ])),
          ),
        )
      ],
    );
  }

  /// dispose text controllers to avoid memory leaks
  @override
  void dispose() {
    // _passwordController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _image = null;
    super.dispose();
  }

  /// if the fields are validated and location is enabled we create a new user
  /// and navigate to [ContainerScreen] else we show error
  _signUp() async {
    if (_key.currentState?.validate() ?? false) {
      _key.currentState!.save();
      // await _signUpWithEmailAndPassword();
      await _updateData();
    } else {
      setState(() {
        _validate = AutovalidateMode.onUserInteraction;
      });
    }
  }

  _updateData() async {
    await showProgress(context, 'updatingDataToDatabase'.tr(), false);
    dynamic result = await FireStoreUtils.firebaseUpdateUserData(
        MyAppState.currentUser!.userID,
        email!.trim(),
        _image,
        firstName!,
        lastName!,
        mobile!,
        context);
    await hideProgress();

    if (result != null && result is User) {
      MyAppState.currentUser = result;
      if (MyAppState.currentUser!.active != true) {
        // pushAndRemoveUntil(context, ContainerScreen(user: result), false);
        showAlertDialog(context,
            'yourAccountHasBeenDisabledPleaseContactToAdmin'.tr(), "", true);
      } else {
        pushAndRemoveUntil(context, ContainerScreen(user: result), false);
      }
      // pushAndRemoveUntil(context, ContainerScreen(user: result), false);
    } else {
      showAlertDialog(context, 'failed'.tr(), result, true);
      pushReplacement(context, AuthScreen());
    }
  }

  _signUpWithEmailAndPassword() async {
    await showProgress(context, 'creatingNewAccountPleaseWait'.tr(), false);
    dynamic result = await FireStoreUtils.firebaseSignUpWithEmailAndPassword(
        email!.trim(),
        password!.trim(),
        _image,
        firstName!,
        lastName!,
        mobile!,
        context);
    await hideProgress();
    if (result != null && result is User) {
      MyAppState.currentUser = result;
      pushAndRemoveUntil(context, ContainerScreen(user: result), false);
    } else if (result != null && result is String) {
      showAlertDialog(context, 'failed'.tr(), result, true);
    } else {
      showAlertDialog(context, 'failed'.tr(), 'couldNotSignUp'.tr(), true);
    }
  }
}
