# Diseño visual de Vitrina Local

Se aplicó la habilidad frontend-design, ya instalada en el entorno, después de buscar y verificar su fuente en https://skills.sh/anthropics/skills/frontend-design. Su repositorio es https://github.com/anthropics/skills. No se instaló ni actualizó una habilidad global.

La dirección visual es una guía editorial de barrio: papel cálido, verde bosque, terracota y detalles miel. Fraunces se usa en titulares y Manrope en navegación, formularios y lectura. Ambas fuentes se incluyen localmente con sus licencias SIL Open Font License en assets/fonts; la app no depende de descargas de fuentes al iniciar.

El inicio incluye una ilustración vectorial de comercios y montañas. Las fichas sin fotografía muestran una ilustración identificada como tal. Los archivos se dibujan con CustomPainter y mantienen su nitidez en distintos tamaños. Las fotos reales de los negocios tienen prioridad cuando están disponibles.

Las tarjetas de negocios tienen categoría, título, descripción breve y zona. La interacción con mouse usa una transición de borde y sombra, desactivada cuando el sistema solicita reducir animaciones. Los filtros se desplazan horizontalmente en móvil. La barra inferior conserva las etiquetas de navegación; en escritorio se utiliza un menú lateral. Acceso y edición usan anchos máximos menores para mejorar la lectura.

Archivos principales:

- lib/core/visual_theme.dart: colores, tipografía y componentes Material.
- lib/features/discovery_widgets.dart: portada, tarjetas de negocios y publicaciones.
- lib/features/neighborhood_art.dart: ilustraciones vectoriales.
- lib/features/shared.dart: componentes compartidos y estados vacíos.
- test/visual_layout_test.dart: comprobaciones de diseño a 320 y 1440 píxeles.

No se modificaron los permisos, las reglas Firebase ni los procesos de solicitud y aprobación.
