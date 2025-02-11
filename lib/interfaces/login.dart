import 'package:flutter/material.dart';
import 'package:refmp/connections/login.dart';
import 'package:refmp/interfaces/home.dart';
import 'package:refmp/interfaces/register.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool rememberMe = false;

  Future<void> loginUser() async {
    setState(() {
      isLoading = true;
    });

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos')),
      );
      setState(() {
        isLoading = false;
      });
      return;
    }

    final result = await LoginConnections.login(email, password);

    setState(() {
      isLoading = false;
    });

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'])),
      );

      String role = result['role'] ?? 'Usuario';

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(title: 'Inicio - $role'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'])),
      );
      passwordController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Iniciar Sesión',
          style: TextStyle(
              fontSize: 22, color: Colors.blue, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(17.0),
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
                  borderSide: BorderSide(color: Colors.blue),
                ),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Checkbox(
                  value: rememberMe,
                  hoverColor: Colors.blue,
                  activeColor: Colors.blue,
                  onChanged: (value) {
                    setState(() {
                      rememberMe = value!;
                    });
                  },
                ),
                const Text(
                  'Recuérdame',
                  style: TextStyle(color: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 10),
            isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                    color: Colors.blue,
                  ))
                : ElevatedButton.icon(
                    onPressed: loginUser,
                    icon: const Icon(Icons.login, color: Colors.white),
                    label: const Text(
                      'Iniciar Sesión',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterPage()),
                );
              },
              child: const Text(
                'Registrarse',
                style: TextStyle(fontSize: 16, color: Colors.blue),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                // Lógica para olvidar la contraseña
              },
              child: const Text(
                '¿Olvidaste tu contraseña?',
                style: TextStyle(fontSize: 15, color: Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
