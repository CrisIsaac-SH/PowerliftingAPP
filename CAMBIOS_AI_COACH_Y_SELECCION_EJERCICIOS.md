# Documentación de Cambios: AI Coach y Fijación de Ejercicios

Este documento detalla todas las modificaciones realizadas en el proyecto **Powerlifting App**, explicando las causas de las fallas originales y el porqué de cada solución implementada para cumplir con los requerimientos solicitados.

---

## 1. Problema 1: ¿Por qué no detectaba el cuerpo ni las trazas en AI Coach?

### Diagnóstico de las causas:
1. **Incompatibilidad de formato de imagen en Android (`ImageFormatGroup`)**:
   - Por defecto, el plugin `camera` en Android entrega imágenes en formato `YUV_420_888` (código 35).
   - En la capa nativa de Android de `google_mlkit`, el método `InputImage.fromByteArray(...)` de Google ML Kit **únicamente acepta formato NV21 (código 17)**.
   - Al recibir YUV420, Google ML Kit lanzaba internamente una excepción `IllegalArgumentException: Unsupported image format: 35. Only NV21 (17) is supported`. Esto provocaba que cada fotograma cayera en el bloque `catch`, impidiendo que el detector de poses procesara un solo cuadro.
2. **Cálculo de rotación del sensor incompleto**:
   - Se utilizaba directamente `camera.sensorOrientation` sin compensar la orientación del dispositivo (`controller.value.deviceOrientation`) ni la dirección de la cámara (frontal vs trasera).
   - En Android, si la rotación no se compensa, la imagen llega acostada (90° o 270°), y el modelo de ML Kit (entrenado para personas de pie) no reconoce cuerpos humanos en posición horizontal.
3. **Error tipográfico en `PosePainter` y dibujo incompleto**:
   - En `lib/screens/ai_coach/pose_painter.dart` existía un error en la línea 57: `_translateX(cadera.y, ...)` usaba `_translateX` en lugar de `_translateY`, proyectando líneas distorsionadas fuera de pantalla.
   - Solo se evaluaba el lado derecho (`rightHip`, `rightKnee`, `rightAnkle`) y con un umbral excesivamente restrictivo (`likelihood > 0.8`). Si el atleta grababa desde el perfil izquierdo o con iluminación de gimnasio estándar, no se dibujaba nada.
   - No se dibujaba el esqueleto corporal completo ni la traza del movimiento.
4. **Falta de lógica de finalización**:
   - El botón flotante de grabación contenía un comentario vacío (`// Lógica de grabación sin cambios...`) y nunca retornaba los datos ni las métricas analizadas a la pantalla de registro.

---

## 2. Solución Implementada para AI Coach y Detección de Cuerpo

