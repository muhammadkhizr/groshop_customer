class BannerModel {
  int? setOrder;
  String? photo;
  String? title;
  bool? isPublish;

  BannerModel({this.setOrder, this.photo, this.title, this.isPublish});

  BannerModel.fromJson(Map<String, dynamic> json) {
    setOrder = json['set_order'];
    photo = json['photo'];
    title = json['title'];
    isPublish = json['is_publish'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['set_order'] = this.setOrder;
    data['photo'] = this.photo;
    data['title'] = this.title;
    data['is_publish'] = this.isPublish;
    return data;
  }
}
