class Animal {
  final int id;
  final String rfidTag;
  final String species;
  final String breed;
  final String gender;
  final String status;
  final String farmName;

  Animal({
    required this.id,
    required this.rfidTag,
    required this.species,
    required this.breed,
    required this.gender,
    required this.status,
    required this.farmName,
  });

  factory Animal.fromJson(Map<String, dynamic> json) {
    return Animal(
      id: json['id'],
      rfidTag: json['rfidTag'],
      species: json['species'],
      breed: json['breed'],
      gender: json['gender'],
      status: json['status'],
      farmName: json['farmName'],
    );
  }
}