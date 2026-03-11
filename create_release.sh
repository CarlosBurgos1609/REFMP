#!/bin/bash

# ========================================
# Script para crear nueva versión y release
# ========================================
# 
# Este script automatiza:
# 1. Compilación de APK de release
# 2. Cálculo de hash SHA-256
# 3. Preparación de comando SQL para Supabase
# 
# Uso: ./create_release.sh 1.0.1 2
#   Arg 1: Versión (ejemplo: 1.0.1)
#   Arg 2: Build number (ejemplo: 2)

set -e  # Salir si hay errores

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Verificar argumentos
if [ "$#" -ne 2 ]; then
    echo -e "${RED}❌ Error: Se requieren 2 argumentos${NC}"
    echo "Uso: $0 <version> <build_number>"
    echo "Ejemplo: $0 1.0.1 2"
    exit 1
fi

VERSION=$1
BUILD_NUMBER=$2

echo -e "${BLUE}🚀 Iniciando proceso de release...${NC}"
echo -e "   Versión: ${GREEN}${VERSION}${NC}"
echo -e "   Build: ${GREEN}${BUILD_NUMBER}${NC}"
echo ""

# Verificar que estamos en el directorio raíz del proyecto
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}❌ Error: Ejecuta este script desde la raíz del proyecto${NC}"
    exit 1
fi

# Paso 1: Actualizar pubspec.yaml
echo -e "${YELLOW}📝 Paso 1: Actualizando pubspec.yaml...${NC}"
sed -i.bak "s/^version: .*/version: ${VERSION}+${BUILD_NUMBER}/" pubspec.yaml
echo -e "${GREEN}✅ pubspec.yaml actualizado${NC}"
echo ""

# Paso 2: Limpiar build anterior
echo -e "${YELLOW}🧹 Paso 2: Limpiando build anterior...${NC}"
flutter clean
echo -e "${GREEN}✅ Limpieza completada${NC}"
echo ""

# Paso 3: Obtener dependencias
echo -e "${YELLOW}📦 Paso 3: Obteniendo dependencias...${NC}"
flutter pub get
echo -e "${GREEN}✅ Dependencias actualizadas${NC}"
echo ""

# Paso 4: Compilar APK de release
echo -e "${YELLOW}🔨 Paso 4: Compilando APK de release...${NC}"
echo -e "   ${BLUE}Esto puede tomar varios minutos...${NC}"
flutter build apk --release
echo -e "${GREEN}✅ APK compilado exitosamente${NC}"
echo ""

# Verificar que el APK existe
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "$APK_PATH" ]; then
    echo -e "${RED}❌ Error: No se encontró el APK en $APK_PATH${NC}"
    exit 1
fi

# Obtener tamaño del APK
APK_SIZE=$(ls -lh "$APK_PATH" | awk '{print $5}')
echo -e "${GREEN}📦 Tamaño del APK: ${APK_SIZE}${NC}"

# Paso 5: Calcular hash SHA-256
echo -e "${YELLOW}🔐 Paso 5: Calculando hash SHA-256...${NC}"
if command -v sha256sum &> /dev/null; then
    APK_HASH=$(sha256sum "$APK_PATH" | awk '{print $1}')
elif command -v shasum &> /dev/null; then
    APK_HASH=$(shasum -a 256 "$APK_PATH" | awk '{print $1}')
else
    echo -e "${YELLOW}⚠️  Herramienta de hash no encontrada, omitiendo...${NC}"
    APK_HASH="CALCULAR_MANUALMENTE"
fi
echo -e "${GREEN}✅ Hash: ${APK_HASH:0:16}...${NC}"
echo ""

# Paso 6: Copiar APK a carpeta releases
echo -e "${YELLOW}📁 Paso 6: Organizando archivos...${NC}"
RELEASE_DIR="releases/v${VERSION}"
mkdir -p "$RELEASE_DIR"
cp "$APK_PATH" "$RELEASE_DIR/refmp-v${VERSION}.apk"
echo -e "${GREEN}✅ APK copiado a: ${RELEASE_DIR}${NC}"
echo ""

# Paso 7: Generar instrucciones
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}✅ ¡Release preparado exitosamente!${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${YELLOW}📋 SIGUIENTE PASOS:${NC}"
echo ""
echo -e "${BLUE}1. Subir a GitHub:${NC}"
echo "   - Ve a: https://github.com/TU_USUARIO/TU_REPO/releases/new"
echo "   - Tag: v${VERSION}"
echo "   - Título: Versión ${VERSION}"
echo "   - Arrastra el APK desde: ${RELEASE_DIR}/refmp-v${VERSION}.apk"
echo "   - Click 'Publish release'"
echo ""
echo -e "${BLUE}2. Obtener URL del APK:${NC}"
echo "   - Después de publicar, click derecho en el APK y 'Copiar enlace'"
echo "   - La URL será algo como:"
echo "     https://github.com/TU_USUARIO/TU_REPO/releases/download/v${VERSION}/refmp-v${VERSION}.apk"
echo ""
echo -e "${BLUE}3. Registrar en Supabase:${NC}"
echo ""
echo -e "${GREEN}-- Copia y ejecuta este SQL en Supabase:${NC}"
echo ""
echo "INSERT INTO app_version (version, build_number, required, release_notes, android_url, apk_sha256)"
echo "VALUES ("
echo "    '${VERSION}',"
echo "    ${BUILD_NUMBER},"
echo "    false, -- Cambiar a true si es actualización obligatoria"
echo "    '- Corrección de errores"
echo "- Mejoras de rendimiento"
echo "- [Agregar más cambios aquí]',"
echo "    'https://github.com/TU_USUARIO/TU_REPO/releases/download/v${VERSION}/refmp-v${VERSION}.apk',"
echo "    '${APK_HASH}'"
echo ");"
echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}🎉 ¡Listo para publicar!${NC}"
echo -e "${BLUE}================================================${NC}"
