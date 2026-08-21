// M-11 USED FOR NOTIFICATION AND STORING THE DEVICE TYPE
class DeviceTokenModel {
  String token;
  String platform;

  DeviceTokenModel({required this.token, this.platform = 'android'});

  Map<String, dynamic> toJson() => {
        'token': token,
        'platform': platform,
      };

  factory DeviceTokenModel.fromJson(Map<String, dynamic> json) =>
      DeviceTokenModel(
        token: json['token'] ?? '',
        platform: json['platform'] ?? 'android',
      );
}
