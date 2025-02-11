import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

Future<Map<String, dynamic>> signUpUser(
    String email, String password, String role) async {
  try {
    final response = await supabase.auth.signUp(
      email: email,
      password: password,
    );

    if (response.user != null) {
      final userId = response.user!.id;

      // Determinar en qué tabla guardar el usuario
      String table;
      switch (role) {
        case 'student':
          table = 'students';
          break;
        case 'teacher':
          table = 'teachers';
          break;
        case 'advisor':
          table = 'advisors';
          break;
        case 'graduate':
          table = 'graduates';
          break;
        case 'parent':
          table = 'parents';
          break;
        default:
          table = 'users';
      }

      // Insertar el usuario en la tabla correspondiente
      await supabase.from(table).insert({
        'user_id': userId, // Relacionar con auth.users
        'email': email,
        'created_at': DateTime.now().toIso8601String(),
      });

      return {'success': true, 'message': 'Usuario registrado correctamente'};
    } else {
      return {'success': false, 'message': 'No se pudo registrar el usuario'};
    }
  } catch (e) {
    return {'success': false, 'message': 'Error: ${e.toString()}'};
  }
}
