# Detox — rediseño del símbolo

**Marca:** Detox · **Desarrolladora:** Nerqova · **Paquete:** `com.nerqova.detox`

Este directorio contiene el rediseño del logotipo **en uso** en la app: el icono
cian con degradado sobre negro que aparece en `assets/images/detox_logo.png`.
No modifica todavía el proyecto Flutter; entrega los archivos de diseño.

> Existe una propuesta anterior en [`../detox-logo/`](../detox-logo/) que nunca
> se aplicó. Este rediseño es independiente: no reutiliza sus formas.

## Qué se está reemplazando

Medido directamente sobre el archivo actual, que sigue en el repositorio:

| Dato | Valor |
| --- | --- |
| Formato | PNG de 1.024 × 1.024, 483 KB, 48.806 colores distintos |
| Fondo | Negro casi puro `#020202`, 64 % de los píxeles |
| Tinta | Cian con degradado, media `#5CCDE9`, hasta blanco `#FEFEFF` |
| Relación con la paleta de la app | Ninguna: la app usa salvia `#8BC7AE` sobre `#0B110F` |
| Vector fuente | No existe; ninguna curva se puede corregir ni escalar |

Ese conjunto —fondo negro, degradado cian, brillo— es exactamente el aspecto
genérico de un logo generado por IA. El problema de fondo no es el estilo, sino
que **no hay construcción**: no se puede corregir un trazo, adaptar la marca al
tema claro ni derivar un icono adaptable.

## Dirección elegida: «Umbral»

Una **sala de esquinas redondeadas** —el mismo lenguaje que las tarjetas con las
que está hecha toda la interfaz— con **una sola puerta** en el muro y el
**núcleo dentro**. La idea es literal: el espacio donde las distracciones no
entran, con un único lugar por el que el exterior pasa.

Por qué funciona como marca de Detox:

- **El squircle no es otro círculo.** Los logos de bienestar digital son
  círculos, anillos y escudos. Una silueta cuadrada de esquinas muy redondeadas
  se reconoce a distancia y no se confunde con la competencia.
- **La puerta da asimetría.** Es el detalle que se recuerda, y es lo que impide
  que el símbolo se lea como un simple marco.
- **El núcleo cuenta la promesa.** Es la atención del usuario, protegida.
- **No necesita color para funcionar.** Son dos formas y un relleno plano; sin
  degradados, sin brillos, sin transparencias. Funciona en un sello, en
  grabado, en un icono de notificación y sobre cualquier fondo.

### Construcción

Todo se deriva de números sobre una retícula de 256 × 256, así que cualquier
corrección se hace cambiando un valor, no volviendo a dibujar. La malla está en
`malla_construccion.svg`.

| Elemento | Valor |
| --- | --- |
| Lienzo | 256 × 256 |
| Muro (grosor) | 44 |
| Lado exterior de la sala | 176 (68,75 % del lienzo) |
| Esquina exterior | radio 46 |
| Esquina interior | radio 22 |
| Puerta | 44 de alto × 44 de ancho, en el muro derecho, centrada verticalmente |
| Núcleo | círculo de radio 22, centrado |
| Trazo más estrecho | 22 unidades → 2,75 px a 32 px |
| Primer plano adaptable | escalado a 0,96 → ocupa 66,0 % (límite de Android: 66,7 %) |

La pared, la sala y la puerta son **tres subtrazados de un solo `path` con
`fill-rule="evenodd"`**. Esto significa que la forma no depende del color de
fondo y que se puede recolorear de una vez en Figma o en código.

### La altura de la puerta se deriva, no se elige

El muro interior solo es **recto** en el tramo que queda entre sus dos curvas de
esquina, es decir entre `128 − (44 − 22) = 106` y `128 + (44 − 22) = 150`. La
puerta ocupa exactamente ese tramo.

Esto no es un detalle estético: en la primera versión la puerta medía 48 y su
arista izquierda recta cortaba las curvas de esquina, dejando una **rebaba de
0,25 unidades de ancho** colgando dentro del hueco, arriba y abajo. Se veía como
un corte mal hecho. Ahora `DOOR_HALF` se calcula como `IN_HALF − IN_R`, así que
la arista de la puerta coincide con la del muro y el defecto es imposible por
construcción. De paso, la abertura queda tan alta como grueso es el muro.

`export_previews.py` verifica esta relación en cada ejecución.

### Peso de la esquina

El radio interior no es concéntrico con el exterior. Medido en diagonal, el muro
pasa de 44 unidades en los tramos rectos a 52,3 en la esquina, un 19 % más.

Es una decisión, no un descuido: una esquina algo más pesada hace que el símbolo
se lea como un objeto sólido y amable en lugar de como un anillo de trazo
uniforme. La alternativa es la esquina concéntrica, que da un muro de 44 exactos
en todo el recorrido, pero deja la sala casi cuadrada por dentro:

