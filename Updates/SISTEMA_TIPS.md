# Sistema de Tips con Viñetas 💡

## Descripción
Sistema para mostrar tips educativos mediante viñetas interactivas con imágenes, descripciones y navegación secuencial.

## Estructura de la Base de Datos

### Tabla `tips`

```sql
CREATE TABLE tips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sublevel_id UUID NOT NULL REFERENCES sublevels(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    img_url TEXT,
    description TEXT NOT NULL,
    tip_order INTEGER NOT NULL DEFAULT 1,
    experience_points INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Campos

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | UUID | Identificador único del tip |
| `sublevel_id` | UUID | ID del subnivel al que pertenece |
| `title` | VARCHAR(255) | Título del tip |
| `img_url` | TEXT | URL de la imagen del tip |
| `description` | TEXT | Descripción detallada del tip |
| `tip_order` | INTEGER | Orden de presentación (1, 2, 3...) |
| `experience_points` | INTEGER | Puntos XP al completar TODAS las viñetas |
| `created_at` | TIMESTAMP | Fecha de creación |
| `updated_at` | TIMESTAMP | Fecha de última actualización |

## Cómo Usar

### 1. Crear la Tabla en Supabase

Ejecuta el script SQL ubicado en:
```
sql_triggers/tips_table.sql
```

### 2. Insertar Datos de Ejemplo

```sql
-- Ejemplo: Tips para un subnivel de teoría musical
INSERT INTO tips (sublevel_id, title, img_url, description, tip_order, experience_points) VALUES
('tu-sublevel-id-uuid', 
 'Tip 1: Las Notas Musicales', 
 'https://tu-url-imagen-1.jpg',
 'Las notas musicales son 7: Do, Re, Mi, Fa, Sol, La, Si. Cada una representa un sonido específico en la escala musical.',
 1,
 100), -- Puntos solo se otorgan al completar TODAS las viñetas

('tu-sublevel-id-uuid',
 'Tip 2: El Pentagrama',
 'https://tu-url-imagen-2.jpg',
 'El pentagrama es el conjunto de 5 líneas y 4 espacios donde se escriben las notas musicales. Cada línea y espacio representa una nota diferente.',
 2,
 100), -- Mismos puntos (se otorgan una sola vez al final)

('tu-sublevel-id-uuid',
 'Tip 3: La Clave de Sol',
 'https://tu-url-imagen-3.jpg',
 'La clave de sol se coloca al inicio del pentagrama y nos indica la posición de las notas. Es la más común en partituras.',
 3,
 100); -- Mismos puntos
```

### 3. Configurar el Subnivel

En tu tabla `sublevels`, asegúrate de que el campo `type` sea:
```sql
UPDATE sublevels 
SET type = 'Tips' 
WHERE id = 'tu-sublevel-id-uuid';
```

### 4. Flujo de Usuario

1. **Navegación**: Usuario accede a un subnivel tipo "Tips"
2. **Visualización**: Se muestra la primera viñeta con:
   - Contador (Tip 1 de 3)
   - Barra de progreso
   - Imagen
   - Título
   - Descripción
3. **Navegación entre viñetas**:
   - Botón "Siguiente" para avanzar
   - Botón "Anterior" para retroceder
4. **Completado**:
   - Al llegar a la última viñeta, aparece "Ver resumen"
   - Se muestra botón "Marcar como Completado"
   - Al completar se otorgan los puntos XP
   - Se guarda el progreso en `users_levels` y `user_sublevels`

## Características

✅ **Navegación Secuencial**: Avanza y retrocede entre viñetas
✅ **Barra de Progreso**: Indica visualmente el avance
✅ **Contador Visual**: "Tip 1 de 3"
✅ **Imágenes**: Soporte completo con loading y error handling
✅ **Puntos XP**: Se otorgan al completar todas las viñetas
✅ **Persistencia**: Guarda progreso en base de datos
✅ **Tema Oscuro/Claro**: Compatible con ambos temas
✅ **Responsive**: Se adapta a diferentes tamaños de pantalla

## Puntos de Experiencia

- Los puntos XP se configuran en el campo `experience_points`
- Se otorgan **UNA SOLA VEZ** al completar todas las viñetas
- Se distribuyen en:
  - Perfil del usuario (tabla específica: students, teachers, etc.)
  - `users_games` (points_xp_totally y points_xp_weekend)
  - Monedas (1 moneda cada 10 XP)

## Archivos Creados

1. **SQL**: `sql_triggers/tips_table.sql` - Script de creación de tabla
2. **Flutter**: `lib/games/game/escenas/tips_page.dart` - Página de viñetas
3. **Integración**: Modificación en `questions.dart` para manejar tipo "Tips"

## Tipos de Subnivel Soportados

Ahora la aplicación soporta:
- ✅ `Quiz` - Cuestionarios
- ✅ `Evaluation` - Evaluaciones
- ✅ `Video` - Videos educativos
- ✅ `Game` / `Juego` - Juegos educativos
- ✅ `Tips` / `Tip` - **NUEVO** Viñetas educativas

## Ejemplo Visual

```
┌─────────────────────────────────────┐
│    Tip 1 de 3              💡       │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━         │  (Barra progreso 33%)
├─────────────────────────────────────┤
│                                     │
│       [Imagen del Tip]              │
│                                     │
├─────────────────────────────────────┤
│   📝 Descripción detallada          │
│   del tip con información           │
│   educativa importante              │
└─────────────────────────────────────┘
     [Anterior]      [Siguiente →]
```

## Notas Importantes

⚠️ **Orden de Viñetas**: Usa `tip_order` para controlar la secuencia
⚠️ **Puntos XP**: Los puntos solo se otorgan al completar TODAS las viñetas
⚠️ **Imágenes**: Usa URLs válidas y accesibles
⚠️ **Sublevel ID**: Debe coincidir con un subnivel existente

## Mantenimiento

Para agregar más viñetas a un subnivel existente:

```sql
INSERT INTO tips (sublevel_id, title, img_url, description, tip_order, experience_points)
VALUES (
    'id-del-sublevel',
    'Nuevo Tip',
    'url-imagen',
    'Descripción del nuevo tip',
    4, -- Siguiente número en la secuencia
    100 -- Mismos puntos que las otras viñetas
);
```

Para modificar el orden:

```sql
UPDATE tips 
SET tip_order = 2 
WHERE id = 'id-del-tip';
```

## Troubleshooting

**Problema**: Las viñetas no aparecen
- Verifica que `sublevel_id` coincida exactamente
- Revisa que `type = 'Tips'` en la tabla `sublevels`

**Problema**: Las imágenes no cargan
- Verifica que las URLs sean accesibles públicamente
- Comprueba que no haya errores CORS

**Problema**: No se otorgan puntos XP
- Verifica que `experience_points > 0`
- Confirma que el usuario completó todas las viñetas
- Revisa los logs de debug en la consola

---

**Fecha de creación**: 10 de febrero de 2026
**Versión**: 1.0.0
