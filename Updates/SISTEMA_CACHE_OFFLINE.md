# 📱 Sistema de Caché Offline y Sincronización

## 🎯 Resumen General

He implementado un **sistema completo de caché offline** que permite a tu aplicación funcionar sin conexión a internet. Las imágenes, textos, datos de subniveles, tips, juegos educativos y preguntas se guardan en caché local. Los puntos XP y monedas se almacenan temporalmente y se sincronizan automáticamente cuando hay conexión.

---

## 📦 Nuevos Archivos Creados

### 1. `lib/services/offline_sync_service.dart`
**Servicio centralizado de sincronización offline**

✨ Funcionalidades:
- ✅ Detectar conexión a internet
- 💾 Guardar datos en caché local  
- 📤 Sincronizar puntos XP pendientes
- 💰 Sincronizar monedas pendientes
- ✔️ Sincronizar completaciones de subniveles
- 🔄 Sincronización automática al recuperar conexión

---

## 🔧 Archivos Modificados

### 1. **subnivels.dart**
**Cambios:**
- ✅ Integrado servicio de sincronización
- 💾 Caché completo de subniveles
- 🔄 Sincronización automática al iniciar
- 📱 Completaciones guardadas offline

**Ejemplo de uso:**
```dart
// Se guarda automáticamente offline si no hay internet
await _syncService.savePendingCompletion(
  userId: userId,
  levelId: widget.levelId,
  sublevelId: sublevelId,
  completed: true,
);
```

### 2. **tips_page.dart**
**Cambios:**
- ✅ Caché completo de tips e imágenes
- 💾 Puntos XP guardados offline
- 📱 Muestra tips desde caché sin conexión
- 🔔 Notifica cuando los datos se sincronizarán

**Flujo offline:**
```
Usuario completa tips sin internet
    ↓
Puntos guardados en caché local
    ↓
Usuario recupera conexión
    ↓
Sincronización automática en background
    ↓
Puntos actualizados en Supabase
```

### 3. **educational_game.dart**
**Cambios:**
- ✅ Caché de notas musicales y partituras
- 💾 Puntos XP y monedas guardados offline
- 📊 Estadísticas guardadas en caché
- 🎵 Audio precargado funciona offline

**Datos cacheados:**
- Notas del juego (startTimeMs, durationMs, pistones)
- URLs de partituras e imágenes
- Configuración de puntos XP y monedas
- Estadísticas de rendimiento (accuracy, stars)

### 4. **questions.dart** 
**Cambios:**
- ✅ Caché de preguntas de Quiz y Evaluación
- 💾 Respuestas guardadas offline
- 🎥 URLs de videos cacheadas
- 🔄 Sincronización automática

---

## 🚀 Cómo Funciona el Sistema

### 📥 **Modo Online (con internet)**
1. **Carga datos desde Supabase**
2. **Guarda todo en caché local** (Hive)
3. **Muestra datos al usuario**
4. **Guarda puntos/monedas directamente en Supabase**

### 📴 **Modo Offline (sin internet)**
1. **Carga datos desde caché local**
2. **Usuario puede jugar/estudiar normalmente**
3. **Puntos/monedas se guardan en cola pendiente**
4. **Muestra notificación:** "Se sincronizarán al conectarse"

### 🔄 **Sincronización Automática**
1. **Detecta recuperación de conexión**
2. **Sincroniza automáticamente:**
   - ✅ Puntos XP pendientes
   - 💰 Monedas pendientes
   - ✔️ Completaciones de subniveles
3. **Registra todo en historial XP**
4. **Limpia cola de pendientes**

---

## 💾 Datos que se Cachean

### **Subniveles:**
```json
{
  "id": "sublevel_123",
  "title": "Aprende las notas",
  "description": "Descripción del subnivel",
  "type": "Game",
  "order_number": 1,
  "image_url": "https://..."
}
```

### **Tips:**
```json
{
  "id": "tip_456",
  "sublevel_id": "sublevel_123",
  "title": "Tip 1",
  "description": "Contenido del tip",
  "img_url": "https://...",
  "experience_points": 50,
  "tip_order": 1
}
```

### **Notas del Juego Educativo:**
```json
{
  "id": 1,
  "chromatic_scale_note_id": 10,
  "start_time_ms": 3000,
  "duration_ms": 800,
  "order_index": 1
}
```