```python
IN_R = 2.0   # = OUT_R - WALL, muro de grosor uniforme
```

El resto se recalcula solo, porque la puerta se deriva del tramo recto. Es un
cambio de carácter, no una corrección, así que no se ha aplicado.

## Comportamiento a tamaño real

Medido sobre el PNG renderizado, reduciendo el icono con Lanczos:

| Tamaño | Muro | Hueco | Núcleo | Puerta | Resultado |
| --- | --- | --- | --- | --- | --- |
| 128 px | 22 px | 11 px | 22 px | 22 px | Holgado |
| 48 px | 8 px | 4 px | 8 px | 8 px | Holgado |
| 32 px | 5,5 px | 2,75 px | 5,5 px | 5,5 px | Los tres tramos siguen separados |
| 24 px | 4,1 px | 2,1 px | 4,1 px | 4,1 px | Se sigue leyendo |
| 16 px | 2,75 px | 1,4 px | 2,75 px | 2,75 px | Límite práctico; por debajo, usar solo el isotipo |

A 32 y 24 px el perfil central del icono mantiene sus tres tramos de tinta con
la puerta abierta, que es lo que se comprobó explícitamente.

## Color

Tomado de `lib/theme/app_theme.dart`, sin valores nuevos:

| Uso | Valor | Contraste medido |
| --- | --- | --- |
| Salvia sobre carbón | `#8BC7AE` sobre `#0B110F` | 9,88:1 |
| Salvia sobre tarjeta | `#8BC7AE` sobre `#151E1A` | 8,83:1 |
| Salvia suave | `#B7DDCA` sobre `#0B110F` | 12,90:1 |
| Verde profundo sobre claro | `#426A59` sobre `#F4F7F3` | 5,66:1 |
| Tinta sobre carbón | `#E8EDEA` sobre `#0B110F` | 16,10:1 |

Sobre fondo oscuro la marca va en **salvia**; sobre fondo claro, en **verde
profundo**. El núcleo nunca lleva un segundo color: el contraste entre el muro y
el núcleo lo produce el hueco, no la paleta.

## Archivos

| Archivo | Uso |
| --- | --- |
| `isotipo_sobre_oscuro.svg` | Símbolo en salvia, fondo transparente. Uso principal en la app. |
| `isotipo_sobre_claro.svg` | Símbolo en verde profundo, fondo transparente. |
| `isotipo_blanco.svg` | Un solo color blanco. Para fondos de color o fotografía. |
| `isotipo_negro.svg` | Un solo color oscuro. Para impresión y grabado. |
| `icono_app.svg` | Icono de 512 px con fondo carbón a sangre. |
| `icono_app_claro.svg` | Variante sobre el fondo claro de la app. |
| `icono_app_alterno.svg` | Variante sobre el carbón elevado `#101916`. |
| `icono_adaptable_frente.svg` | Primer plano transparente para el icono adaptable de Android, ya escalado a la zona segura. |
| `icono_adaptable_monocromo.svg` | Capa monocroma para los iconos tematizados de Android 13 y posteriores. |
| `aplicar_al_proyecto.py` | Copia todo a los recursos de Flutter y Android. |
| `logo_horizontal_oscuro.svg` | Lockup símbolo + «Detox», fondo transparente. |
| `logo_horizontal_oscuro_fondo.svg` | El mismo lockup sobre carbón sólido. |
| `logo_horizontal_claro.svg` | Lockup sobre el fondo claro. |
| `malla_construccion.svg` | La retícula con sus medidas. Es la referencia para corregir el símbolo. |
| `tablero_direcciones.svg` | Las tres rutas comparadas con su razonamiento. |
| `alternativa_b_ruido_a_calma.svg` | Alternativa: barras que bajan hasta un punto de reposo. |
| `alternativa_c_umbral_circular.svg` | Alternativa: la misma idea en contenedor circular. |
| `prueba_tamanos.png` | El icono a 128, 64, 48, 32 y 24 px. |
| `prueba_comparativa.png` | El logo anterior frente al nuevo. |
| `prueba_monocromo.png` | Uso a un solo color sobre oscuro y sobre claro. |
| `prueba_contraste.png` | Contrastes por fondo. |

Cada SVG tiene su PNG al lado. Los SVG se importan directamente en Figma.

### Sobre la tipografía

«Detox» está como **texto editable** en `Segoe UI` con alternativa `Arial`. Al
preparar archivos para imprenta o para terceros, conviene convertir ese texto a
contornos dentro de Figma.

## Reglas de uso

- **Aire:** no reducir el margen libre por debajo de 16 unidades de la retícula
  (≈ 6 % del icono) en ningún lado.
