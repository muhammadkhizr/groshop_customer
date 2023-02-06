// ignore_for_file: non_constant_identifier_names

class PayFastSettingData {
  bool isEnable;
  bool isSandbox;
  String merchant_id;
  String merchant_key;

  String return_url;
  String cancel_url;
  String notify_url;

  PayFastSettingData({
    this.merchant_id = '',
    this.cancel_url = '',
    required this.isEnable,
    required this.isSandbox,
    this.merchant_key = '',
    this.notify_url = '',
    this.return_url = '',
  });

  factory PayFastSettingData.fromJson(Map<String, dynamic> parsedJson) {
    return PayFastSettingData(
      isSandbox: parsedJson['isSandbox'] ?? false,
      isEnable: parsedJson['isEnable'] ?? false,
      return_url: parsedJson['return_url'] ?? '',
      notify_url: parsedJson['notify_url'] ?? '',
      merchant_key: parsedJson['merchant_key'] ?? '',
      cancel_url: parsedJson['cancel_url'] ?? '',
      merchant_id: parsedJson['merchant_id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'merchant_id': this.merchant_id,
      'merchant_key': this.merchant_key,
      'return_url': this.return_url,
      'cancel_url': this.cancel_url,
      'notify_url': this.notify_url,
      'isEnable': this.isEnable,
      'isSandbox': this.isSandbox,
    };
  }
}
