# Sistema de Notificaciones - Instrucciones de Configuración

## 1. Configuración de Base de Datos

### Ejecutar el archivo SQL en Supabase

Ve a tu proyecto en Supabase → SQL Editor y ejecuta el contenido del archivo:
```
sql_triggers/notifications_trigger.sql
```

Este archivo crea:
- Trigger `on_notification_created`: Cuando se inserta una notificación en `notifications`, automáticamente crea registros en `user_notifications` para **todos los usuarios autenticados**
- Trigger `on_user_notification_deleted`: Cuando `is_deleted = true` en `user_notifications`, elimina el registro automáticamente (evita saturar la base de datos)

### Estructura de tablas necesarias

**Tabla: `notifications`**
```sql
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  icon TEXT,
  redirect_to TEXT,
  image TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);
```

**Tabla: `user_notifications`**
```sql
CREATE TABLE user_notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  notification_id UUID REFERENCES notifications(id) ON DELETE CASCADE,
  is_read BOOLEAN DEFAULT false,
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW()
);
```

## 2. Funcionamiento del Sistema

### Cuando se crea un registro nuevo:

#### **Eventos** (`eventsForm.dart`)
- Se crea el evento en la tabla `events`
- Se inserta una notificación con:
  - `title`: "🎉 Nuevo Evento"
  - `message`: Nombre del evento + fecha y hora
  - `icon`: "event"
  - `redirect_to`: "/event_detail/{eventId}" (específico para ese evento)
  - `image`: URL de la imagen del evento

#### **Sedes** (`headquartersforms.dart`)
- Se crea la sede en la tabla `sedes`
- Se inserta una notificación con:
  - `title`: "🏢 Nueva Sede"
  - `message`: "Se ha agregado la sede {nombre}"
  - `icon`: "home"
  - `redirect_to`: "/headquarters"
  - `image`: URL de la foto de la sede

#### **Instrumentos** (`instrumentsForm.dart`)
- Se crea el instrumento en la tabla `instruments`
- Se inserta una notificación con:
  - `title`: "🎸 Nuevo Instrumento"
  - `message`: "Se ha agregado el instrumento {nombre}"
  - `icon`: "music"
  - `redirect_to`: "/intrumentos"
  - `image`: URL de la foto del instrumento

#### **Objetos** (`onbjetsForm.dart`)
- Se crea el objeto en la tabla `objets`
- Se inserta una notificación con:
  - `title`: "🎁 Nuevo Objeto Disponible"
  - `message`: "{nombre} - {precio} monedas"
  - `icon`: "star"
  - `redirect_to`: "/objects"
  - `image`: URL de la imagen del objeto

### Flujo de notificaciones:

1. **Admin crea un registro** (evento, sede, instrumento, objeto)
2. **Se inserta en `notifications`** con los datos correspondientes
3. **El trigger automáticamente crea registros en `user_notifications`** para TODOS los usuarios autenticados
4. **Los usuarios reciben la notificación** cuando abren la app (notification.dart verifica notificaciones no leídas)
5. **Se muestra la notificación push** con imagen incluida
6. **Al tocar la notificación**, redirige a la ruta específica en `redirect_to`
7. **Cuando el usuario elimina una notificación** (`is_deleted = true`), se elimina automáticamente de la base de datos

## 3. Características Implementadas

### ✅ Notificaciones con Imagen
- El servicio `notification_service.dart` ahora descarga las imágenes y las muestra en las notificaciones
- Usa `BigPictureStyleInformation` para Android
- Las imágenes se cachean temporalmente

### ✅ Redirección Específica
- Cada tipo de notificación tiene su propia ruta
- Los eventos usan rutas dinámicas: `/event_detail/{id}`
- Al tocar la notificación, navega a la pantalla correcta

### ✅ Limpieza Automática
- Cuando `is_deleted = true`, el registro se elimina automáticamente
- Evita saturar la base de datos con notificaciones borradas

### ✅ Sistema Multi-Usuario
- Una sola inserción en `notifications` envía a **todos los usuarios**
- Cada usuario tiene su propio estado de lectura (`is_read`)
- Cada usuario puede eliminar su notificación sin afectar a otros

## 4. Para agregar notificaciones a nuevos formularios

Si creas un nuevo formulario (por ejemplo, para canciones), sigue este patrón:

```dart
// Después de crear el registro en la base de datos
final response = await supabase.from('songs').insert({
  // ... campos de la canción
}).select().single();

// Crear notificación para todos los usuarios
await supabase.from('notifications').insert({
  'title': '🎵 Nueva Canción Disponible',
  'message': 'Se ha agregado la canción ${nombreCancion}',
  'icon': 'music',
  'redirect_to': '/song_detail/${response['id']}',
  'image': urlImagenCancion,
});
```

## 5. Verificación

Para verificar que todo funciona:

1. **Verifica los triggers en Supabase**: SQL Editor → Functions
2. **Crea un evento/sede/instrumento/objeto** desde la app
3. **Verifica en Supabase**: 
   - Tabla `notifications` debe tener 1 registro nuevo
   - Tabla `user_notifications` debe tener N registros (uno por cada usuario autenticado)
4. **Abre la app con otro usuario**: Debe recibir la notificación push
5. **Toca la notificación**: Debe redirigir a la pantalla correcta

## 6. Solución de Problemas

### Las notificaciones no se envían a todos los usuarios
- Verifica que el trigger `on_notification_created` esté activo
- Ejecuta manualmente: `SELECT * FROM auth.users;` para ver usuarios

### Las imágenes no se muestran
- Verifica que el campo `image` tenga una URL válida
- Verifica permisos de internet en `AndroidManifest.xml`

### Las notificaciones eliminadas no desaparecen
- Verifica que el trigger `on_user_notification_deleted` esté activo
- Verifica que `is_deleted` se esté actualizando correctamente

## 7. Permisos de Android

Asegúrate de tener estos permisos en `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

## 8. Rutas Implementadas

| Tipo | Ruta | Descripción |
|------|------|-------------|
| Eventos | `/event_detail/{id}` | Detalle específico del evento |
| Sedes | `/headquarters` | Lista de sedes |
| Instrumentos | `/intrumentos` | Lista de instrumentos |
| Objetos | `/objects` | Tienda de objetos |

**Nota**: Para que las rutas funcionen, asegúrate de tenerlas configuradas en tu navegación principal.
