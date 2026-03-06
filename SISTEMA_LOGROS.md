# 🏆 Sistema de Logros (Achievements)

## Descripción
Sistema que otorga medallas/logros a los usuarios cuando completan niveles del juego educativo de trompeta.

## 📊 Estructura de Base de Datos

### Tabla: `achievements`
Almacena los logros disponibles en el sistema.

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid | ID único del logro |
| `name` | text | Nombre del logro (ej: "Trompetista Nivel 2") |
| `description` | text | Descripción del logro |
| `image` | text | URL de la imagen del logro |
| **`level_id`** | uuid | ⚠️ **NUEVA** - ID del nivel asociado (FK a `levels.id`) |
| **`created_at`** | timestamptz | ⚠️ **NUEVA** - Fecha de creación del logro |

### Tabla: `users_achievements`
Relaciona usuarios con los logros que han obtenido.

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | int8 | ID único del registro |
| `user_id` | uuid | ID del usuario (FK a `auth.users.id`) |
| `achievement_id` | uuid | ID del logro obtenido (FK a `achievements.id`) |
| `created_at` | timestamptz | Fecha en que se obtuvo el logro |

## 🚀 Instalación

### 1. Agregar Columnas a `achievements`
Ejecuta el script SQL para agregar las columnas faltantes:

```bash
sql_triggers/add_achievements_columns.sql
```

Este script:
- ✅ Agrega la columna `level_id` (relación con niveles)
- ✅ Agrega la columna `created_at` (timestamp)
- ✅ Crea índice para búsquedas rápidas
- ✅ Agrega documentación en la BD

### 2. Insertar Logros Iniciales
Edita y ejecuta el script de ejemplo:

```bash
sql_triggers/insert_achievements_examples.sql
```

**⚠️ IMPORTANTE:** Reemplaza los `UUID_DEL_NIVEL_X` con los IDs reales de tus niveles.

Para obtener los UUIDs correctos, ejecuta en Supabase:
```sql
SELECT l.id, l.name, l.number, i.name as instrument
FROM public.levels l
JOIN public.instruments i ON l.instrument_id = i.id
WHERE i.name = 'Trompeta'
ORDER BY l.number;
```

## 🎮 Funcionamiento

### Flujo Automático
1. **Usuario completa todos los subniveles de un nivel**
2. `_calculateLevelProgress()` detecta progreso 100%
3. `_markLevelAsCompleted()` marca el nivel como completado
4. **`_checkAndAwardAchievement()`** se ejecuta automáticamente:
   - Busca si existe un logro asociado al `level_id`
   - Verifica si el usuario ya lo tiene
   - Si no lo tiene, lo inserta en `users_achievements`
   - Muestra un diálogo animado con el logro obtenido

### Modo Offline
- Si el usuario completa un nivel **sin conexión**:
  - El logro se guarda en caché local (Hive)
  - Se agrega a lista `pending_achievements`
- Cuando recupera conexión:
  - **`_syncPendingAchievements()`** sincroniza automáticamente
  - Todos los logros pendientes se otorgan

## 🎨 Diálogo de Logro

Cuando un usuario obtiene un logro, ve un diálogo atractivo con:
- ✨ Animación de escala elástica
- 🏆 Icono de trofeo dorado
- 🖼️ Imagen del logro (con caché)
- 📝 Nombre y descripción del logro
- 🎨 Gradiente de colores cálidos (ámbar/naranja)
- 🔘 Botón "¡Continuar!"

## 📝 Ejemplo de Configuración

### Crear logro para Nivel 2:
```sql
INSERT INTO public.achievements (name, description, image, level_id) 
VALUES (
  'Trompetista Nivel 2',
  'Completaste el nivel 2 con éxito. ¡Sigue así!',
  'https://tuservidor.com/logros/nivel2.png',
  'abc123-def456-ghi789' -- UUID del nivel 2
);
```

## 🔧 Funciones Principales

| Función | Descripción |
|---------|-------------|
| `_checkAndAwardAchievement(levelId)` | Verifica y otorga logro al completar nivel |
| `_showAchievementDialog()` | Muestra diálogo bonito del logro obtenido |
| `_syncPendingAchievements()` | Sincroniza logros completados offline |

## 📱 Variables de Caché

| Clave Hive | Contenido |
|------------|-----------|
| `pending_achievements` | Lista de `level_id` pendientes de sincronizar |

## ⚙️ Configuración Recomendada

### Política RLS en Supabase

Habilita Row Level Security en `achievements` y `users_achievements`:

```sql
-- Permitir lectura pública de achievements
CREATE POLICY "Anyone can read achievements"
ON public.achievements FOR SELECT
USING (true);

-- Solo el sistema puede insertar en users_achievements
CREATE POLICY "Users can read their own achievements"
ON public.users_achievements FOR SELECT
USING (auth.uid() = user_id);

-- El sistema puede insertar logros para usuarios autenticados
CREATE POLICY "System can insert achievements"
ON public.users_achievements FOR INSERT
WITH CHECK (auth.uid() = user_id);
```

## 🐛 Debugging

Logs útiles en consola:
```
🏆 ¡Logro otorgado! Trompetista Nivel 2
⚠️ No hay logro configurado para este nivel
✅ Usuario ya tiene este logro
🔄 Sincronizando 2 logros pendientes...
```

## 📚 Recursos

- Tabla achievements: `public.achievements`
- Tabla vincular: `public.users_achievements`
- Scripts SQL: `sql_triggers/add_achievements_columns.sql`
- Código Flutter: `lib/games/learning.dart`

---

**Última actualización:** 5 de marzo de 2026  
**Versión:** 1.0.0