### **Preguntas de Quiz:**
```json
{
  "question": "¿Cuál es la nota Do?",
  "option_a": "C",
  "option_b": "D",
  "option_c": "E",
  "option_d": "F",
  "correct_answer": "C",
  "experience_points": 10
}
```

---

## 🖼️ Caché de Imágenes

Las imágenes se cachean automáticamente usando `CachedNetworkImage` que ya está implementado en tu proyecto. Las URLs se guardan en el caché y las imágenes se descargan progresivamente.

**Imágenes cacheadas:**
- 🎼 Partituras de juegos educativos
- 💡 Imágenes de tips
- 🎮 Íconos de subniveles
- 📸 Imágenes de perfil
- 🎨 Recursos visuales

**Ventajas:**
- ✅ Carga rápida en visitas posteriores
- 📴 Disponibles offline después de primera carga
- 💾 Ahorro de datos móviles
- 🔄 Actualización automática si cambian

---

## 📊 Seguimiento de Datos Pendientes

### Ver cuántos datos hay pendientes de sincronización:
```dart
final counts = _syncService.getPendingCounts();

print('XP pendientes: ${counts['xp']}');
print('Monedas pendientes: ${counts['coins']}');
print('Completaciones pendientes: ${counts['completions']}');
print('Total pendiente: ${counts['total']}');
```

### Forzar sincronización manual:
```dart
// En cualquier parte de la app
final success = await OfflineSyncService().syncAllPendingData();

if (success) {
  print('✅ Sincronización exitosa');
} else {
  print('⚠️ Algunos datos no se pudieron sincronizar');
}
```

---

## 🗄️ Estructura de Caché (Hive)

### **Box único centralizado:**

**`offline_data`** - Box único para todos los datos de caché (ya abierto en main.dart)

Contiene todas las claves de caché organizadas por tipo:
- `tips_{sublevelId}` - Tips de cada subnivel
- `questions_{sublevelId}_{sublevelType}` - Preguntas de Quiz/Evaluación
- `educational_sublevel_{sublevelId}_notes` - Notas del juego educativo
- `sublevels_{levelId}` - Subniveles de cada nivel
- `completion_status_{userId}_{levelId}` - Estado de completación

### **Boxes del servicio de sincronización:**

1. **`pending_xp`** - Puntos XP pendientes de sincronizar
2. **`pending_coins`** - Monedas pendientes
3. **`pending_completions`** - Completaciones pendientes

### **Ejemplo de datos en offline_data:**
```dart
// En el box offline_data:
{
  'tips_sublevel_123': [
    {
      'id': 'tip_456',
      'title': 'Tip 1',
      'description': 'Contenido...',
      'experience_points': 50
    }
  ],
  'questions_sublevel_456_quiz': [
    {
      'question': '¿Cuál es...?',
      'option_a': 'A',
      'correct_answer': 'A'
    }
  ]
}
```

---

## ⚙️ Configuración y Uso

### **Inicialización automática en main.dart**

El box `offline_data` se abre una sola vez en `main.dart`:

```dart
// En main.dart
await Hive.initFlutter();
final offlineBox = await Hive.openBox('offline_data');
```

### **Uso en los componentes del juego**

Todos los componentes acceden al box ya abierto de forma sincrónica:

```dart
// En cualquier página (tips_page.dart, questions.dart, etc.)
final box = Hive.box('offline_data');
final cacheKey = 'tips_${sublevelId}';

// Guardar datos
await box.put(cacheKey, data);

// Cargar datos
final cachedData = box.get(cacheKey, defaultValue: []);
```

### **Patrón de implementación**

El sistema sigue el mismo patrón que `learning.dart`:

1. **Acceso directo al box** - `Hive.box('offline_data')` (sin await)
2. **Claves específicas** - Cada tipo de dato usa su propia clave
3. **Sincronización de XP/monedas** - A través de `OfflineSyncService`
4. **Sin delay de carga** - Datos disponibles inmediatamente

### **Notificaciones al usuario:**
```dart
// Cuando se guardan datos offline:
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Puntos guardados. Se sincronizarán al conectarse'),
    backgroundColor: Colors.orange,
  ),
);
```

---

## 🔍 Debug y Monitoreo

