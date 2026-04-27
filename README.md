# REFMP: Red de Escuelas De Formación Musical de Pasto

<div align='center'>
  
![Logo](https://github.com/user-attachments/assets/3ba2280f-5c3f-45a5-b484-b3147b1403c1)

</div>

---
# Desacargar la última versión del software

>[!NOTE]
> Para instalar la aplicación es necesario permitir la instalación desde fuentes desconocidas en tu navegador o dispositivo Android. Cuando descargues el archivo APK, activa esta opción si el sistema te lo solicita y luego procede con la instalación de la última versión disponible de la aplicación.

<div align='center'>
  
[![Descargar la versión v1.1.2](https://img.shields.io/badge/Descargar%20v1.1.2-REFMP-blue?style=for-the-badge&logo=android)](https://github.com/CarlosBurgos1609/REFMP/releases/download/v.1.1.2/REFMP.apk)

[![GitHub](https://img.shields.io/badge/GitHub-Repositorio-black?style=for-the-badge&logo=github)](https://github.com/CarlosBurgos1609/REFMP)

</div>

# 📄 Documentación

> [!NOTE]
> En esta sección se presentan los documentos principales relacionados con el desarrollo, uso e implementación de la aplicación REFMP. Estos documentos permiten comprender el funcionamiento del sistema, su instalación, uso y especificaciones técnicas.

---

## 📘 Documento de Tesis (Versión Final)
Contiene el desarrollo completo del proyecto, incluyendo marco teórico, metodología, resultados, análisis y conclusiones.

🔗 [Ver documento completo](https://drive.google.com/file/d/1kr1dqOE1LWizwm3MHlzBVaVXLlA94VYQ/view?usp=sharing)

---

## ⚙️ Manual de Instalación
Describe el proceso paso a paso para la instalación y configuración de la aplicación, incluyendo requisitos del sistema y dependencias necesarias.

🔗 [Ver manual de instalación](https://drive.google.com/file/d/1TdnLnLOWSEJKTimSg9Jz9JoDyMb2XdF-/view?usp=sharing)

---

## 👤 Manual de Usuario
Explica el uso de la aplicación desde la perspectiva del usuario final, incluyendo funcionalidades, navegación y operación del sistema.

🔗 [Ver manual de usuario](https://drive.google.com/file/d/19Yk61QG5RpAfwgks3nmU8uzbl6GItFP-/view?usp=sharing)

---

## 🗂️ Ficha Técnica / Catalogación
Presenta la información general del software, incluyendo características, propósito, entorno de uso y datos técnicos relevantes.

🔗 [Ver ficha técnica](https://drive.google.com/file/d/101PT0-ZC95uHJty_47uInVdTFgtKM5lB/view?usp=sharing)

---

## 🧾 Documento Técnico de Requisitos
Define los requisitos funcionales y no funcionales del sistema, así como las especificaciones necesarias para su desarrollo e implementación.

🔗 [Ver documento de requisitos](https://drive.google.com/file/d/1kATqxUqGPAwn-oEnoDtPB88Bu5m8iktg/view?usp=sharing)

---

## Getting Started

This project is a starting point for a Flutter application.



A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

>[!IMPORTANT]
>
>```sql
>DO $$
>DECLARE
>  r RECORD;
>BEGIN
>  FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename NOT IN ('storage.objects', 'auth.users')  -- >Excluye tablas de sistema si es necesario
>  LOOP
>    PERFORM setup_rls_policies_for_table(r.tablename);
>  END LOOP;
>END $$;
>
>```
