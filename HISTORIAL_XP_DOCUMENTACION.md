# Sistema de Historial de Puntos de Experiencia (XP)

## 📋 Descripción General

Se ha implementado un sistema completo de historial de puntos de experiencia que registra detalladamente cada vez que un usuario gana XP en la aplicación. Este sistema reemplaza la dependencia de `games_history` para el seguimiento de estadísticas y proporciona mayor flexibilidad y trazabilidad.

---

## 🗄️ Estructura de la Tabla

### Tabla: `xp_history`

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | UUID | Identificador único del registro |
| `user_id` | UUID | ID del usuario (FK a `auth.users`) |
| `points_earned` | INTEGER | Cantidad de puntos XP ganados |
| `source` | TEXT | Origen de los puntos (ver tipos abajo) |
| `source_id` | TEXT | ID del elemento que generó los puntos |
| `source_name` | TEXT | Nombre descriptivo del elemento |
| `source_details` | JSONB | Detalles adicionales en formato JSON |
| `created_at` | TIMESTAMP | Fecha y hora del registro |

### Tipos de Fuentes (source)

```sql
'tips_completion'        -- Completar tips/viñetas
'educational_game'       -- Juegos educativos
'beginner_game'          -- Juegos para principiantes
'level_completion'       -- Completar niveles
'achievement_unlocked'   -- Desbloquear logros
'daily_bonus'           -- Bonus diario
'weekly_bonus'          -- Bonus semanal
'other'                 -- Otros orígenes
```

---

## 🔧 Implementación en el Código

### 1. Tips Completion (tips_page.dart)

Cuando un usuario completa todas las viñetas de tips:

```dart
await _recordXpHistory(
  userId,
  totalExperience,
  'tips_completion',
  widget.sublevelId,        // ID del sublevel
  widget.sublevelTitle,     // Nombre del sublevel
  {
    'total_tips': tips.length,
    'coins_earned': totalExperience ~/ 10,
  },
);
```

**Ejemplo de registro:**
- **Usuario:** Juan Pérez
- **Puntos:** 100 XP
- **Fuente:** Completar tips de "Técnica de respiración"
- **Detalles:** 5 viñetas completadas, 10 monedas ganadas

### 2. Educational Game (educational_game.dart)

Cuando un usuario completa un juego educativo:

```dart
await _recordXpHistory(
  userId,
  experiencePoints,
  'educational_game',
  widget.sublevelId,        // ID del sublevel
  widget.title,             // Nombre del nivel
  {
    'coins_earned': experiencePoints ~/ 10,
    'accuracy': accuracy,   // Precisión del jugador
    'stars': stars,         // Estrellas obtenidas
  },
);
```

**Ejemplo de registro:**
- **Usuario:** María García
- **Puntos:** 150 XP
- **Fuente:** Juego educativo "Notas básicas"
- **Detalles:** 95% precisión, 3 estrellas, 15 monedas

### 3. Beginner Game (begginer_game.dart)

Cuando un usuario completa un juego para principiantes:

```dart
await _recordXpHistory(
  userId,
  experiencePoints,
  'beginner_game',
  widget.songId,            // ID de la canción
  widget.songName,          // Nombre de la canción
  {
    'difficulty': widget.songDifficulty,
    'coins_earned': totalCoins,
    'accuracy': accuracy,
    'stars': stars,
  },
);
```

**Ejemplo de registro:**
- **Usuario:** Carlos López
- **Puntos:** 80 XP
- **Fuente:** Juego principiante "Himno Alegre"
- **Detalles:** Dificultad fácil, 88% precisión, 2 estrellas, 20 monedas

---

## 📊 Funciones de Consulta SQL

### 1. Obtener XP por fuente

```sql
SELECT * FROM get_xp_by_source('user-id-aqui');
```

Retorna:
| source | total_points | count_records |
|--------|-------------|--------------|
| educational_game | 450 | 3 |
| tips_completion | 300 | 3 |
| beginner_game | 240 | 3 |

### 2. Obtener historial semanal

```sql
SELECT * FROM get_weekly_xp_history('user-id-aqui');
```

Retorna XP agrupado por día de la semana (0=Domingo, 6=Sábado)

### 3. Obtener historial reciente

```sql
SELECT * FROM get_recent_xp_history('user-id-aqui', 10);
```

Retorna los últimos 10 registros de XP del usuario

---

## 📈 Integración con Gráficas

El archivo `profile.dart` ha sido actualizado para usar `xp_history` en lugar de `games_history`:

