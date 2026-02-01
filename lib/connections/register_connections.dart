import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

Future<Map<String, dynamic>> signUpGuestUser({
  required String firstName,
  required String lastName,
  required String email,
  required String password,
  String? identificationNumber,
}) async {
  try {
    // Clean and normalize email (lowercase, trim, remove all whitespace)
    final normalizedEmail =
        email.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

    // Validate email format before sending to Supabase
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(normalizedEmail)) {
      return {
        'success': false,
        'message': 'El formato del correo electrónico no es válido'
      };
    }

    // Validate password length
    if (password.length < 8) {
      return {
        'success': false,
        'message': 'La contraseña debe tener al menos 8 caracteres'
      };
    }

    // Create user in auth.users with email confirmation disabled
    final response = await supabase.auth.signUp(
      email: normalizedEmail,
      password: password,
      emailRedirectTo: null,
    );

    if (response.user != null) {
      final userId = response.user!.id;

      // Insert into guests table with all required fields
      await supabase.from('guests').insert({
        'first_name': firstName,
        'last_name': lastName,
        'email': normalizedEmail,
        'password': password, // Store same password as auth
        'identification_number': identificationNumber,
        'profile_image': null, // No profile image for guests
        'charge': 'Invitado', // Default role for guests
        'user_id': userId, // Link to auth.users
        'created_at': DateTime.now().toIso8601String(),
      });

      // Pequeño delay para que el trigger de base de datos confirme el email
      await Future.delayed(const Duration(milliseconds: 500));

      // Iniciar sesión automáticamente después del registro
      // Esto es crítico para que el usuario esté autenticado
      final signInResponse = await supabase.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );

      if (signInResponse.user == null) {
        return {
          'success': false,
          'message':
              'Usuario registrado pero no se pudo iniciar sesión automáticamente. Por favor, inicia sesión manualmente.'
        };
      }

      // Verificar que el usuario tenga email confirmado
      if (signInResponse.session != null) {
        return {
          'success': true,
          'message':
              'Usuario invitado registrado e iniciado sesión correctamente',
          'user': signInResponse.user
        };
      } else {
        return {
          'success': false,
          'message':
              'Usuario registrado pero la sesión no se pudo establecer. Por favor contacta al administrador.'
        };
      }
    } else {
      return {'success': false, 'message': 'No se pudo registrar el usuario'};
    }
  } on AuthException catch (e) {
    // Manejar errores específicos de autenticación
    if (e.message.contains('invalid')) {
      return {
        'success': false,
        'message': 'El correo electrónico o la contraseña no son válidos'
      };
    } else if (e.message.contains('already')) {
      return {
        'success': false,
        'message': 'Este correo electrónico ya está registrado'
      };
    }
    return {
      'success': false,
      'message': 'Error de autenticación: ${e.message}'
    };
  } catch (e) {
    return {'success': false, 'message': 'Error al registrar: ${e.toString()}'};
  }
}

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