### Archivos modificados:
- [`lib/screens/ai_coach/pose_detector_view.dart`](file:///C:/Users/crist/Desktop/AppPower/powerliftingapp/lib/screens/ai_coach/pose_detector_view.dart)
- [`lib/screens/ai_coach/pose_painter.dart`](file:///C:/Users/crist/Desktop/AppPower/powerliftingapp/lib/screens/ai_coach/pose_painter.dart)
- [`lib/utils/pose_math_utils.dart`](file:///C:/Users/crist/Desktop/AppPower/powerliftingapp/lib/utils/pose_math_utils.dart)

### Cambios realizados y su justificación:

1. **Configuración de formato NV21 en CameraController**:
   - Se configuró:
     ```dart
     imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
     enableAudio: false,
     ```
   - *Por qué:* Garantiza que los fotogramas en Android se capturen en formato `NV21` nativo en un único plano de memoria continuo, permitiendo que Google ML Kit procese el cuerpo fluidamente a 30 FPS sin excepciones ni caídas de memoria.

2. **Compensación exacta de rotación y traslación de coordenadas**:
   - Se implementó `_getImageRotation(CameraDescription camera)` teniendo en cuenta `sensorOrientation`, `deviceOrientation` y si la lente es frontal o trasera.
   - En `PosePainter`, las funciones `_translateX` y `_translateY` ahora contemplan espejado para cámara frontal y mapeo correcto según la rotación de 90°/270° de Android.
   - *Por qué:* Asegura que el modelo vea a la persona verticalmente y que las trazas dibujadas coincidan milimétricamente con el cuerpo del atleta en pantalla.

3. **Confirmación visual de Registro de Cuerpo (Prioridad Solicitada)**:
   - Se agregó un **Badge Dinámico de Estado en tiempo real**:
     - **Verde brillante con sombra**: `¡CUERPO REGISTRADO Y RASTREADO! - Analizando técnica de [EJERCICIO] en vivo` cuando el cuerpo y articulaciones están detectados.
     - **Ámbar**: `BUSCANDO ATLETA... Ubica tu cuerpo completo en el encuadre` cuando el atleta no está en cuadro.
   - *Por qué:* Brinda confirmación inmediata al atleta de que la IA está reconociendo activamente su cuerpo antes y durante el levantamiento.

4. **Trazas corporales completas y Traza de Trayectoria (Bar Path / Body Trail)**:
   - **Esqueleto Base:** Dibuja cabeza, hombros, brazos, torso, caderas, piernas y pies en tono blanco/cian semi-transparente.
   - **Trazas Activas del Ejercicio:** Resalta con líneas gruesas y colores dinámicos (Verde = ROM válido, Ámbar = En recorrido, Rojo = Inicial) las articulaciones clave:
     - **SQUAT:** Cadera -> Rodilla -> Tobillo.
     - **BENCH:** Hombro -> Codo -> Muñeca.
     - **DEADLIFT:** Hombro -> Cadera -> Rodilla -> Tobillo.
   - **Traza de Trayectoria (Motion Path):** Se implementó un historial de puntos (`_trajectoryPoints`) que dibuja una línea brillante con desvanecimiento siguiendo el trayecto de la barra/cuerpo (muñeca en banca, cadera/muñeca en sentadilla y peso muerto), permitiendo analizar el recorrido vertical.
   - **Etiqueta flotante:** Muestra el ángulo actual en grados y el estado técnico directamente junto a la articulación activa en tiempo real.

5. **Detección adaptable de perfil (Izquierda / Derecha)**:
   - `PoseMathUtils.obtenerLadoMasVisible` compara automáticamente la visibilidad de las articulaciones del lado derecho e izquierdo.
   - *Por qué:* El usuario puede filmarse desde cualquier ángulo en el gimnasio y la app rastreará el lado visible automáticamente sin requerir configuración manual.

---

## 3. Reducción de Sensibilidad y Sistema de "Bloqueo de Traza Corporal"

### Diagnóstico de la sensibilidad:
- Al procesar fotograma a fotograma sin filtro temporal, las coordenadas de los landmarks oscilan levemente (ruido óptico y temblores musculares menores de 5 a 10 píxeles).
- Esto provocaba que los ángulos fluctuaran rápidamente y que el algoritmo cambiara erráticamente entre perfil izquierdo y derecho.

### Soluciones implementadas para estabilizar y "Bloquear la Traza":
1. **Filtro de Suavizado Temporal Exponencial (EMA - Exponential Moving Average)**:
   - Se implementó `PoseMathUtils.suavizarValor(...)`:
     ```dart
     static double suavizarValor(double nuevoValor, double valorAnterior, double factor)
     ```
   - Cada articulación y el ángulo articular calculado se filtran continuamente con amortiguación temporal. Las variaciones bruscas de 1 fotograma quedan neutralizadas, manteniendo una respuesta fluida pero estable.
2. **Botón y Modo de "Bloquear Traza" (`_isLocked`)**:
   - En la cámara se incorporó el botón **`[🔒 Bloquear Traza]` / `[Desbloquear]`**:
     - Al activarlo, el sistema **congela el lado de seguimiento (`_lockedSide`)**: nunca más alternará entre perfil izquierdo y derecho durante el ejercicio.
     - Aplica un filtro de máxima estabilidad (`alpha = 0.40`), fijando las líneas del esqueleto firmemente sobre el atleta sin vibraciones.
     - Cambia el badge superior a color cian: `🔒 TRAZA BLOQUEADA (ALTA ESTABILIDAD)`.
3. **Filtro de Ruido en Trayectoria (Noise Gate)**:
   - La traza del movimiento (Bar Path) solo registra un nuevo punto si el desplazamiento real es mayor a $3.5\text{ px}$. Si el atleta está quieto en la posición inicial, no se genera una maraña de puntos por micro-vibraciones.
4. **Debounce e Histéresis en el Contador de Repeticiones**:
   - Se exige una duración mínima por repetición ($\ge 900\text{ ms}$) mediante `_tiempoInicioRep`.
   - Se exige que la profundidad se mantenga por al menos 2 fotogramas consecutivos antes de darla por válida.
   - Para cerrar la repetición, el ángulo debe volver a subir limpiamente por encima de $148^\circ-150^\circ$. Esto impide que micro-movimientos o temblores cuenten repeticiones fantasmas.

---

## 4. Preview del Ejercicio del Atleta antes de Guardar la Serie

Se crearon dos instancias de previsualización para que el atleta pueda revisar minuciosamente su desempeño antes de guardar la serie:

### A. Modal BottomSheet de Preview en `PoseDetectorView`:
- Al presionar **"VER PREVIEW Y FINALIZAR"**, se despliega una vista previa modal interactiva que incluye:
  1. **Miniatura gráfica del Bar Path / Trayectoria**: Mediante `TrajectoryMiniPreviewPainter`, se dibuja el gráfico real del recorrido vertical de la barra/cuerpo con cuadrícula milimétrica, punto de inicio verde y punto final cian.
  2. **Tarjetas de Estadísticas**:
     - Total de repeticiones detectadas.
     - Repeticiones válidas con ROM reglamentario.
     - Mejor ángulo / profundidad lograda (en grados).
  3. **Evaluación Técnica Cualitativa**: Diagnóstico automático (ej. *"¡Excelente técnica y ROM completo!"*).
  4. **Acciones**: Botón *"Continuar"* (para seguir entrenando o agregar reps) y botón *"VINCULAR A LA SERIE"*.

### B. Sección de Preview Permanente en `RecordSetScreen`:
- Al regresar a `RecordSetScreen`, aparece una tarjeta dedicada:
  - **`PREVIEW DEL EJERCICIO - [SQUAT / BENCH / DEADLIFT] [Listo para guardar]`**.
  - Muestra la curva visual del Bar Path capturada por la IA.
  - Tabla de resumen con: Carga Levantada, 1RM Estimado, Repeticiones IA (Totales vs Válidas), Ángulo de profundidad y Evaluación de Técnica.
- **Diálogo de Confirmación Final**:
  - Al pulsar el botón principal **"GUARDAR SERIE"**, se despliega un diálogo de confirmación con el resumen completo para evitar guardados accidentales. Una vez confirmado, los datos y métricas (`ai_metrics`) se guardan en Supabase.

---

## 5. Problema 2: Ejercicio fijo desde HomeScreen a RecordSetScreen

### Diagnóstico de la situación previa:
- Al tocar SQUAT, BENCH o DEADLIFT en `home_screen.dart`, se pasaba `initialExercise: title`, pero en `record_set_screen.dart` se mostraba un desplegable editable (`DropdownButtonFormField`), permitiendo modificar la selección y obligando a seleccionar de nuevo si no coincidía el nombre con la base de datos.

### Cambios realizados en [`lib/screens/record_set_screen.dart`](file:///C:/Users/crist/Desktop/AppPower/powerliftingapp/lib/screens/record_set_screen.dart):
1. **Eliminación del menú desplegable (`DropdownButtonFormField`)**:
   - Se removió por completo la sección de selección.
2. **Tarjeta de Ejercicio Fijado**:
   - Se creó un componente estilizado que muestra claramente:
     - Icono de barra/mancuerna.
     - Etiqueta `EJERCICIO SELECCIONADO`.
     - Nombre del ejercicio previamente seleccionado en mayúsculas (`SQUAT`, `BENCH`, `DEADLIFT`).
     - Badge con candado: `[🔒 Fijo]`.
3. **Mapeo inteligente con Supabase**:
   - La función `_fetchExercises()` busca equivalencias en español e inglés (`squat`/`sentadilla`, `bench`/`banca`, `deadlift`/`muerto`).
   - Asigna el `id` correspondiente de forma fija para la posterior inserción en la tabla `sets`.
4. *Por qué:* Cumple exactamente con la solicitud del usuario de que el ejercicio sea inmutable en esa pantalla, indicando únicamente el previamente elegido.

---

## 6. Problema 3: Detección según el ejercicio guardado (Squat, Bench, Deadlift)

### Cambios realizados:
1. **Comunicación entre pantallas**:
   - Al pulsar "Grabar con IA Coach", `RecordSetScreen` le pasa el ejercicio fijado a `PoseDetectorView`:
     ```dart
     PoseDetectorView(exercise: widget.initialExercise ?? _nombreEjercicioMostrado)
     ```
2. **Análisis Biomecánico Diferenciado en `PoseMathUtils`**:
   - **SQUAT (Sentadilla):**
     - Evalúa el ángulo de flexión de rodilla (`Cadera -> Rodilla -> Tobillo`).
     - Rango válido: Ángulo $\le 88^\circ$ (rompe la paralela competitiva de powerlifting).
     - Traza de seguimiento: Trayectoria vertical de cadera.
   - **BENCH (Press de Banca):**
     - Evalúa el ángulo de flexión de codo (`Hombro -> Codo -> Muñeca`).
     - Rango válido: Ángulo $\le 92^\circ$ (barra en contacto con el pecho).
     - Bloqueo: Ángulo $\ge 155^\circ$ (brazos extendidos).
     - Traza de seguimiento: Trayectoria de la barra a través de la muñeca.
   - **DEADLIFT (Peso Muerto):**
     - Evalúa extensión de cadera (`Hombro -> Cadera -> Rodilla`) y de rodilla (`Cadera -> Rodilla -> Tobillo`).
     - Rango válido: Ambos ángulos $\ge 160^\circ$ (bloqueo completo de rodillas y cadera erguida).
     - Traza de seguimiento: Trayectoria de la barra / muñeca desde el suelo hasta el bloqueo.
3. **Tarjeta de Resumen de IA en RecordSetScreen**:
   - Al volver de la cámara, se presenta una tarjeta con:
     - Check verde: `Análisis completado para [EJERCICIO]`.
     - Repeticiones detectadas por la IA y repeticiones válidas.
     - Mejor ángulo alcanzado durante la serie.
     - Confirmación de registro de cuerpo: `Confirmado y bloqueado`.
     - Auto-rellenado del campo de repeticiones si estaba vacío.
4. **Almacenamiento en Supabase**:
   - El objeto JSON `ai_metrics` (incluyendo repeticiones, mejor ángulo, evaluación técnica y puntos de trayectoria) se inserta directamente en la tabla `sets`.

---

## 7. Resumen de Archivos Modificados

| Archivo | Tipo de Cambio | Propósito |
| :--- | :--- | :--- |
| [`lib/utils/pose_math_utils.dart`](file:///C:/Users/crist/Desktop/AppPower/powerliftingapp/lib/utils/pose_math_utils.dart) | Modificación y Ampliación | Soporte para Squat, Bench y Deadlift, suavizado EMA anti-sensibilidad, fijación de lado (`ladoBloqueado`) y cálculo de ROM. |
| [`lib/screens/ai_coach/pose_painter.dart`](file:///C:/Users/crist/Desktop/AppPower/powerliftingapp/lib/screens/ai_coach/pose_painter.dart) | Reescritura Completa | Soporte para coordenadas suavizadas (`smoothedOffsets`), indicador visual de bloqueo (`isLocked`), esqueleto completo y trazas de ejercicio. |
| [`lib/screens/ai_coach/pose_detector_view.dart`](file:///C:/Users/crist/Desktop/AppPower/powerliftingapp/lib/screens/ai_coach/pose_detector_view.dart) | Reescritura Completa | Botón de bloqueo de traza, amortiguación temporal anti-vibración, debounce en reps, y modal de preview con miniatura gráfica del Bar Path. |
| [`lib/screens/record_set_screen.dart`](file:///C:/Users/crist/Desktop/AppPower/powerliftingapp/lib/screens/record_set_screen.dart) | Modificación | Ejercicio fijo no editable (sin desplegable), sección interactiva de "Preview del Ejercicio" con minicarta de trayectoria y diálogo de confirmación. |

---

## 8. Guía de Prueba Rápida

1. **Abrir la app** y dirigirse a `HomeScreen`.
2. **Seleccionar uno de los 3 ejercicios** (ejemplo: tocar la tarjeta de **SQUAT**).
3. **Verificar pantalla de registro**:
   - Observarás que no hay selector desplegable; aparece el banner `EJERCICIO SELECCIONADO: SQUAT [🔒 Fijo]`.
4. **Tocar "Grabar con IA Coach"**:
   - La cámara se iniciará en tiempo real en formato NV21 optimizado.
   - Al colocarte en el encuadre, aparecerá el badge verde `¡CUERPO REGISTRADO Y RASTREADO!`.
   - Presiona el botón **`[Bloquear Traza]`** en el badge para fijar el cuerpo y anclar la postura (el badge cambiará a cian `🔒 TRAZA BLOQUEADA`). Observarás que la sensibilidad disminuye radicalmente y el esqueleto queda perfectamente estabilizado.
   - Realiza tus repeticiones: el contador utiliza histéresis y filtro temporal, evitando falsos conteos.
5. **Presionar "VER PREVIEW Y FINALIZAR"**:
   - Se abrirá la ventana de previsualización mostrando el gráfico de la curva del movimiento (Bar Path), tus repeticiones válidas y el ángulo de profundidad.
   - Pulsa **"VINCULAR A LA SERIE"**.
6. **Revisar Preview en RecordSetScreen y Guardar**:
   - Verás la tarjeta `PREVIEW DEL EJERCICIO` con el gráfico y los datos listos para registrar.
   - Pulsa **"GUARDAR SERIE"** -> se abrirá el diálogo de confirmación final antes de enviar a Supabase.
