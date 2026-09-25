# Detox — propuesta de identidad

**Marca:** Detox · **Desarrolladora:** Nerqova · **Aplicación:** `com.nerqova.detox`

La propuesta mantiene el carbón y el verde salvia que ya aparecen en la interfaz. Las formas son planas y geométricas para que el símbolo siga siendo reconocible en un icono pequeño.

## Cinco conceptos

| Concepto | Idea principal | Por qué representa Detox | Como icono de app |
| --- | --- | --- | --- |
| **01 · D Anillo** | Una D geométrica, abierta como un anillo de progreso, con un punto de atención en el centro. | Une identidad, control del tiempo y claridad mental. La abertura da aire a la forma. | Una silueta única, reconocible sobre carbón incluso a 32 px. |
| **02 · Pausa orbital** | Dos barras de pausa dentro de un círculo parcialmente recorrido. | Expresa la decisión de detener el uso impulsivo y administrar el tiempo. | Se lee inmediatamente, aunque es menos distintivo que la D. |
| **03 · Foco** | Cuatro esquinas suaves enmarcan un punto. | Dirige la atención hacia lo importante y reduce el ruido alrededor. | Muy nítido a escala pequeña; funciona como símbolo de enfoque independiente. |
| **04 · Equilibrio** | Dos curvas simétricas separadas por una línea serena. | Evoca el balance entre actividad digital y descanso. | Tiene un ritmo visual calmado y se reconoce por simetría. |
| **05 · Ruido a calma** | Cuatro señales decrecen hasta convertirse en un punto. | Visualiza la reducción gradual de estímulos digitales. | Es simple y visible, con una lectura cercana a una señal de actividad. |

La comparación está en [conceptos.svg](conceptos.svg) y [conceptos.png](conceptos.png). Cada concepto también tiene su propio SVG editable.

## Dirección elegida: D Anillo

La **D** vincula el símbolo con Detox sin necesitar texto. Su borde abierto sugiere un anillo de progreso y una pausa. El punto interior representa la atención puesta en un solo lugar. El dibujo usa un trazo grueso, dos formas y un solo color; no depende de brillos, gradientes ni detalles finos.

### Archivos finales

| Archivo | Uso |
| --- | --- |
| `logo_principal.svg` | Logotipo transparente para superficies oscuras. |
| `isotipo.svg` | Símbolo sin texto en verde profundo, para superficies claras. |
| `isotipo_oscuro.svg` | Símbolo sin texto en salvia, para superficies oscuras. |
| `app_icon.svg` / `app_icon.png` | Icono de 512 × 512 con fondo carbón completo. La máscara redondeada la aplica la plataforma. |
| `app_icon_claro.svg` / `app_icon_claro.png` | Variante de icono sobre fondo claro. |
| `adaptive_foreground.svg` | Símbolo transparente centrado para un icono adaptable de Android. |
| `logo_fondo_claro.svg` / `.png` | Presentación sobre el fondo claro de la app. |
| `logo_fondo_oscuro.svg` / `.png` | Presentación sobre el fondo oscuro de la app. |

Los archivos SVG se pueden importar directamente en Figma. El isotipo y los iconos usan trazos y formas vectoriales. La palabra «Detox» permanece como texto editable con `Segoe UI` y alternativa `Arial`; al preparar archivos para imprenta o compartirlos con terceros, conviene convertir ese texto a contornos dentro de Figma.

### Especificaciones

- Fondo oscuro: `#0B110F`
- Verde salvia: `#8BC7AE`
- Verde profundo: `#426A59`
- Texto claro: `#E8EDEA`
- Fondo claro: `#F4F7F3`
- Texto oscuro: `#202B26`
- Retícula del icono: 256 × 256 unidades; trazo principal: 17 unidades.
- Zona ocupada por el símbolo: aproximadamente el 52 % del ancho del icono, para conservar aire al aplicarse la máscara del sistema.

La propuesta permanece disponible como archivos de diseño. La app usa su logo anterior.

Para regenerar los SVG y las vistas previas: `python docs/brand/detox-logo/generate.py` y `python docs/brand/detox-logo/export_previews.py`. Para volver a aplicar el icono a Flutter y Android: `python docs/brand/detox-logo/apply_to_app.py`.