### **Logs del sistema:**
```
🌐 Cargando tips ONLINE
💾 Tips guardados en caché: 5
⭐ Puntos XP totales: 50
✅ Tips cargados: 5

// Si no hay internet:
📱 Sin conexión, cargando desde caché
💾 Tips cargados desde caché: 5
💾 Puntos guardados para sincronizar cuando haya conexión

// Al recuperar conexión:
🔄 Iniciando sincronización de datos pendientes...
✅ XP sincronizado: 50 puntos
✅ Monedas sincronizadas: 5
✅ Completación sincronizada: tip_456
✅ Sincronización completada exitosamente
```

---

## 🛠️ Mantenimiento y Limpieza

### **Limpiar caché manualmente** (usar con precaución):
```dart
// Limpiar SOLO datos pendientes
await OfflineSyncService().clearAllPending();

// Limpiar caché completo de tips
final box = await Hive.openBox('tips_cache');
await box.clear();
```

### **Verificar tamaño del caché:**
```dart
final box = await Hive.openBox('offline_cache');
print('Elementos en caché: ${box.length}');
```

---

## 📝 Próximos Pasos para el Usuario

### 1. **Probar sin conexión:**
   - ✅ Desactiva WiFi y datos móviles
   - ✅ Navega por subniveles (debe cargar desde caché)
   - ✅ Completa un tip o juego
   - ✅ Verifica que muestre mensaje de sincronización pendiente

### 2. **Probar sincronización:**
   - ✅ Reactiva la conexión a internet
   - ✅ Abre cualquier sección con sincronización
   - ✅ Verifica en consola los logs de sincronización
   - ✅ Comprueba en Supabase que los puntos se guardaron

### 3. **Monitorear logs:**
   - ✅ Abre el debug console
   - ✅ Busca emojis: 🌐 📱 💾 ✅ ❌ 🔄
   - ✅ Verifica que no haya errores ❌

---

## ⚠️ Consideraciones Importantes

### **Limitaciones:**
- ⚠️ Los videos NO se cachean completamente (solo URLs)
- ⚠️ El audio de los juegos debe cargarse al menos una vez online
- ⚠️ Las imágenes grandes pueden tardar en cachear

### **Tamaño del caché:**
- 📊 Hive es muy eficiente (~KB por subnivel)
- 🖼️ Las imágenes ocupan más espacio (~MB)
- 🧹 No hay límite automático de tamaño

### **Sincronización:**
- 🔄 Se intenta cada vez que hay conexión
- ⏱️ Si falla, se reintenta después
- 📝 Los datos pendientes persisten hasta sincronizarse

---

## 🎉 Beneficios del Sistema

### **Para los Usuarios:**
- ✅ Pueden estudiar sin internet
- ✅ No pierden progreso si se cae la conexión
- ✅ Carga más rápida con caché
- ✅ Ahorro de datos móviles

### **Para el Desarrollo:**
- ✅ Sistema centralizado fácil de mantener
- ✅ Logs detallados para debugging
- ✅ Sincronización automática
- ✅ Manejo robusto de errores

---

## 📚 Referencias

**Paquetes utilizados:**
- `hive` / `hive_flutter` - Base de datos local NoSQL
- `connectivity_plus` - Detección de conexión a internet
- `cached_network_image` - Caché de imágenes

**Archivos clave:**
- `lib/services/offline_sync_service.dart` - Servicio principal
- `lib/games/game/escenas/subnivels.dart` - Implementación en subniveles
- `lib/games/game/escenas/tips_page.dart` - Implementación en tips
- `lib/games/scens_game/educational_game.dart` - Implementación en juegos
- `lib/games/game/escenas/questions.dart` - Implementación en preguntas

---

## 🆘 Troubleshooting

### **"No hay tips disponibles offline"**
- ✔️ Primero abre esa sección CON internet
- ✔️ Los datos se cachean en primera carga
- ✔️ Después funcionará sin internet

### **"Puntos no se sincronizan"**
- ✔️ Verifica logs en consola con 🔄
- ✔️ Comprueba que Supabase esté activo
- ✔️ Revisa permisos RLS en Supabase

### **"Imágenes no cargan offline"**
- ✔️ Asegúrate de haber abierto esa sección online primero
- ✔️ `CachedNetworkImage` descarga progresivamente
- ✔️ Puede tardar unos segundos la primera vez

---

**¡Sistema de caché offline implementado exitosamente!** 🎊
