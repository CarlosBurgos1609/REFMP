import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  final String userTable;

  const EditProfilePage({
    super.key,
    required this.userProfile,
    required this.userTable,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final supabase = Supabase.instance.client;

  // late TextEditingController firstNameController;
  // late TextEditingController lastNameController;
  // late TextEditingController emailController;
  // // late TextEditingController identificationController;
  // late TextEditingController chargeController;

  // Contraseña
  final TextEditingController currentPasswordController =
      TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool showPasswordFields = false;

  @override
  void initState() {
    super.initState();
    // firstNameController =
    //     TextEditingController(text: widget.userProfile['first_name']);
    // lastNameController =
    //     TextEditingController(text: widget.userProfile['last_name']);
    // emailController = TextEditingController(text: widget.userProfile['email']);
    // identificationController = TextEditingController(
    //     text: widget.userProfile['identification_number']);
    // chargeController =
    //     TextEditingController(text: widget.userProfile['charge']);
  }

  Future<void> _updateProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Validar contraseña si el usuario desea cambiarla
    if (showPasswordFields) {
      if (newPasswordController.text != confirmPasswordController.text) {
        _showMessage('Las contraseñas no coinciden');
        return;
      }

      try {
        await supabase.auth.signInWithPassword(
          // email: emailController.text.trim(),
          password: currentPasswordController.text.trim(),
        );

        await supabase.auth.updateUser(
          UserAttributes(password: newPasswordController.text.trim()),
        );
      } catch (e) {
        _showMessage('Contraseña actual incorrecta');
        return;
      }
    }

    // Actualizar perfil en la tabla
    await supabase.from(widget.userTable).update({
      // 'first_name': firstNameController.text.trim(),
      // 'last_name': lastNameController.text.trim(),
      // 'email': emailController.text.trim(),
      // 'identification_number': identificationController.text.trim(),
      // 'charge': chargeController.text.trim(),
    }).eq('user_id', user.id);

    _showMessage('Perfil actualizado');
    Navigator.pop(context);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildField(String label, TextEditingController controller,
      {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.blue),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.blue),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.blue),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        style: const TextStyle(color: Colors.blue), // Texto en azul
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Editar Perfil', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: _updateProfile,
            tooltip: 'Guardar cambios',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // _buildField('Nombres', firstNameController),
            // _buildField('Apellidos', lastNameController),
            // _buildField('Correo', emailController),
            // _buildField('Identificación', identificationController),
            // _buildField('Cargo', chargeController),
            const SizedBox(height: 20),
            Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                  "Si quiere cambiar la información del perfil comuníquese con la sede principal"),
            ),
            const SizedBox(height: 10),
            ListTile(
              title: const Text('¿Deseas cambiar la contraseña?',
                  style: TextStyle(color: Colors.blue)),
              trailing: Switch(
                value: showPasswordFields,
                onChanged: (value) {
                  setState(() {
                    showPasswordFields = value;
                  });
                },
                activeColor: Colors.blue,
                inactiveThumbColor: Colors.blue,
              ),
            ),
            if (showPasswordFields) ...[
              _buildField('Contraseña actual', currentPasswordController,
                  obscure: true),
              _buildField('Nueva contraseña', newPasswordController,
                  obscure: true),
              _buildField(
                  'Confirmar nueva contraseña', confirmPasswordController,
                  obscure: true),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
