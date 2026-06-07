-- Crear tabla de artículos para el blog oficial de pesca de Capitán-YA
CREATE TABLE IF NOT EXISTS blog_articulos (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    titulo VARCHAR(200) NOT NULL,
    resumen TEXT NOT NULL,
    contenido TEXT NOT NULL,
    autor VARCHAR(100) NOT NULL,
    minutos_lectura INTEGER DEFAULT 5,
    imagen_portada TEXT NOT NULL,
    categoria VARCHAR(50) DEFAULT 'Guías',
    productos_sugeridos TEXT[] DEFAULT '{}',
    fuente_url TEXT,
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear índices para optimización de búsquedas y ordenamiento
CREATE INDEX IF NOT EXISTS idx_blog_articulos_activo ON blog_articulos(activo);
CREATE INDEX IF NOT EXISTS idx_blog_articulos_categoria ON blog_articulos(categoria);
CREATE INDEX IF NOT EXISTS idx_blog_articulos_created_at ON blog_articulos(created_at);

-- Crear trigger para actualizar el campo updated_at automáticamente
CREATE OR REPLACE FUNCTION trigger_set_timestamp_blog()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_blog_articulos_timestamp
    BEFORE UPDATE ON blog_articulos
    FOR EACH ROW
    EXECUTE FUNCTION trigger_set_timestamp_blog();

-- Insertar artículos de semilla (pesca deportiva argentina y novedades)
INSERT INTO blog_articulos (titulo, resumen, contenido, autor, minutos_lectura, imagen_portada, categoria, productos_sugeridos, fuente_url) VALUES
(
    '🎣 El regreso de los gigantes: Pesca de Dorado en Paso de la Patria',
    'El río Paraná presenta condiciones óptimas y se registran capturas históricas de dorados de gran porte en la provincia de Corrientes. Conocé las mejores técnicas y carnadas para esta semana.',
    '# El regreso de los gigantes: Pesca de Dorado en Paso de la Patria

El río Paraná a la altura de Paso de la Patria, Corrientes, está pasando por un momento extraordinario. Tras las variaciones del caudal de agua en las últimas semanas, los bancos de arena y los veriles profundos se han convertido en el escenario ideal para el acecho del gran "Tigre de los Ríos".

## Técnicas recomendadas para esta semana
Durante los últimos días, los guías de la zona reportaron excelentes resultados utilizando dos modalidades principales:
* **Trolling (Arrastre):** Utilizando señuelos de paleta profunda (de 15 a 20 pies) en colores llamativos como el cardenal (cabeza roja, cuerpo blanco) o tonos verde limón. Es crucial mantener una velocidad de arrastre baja (aproximadamente 3 a 5 km/h a favor de la corriente).
* **Pesca al golpe (Casting):** Lanzando señuelos de media agua o subsuperficiales contra las piedras y las ramas caídas de la costa. Esta técnica requiere gran precisión pero ofrece las batallas más explosivas.

> **Tip del Capitán:** Los ejemplares más grandes se están registrando en las horas de menor sol, temprano por la mañana (de 06:30 a 09:00 hs) y al caer la tarde. 

## Carnada viva vs. Señuelos
Aunque los señuelos artificiales están dando muy buenas capturas, la carnada viva sigue siendo la reina de la efectividad. La **mamacha** (o anguila grande) y el **cascarudo** presentados con líneas de un solo anzuelo 8/0 y un líder de acero de 40 lbs son una apuesta segura para tentar a los dorados que superan los 12 kilogramos.',
    'Capitán Daniel',
    5,
    'https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=800&h=450&fit=crop',
    'Guías de Pesca',
    '{}',
    'https://sentilapesca.com.ar'
),
(
    '🎒 Guía Definitiva: Cómo elegir tu primer equipo de pesca variada de río',
    '¿Querés iniciarte en la pesca de río y no sabés qué comprar? Te explicamos de manera simple cómo armar un equipo versátil sin gastar una fortuna.',
    '# Guía Definitiva: Cómo elegir tu primer equipo de pesca variada de río

Iniciarse en la pesca deportiva es un camino de ida, pero el primer obstáculo suele ser la elección del equipamiento. En las tiendas encontramos cientos de cañas y reels con términos técnicos confusos. En esta guía te simplificamos la elección para que compres tu primer equipo versátil de variada de río (ideal para bagres, armados, bogas y tarariras).

## 1. La Caña: Resistencia y Sensibilidad
Para la pesca variada en ríos interiores de Argentina (como el Paraná, Uruguay o el Río de la Plata), buscamos una caña de acción media a media-rápida.
* **Medida ideal:** Entre 2.10 y 2.40 metros. Si pescás desde costa, una caña más larga te ayudará a lanzar más lejos. Si pescás embarcado, una de 2.10 metros es más cómoda.
* **Material:** Fibra de vidrio (más económica y extremadamente resistente a los golpes) o grafito compuesto (más ligera y sensible para sentir los piques sutiles de la boga).
* **Libraje:** Una caña de 10 a 20 libras es el estándar perfecto de versatilidad.

## 2. El Reel: Frontal o Rotativo
Como principiante, tu mejor opción es un **reel frontal de tamaño 3000 o 4000**.
* **¿Por qué frontal?** Son extremadamente fáciles de usar, no generan las temidas "galletas" (enredos de nylon) al lanzar y tienen un sistema de freno muy dócil.
* **Capacidad:** Debe poder cargar al menos 150 metros de nylon de 0.35 mm o multifilamento de 0.20 mm.

## 3. Accesorios Básicos indispensables
Completá tu equipo con:
- Una caja pequeña con plomadas de 40 a 80 gramos.
- Anzuelos de garras de águila (tamaños del 1 al 3/0).
- Líderes de acero livianos (por si muerde algún cachorro de surubí o doradillo).
- Mosquetones con esmerillón para cambiar las líneas rápido.',
    'Staff Capitán-YA',
    4,
    'https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=800&h=450&fit=crop',
    'Tutoriales',
    '{}',
    NULL
),
(
    '🌊 Reporte de Piques: Espectacular pique de Surubí en Esquina',
    'Las últimas jornadas de pesca en Esquina, Corrientes, dejaron postales increíbles con capturas de surubíes pintados gigantes. Enterate en qué zonas se están concentrando.',
    '# Reporte de Piques: Espectacular pique de Surubí en Esquina

Esquina sigue consolidándose como uno de los pesqueros más rendidores del sur correntino. Durante los últimos 5 días, pescadores locales e invitados registraron una gran cantidad de capturas de surubíes (tanto pintados como atigrados), con portes que oscilaron entre los 8 y los 22 kilogramos.

## ¿Dónde está el pique?
Los mejores spots de la semana se localizaron en:
1. **La desembocadura del Río Corriente sobre el Paraná:** El cruce de aguas genera remolinos ricos en nutrientes que atraen al sábalo, principal alimento del surubí.
2. **Las canaletas profundas del Paraná medio:** Los surubíes están buscando refugio en pozones de entre 8 y 12 metros de profundidad durante las horas del mediodía.

## Carnadas y Señuelos del momento
La modalidad estrella de la semana fue la **pesca a la espera con carnada viva**. 
* **La Carnada de Oro:** El morenón grande encarnado en anzuelo 9/0 con plomo pasante de 60 gramos. La presentación debe ser muy natural, dejando que derive lentamente cerca del fondo.
* **Trolling Nocturno:** Algunos guías experimentados obtuvieron piques espectaculares al caer el sol utilizando señuelos artificiales de colores oscuros (negro/violeta o negro/dorado) que recortan una silueta muy visible contra el cielo nocturno.',
    'Gu-IA Redactora',
    3,
    'https://images.unsplash.com/photo-1504280390367-361c7a9ba8ad?w=800&h=450&fit=crop',
    'Piques de la Semana',
    '{}',
    'https://pescaargentina.com.ar'
);

-- Habilitar RLS (Row Level Security)
ALTER TABLE blog_articulos ENABLE ROW LEVEL SECURITY;

-- Política de lectura pública para artículos activos
CREATE POLICY "Lectura publica de articulos activos" 
ON blog_articulos FOR SELECT 
USING (activo = true);

-- Política de control total para administradores
CREATE POLICY "Administrar articulos completa" 
ON blog_articulos FOR ALL 
USING (auth.jwt() ->> 'role' = 'admin')
WITH CHECK (auth.jwt() ->> 'role' = 'admin');
