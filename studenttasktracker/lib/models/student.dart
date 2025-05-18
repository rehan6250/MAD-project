class Student {
  final int? id;
  final String name;
  final String email;
  final String password;
  final bool isAdmin;

  Student({
    this.id,
    required this.name,
    required this.email,
    required this.password,
    this.isAdmin = false,
  });

  // Add toMap and fromMap methods if not already present
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': password,
      'isAdmin': isAdmin ? 1 : 0,
    };
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      password: map['password'],
      isAdmin: map['isAdmin'] == 1,
    );
  }
}