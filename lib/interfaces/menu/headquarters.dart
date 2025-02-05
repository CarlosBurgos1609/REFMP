import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/routes/menu.dart';

class HeadquartersPage extends StatefulWidget {
  const HeadquartersPage({super.key, required this.title});
  final String title;

  @override
  State<HeadquartersPage> createState() => _HeadquartersPage();
}

class _HeadquartersPage extends State<HeadquartersPage> {
  File? _image;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadImage() async {
    if (_image == null ||
        _nameController.text.isEmpty ||
        _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Todos los campos son obligatorios")),
      );
      return;
    }
    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = _storage.ref().child("headquarters/$fileName.jpg");
      await ref.putFile(_image!);
      String imageUrl = await ref.getDownloadURL();

      await _firestore.collection("headquarters").add({
        "name": _nameController.text,
        "description": _descriptionController.text,
        "photo": imageUrl,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Imagen subida exitosamente")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al subir imagen: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => showExitConfirmationDialog(context),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 22,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.blue,
          leading: Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              );
            },
          ),
        ),
        drawer: Menu.buildDrawer(context),
        body: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Nombre"),
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: "Descripción"),
            ),
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text("Seleccionar Imagen"),
            ),
            _image != null ? Image.file(_image!, height: 100) : Container(),
            ElevatedButton(
              onPressed: _uploadImage,
              child: const Text("Subir Imagen"),
            ),
            Expanded(
              child: StreamBuilder(
                stream: _firestore.collection("headquarters").snapshots(),
                builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text("No hay imágenes disponibles"));
                  }
                  return ListView(
                    children: snapshot.data!.docs.map((doc) {
                      return ListTile(
                        leading: Image.network(doc["photo"],
                            width: 50, height: 50, fit: BoxFit.cover),
                        title: Text(doc["name"]),
                        subtitle: Text(doc["description"]),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
