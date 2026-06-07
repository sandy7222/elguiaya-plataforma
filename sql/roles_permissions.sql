-- =====================================================
-- Permisos de Roles para Vista de Gestión de Usuarios
-- =====================================================

-- Crear políticas RLS para vista_gestion_usuarios si no existen
DROP POLICY IF EXISTS "Administradores pueden gestionar usuarios" ON vista_gestion_usuarios;
DROP POLICY IF EXISTS "Usuarios autenticados pueden ver usuarios" ON vista_gestion_usuarios;

-- Política de SELECT: Usuarios autenticados pueden ver la lista de usuarios
CREATE POLICY "Usuarios autenticados pueden ver usuarios" ON vista_gestion_usuarios
    FOR SELECT USING (
        auth.role() = 'authenticated'
    );

-- Política de INSERT: Solo administradores pueden insertar usuarios
CREATE POLICY "Administradores pueden insertar usuarios" ON vista_gestion_usuarios
    FOR INSERT WITH CHECK (
        auth.role() = 'authenticated' AND
        (
            auth.jwt() ->> 'role' = 'admin' OR
            auth.jwt() ->> 'rol' = 'admin'
        )
    );

-- Política de UPDATE: Solo administradores pueden actualizar usuarios
CREATE POLICY "Administradores pueden actualizar usuarios" ON vista_gestion_usuarios
    FOR UPDATE USING (
        auth.role() = 'authenticated' AND
        (
            auth.jwt() ->> 'role' = 'admin' OR
            auth.jwt() ->> 'rol' = 'admin'
        )
    );

-- Política de DELETE: Solo administradores pueden eliminar usuarios
CREATE POLICY "Administradores pueden eliminar usuarios" ON vista_gestion_usuarios
    FOR DELETE USING (
        auth.role() = 'authenticated' AND
        (
            auth.jwt() ->> 'role' = 'admin' OR
            auth.jwt() ->> 'rol' = 'admin'
        )
    );

-- Habilitar RLS en la vista si no está activado
ALTER TABLE vista_gestion_usuarios ENABLE ROW LEVEL SECURITY;

-- Permisos adicionales para la tabla usuarios si existe
-- Política de SELECT para usuarios base
CREATE POLICY IF NOT EXISTS "Usuarios autenticados pueden ver usuarios_base" ON usuarios
    FOR SELECT USING (
        auth.role() = 'authenticated'
    );

-- Política de INSERT para usuarios base
CREATE POLICY IF NOT EXISTS "Administradores pueden insertar usuarios_base" ON usuarios
    FOR INSERT WITH CHECK (
        auth.role() = 'authenticated' AND
        (
            auth.jwt() ->> 'role' = 'admin' OR
            auth.jwt() ->> 'rol' = 'admin'
        )
    );

-- Política de UPDATE para usuarios base
CREATE POLICY IF NOT EXISTS "Administradores pueden actualizar usuarios_base" ON usuarios
    FOR UPDATE USING (
        auth.role() = 'authenticated' AND
        (
            auth.jwt() ->> 'role' = 'admin' OR
            auth.jwt() ->> 'rol' = 'admin'
        )
    );

-- Política de DELETE para usuarios base
CREATE POLICY IF NOT EXISTS "Administradores pueden eliminar usuarios_base" ON usuarios
    FOR DELETE USING (
        auth.role() = 'authenticated' AND
        (
            auth.jwt() ->> 'role' = 'admin' OR
            auth.jwt() ->> 'rol' = 'admin'
        )
    );

-- Habilitar RLS en la tabla usuarios si no está activado
ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;

-- Confirmar que las políticas estén activas
SELECT 
    schemaname, 
    tablename, 
    policyname, 
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename IN ('vista_gestion_usuarios', 'usuarios');
