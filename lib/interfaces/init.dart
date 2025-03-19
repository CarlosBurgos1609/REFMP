import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/interfaces/login.dart';
import 'package:refmp/theme/theme_provider.dart';

class Init extends StatelessWidget {
  const Init({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return WillPopScope(
      onWillPop: () => showExitConfirmationDialog(context),
      child: Scaffold(
        backgroundColor: themeProvider.currentTheme.scaffoldBackgroundColor,
        body: Stack(
          children: [
            Positioned(
              top: -50,
              left: -100,
              child: Container(
                width: MediaQuery.of(context).size.width * 1.8,
                height: MediaQuery.of(context).size.width * 1.2,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 100),
                    Center(
                      child: BounceInDown(
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
                    ),
                    const SizedBox(height: 30),
                    FadeIn(
                      duration: const Duration(milliseconds: 1200),
                      child: Text(
                        'La Red de Escuelas de Formación Musical de Pasto es un proyecto que busca fomentar la educación musical en la región mediante la enseñanza de instrumentos y la promoción de la cultura musical local. Está conformada por diversas escuelas y centros de formación que ofrecen a niños, jóvenes y adultos la oportunidad de aprender música de manera estructurada.',
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          fontSize: 18.5,
                          height: 1.5,
                          color: themeProvider
                                  .currentTheme.textTheme.bodyLarge?.color ??
                              Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    ZoomIn(
                      duration: const Duration(milliseconds: 800),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LoginPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 80, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                        ),
                        label: const Text(
                          'Ir al Inicio de Sesión',
                          style: TextStyle(fontSize: 20, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        icon: const Icon(
                          Icons.person,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
