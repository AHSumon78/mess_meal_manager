// lib/models/member.dart

class Member {
  final String id;
  final String name;
  final DateTime joiningDate;

  Member({required this.id, required this.name, required this.joiningDate});

  // Convert a Member object into a Map.
  // The keys must correspond to the names of the columns in the database.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'joiningDate': joiningDate
          .toIso8601String(), // Store DateTime as a String
    };
  }

  // Create a Member object from a Map.
  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'],
      name: map['name'],
      joiningDate: DateTime.parse(
        map['joiningDate'],
      ), // Parse String back to DateTime
    );
  }
}
