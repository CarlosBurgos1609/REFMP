import 'package:supabase_flutter/supabase_flutter.dart';

class LoginConnections {
  static Future<Map<String, dynamic>> login(
      String email, String password, bool rememberMe) async {
    final supabase = Supabase.instance.client;

    try {
      // Intentar autenticar al usuario con Supabase Auth
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        return {
          'success': false,
          'message': 'Usuario o contraseña incorrectos',
        };
      }

      // Listado de las tablas donde se podría encontrar el usuario
      final List<String> tables = [
        'users',
        'students',
        'teachers',
        'advisors',
        'graduates',
        'parents',
      ];

      // Buscar el usuario en las tablas
      for (final table in tables) {
        final data = await supabase
            .from(table)
            .select()
            .eq('email', email)
            .maybeSingle();

        if (data != null) {
          return {
            'success': true,
            'message': 'Inicio de sesión correcto como $table',
            'user': data, // Retorna los datos del usuario
          };
        }
      }

      return {
        'success': false,
        'message': 'Usuario no encontrado en las tablas.',
      };
    } on AuthException catch (e) {
      return {
        'success': false,
        'message': 'Error de autenticación: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error inesperado: ${e.toString()}',
      };
    }
  }
}
