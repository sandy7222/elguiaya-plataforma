-- =====================================================================
-- CAPITAN-YA: MÓDULO DE GESTIÓN DE COMISIONISTAS (PROMOTORES)
-- =====================================================================

-- 1. Crear tabla comisionistas
CREATE TABLE IF NOT EXISTS public.comisionistas (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    nombre VARCHAR(255) NOT NULL,
    dni VARCHAR(50) NOT NULL,
    cuenta_mp VARCHAR(255) NOT NULL,
    codigo_comision VARCHAR(100) NOT NULL UNIQUE,
    estado VARCHAR(50) DEFAULT 'activo' CHECK (estado IN ('activo', 'pausado')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS (Row Level Security)
ALTER TABLE public.comisionistas ENABLE ROW LEVEL SECURITY;

-- 2. Crear Políticas de Seguridad RLS
-- Permitir lectura pública de códigos de comisionistas para validación en registro
CREATE POLICY "Permitir lectura publica de comisionistas" 
ON public.comisionistas 
FOR SELECT 
USING (true);

-- Permitir todas las operaciones a administradores autenticados
CREATE POLICY "Permitir gestion completa a administradores" 
ON public.comisionistas 
FOR ALL 
TO authenticated 
USING (true) 
WITH CHECK (true);

-- 3. Crear índices para búsquedas ultra rápidas
CREATE INDEX IF NOT EXISTS idx_comisionistas_codigo ON public.comisionistas(codigo_comision);
CREATE INDEX IF NOT EXISTS idx_comisionistas_dni ON public.comisionistas(dni);

-- 4. Insertar datos semilla de prueba
INSERT INTO public.comisionistas (nombre, dni, cuenta_mp, codigo_comision, estado)
VALUES 
('Sebastián Promociones', '38450123', 'seba.mp@gmail.com', 'SEBA8020', 'activo'),
('Martín Referidos', '35678912', 'martin.pagos.mp@gmail.com', 'TINCHO90', 'activo'),
('Paula Patagonia', '40123456', 'paula.patagonia.mp@gmail.com', 'PAULA10', 'pausado')
ON CONFLICT (codigo_comision) DO NOTHING;