- **No** añadir degradados, sombras, biseles ni transparencias al símbolo. Con
  un relleno plano ya funciona a 16 px.
- **No** girar el símbolo. La puerta siempre a la derecha: es lo que da la
  orientación.
- Las dos esquinas de la puerta que dan al exterior son **ángulos rectos a
  propósito**. Redondearlas dejaría de nuevo una rebaba, porque la puerta es
  material *retirado* y su curva chocaría con la cara exterior.
- **No** escalar a lo ancho ni a lo alto por separado.
- **Por debajo de 24 px**, usar el isotipo sin núcleo o la versión simplificada
  sin puerta. A ese tamaño el núcleo es más ruido que información.
- El símbolo **nunca** va dentro de otro contenedor redondeado: ya tiene su
  propia esquina.

## Regenerar

Desde la raíz del repositorio:

```bash
python docs/brand/detox-icon/generate.py
python docs/brand/detox-icon/export_previews.py
```

`generate.py` escribe los SVG a partir de las constantes del inicio del archivo.
`export_previews.py` rasteriza con Edge en modo headless y compone las hojas de
verificación. No requiere dependencias más allá de Pillow.

`export_previews.py` no solo exporta: **verifica**. Cada vez que se ejecuta
comprueba que el PNG renderizado coincide con la construcción (posición y grosor
del muro, del núcleo y de la puerta, con tolerancia de 1,5 unidades), que el
primer plano adaptable cabe en la zona segura de Android, que el símbolo y el
texto del lockup comparten centro óptico con márgenes equilibrados y que la
puerta sigue derivándose del tramo recto del muro, que es lo que impide la
rebaba. Si alguien toca una constante y rompe la geometría, el script falla en
vez de generar un archivo silenciosamente incorrecto.

El renderizado se hace envolviendo cada SVG en una página HTML con márgenes a
cero. Abrir un `.svg` directamente hace que Chromium lo trate con su visor de
imágenes, que reescala el dibujo para encajarlo; la página HTML garantiza que el
rasterizado sea 1:1 con la retícula.

## Aplicado a la app

El sistema ya está en uso. Lo aplica:

```bash
python docs/brand/detox-icon/aplicar_al_proyecto.py
```

Es el único script de esta carpeta que escribe fuera de ella. Copia los PNG a
los recursos de Flutter y Android:

| Destino | Origen |
| --- | --- |
| `assets/images/detox_logo.png` | `icono_app.png` |
| `assets/images/detox_symbolo_oscuro.png` | `isotipo_sobre_oscuro.png` |
| `assets/images/detox_symbolo_claro.png` | `isotipo_sobre_claro.png` |
| `mipmap-{mdpi..xxxhdpi}/ic_launcher.png` | 48 a 192 px |
| `mipmap-{mdpi..xxxhdpi}/ic_launcher_round.png` | máscara circular |
| `drawable/ic_launcher_foreground.png` | 432 px, ya en zona segura |
| `drawable/ic_launcher_monocromo.png` | 432 px, para iconos tematizados |
| `drawable-*/splash_symbol.png` y `drawable-night-*/` | símbolo del splash por densidad |
| `mipmap-anydpi-v26/ic_launcher{,_round}.xml` | icono adaptable |

### Cambios hechos a mano, una sola vez

- `drawable/launch_background.xml` y `drawable-v21/launch_background.xml`: el
  fondo pasa a `@color/launch_background` y se centra el símbolo. Antes era
  blanco fijo, así que la app oscura **destellaba en blanco** al abrirse.
- `values/colors.xml` y `values-night/colors.xml`: `#F4F7F3` y `#0B110F`. El
  mismo recurso resuelve bien en claro y en oscuro sin duplicar el layer-list.
- `AndroidManifest.xml`: se añadió `android:roundIcon`.
- `pubspec.yaml`: el bloque `flutter_launcher_icons` apuntaba el primer plano
  adaptable al raster a sangre y usaba `#0F172A`, un azul marino que no está en
  la paleta. Corregido a `#0B110F` y al símbolo transparente, y marcado como
  inerte porque el paquete no es una dependencia declarada.
- `lib/widgets/detox_logo.dart`: ya no enmarca el logo en un contenedor con
  borde ni lo atenúa con `opacity: 0.92`. Dibuja el símbolo transparente en
  salvia o verde profundo según el tema, que es como está diseñado.
- `lib/l10n_app_strings.dart`, `auth_screen.dart`, `settings_screen.dart`: pie
  de marca «Desarrollado por Nerqova» en la pantalla de acceso y en ajustes.

Verificado con `flutter analyze` (0 errores) y con un build real
(`flutter build apk --debug`), comprobando después que el APK contiene el icono
adaptable, las cinco densidades y que no queda ningún píxel del logo cian
anterior.
