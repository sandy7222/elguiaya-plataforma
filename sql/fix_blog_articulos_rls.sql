-- ====================================================================
-- SCRIPT DE BASE DE DATOS PARA CORRECCIÓN DE SEGURIDAD RLS EN BLOG
--
-- INSTRUCCIONES:
-- 1. Copia el contenido completo de este script.
-- 2. Ve a tu consola de Supabase (https://supabase.com).
-- 3. Entra en tu proyecto (PescadorYA / CapitánYA-MAESTRO).
-- 4. En el menú lateral izquierdo, haz clic en "SQL Editor".
-- 5. Crea una nueva consulta ("New Query").
-- 6. Pega este código y haz clic en el botón "Run" (Ejecutar).
-- ====================================================================

BEGIN;

-- 1. Habilitar Row Level Security (RLS)
ALTER TABLE public.blog_articulos ENABLE ROW LEVEL SECURITY;

-- 2. Eliminar políticas antiguas si existen
DROP POLICY IF EXISTS "Lectura publica de articulos activos" ON public.blog_articulos;
DROP POLICY IF EXISTS "Administrar articulos completa" ON public.blog_articulos;
DROP POLICY IF EXISTS "Lectura de articulos" ON public.blog_articulos;
DROP POLICY IF EXISTS "Insertar articulos" ON public.blog_articulos;
DROP POLICY IF EXISTS "Actualizar articulos" ON public.blog_articulos;
DROP POLICY IF EXISTS "Eliminar articulos" ON public.blog_articulos;

-- 3. Crear política de SELECT (Público general para activos, total para admins)
CREATE POLICY "Lectura de articulos" ON public.blog_articulos
    FOR SELECT USING (
        activo = true OR (
            auth.role() = 'authenticated' AND (
                (auth.jwt() -> 'user_metadata' ->> 'rol') = 'admin' OR
                (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' OR
                auth.jwt() ->> 'email' = 'admin@capitanya.com' OR
                auth.jwt() ->> 'role' = 'admin' OR
                auth.jwt() ->> 'rol' = 'admin'
            )
        )
    );

-- 4. Crear política de INSERT (Solo administradores)
CREATE POLICY "Insertar articulos" ON public.blog_articulos
    FOR INSERT WITH CHECK (
        auth.role() = 'authenticated' AND (
            (auth.jwt() -> 'user_metadata' ->> 'rol') = 'admin' OR
            (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' OR
            auth.jwt() ->> 'email' = 'admin@capitanya.com' OR
            auth.jwt() ->> 'role' = 'admin' OR
            auth.jwt() ->> 'rol' = 'admin'
        )
    );

-- 5. Crear política de UPDATE (Solo administradores)
CREATE POLICY "Actualizar articulos" ON public.blog_articulos
    FOR UPDATE USING (
        auth.role() = 'authenticated' AND (
            (auth.jwt() -> 'user_metadata' ->> 'rol') = 'admin' OR
            (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' OR
            auth.jwt() ->> 'email' = 'admin@capitanya.com' OR
            auth.jwt() ->> 'role' = 'admin' OR
            auth.jwt() ->> 'rol' = 'admin'
        )
    ) WITH CHECK (
        auth.role() = 'authenticated' AND (
            (auth.jwt() -> 'user_metadata' ->> 'rol') = 'admin' OR
            (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' OR
            auth.jwt() ->> 'email' = 'admin@capitanya.com' OR
            auth.jwt() ->> 'role' = 'admin' OR
            auth.jwt() ->> 'rol' = 'admin'
        )
    );

-- 6. Crear política de DELETE (Solo administradores)
CREATE POLICY "Eliminar articulos" ON public.blog_articulos
    FOR DELETE USING (
        auth.role() = 'authenticated' AND (
            (auth.jwt() -> 'user_metadata' ->> 'rol') = 'admin' OR
            (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' OR
            auth.jwt() ->> 'email' = 'admin@capitanya.com' OR
            auth.jwt() ->> 'role' = 'admin' OR
            auth.jwt() ->> 'rol' = 'admin'
        )
    );

-- 7. Notificar recarga del esquema
NOTIFY pgrst, 'reload schema';

COMMIT;

SELECT '✅ ¡Políticas RLS para blog_articulos actualizadas con éxito!' AS resultado;
