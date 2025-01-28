import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class FirebaseServices {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Iniciar sesión de usuario
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print("Error en login: $e");
      return null;
    }
  }

  // Obtener estudiantes
  Future<List<Map<String, dynamic>>> getStudents() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('students').get();
      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print("Error al obtener estudiantes: $e");
      return [];
    }
  }

  // Obtener perfil del usuario autenticado
  Future<Map<String, dynamic>> getUserProfile(String uid) async {
    try {
      DocumentSnapshot snapshot =
          await _firestore.collection('users').doc(uid).get();
      return snapshot.data() as Map<String, dynamic>;
    } catch (e) {
      print("Error al obtener perfil: $e");
      return {};
    }
  }

  // Subir una imagen a Firebase Storage
  Future<String> uploadImage(XFile image) async {
    try {
      File file = File(image.path);
      String fileName =
          'profile_images/${DateTime.now().millisecondsSinceEpoch}.jpg';
      UploadTask uploadTask = _storage.ref(fileName).putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String imageUrl = await snapshot.ref.getDownloadURL();
      return imageUrl;
    } catch (e) {
      print("Error al subir imagen: $e");
      return "";
    }
  }
}
