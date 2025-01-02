import 'package:flutter/material.dart';
import 'package:refmp/interfaces/login.dart';

class Init extends StatelessWidget {
  const Init({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 50),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/logofn.png',
                    width: MediaQuery.of(context).size.width * 0.9,
                    height: MediaQuery.of(context).size.width * 0.27,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'La Red de Escuelas de Formación Musical de Pasto es un proyecto que busca fomentar la educación musical en la región mediante la enseñanza de instrumentos y la promoción de la cultura musical local. Está conformada por diversas escuelas y centros de formación que ofrecen a niños, jóvenes y adultos la oportunidad de aprender música de manera estructurada. Su objetivo principal es desarrollar habilidades musicales, promover valores como la disciplina y el trabajo en equipo, y preservar las tradiciones culturales de la región. Además, la red se enfoca en brindar acceso inclusivo a la educación musical, contribuyendo al desarrollo personal y social de los participantes. También organiza actividades como conciertos, talleres y encuentros musicales que fortalecen la vida cultural de la comunidad.',
                textAlign: TextAlign.justify,
                style: const TextStyle(
                  fontSize: 18.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 80, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Ir al Inicio de Sesión',
                  style: TextStyle(fontSize: 20, color: Colors.blue),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
