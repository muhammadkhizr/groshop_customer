import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gromartconsumer/AppGlobal.dart';
import 'package:gromartconsumer/constants.dart';
import 'package:gromartconsumer/model/CuisineModel.dart';
import 'package:gromartconsumer/services/FirebaseHelper.dart';
import 'package:gromartconsumer/services/helper.dart';
import 'package:gromartconsumer/ui/categoryDetailsScreen/CategoryDetailsScreen.dart';

class CuisinesScreen extends StatefulWidget {
  const CuisinesScreen({
    Key? key,
    this.isPageCallFromHomeScreen = false,
  }) : super(key: key);

  @override
  _CuisinesScreenState createState() => _CuisinesScreenState();
  final bool? isPageCallFromHomeScreen;
}

class _CuisinesScreenState extends State<CuisinesScreen> {
  final fireStoreUtils = FireStoreUtils();
  late Future<List<CuisineModel>> categoriesFuture;

  @override
  void initState() {
    super.initState();
    categoriesFuture = fireStoreUtils.getCuisines();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: isDarkMode(context) ? Color(DARK_VIEWBG_COLOR) : null,
        appBar: widget.isPageCallFromHomeScreen! ? AppGlobal.buildAppBar(context, "categories".tr()) : null,
        body: FutureBuilder<List<CuisineModel>>(
            future: categoriesFuture,
            initialData: [],
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return Center(
                  child: CircularProgressIndicator.adaptive(
                    valueColor: AlwaysStoppedAnimation(Color(COLOR_PRIMARY)),
                  ),
                );

              if (snapshot.hasData || (snapshot.data?.isNotEmpty ?? false)) {
                print('\x1b[92m ${snapshot.data!.length}');
                return ListView.builder(
                    padding: EdgeInsets.all(10),
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      return snapshot.data != null
                          ? buildCuisineCell(snapshot.data![index])
                          : showEmptyState('noCategories'.tr(), 'startByAddingCategoriesToFirebase'.tr());
                    });
              }
              return CircularProgressIndicator();
            }));
  }

  Widget buildCuisineCell(CuisineModel cuisineModel) {
    return Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: GestureDetector(
          onTap: () => push(
            context,
            CategoryDetailsScreen(
              category: cuisineModel,
            ),
          ),
          child:
              // CachedNetworkImage(
              //   imageUrl: getImageVAlidUrl(cuisineModel.photo.toString()),
              //   imageBuilder: (context, imageProvider) => Container(
              //     height: MediaQuery.of(context).size.height * 0.11,
              //     width: MediaQuery.of(context).size.width * 0.23,
              //     decoration: BoxDecoration(
              //         border: Border.all(
              //           width: 6,
              //           // color: Color(COLOR_PRIMARY),
              //         ),
              //         borderRadius: BorderRadius.circular(30)),
              //     child: Container(
              //       // height: 80,width: 80,
              //       decoration: BoxDecoration(
              //           border: Border.all(
              //             width: 4,
              //             color: isDarkMode(context)
              //                 ? Color(DARK_COLOR)
              //                 : Color(0xffE0E2EA),
              //           ),
              //           borderRadius: BorderRadius.circular(30)),
              //       child: Container(
              //         width: 60,
              //         height: 60,
              //         decoration: BoxDecoration(
              //             borderRadius: BorderRadius.circular(20),
              //             image: DecorationImage(
              //               image: imageProvider,
              //               fit: BoxFit.cover,
              //             )),
              //       ),
              //     ),
              //   ),
              //   memCacheHeight: (MediaQuery.of(context).size.height * 0.11).toInt(),
              //   memCacheWidth: (MediaQuery.of(context).size.width * 0.23).toInt(),
              //   placeholder: (context, url) => ClipOval(
              //     child: Container(
              //       // padding: EdgeInsets.only(top: 10),
              //       decoration: BoxDecoration(
              //         borderRadius: BorderRadius.all(Radius.circular(75 / 1)),
              //         border: Border.all(
              //           color: Color(COLOR_PRIMARY),
              //           style: BorderStyle.solid,
              //           width: 2.0,
              //         ),
              //       ),
              //       width: 75,
              //       height: 75,
              //       child: Icon(
              //         Icons.fastfood,
              //         color: Color(COLOR_PRIMARY),
              //       ),
              //     ),
              //   ),
              //   errorWidget: (context, url, error) => ClipRRect(
              //       borderRadius: BorderRadius.circular(20),
              //       child: Image.network(
              //         AppGlobal.placeHolderImage!,
              //         fit: BoxFit.cover,
              //       )),
              // ),
              Container(
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(23),
              image: DecorationImage(
                image: NetworkImage(
                  cuisineModel.photo.toString().isNotEmpty ? cuisineModel.photo.toString() : AppGlobal.placeHolderImage!,
                ),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.darken),
              ),
            ),
            child: Center(
              child: Text(
                cuisineModel.title,
                style: TextStyle(color: Colors.white, fontFamily: "Poppinsm", fontSize: 27),
              ).tr(),
            ),
          ),
        ));
  }
}
