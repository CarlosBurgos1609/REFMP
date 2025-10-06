# Guía Completa para Crear Mockups REFMP en Balsamiq

## Resumen del Proyecto

REFMP (Red de Escuelas de Formación Musical de Pasto) es una aplicación móvil Flutter que conecta estudiantes con escuelas de música, ofrece juegos educativos de instrumentos y permite el aprendizaje musical interactivo.

## Estructura de la Aplicación

### Flujo Principal:
1. **Pantalla de Bienvenida** → Login → Inicio
2. **Navegación Principal**: Inicio, Eventos, Instrumentos, Sedes, Perfil
3. **Módulo de Juegos**: Aprender, Música, Torneo, Objetos, Perfil del Juego

## Instrucciones para Balsamiq

### 1. Configuración Inicial

#### Crear Nuevo Proyecto:
- Nombre: "REFMP - Red de Escuelas Musicales"
- Tipo: Mobile App
- Dispositivo: iPhone (375x812)

#### Configurar Assets:
1. **Símbolos Personalizados**:
   - Crear símbolo para Bottom Navigation (reutilizable)
   - Crear símbolo para Cards de Sede
   - Crear símbolo para Cards de Instrumento
   - Crear símbolo para Items de Lista

2. **Paleta de Colores** (Agregar a proyecto):
   ```
   Azul Principal: #2196F3
   Verde Éxito: #4CAF50
   Rojo Error: #F44336
   Naranja Advertencia: #FF9800
   Púrpura: #9C27B0
   Gris Claro: #F5F5F5
   Gris Medio: #9E9E9E
   Gris Oscuro: #666666
   ```

### 2. Orden de Creación de Mockups

#### Fase 1 - Pantallas Básicas:
1. **01_Pantalla_Bienvenida.bmml**
2. **08_Pantalla_Login.bmml**
3. **02_Pantalla_Inicio.bmml**

#### Fase 2 - Navegación y Detalle:
4. **07_Detalle_Sede.bmml**
5. **Menu_Principal.bmml** (crear basado en navegación)

#### Fase 3 - Módulo de Juegos:
6. **03_Pantalla_Juego_Musica.bmml**
7. **04_Pantalla_Torneo.bmml**
8. **05_Pantalla_Objetos.bmml**
9. **06_Pantalla_Perfil_Juego.bmml**

#### Fase 4 - Elementos Interactivos:
10. **09_Dialogos_Modales.bmml**
11. **10_Componentes_Comunes.bmml**

### 3. Consejos para Balsamiq

#### Uso de Componentes:
- **Rectangle**: Para containers y cards
- **Image**: Para placeholders de imágenes (usar texto descriptivo)
- **Button**: Para botones con diferentes estados
- **Icon**: Para iconografía (usar Material Design icons)
- **Text**: Para títulos y párrafos
- **DataGrid**: Para listas estructuradas
- **TabBar**: Para navegación por pestañas
- **Modal**: Para diálogos y overlays

#### Buenas Prácticas:
1. **Naming Convention**:
   - Usa nombres descriptivos: "Card_Sede_Centro", "Btn_Login_Primary"
   - Agrupa elementos relacionados

2. **Layers y Organización**:
   - Background
   - Content
   - Navigation
   - Overlays/Modals

3. **Reutilización**:
   - Crea símbolos para elementos repetidos
   - Usa Masters para layouts comunes
   - Define estilos de texto consistentes

4. **Anotaciones**:
   - Agrega notas para interacciones complejas
   - Documenta estados de componentes
   - Especifica animaciones y transiciones

### 4. Linking (Conexión de Pantallas)

#### Links Principales:
```
Bienvenida → Login → Inicio
Inicio → Detalle Sede (tap en card sede)
Inicio → Juego (tap en card instrumento)
Login → Registro (link)
Cualquier pantalla → Perfil (bottom nav)
```

#### Links del Módulo Juego:
```
Música ↔ Torneo ↔ Objetos ↔ Perfil (bottom nav)
Objetos → Detalle Objeto (tap en item)
Perfil → Configuración (botón settings)
```

### 5. Estados y Variaciones

#### Crear variaciones para:
1. **Estados de Carga**:
   - Skeleton screens
   - Progress indicators
   - Empty states

2. **Estados de Error**:
   - Sin conexión
   - Error de servidor
   - Datos no encontrados

3. **Estados de Interacción**:
   - Botones pressed/disabled
   - Forms con validación
   - Modales abiertos/cerrados

### 6. Responsive Considerations

#### Diferentes Tamaños:
- **iPhone SE (375x667)**: Versión compacta
- **iPhone 12 (390x844)**: Versión estándar
- **Android Large (411x731)**: Versión Android

#### Adaptaciones:
- Ajustar spacing vertical
- Reducir tamaños de imagen si es necesario
- Mantener proporciones de botones y texto

### 7. Exportación y Entrega

#### Formatos de Export:
1. **PDF**: Para presentaciones y documentación
2. **PNG**: Para assets individuales
3. **BMML**: Para compartir archivos editables

#### Organización de Entrega:
```
/REFMP_Mockups/
  /01_Screens/
    - 01_Bienvenida.png
    - 02_Inicio.png
    - ...
  /02_Components/
    - Navigation_Bar.png
    - Cards_Collection.png
    - ...
  /03_Flows/
    - User_Registration_Flow.png
    - Game_Navigation_Flow.png
    - ...
  /04_Specs/
    - Design_System.pdf
    - Component_Library.pdf
```

## Templates de Componentes para Balsamiq

### Bottom Navigation Template:
```
Container: 375x50, #FFFFFF
Items: 5 x (Icon + Label)
Spacing: 75px entre centros
Active Color: #2196F3
Inactive Color: #9E9E9E
```

### Card Template:
```
Container: Ancho variable x Alto variable
Background: #FFFFFF
Border Radius: 12px
Shadow: 0 2px 8px rgba(0,0,0,0.1)
Padding: 16px
```

### Button Template:
```
Primary: #2196F3 background, #FFFFFF text
Secondary: Transparent background, #2196F3 border and text
Height: 40px (small), 50px (medium), 60px (large)
Border Radius: 12px
```

## Entregables Finales

1. **Archivo .bmpr** completo con todos los mockups
2. **PDF de presentación** con flujos principales
3. **Style Guide** con colores, tipografías y componentes
4. **Asset library** con componentes reutilizables
5. **Documentación de interacciones** y estados

¡Con esta guía tendrás todo lo necesario para crear mockups profesionales de REFMP en Balsamiq!