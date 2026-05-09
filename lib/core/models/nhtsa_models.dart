class CarMake {
  final int makeId;
  final String makeName;

  CarMake({required this.makeId, required this.makeName});

  factory CarMake.fromJson(Map<String, dynamic> json) {
    return CarMake(
      makeId: json['Make_ID'] ?? 0,
      makeName: json['Make_Name'] ?? '',
    );
  }
}

class CarModel {
  final int makeId;
  final String makeName;
  final int modelId;
  final String modelName;

  CarModel({
    required this.makeId,
    required this.makeName,
    required this.modelId,
    required this.modelName,
  });

  factory CarModel.fromJson(Map<String, dynamic> json) {
    return CarModel(
      makeId: json['Make_ID'] ?? 0,
      makeName: json['Make_Name'] ?? '',
      modelId: json['Model_ID'] ?? 0,
      modelName: json['Model_Name'] ?? '',
    );
  }
}