```dart
Future<void> fetchWeeklyXpData() async {
  // Consulta la tabla xp_history para obtener datos semanales
  final response = await supabase
      .from('xp_history')
      .select('points_earned, created_at, source, source_name')
      .eq('user_id', userId)
      .gte('created_at', startOfWeekMidnight.toIso8601String())
      .order('created_at', ascending: true);
  
  // Agrupa por día de la semana para la gráfica
}
```

---

## 🔐 Seguridad (RLS)

La tabla tiene políticas de Row Level Security:

1. **Lectura:** Los usuarios solo pueden ver su propio historial
2. **Inserción:** Los usuarios solo pueden insertar sus propios registros
3. **Actualización/Eliminación:** Solo administradores

---

## 📝 Ejemplos de Consultas

### Obtener total de XP del mes actual

```sql
SELECT SUM(points_earned) as total_xp
FROM xp_history
WHERE user_id = 'user-id-aqui'
  AND created_at >= DATE_TRUNC('month', NOW());
```

### Obtener XP por día del mes

```sql
SELECT 
  DATE(created_at) as date,
  SUM(points_earned) as daily_xp,
  COUNT(*) as activities
FROM xp_history
WHERE user_id = 'user-id-aqui'
  AND created_at >= DATE_TRUNC('month', NOW())
GROUP BY DATE(created_at)
ORDER BY date DESC;
```

### Obtener actividades más comunes

```sql
SELECT 
  source,
  COUNT(*) as count,
  SUM(points_earned) as total_xp,
  AVG(points_earned) as avg_xp
FROM xp_history
WHERE user_id = 'user-id-aqui'
GROUP BY source
ORDER BY count DESC;
```

### Ver último XP ganado con detalles

```sql
SELECT 
  points_earned,
  source,
  source_name,
  source_details,
  created_at
FROM xp_history
WHERE user_id = 'user-id-aqui'
ORDER BY created_at DESC
LIMIT 1;
```

---

## 🔄 Migración desde `games_history`

Si tienes datos históricos en `games_history` que quieres migrar:

```sql
-- Ejemplo de migración (ajustar según estructura de games_history)
INSERT INTO xp_history (user_id, points_earned, source, source_id, source_name, created_at)
SELECT 
  user_id,
  points_xp,
  'level_completion',
  level_id,
  level_name,
  created_at
FROM games_history
WHERE points_xp > 0;
```

---

## 🎯 Beneficios del Sistema

1. **Trazabilidad completa:** Saber exactamente de dónde vino cada punto de XP
2. **Análisis detallado:** Identificar qué actividades generan más XP
3. **Gamificación:** Mostrar al usuario su progreso detallado
4. **Estadísticas:** Generar informes y gráficas más precisas
5. **Debugging:** Identificar problemas con puntos duplicados o faltantes
6. **Flexibilidad:** Fácil de extender para nuevas fuentes de XP

---

## 📱 Próximos Pasos Sugeridos

1. **Crear una pantalla de historial de XP** donde el usuario pueda ver:
   - Lista de todas sus ganancias de XP
   - Filtros por tipo de actividad
   - Gráfica de progreso temporal
   
2. **Implementar notificaciones** cuando se gana XP

3. **Añadir badges/insignias** basados en el historial:
   - "Completó 10 tips" (tips_completion > 10)
   - "Maestro educativo" (educational_game > 20)

4. **Crear un dashboard de admin** para ver:
   - Qué actividades generan más engagement
   - Usuarios más activos
   - Tendencias de uso

---

## 🐛 Solución de Problemas

### Los puntos no se registran en el historial

1. Verificar que la tabla `xp_history` existe
2. Revisar las políticas RLS
3. Comprobar los logs en la consola (buscar "✅ Historial de XP registrado")

### Gráfica semanal no muestra datos

1. Verificar que `fetchWeeklyXpData()` está consultando `xp_history`
2. Revisar que los datos existen en la tabla
3. Comprobar el formato de fechas (timezone)

### Duplicación de puntos

El sistema está diseñado para evitar duplicados ya que cada registro es independiente. Si ocurre:
1. Revisar que no se llame múltiples veces a `_recordXpHistory()`
2. Verificar triggers en la base de datos

---

## 📞 Soporte

Para más información o problemas, revisar:
- Script SQL: `sql_triggers/xp_history_table.sql`
- Implementación Tips: `lib/games/game/escenas/tips_page.dart`
- Implementación Educational: `lib/games/scens_game/educational_game.dart`
- Implementación Beginner: `lib/games/scens_game/begginer_game.dart`
- Visualización: `lib/games/game/escenas/profile.dart`
