#!/bin/bash

# ========================================
# Script de instalación rápida
# Sistema de Actualizaciones Automáticas
# ========================================

echo "🔄 Instalando dependencias para actualizaciones automáticas..."
echo ""

# Instalar dependencias
echo "📦 Instalando paquetes..."
flutter pub add dio
flutter pub add install_plugin
flutter pub add device_info_plus

echo ""
echo "✅ Dependencias instaladas"
echo ""
echo "📋 SIGUIENTE PASOS:"
echo ""
echo "1. Configurar AndroidManifest.xml"
echo "   Copia el contenido de: android/app/ANDROID_MANIFEST_REFERENCE.xml"
echo ""
echo "2. Verificar file_paths.xml"
echo "   Ya está en: android/app/src/main/res/xml/file_paths.xml"
echo ""
echo "3. Ejecutar script SQL en Supabase"
echo "   Archivo: sql_triggers/app_version_table.sql"
echo ""
echo "4. Leer documentación completa"
echo "   Archivo: SISTEMA_ACTUALIZACIONES_APK.md"
echo ""
echo "🎉 ¡Listo! Ahora configura los permisos en Android."
