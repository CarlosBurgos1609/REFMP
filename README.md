# REFMP
# Red de Escuelas De Formación Musical de Pasto


## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

>[!IMPORTANT]
>
>```sql
>DO $$
>DECLARE
>  r RECORD;
>BEGIN
>  FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename NOT IN ('storage.objects', 'auth.users')  -- >Excluye tablas de sistema si es necesario
>  LOOP
>    PERFORM setup_rls_policies_for_table(r.tablename);
>  END LOOP;
>END $$;
>
>```
