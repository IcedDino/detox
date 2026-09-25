# Auditoría UI/UX y sistema de diseño de Detox

Fecha: 2026-09-24. La interfaz está implementada en Flutter; el código Kotlin de `android/` presta servicios nativos. Flutter usa Material 3 mediante `ThemeData(useMaterial3: true)`.

## Inventario y propósito

| Pantalla | Propósito | Diagnóstico |
| --- | --- | --- |
| Acceso y registro | Entrar o crear cuenta | Dos pestañas y un enlace inferior repiten la misma elección. Los formularios sí tienen etiquetas y validación, pero los errores remotos solo aparecen en un snackbar. |
| Permiso de uso | Explicar y conceder Usage Access | La acción está clara, pero el icono grande, brillo y emoji compiten con la explicación. No se muestra un error local si Android no abre Ajustes. |
| Inicio | Ver uso de hoy y comenzar una sesión | El dato principal es claro. “App principal” se repite debajo en la lista; la tarjeta principal y los accesos de configuración ocupan demasiado alto. |
| Enfoque | Elegir duración/modo, iniciar y seguir una sesión | El temporizador domina bien. El anillo y círculo decorativo toman mucho espacio; duración aparece en el centro y en el selector. La lista completa de apps desplaza la acción. |
| Estadísticas | Entender tendencia y meta semanal | Cabecera, tarjeta de resumen, tendencia, dos métricas y meta repiten conclusiones. El error de carga se confunde con ausencia de datos. |
| Ajustes | Gestionar cuenta, límites, bloqueo, zonas y preferencias | Es una lista muy larga. Hay tarjetas anidadas, título y descripción duplicados para horarios y padrino, y muchos controles simultáneos por fila. Iconos de agregar, editar y borrar necesitan nombres accesibles. |
| Horarios | Crear presets y reglas automáticas | El título de AppBar se repite en la cabecera; cada regla tiene varias insignias y texto repetido. El botón de agregar carece de descripción. |
| Zonas y selector de apps | Crear zonas y elegir apps bloqueadas | Hojas densas con decisiones relacionadas. Mantener selección, búsqueda y confirmación visibles; reducir contenedores anidados y rotular acciones. |
| Padrino | Vincular persona, atender solicitudes y pedir pausas | Introducción extensa y AppBar duplicada; múltiples tarjetas con estados repetidos. Las solicitudes requieren estados textuales además de color. |
| Registro por pasos (`CreateAccountScreen`) | Flujo alternativo de registro | No tiene ruta desde la navegación actual. Conserva una estética azul distinta, usa gestos sin semántica y no adapta bien el teclado. Tratarlo como deuda aislada mientras no sea alcanzable. |

## Hallazgos transversales

- **Jerarquía y carga cognitiva:** una tarea principal por pantalla, pero subtítulos, insignias, iconos decorativos y tarjetas anidadas igualan visualmente contenido principal y secundario.
- **Redundancia y densidad:** Inicio duplica la app principal; Estadísticas expresa la tendencia y la meta varias veces; Ajustes y pantallas secundarias repiten títulos y explicaciones. El sistema debe usar una sola superficie por grupo y una sola frase por estado.
- **Navegación:** cuatro destinos inferiores son apropiados. El `PageView` permite deslizar lateralmente, lo que puede activarse por accidente y competir con volver; los destinos deben cambiarse desde la barra. Las rutas secundarias conservan volver en AppBar.
- **Touch y una mano:** la barra inferior y acciones de inicio/enfoque están al alcance del pulgar. Los iconos de ajustes y algunos controles personalizados necesitan objetivos de al menos 48 dp, separación y `tooltip`; la acción principal debe permanecer antes de contenido largo.
- **Accesibilidad:** faltan etiquetas en iconos de acción y significado en algunos iconos; etiquetas pequeñas y tonos apagados necesitan mayor contraste. El escalado de texto debe poder envolver títulos y controles. Estados de carga, vacío y error deben ser distintos.
- **Material 3 y consistencia:** ya existe Material 3, pero estilos manuales de tarjetas, gradientes y botones crean un lenguaje paralelo. Usar `ColorScheme`, componentes Material, estados de presión y tokens compartidos.

## Sistema de diseño: Detox Calma

UI/UX Pro Max aporta mínimos de 48 dp para Android, 8 dp entre objetivos, contraste de texto de 4.5:1, semántica y estado de carga/error. Su propuesta automática de claymorphism no encaja con una app de bienestar poco saturada; se conserva la dirección serena existente y se eliminan adornos.

1. **Estructura:** fondo uniforme; una superficie tonal por grupo funcional; evitar tarjeta dentro de tarjeta. Márgenes horizontales de 20 dp en teléfono; grupos separados por 24 dp; elementos por 8 o 12 dp.
2. **Tipografía:** cifra principal 42 sp, encabezado 22 sp, sección 18 sp, cuerpo 15–16 sp, ayuda 13–14 sp. Peso 600 como máximo habitual. Títulos y textos pueden envolver con escalado del sistema.
3. **Color semántico:** `ColorScheme` para fondo, superficie, texto, borde, primario y estados. Verde solo para progreso/éxito, ámbar para advertencia y rojo para error. Contraste verificable en claro y oscuro.
4. **Componentes:** `AppPageHeader` con título y subtítulo solo cuando aportan contexto; `SectionTitle` para grupos; `GlassCard` como superficie plana; `SoftActionTile` como fila única; `StatusPill` solo para estado vivo; botones Material 3 con área mínima de 48 dp.
5. **Interacción:** navegación inferior estable, gesto vertical para contenido; acciones de una fila con nombre accesible; estados de carga, vacío y error separados y recuperación visible. La acción primaria se presenta antes de datos secundarios.

## Plan de simplificación

1. Aplanar fondo y superficies compartidas, eliminar iconos decorativos y subtítulos redundantes sin tocar servicios.
2. Reducir Inicio a uso/meta, acción y lista; Enfoque a temporizador, decisiones y acción; Estadísticas a una conclusión, gráfico y objetivo.
3. En Ajustes, convertir enlaces secundarios en filas simples, reducir anidamiento, explicitar botones de agregar y rotular acciones de zonas/apps.
4. Simplificar cabeceras de Horarios y Padrino, y dejar el permiso con una explicación y una acción.
5. Verificar con `flutter analyze` y las pruebas existentes; revisar visualmente tamaños pequeños, escalado de texto y modos claro/oscuro donde haya emulador disponible.

## Implementación y verificación

- Fondo y superficies compartidas aplanados; mayor tamaño de texto auxiliar y colores de Material 3 definidos por rol. Contraste calculado: texto secundario oscuro sobre tarjeta 5.68:1; primario sobre superficie clara 6.11:1.
- Inicio conserva uso, meta, una acción y lista de apps; se retiró la app principal duplicada. Enfoque perdió adornos del temporizador y contrae la lista de apps. Estadísticas distingue error de estado vacío y presenta una sola conclusión semanal.
- Ajustes y Horarios eliminan superficies anidadas y títulos repetidos. Padrino usa la barra de navegación como título. Acceso y permiso tienen menos opciones duplicadas y adornos. Se añadieron nombres accesibles a acciones y controles relevantes.
- La navegación entre las cuatro secciones permanece en la barra inferior; se deshabilitó el cambio por deslizamiento lateral para evitar activaciones accidentales.
- `dart analyze` en UI: cero errores y cero advertencias; quedan avisos informativos previos de estilo/API. `flutter test --no-pub`: seis pruebas superadas. No hay emulador Android conectado, así que falta la comprobación visual y de TalkBack en un dispositivo real.
