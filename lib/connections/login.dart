import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:shared_preferences/shared_preferences.dart';

class LoginConnections {
  static Future<Map<String, dynamic>> login(
      String email, String password, bool rememberMe) async {
    final List<String> collections = [
      'users',
      'students',
      'teachers',
      'secretary'
    ];

    try {
      for (final collection in collections) {
        final QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection(collection)
            .where('email', isEqualTo: email)
            .where('password', isEqualTo: password)
            .get();

        if (snapshot.docs.isNotEmpty) {
          // Guardar credenciales si se seleccionó "Recuérdame"
          // if (rememberMe) {
          //   // final prefs = await SharedPreferences.getInstance();
          //   await prefs.setString('email', email);
          //   await prefs.setString('password', password);
          // }

          return {
            'success': true,
            'message': 'Inicio de sesión correcto como $collection',
          };
        }
      }

      return {
        'success': false,
        'message': 'Usuario o contraseña incorrectos',
      };
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return {
          'success': false,
          'message': 'Usuario o contraseña incorrectos',
        };
      }
      return {
        'success': false,
        'message': 'Error: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error inesperado: ${e.toString()}',
      };
    }
  }
}
