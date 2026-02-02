import 'package:supabase_flutter/supabase_flutter.dart';

class LoginConnections {
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final supabase = Supabase.instance.client;

    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        return {
          'success': false,
          'message': 'Usuario o contraseña incorrectos'
        };
      }

      final userId = response.user!.id;

      // Listado de tablas donde buscar el usuario
      final List<String> tables = [
        'users',
        'students',
        'teachers',
        'advisors',
        'graduates',
        'parents'
      ];

      for (final table in tables) {
        final data = await supabase
            .from(table)
            .select()
            .eq('user_id', userId)
            .maybeSingle();

        if (data != null) {
          final charge = data['charge'] ?? 'Usuario';
          return {
            'success': true,
            'message': 'Inicio de sesión correcto como $charge',
            'role': table,
            'charge': charge,
            'user': data, // Retorna los datos del usuario
          };
        }
      }

      return {
        'success': false,
        'message': 'Usuario autenticado, pero no registrado en ninguna tabla'
      };
    } catch (e) {
      return {'success': false, 'message': 'Usuario o contraseña incorrectos'};
    }
  }
}
