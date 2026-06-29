-- El retiro del capitán SÍ se guarda en liquidaciones, pero el admin no lo veía:
-- la policy usaba auth.jwt() ->> 'role' (= 'authenticated'), no user_metadata.role ni email admin.

DROP POLICY IF EXISTS "Admin puede ver todas las liquidaciones" ON public.liquidaciones;

CREATE POLICY "Admin puede ver todas las liquidaciones"
ON public.liquidaciones
FOR ALL
USING (
  (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
  OR (auth.jwt() ->> 'email') = 'admin@capitanya.com'
  OR EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = auth.uid()
      AND p.admin = true
  )
)
WITH CHECK (
  (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
  OR (auth.jwt() ->> 'email') = 'admin@capitanya.com'
  OR EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = auth.uid()
      AND p.admin = true
  )
);

-- Admin necesita leer billeteras al armar el panel (saldo retenido / validación)
DROP POLICY IF EXISTS "Admin lee billeteras capitanes" ON public.billetera_capitanes;
CREATE POLICY "Admin lee billeteras capitanes"
ON public.billetera_capitanes
FOR SELECT
USING (
  (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
  OR (auth.jwt() ->> 'email') = 'admin@capitanya.com'
  OR EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = auth.uid()
      AND p.admin = true
  )
);
