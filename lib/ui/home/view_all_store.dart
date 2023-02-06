import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:geoflutterfire/geoflutterfire.dart';
import 'package:gromartconsumer/AppGlobal.dart';
import 'package:gromartconsumer/constants.dart';
import 'package:gromartconsumer/main.dart';
import 'package:gromartconsumer/model/FavouriteModel.dart';
import 'package:gromartconsumer/model/VendorModel.dart';
import 'package:gromartconsumer/services/FirebaseHelper.dart';
import 'package:gromartconsumer/services/helper.dart';
import 'package:gromartconsumer/ui/auth/AuthScreen.dart';
import 'package:gromartconsumer/ui/vendorProductsScreen/VendorProductsScreen.dart';

class ViewAllStore extends StatefulWidget {
  const ViewAllStore({Key? key}) : super(key: key);

  @override
  State<ViewAllStore> createState() => _ViewAllStoreState();
}

class _ViewAllStoreState extends State<ViewAllStore> {
  List<VendorModel> vendors = [];

  bool isLoading = true;

  getProducts() async {
    setState(() {
      isLoading = true;
    });
    var collectionReference = FireStoreUtils.firestore.collection(VENDORS);

    GeoFirePoint center = Geoflutterfire().point(latitude: MyAppState.selectedPosotion.latitude, longitude: MyAppState.selectedPosotion.longitude);
    String field = 'g';

    Stream<List<DocumentSnapshot>> stream =
        Geoflutterfire().collection(collectionRef: collectionReference).within(center: center, radius: radius, field: field, strictMode: true);
    stream.listen((documentList) {
      documentList.forEach((DocumentSnapshot document) {
        final data = document.data() as Map<String, dynamic>;
        setState(() {
          vendors.add(VendorModel.fromJson(data));
        });
      });
    });
    setState(() {
      isLoading = false;
    });
  }

  late Future<List<FavouriteModel>> lstFavourites;

  getData() {
    if (MyAppState.currentUser != null) {
      lstFavourites = FireStoreUtils().getFavouriteStore(MyAppState.currentUser!.userID);
      lstFavourites.then((event) {
        lstFav.clear();
        for (int a = 0; a < event.length; a++) {
          lstFav.add(event[a].store_id!);
        }
      });
    }
  }

  List<String> lstFav = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppGlobal.buildAppBar(context, "All Store".tr()),
      body: Column(
        children: [
          Expanded(
            child: vendors.length == 0
                ? Center(
                    child: Text('No Data...'),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    scrollDirection: Axis.vertical,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: vendors.length,
                    itemBuilder: (context, index) =>
                        //buildVendorItem(vendors[index])

                        buildAllRestaurantsData(vendors[index]),
                  ),
          ),
          isLoading ? CircularProgressIndicator() : Container()
        ],
      ),
    );
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
                                FireStoreUtils().removeFavouriteStore(favouriteModel);
                              } else {
                                FavouriteModel favouriteModel = FavouriteModel(store_id: vendorModel.id, user_id: MyAppState.currentUser!.userID);
                                FireStoreUtils().setFavouriteStore(favouriteModel);
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

  @override
  void initState() {
    super.initState();
    getRadius();
    getData();
  }

  double radius = 100;

  getRadius() async {
    await FireStoreUtils().getStoreNearBy().then((value) {
      if (value != null) {
        setState(() {
          radius = double.parse(value);
        });
        getProducts();
      }
    });
  }
}
