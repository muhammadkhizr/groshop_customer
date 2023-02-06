import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:gromartconsumer/AppGlobal.dart';
import 'package:gromartconsumer/model/Ratingmodel.dart';
import 'package:gromartconsumer/model/VendorModel.dart';
import 'package:gromartconsumer/services/FirebaseHelper.dart';
import 'package:gromartconsumer/services/helper.dart';

import '../../constants.dart';

class Review extends StatefulWidget {
  final VendorModel vendorModel;

  const Review({Key? key, required this.vendorModel, required String reviewlength}) : super(key: key);

  @override
  _ReviewState createState() => _ReviewState();
}

class _ReviewState extends State<Review> {
  late Future<List<RatingModel>> ratingproduct;
  late RatingModel ratingModel;
  late VendorModel vendor;
  FireStoreUtils fireStoreUtils = FireStoreUtils();
  var rating = 0.0;

  @override
  void initState() {
    vendor = widget.vendorModel;
    super.initState();
    ratingproduct = fireStoreUtils.getReviewsbyVendorID(widget.vendorModel.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppGlobal.buildSimpleAppBar(context, 'Reviews -('.tr() + widget.vendorModel.reviewsCount.toString() + " Reviews)".tr()),
      body: FutureBuilder<List<RatingModel>>(
          future: ratingproduct,
          // initialData: ratingModel,
          builder: (BuildContext context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return Center(
                child: CircularProgressIndicator.adaptive(
                  valueColor: AlwaysStoppedAnimation(Color(COLOR_PRIMARY)),
                ),
              );
            else if (snapshot.data!.isEmpty) return Center(child: showEmptyState("", 'noReviewsAreAvailable'.tr()));
            if (snapshot.hasData) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ListView.builder(
                    itemCount: snapshot.data!.length,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemBuilder: (context, index) {
                      return Container(
                        color: isDarkMode(context) ? Color(DARK_COLOR) : Color(0xffFFFFFF),
                        margin: EdgeInsets.only(bottom: 10),
                        padding: EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                radius: 25,
                                // backgroundColor: Colors.grey.shade300,
                                backgroundImage: NetworkImage(snapshot.data![index].profile.isEmpty ? placeholderImage : snapshot.data![index].profile),
                              ),
                              title: Text(snapshot.data![index].uname),
                              subtitle: RatingBar.builder(
                                ignoreGestures: true,
                                initialRating: snapshot.data![index].rating,
                                minRating: 1,
                                itemSize: 22,
                                direction: Axis.horizontal,
                                allowHalfRating: true,
                                itemCount: 5,
                                itemPadding: EdgeInsets.only(top: 5.0),
                                itemBuilder: (context, _) => Icon(
                                  Icons.star,
                                  color: Color(COLOR_PRIMARY),
                                ),
                                onRatingUpdate: (double rate) {
                                  // ratings = rate;
                                  // print(ratings);
                                },
                              ),
                            ),
                            Divider(),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 22),
                              child: Text(snapshot.data![index].comment),
                            ),
                          ],
                        ),
                      );
                    }),
              );
            }
            return Center(
              child: Text("noReviwes".tr()),
            );
          }),
    );
  }
//   getcount(RatingModel ratingModel,length){
//    var count=0;
//   if (length<count){
//      rating = ratingModel.rating +rating;
//      count++;
//   }
//  print(count);
//     vendor.reviewsCount =length;
//     vendor.reviewsSum =rating;
//     // fireStoreUtils.
//     count == length? FireStoreUtils.updateVendor(vendor):
//   null;
//   return Center();
//     // print(length);
//     // return Center();
//   }
}
