# 🔧 SOLUCIÓN: Eventos Duplicados + Notificaciones No Llegan

## 📱 PROBLEMA 1: Notificaciones no llegan al celular

### ✅ **SOLUCIÓN IMPLEMENTADA**

Se agregó el permiso `POST_NOTIFICATIONS` en el **AndroidManifest.xml** (requerido para Android 13+).

### 🔄 Pasos para aplicar la solución:

1. **Limpia y reconstruye la app completamente:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Desinstala la app del celular y reinstálala:**
   - Ve a Configuración → Apps → REFMP → Desinstalar
   - Instala nuevamente con `flutter run`

3. **Cuando abras la app por primera vez, DEBES aceptar el permiso de notificaciones**

4. **Verifica permisos del celular:**
   - Ve a: Configuración → Apps → REFMP → Permisos → Notificaciones
   - Asegúrate que esté **ACTIVADO**

---

## 🔁 PROBLEMA 2: Eventos se crean duplicados

### 🔍 **DIAGNÓSTICO**

El código Flutter **NO** está creando dos eventos. El problema está en la **BASE DE DATOS de Supabase**.

Posibles causas:
1. **Hay un trigger duplicado en la tabla `events`**
2. **Hay una política RLS o función que duplica inserts**
3. **Hay un trigger BEFORE INSERT que hace otro insert**

---

## 🛠️ SOLUCIÓN PASO A PASO

### **PASO 1: Verificar triggers en la tabla `events`**

1. Ve al **SQL Editor** de Supabase
2. Ejecuta este comando:

```sql
-- Ver TODOS los triggers en la tabla events
SELECT 
    t.tgname AS trigger_name,
    p.proname AS function_name,
    CASE t.tgtype::integer & 66
        WHEN 2 THEN 'BEFORE'
        WHEN 64 THEN 'INSTEAD OF'
        ELSE 'AFTER'
    END AS trigger_timing,
    CASE t.tgtype::integer & cast(28 as int2)
        WHEN 4 THEN 'INSERT'
        WHEN 8 THEN 'DELETE'
        WHEN 16 THEN 'UPDATE'
        WHEN 20 THEN 'INSERT OR UPDATE'
        WHEN 28 THEN 'INSERT OR UPDATE OR DELETE'
        ELSE 'UNKNOWN'
    END AS trigger_event,
    pg_get_triggerdef(t.oid) AS trigger_definition
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
JOIN pg_class c ON t.tgrelid = c.oid
WHERE c.relname = 'events'
AND t.tgisinternal = false
ORDER BY t.tgname;
```

3. **Revisa los resultados:**
   - Si ves **DOS o más triggers** con el mismo nombre o función → HAY DUPLICACIÓN
   - Si ves triggers con tipo `BEFORE INSERT` o `AFTER INSERT` → REVISAR qué hacen

---

### **PASO 2: Eliminar triggers duplicados o problemáticos**

Si encontraste triggers duplicados o sospechosos, elimínalos:

```sql
-- REEMPLAZA 'nombre_del_trigger' con el nombre real que encontraste
DROP TRIGGER IF EXISTS nombre_del_trigger ON events;

-- Ejemplo si el trigger se llama 'duplicate_event_trigger':
-- DROP TRIGGER IF EXISTS duplicate_event_trigger ON events;
```

---

### **PASO 3: Verificar funciones trigger asociadas**

```sql
-- Ver el código de las funciones trigger
SELECT 
    p.proname AS function_name,
    pg_get_functiondef(p.oid) AS function_definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
AND p.proname LIKE '%event%'
ORDER BY p.proname;
```

**Busca en el código si alguna función:**
- Hace `INSERT INTO events` (esto duplicaría eventos)
- Tiene lógica extraña de duplicación
- Tiene comentarios que mencionen "duplicar", "copiar", "backup", etc.

---

### **PASO 4: Verificar políticas RLS**

```sql
-- Ver políticas en la tabla events
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'events';
```

**Si ves políticas raras que puedan estar duplicando, elimínalas:**

```sql
DROP POLICY IF EXISTS nombre_de_la_politica ON events;
```

---

### **PASO 5: Prueba de inserción manual**

Para verificar si el problema está en los triggers, haz un insert manual:

```sql
-- Insertar un evento de prueba manualmente
INSERT INTO events (
    name, 
    date, 
    time, 
    time_fin, 
    location, 
    month, 
    year, 
    start_datetime, 
    end_datetime
) VALUES (
    'TEST - Evento de Prueba',
    NOW(),
    '10:00',
    '11:00',
    'Ubicación de prueba',
    EXTRACT(MONTH FROM NOW()),
    EXTRACT(YEAR FROM NOW()),
    NOW(),
    NOW() + INTERVAL '1 hour'
)
RETURNING *;
```

**Luego verifica cuántos eventos "TEST" se crearon:**

```sql
SELECT * FROM events WHERE name LIKE '%TEST%';
```

