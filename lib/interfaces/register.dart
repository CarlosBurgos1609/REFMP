// import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
import 'package:refmp/interfaces/home.dart';
import 'package:refmp/connections/register_connections.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController lastsController = TextEditingController();
  final TextEditingController identificationController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _validateFields() {
    // Validar campos requeridos (excepto identification que es opcional)
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingrese sus nombres')),
      );
      return false;
    }

    if (lastsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingrese sus apellidos')),
      );
      return false;
    }

    if (emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor ingrese su correo electrónico')),
      );
      return false;
    }

    // Validar que el correo tenga un arroba
    if (!emailController.text.trim().contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('El correo electrónico debe contener un arroba (@)')),
      );
      return false;
    }

    // Validar formato de email más robusto
    final email = emailController.text.trim().toLowerCase();
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Por favor ingrese un correo electrónico válido (ejemplo: usuario@dominio.com)')),
      );
      return false;
    }

    // Validar que el dominio tenga al menos 2 caracteres
    final parts = email.split('@');
    if (parts.length != 2 || parts[0].length < 1 || parts[1].length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('El correo electrónico debe tener un formato válido')),
      );
      return false;
    }

    if (passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingrese una contraseña')),
      );
      return false;
    }

    // Validar contraseña: mínimo 8 caracteres y al menos un carácter especial
    final password = passwordController.text.trim();
    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('La contraseña debe tener al menos 8 caracteres')),
      );
      return false;
    }

    // Verificar que tenga al menos un carácter especial
    final specialCharRegex = RegExp(r'[!@#$%^&*(),.?":{}|<>]');
    if (!specialCharRegex.hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'La contraseña debe contener al menos un carácter especial (!@#\$%^&*(),.?":{}|<>)')),
      );
      return false;
    }

    // Validar que las contraseñas coincidan
    if (passwordController.text.trim() !=
        confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Las contraseñas no coinciden. Por favor verifica e intenta nuevamente.')),
      );
      return false;
    }

    return true;
  }

  Future<void> registerUser() async {
    // Validar campos antes de registrar
    if (!_validateFields()) {
      return;
    }

    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.blue),
      ),
    );

    try {
      // Normalize email before sending
      final normalizedEmail = emailController.text
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '');

      // Register as guest user with all required information
      final result = await signUpGuestUser(
        firstName: nameController.text.trim(),
        lastName: lastsController.text.trim(),
        email: normalizedEmail,
        password: passwordController.text.trim(),
        identificationNumber: identificationController.text.trim().isEmpty
            ? null
            : identificationController.text.trim(),
      );

      // Cerrar indicador de carga
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (result['success']) {
        // Verificar que la sesión esté activa antes de navegar
        if (result['user'] != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'])),
          );

          // Pequeño delay para asegurar que la sesión esté completamente establecida
          await Future.delayed(const Duration(milliseconds: 500));

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => const HomePage(
                        title: 'Inicio',
                      )),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Usuario registrado. Por favor inicia sesión manualmente.')),
          );
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      }
    } catch (e) {
      // Cerrar indicador de carga si aún está abierto
      if (mounted) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al registrar el usuario: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.blue,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Registro',
          style: TextStyle(
            fontSize: 22,
            color: Colors.blue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: Colors.blue,
        onRefresh: () async {
          // Limpiar todos los campos al refrescar
          setState(() {
            nameController.clear();
            lastsController.clear();
            identificationController.clear();
            emailController.clear();
            passwordController.clear();
            confirmPasswordController.clear();
          });
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/refmmp.png',
                    width: MediaQuery.of(context).size.width * 0.5,
                    height: MediaQuery.of(context).size.width * 0.5,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Texto informativo sobre cuenta de invitado
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.grey[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Cuenta de Invitado',
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'La cuenta que se registre como invitado tendrá un período de un mes para ingresar. Una vez transcurrido el mes, la cuenta se borrará automáticamente y tendrás que registrarte nuevamente o solicitar a la Red de Escuelas de Formación Musical de Pasto que te integren para poder iniciar sesión sin límite de tiempo.',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.justify,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                style: const TextStyle(color: Colors.blue),
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nombres',
                  labelStyle: const TextStyle(color: Colors.blue),
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.blue),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue)),
                ),
                keyboardType: TextInputType.name,
              ),
              const SizedBox(height: 20),
              TextField(
                style: const TextStyle(color: Colors.blue),
                controller: lastsController,
                decoration: InputDecoration(
                  labelText: 'Apellidos',
                  labelStyle: const TextStyle(color: Colors.blue),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue)),
                ),
                keyboardType: TextInputType.name,
              ),
              const SizedBox(height: 20),
              TextField(
                style: const TextStyle(color: Colors.blue),
                controller: identificationController,
                decoration: InputDecoration(
                  labelText: 'Número de Identificación (Opcional)',
                  labelStyle: const TextStyle(color: Colors.blue),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue)),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              TextField(
                style: const TextStyle(color: Colors.blue),
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Correo Electrónico',
                  labelStyle: const TextStyle(color: Colors.blue),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue)),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              TextField(
                style: const TextStyle(color: Colors.blue),
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  labelStyle: const TextStyle(color: Colors.blue),
                  helperText:
                      'Mínimo 8 caracteres y al menos un carácter especial (!@#\$%^&*)',
                  helperStyle: TextStyle(color: Colors.grey[600], fontSize: 11),
                  helperMaxLines: 2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.blue,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
              ),
              const SizedBox(height: 20),
              TextField(
                style: const TextStyle(color: Colors.blue),
                controller: confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirmar Contraseña',
                  labelStyle: const TextStyle(color: Colors.blue),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.blue,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscureConfirmPassword,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: registerUser,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Registrarse',
                  style: TextStyle(fontSize: 16, color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
