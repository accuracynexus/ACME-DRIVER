# ACME-DRIVER

App de repartidores de la plataforma **ACME PEDIDOS** (Flutter + Supabase).

## Configuración antes de compilar

Las credenciales **no** viajan dentro del APK: se inyectan en tiempo de
compilación. Copia la plantilla y rellena los valores reales:

```bash
cp dart_defines.example.json dart_defines.json
```

`dart_defines.json` está en `.gitignore` y solo lleva las dos claves
**públicas** (`SUPABASE_URL` y `SUPABASE_ANON_KEY`). El `service role key` y la
cadena de conexión de Postgres nunca deben entrar aquí: viven en `.env`, que
solo usan los scripts de `scripts/` que corren en tu PC.

El `.env` también guarda `GOOGLE_MAPS_API_KEY`. Esa la lee Gradle al compilar
(`android/app/build.gradle.kts`) y la inyecta en el `AndroidManifest`; el `.env`
no se empaqueta dentro del APK.

## Compilar y ejecutar

Hay que pasar **siempre** el flag, o la app arranca y muestra "No se pudo
iniciar la app":

```bash
flutter run --dart-define-from-file=dart_defines.json
```

```bash
flutter build apk --release --dart-define-from-file=dart_defines.json
```

En VS Code no hace falta recordarlo: `.vscode/launch.json` ya trae las
configuraciones de debug, profile y release con el flag puesto.

## Backend

El backend es un proyecto Supabase **compartido** con las apps de comercio y
cliente. Las migraciones de `supabase/migrations/` se ejecutan **a mano** en el
SQL Editor de Supabase, en orden; ver `supabase/README.md`.

Para que un repartidor nuevo pueda operar, un administrador debe ponerle
`drivers.is_verified = true` tras revisar sus documentos.
