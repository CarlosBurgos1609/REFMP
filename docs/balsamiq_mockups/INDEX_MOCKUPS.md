# REFMP - Mockups para Balsamiq

## Resumen

Este directorio contiene especificaciones detalladas para crear mockups en Balsamiq de la aplicación REFMP (Red de Escuelas de Formación Musical de Pasto). Los mockups están basados en el análisis del código Flutter existente y siguen las mejores prácticas de diseño de UI/UX.

## Archivos Incluidos

### Mockups Principales:
1. **01_Pantalla_Bienvenida.md** - Pantalla inicial con logo y acceso al login
2. **02_Pantalla_Inicio.md** - Dashboard principal con sedes y juegos
3. **03_Pantalla_Juego_Musica.md** - Interfaz de selección de canciones
4. **04_Pantalla_Torneo.md** - Ranking y competencia entre usuarios
5. **05_Pantalla_Objetos.md** - Colección de objetos del juego
6. **06_Pantalla_Perfil_Juego.md** - Perfil del usuario en el módulo de juegos
7. **07_Detalle_Sede.md** - Información detallada de una sede musical
8. **08_Pantalla_Login.md** - Formulario de inicio de sesión

### Componentes y Elementos:
9. **09_Dialogos_Modales.md** - Modales, diálogos y elementos emergentes
10. **10_Componentes_Comunes.md** - Biblioteca de componentes reutilizables

### Documentación:
11. **GUIA_COMPLETA_BALSAMIQ.md** - Guía paso a paso para crear los mockups
12. **README_Mockups.md** - Información básica del proyecto

## Características de la Aplicación

### Módulo Principal:
- **Navegación por tabs**: Inicio, Eventos, Instrumentos, Sedes, Perfil
- **Gestión de sedes musicales**: Visualización de ubicaciones y contacto
- **Catálogo de instrumentos**: Acceso a juegos educativos

### Módulo de Juegos:
- **Aprendizaje musical**: Lecciones interactivas por instrumento
- **Biblioteca de canciones**: Organizada alfabéticamente con filtros
- **Sistema de torneos**: Rankings y competencia entre usuarios
- **Colección de objetos**: Sistema de recompensas y personalización
- **Economía virtual**: Sistema de monedas para comprar objetos

### Funcionalidades Clave:
- **Autenticación**: Login con email/password y redes sociales
- **Personalización**: Avatares, fondos de pantalla y temas
- **Progreso gamificado**: Niveles, logros y estadísticas
- **Modo offline**: Sincronización de datos cuando hay conexión

## Paleta de Colores

- **Azul Principal**: #2196F3 - Color corporativo y elementos principales
- **Verde**: #4CAF50 - Estados de éxito y elementos completados
- **Rojo**: #F44336 - Errores y acciones destructivas
- **Naranja**: #FF9800 - Advertencias y elementos intermedios
- **Púrpura**: #9C27B0 - Elementos premium y especiales
- **Grises**: #F5F5F5, #9E9E9E, #666666 - Backgrounds y texto secundario

## Tipografía

- **Títulos principales**: 24-26px, Bold
- **Subtítulos**: 18-20px, Bold
- **Texto normal**: 14-16px, Regular
- **Texto pequeño**: 10-12px, Regular

## Iconografía

Basada en Material Design Icons:
- home, music_note, emoji_events, star, person
- phone, location_on, calendar_today, school
- play_circle, check_circle, error, info, warning

## Flujos de Usuario

### Flujo Principal:
```
Bienvenida → Login → Inicio → [Sedes|Instrumentos|Perfil]
```

### Flujo de Juegos:
```
Inicio → Seleccionar Instrumento → [Música|Torneo|Objetos|Perfil]
```

### Flujo de Objetos:
```
Objetos → Seleccionar Categoría → Ver Item → [Comprar|Equipar]
```

## Instrucciones de Implementación

1. **Configurar Balsamiq** con el template móvil (375x812)
2. **Importar la paleta de colores** definida
3. **Crear símbolos reutilizables** para navegación y cards
4. **Seguir el orden** sugerido en la guía completa
5. **Implementar links** entre pantallas para prototipo interactivo
6. **Exportar en múltiples formatos** (PDF, PNG, BMML)

## Consideraciones Técnicas

- **Responsive design**: Adaptable a diferentes tamaños de pantalla
- **Estados de loading**: Skeletons y indicadores de progreso
- **Estados de error**: Manejo de errores de red y validación
- **Accesibilidad**: Contrastes y tamaños de texto apropiados
- **Animaciones**: Transiciones suaves entre estados

## Próximos Pasos

1. Crear los mockups en Balsamiq siguiendo las especificaciones
2. Conectar las pantallas para crear un prototipo interactivo
3. Validar el flujo de usuario con stakeholders
4. Iterar basado en feedback recibido
5. Generar documentación final para desarrollo

## Contacto y Soporte

Para dudas sobre la implementación de estos mockups o modificaciones específicas, consultar con el equipo de desarrollo de REFMP.

---

*Estos mockups están basados en el análisis del código fuente de la aplicación Flutter REFMP y reflejan la funcionalidad actual y planificada del sistema.*