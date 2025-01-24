// import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

FirebaseFirestore db = FirebaseFirestore.instance;

Future<List> getUsers() async {
  List users = [];
  CollectionReference collectionReferenceUser = db.collection('users');

  QuerySnapshot queryUsers = await collectionReferenceUser.get();

  queryUsers.docs.forEach((documento) {
    users.add(documento.data());
  });
  return users;
}

Future<List<Map<String, dynamic>>> getStudents() async {
  List<Map<String, dynamic>> students = [];
  CollectionReference collectionReferenceStudent = db.collection('students');

  QuerySnapshot queryStudents = await collectionReferenceStudent.get();

  queryStudents.docs.forEach((documento) {
    students.add({
      "id": documento.id, // Agregar el ID del documento
      ...documento.data() as Map<String, dynamic>, // Convertir los datos
    });
  });

  return students;
}