- Si aparece **UN solo evento** → El problema NO está en los triggers
- Si aparecen **DOS eventos** → HAY un trigger duplicando

---

### **PASO 6: Limpiar eventos duplicados existentes**

Si ya tienes eventos duplicados, elimina los duplicados:

```sql
-- Ver eventos duplicados (mismo nombre, fecha, ubicación)
SELECT 
    name, 
    date, 
    location, 
    COUNT(*) as cantidad
FROM events
GROUP BY name, date, location
HAVING COUNT(*) > 1;

-- CUIDADO: Este comando elimina duplicados dejando solo uno
-- Verifica primero qué se va a eliminar
WITH duplicados AS (
    SELECT 
        id,
        ROW_NUMBER() OVER (
            PARTITION BY name, date, location 
            ORDER BY id
        ) as rn
    FROM events
)
SELECT * FROM duplicados WHERE rn > 1;

-- Si estás seguro, descomenta y ejecuta:
-- DELETE FROM events WHERE id IN (
--     SELECT id FROM (
--         SELECT 
--             id,
--             ROW_NUMBER() OVER (
--                 PARTITION BY name, date, location 
--                 ORDER BY id
--             ) as rn
--         FROM events
--     ) x WHERE rn > 1
-- );
```

---

## 🧪 PRUEBA COMPLETA

Después de aplicar las correcciones:

1. **Crea un evento desde la app**
2. **Verifica inmediatamente en Supabase:**
   ```sql
   SELECT * FROM events ORDER BY id DESC LIMIT 5;
   ```
3. **Debe aparecer SOLO UNO**

4. **Verifica que se crearon las notificaciones:**
   ```sql
   SELECT * FROM notifications ORDER BY created_at DESC LIMIT 5;
   ```

5. **Verifica que se crearon user_notifications para todos los usuarios:**
   ```sql
   SELECT 
       n.title,
       COUNT(un.id) as usuarios_notificados
   FROM notifications n
   LEFT JOIN user_notifications un ON un.notification_id = n.id
   WHERE n.id = (SELECT MAX(id) FROM notifications)
   GROUP BY n.title;
   ```

6. **Cierra COMPLETAMENTE la app del celular**

7. **Abre la app nuevamente**

8. **Deberías ver la notificación emergente**

---

## 📋 CHECKLIST FINAL

- [ ] Permiso `POST_NOTIFICATIONS` agregado en AndroidManifest.xml
- [ ] App reinstalada completamente (`flutter clean` + reinstalar)
- [ ] Permisos de notificaciones aceptados en el celular
- [ ] Verificado que NO hay triggers duplicados en la tabla `events`
- [ ] Verificado con insert manual que solo se crea UN evento
- [ ] Eventos duplicados existentes eliminados
- [ ] Trigger `on_notification_created` existe y funciona
- [ ] Prueba completa: crear evento → cerrar app → abrir app → ver notificación

---

## 🆘 SI SIGUE SIN FUNCIONAR

### Para Notificaciones:

1. **Verifica logs de Flutter:**
   ```bash
   flutter run --verbose
   ```
   Busca en los logs: "Notificaciones inicializadas correctamente"

2. **Verifica que la tabla user_notifications tiene datos:**
   ```sql
   SELECT * FROM user_notifications WHERE user_id = 'tu_user_id' LIMIT 10;
   ```

3. **Fuerza la descarga de notificaciones:**
   - Cierra app completamente
   - Abre app
   - Espera 2 segundos
   - Deberían aparecer

### Para Eventos Duplicados:

1. **Exporta la definición completa de la tabla:**
   ```sql
   SELECT pg_get_tabledef('events');
   ```

2. **Busca triggers ocultos:**
   ```sql
   SELECT * FROM pg_trigger WHERE tgrelid = 'events'::regclass;
   ```

3. **Revisa logs de Supabase** en el Dashboard → Database → Logs

---

## 📞 INFORMACIÓN PARA REPORTAR

Si ninguno de los pasos anteriores funciona, recopila esta información:

**Para eventos duplicados:**
```sql
-- 1. Triggers
SELECT tgname, pg_get_triggerdef(oid) FROM pg_trigger WHERE tgrelid = 'events'::regclass;

-- 2. Último evento creado
SELECT * FROM events ORDER BY id DESC LIMIT 2;

-- 3. Funciones trigger
SELECT proname, prosrc FROM pg_proc WHERE proname LIKE '%event%';
```

**Para notificaciones:**
- Screenshot de los permisos de la app en el celular
- Logs de Flutter al abrir la app
- Resultado de: `SELECT COUNT(*) FROM user_notifications WHERE user_id = 'tu_user_id';`

---

## ✅ RESUMEN

1. **Notificaciones:** Agregado permiso POST_NOTIFICATIONS → Reinstala app y acepta permisos
2. **Eventos duplicados:** Busca y elimina triggers duplicados en Supabase → Usa los SQL de verificación
3. **Prueba completa:** Crea evento → Verifica que solo aparece UNO → Cierra y abre app → Ve notificación
