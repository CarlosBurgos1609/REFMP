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
