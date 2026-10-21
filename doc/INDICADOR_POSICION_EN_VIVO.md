# Indicador de posición en vivo

Este documento describe solo el aviso de mala posición que aparece en la cámara del AI Coach. No describe el conteo de repeticiones que se guarda con la serie, ni la profundidad, ni el bloqueo.

Archivos que implementan la función:

- `lib/utils/form_safety.dart`: decide si hay una mala posición y qué texto mostrar.
- `lib/utils/lift_rules.dart`: guarda los números de corte.
- `lib/utils/pose_math_utils.dart`: mide torso, avance de rodilla, valgo y apertura de codos a partir de los puntos de ML Kit.
- `lib/utils/rep_counter.dart`: decide si la repetición ya empezó. El indicador usa una instancia aparte, `_faseRep`.
- `lib/screens/ai_coach/pose_detector_view.dart`: pinta el cartel.
- `lib/screens/ai_coach/pose_painter.dart`: pone en rojo la traza del ejercicio mientras el cartel de riesgo está visible.

## Qué se tomó en cuenta

1. **El aviso es para evitar una lesión durante el levantamiento, no para calificar la repetición.** Una sentadilla puede romper la paralela y, al mismo tiempo, tener las rodillas hacia adentro. Profundidad y posición de riesgo son cosas distintas. El verde de “forma válida” significa rango de movimiento. El rojo de “mala posición” significa una postura que conviene corregir.

2. **No se avisa en el setup.** Estar de pie, agarrar la barra o acomodarse en el banco produce ángulos que, leídos solos, parecen un error. El cartel de riesgo permanece apagado hasta que el contador de fase marca la repetición como iniciada.

3. **Se reutiliza el mismo criterio de inicio que ya usa el contador de repeticiones.** Sentadilla y banca abren al salir del bloqueo. El peso muerto abre al sostener la posición de abajo. Así el aviso y el conteo no discrepan sobre cuándo “ya empezó”.

4. **Solo se miden cosas que ML Kit puede ver en 2D.** El modelo da hombros, codos, muñecas, caderas, rodillas, tobillos y puntas de los pies. No hay puntos de la columna. Por eso “espalda redonda” es la inclinación del segmento hombro–cadera, no una medición real de flexión lumbar.

5. **La vista de la cámara decide qué se puede juzgar.** De perfil se lee el avance de la rodilla y la inclinación del torso. De frente se lee el valgo y la apertura de los codos. Si la vista no permite esa medida, esa alerta no se inventa: queda en nulo y no se muestra.

6. **Un punto con poca confianza no entra.** Cualquier articulación usada necesita `likelihood` de al menos 0.60. Si falta la cadena del ejercicio, no hay medición de posición en ese frame.

7. **Un salto imposible del ángulo no cuenta como movimiento.** Si el ángulo principal cambia a más de 360° por segundo, ese frame se ignora. Si el valor raro se repite en el frame siguiente, se acepta: era un cambio real.

8. **El cartel no parpadea con un solo frame.** La misma alerta prioritaria tiene que repetirse 3 frames seguidos para encenderse, y tienen que pasar 4 frames limpios para apagarse.

9. **Si hay varias fallas a la vez, en pantalla se muestra una.** Se calculan todas, pero el cartel enseña la de mayor prioridad. El orden está en la sección de cada ejercicio.

10. **El aviso es en vivo y no se guarda.** Funciona en la vista previa y mientras se graba. No se escribe en la serie, no aparece en el resumen de repeticiones y no se redibuja al reproducir el video.

11. **El conteo que se guarda sigue siendo independiente.** Las repeticiones del HUD solo avanzan con la grabación activa. `_faseRep` solo responde si la repetición está abierta, para poder avisar también antes de pulsar Grabar.

## Qué significa cada estado del cartel

El cartel solo se dibuja cuando el cuerpo del ejercicio está detectado.

| Estado | Cuándo | Texto |
| --- | --- | --- |
| Espera | Hay cuerpo, pero la repetición no ha empezado | `ESPERANDO LA REPETICIÓN`. El aviso de lesión aparece cuando la repetición ya empezó. |
| En curso | La repetición empezó y ninguna alerta lleva 3 frames | `REPETICIÓN EN CURSO`. Posición estable. Sigue el recorrido. |
| Mala posición | La repetición empezó y una alerta ya se confirmó | `MALA POSICIÓN` más el mensaje de esa alerta. La traza del ejercicio pasa a rojo. |

Reiniciar el contador desde el botón de refresco también borra la fase y el cartel.

## Cuándo se considera que la repetición ya empezó

El ángulo que abre y cierra la fase es el ángulo principal ya suavizado: rodilla en sentadilla, codo en banca, cadera en peso muerto. Con la traza bloqueada el suavizado es más lento (factor 0.35) que en seguimiento normal (factor 0.50).

Antes de poder abrir, el atleta tiene que quedarse en la posición inicial **500 ms**, sin que el ángulo se mueva más de **12°**. Si se mueve más, la espera vuelve a empezar. Si se pierde el cuerpo, también.

### Sentadilla

- Posición inicial: rodilla a **148° o más** (de pie, bloqueo).
- La repetición empieza cuando, ya armada esa espera, la rodilla baja de **128°**.
- La repetición termina cuando la rodilla vuelve a **148° o más**. Después de la primera, la fase queda armada: el siguiente descenso puede abrir sin otra espera de 500 ms.
- Si la persona empieza a bajar sin haber sostenido antes la posición de pie, la repetición no abre y el cartel se queda en espera. En ese caso tampoco hay aviso de mala posición.

### Banca

- Posición inicial: codo a **150° o más** (brazos extendidos).
- La repetición empieza cuando, ya armada la espera, el codo baja de **120°**.
- La repetición termina cuando el codo vuelve a **150° o más**. Igual que en sentadilla, las siguientes pueden abrir sin repetir la espera.
- Bajar sin haber sostenido el bloqueo deja el cartel en espera.

### Peso muerto

- Posición inicial: cadera por debajo de **120°** (abajo, en el suelo).
- La repetición empieza en cuanto esa posición se sostiene **500 ms** con una variación de 12° o menos. No hace falta que la barra haya dejado el suelo: para este indicador, el tirón ya está abierto desde el setup sostenido.
- La fase sigue abierta durante todo el tirón.
- Se cierra cuando, después de haber llegado al bloqueo, la cadera vuelve a bajar de **120°**. El bloqueo aquí es cadera y rodilla a **160° o más**.
- Al cerrar, la fase se desarma. La siguiente repetición exige otros 500 ms quieto abajo antes de volver a evaluar la posición.

### La fase también se cancela, y con ella el aviso

- Si la cadena del ejercicio falta **1.2 s** con una repetición abierta, esa fase se descarta.
- Si una repetición abierta no cierra en **6 s**, se descarta.
- Un hueco de reloj mayor a **1.5 s** se trata como pausa, no como pérdida del cuerpo: el tiempo de la fase se corre y no se borra por ese salto.
- Si el cuerpo desaparece del todo, el cartel se oculta en ese momento. Por dentro, la alerta tarda 4 frames limpios en olvidarse.

## Qué es una mala posición

Es una medida geométrica del esqueleto 2D que cruza un corte mientras la repetición está abierta. No es un diagnóstico médico y no confirma que haya una lesión. Es una señal para corregir en el momento.

Si la vista o la confianza no permiten medir esa falla, no hay alerta de ese tipo aunque la postura sea mala en la vida real.

### Sentadilla

Prioridad en pantalla, de arriba hacia abajo: valgo, torso, asimetría, rodilla adelantada.

**Rodillas hacia adentro** (`valgus`)

- Mensaje: `Rodillas hacia adentro. Empújalas hacia afuera.`
- Qué mide: cuánto se acerca cada rodilla a la línea media respecto de su tobillo, dividido entre el ancho de cadera. Se usa el lado peor.
- Mala posición: ese valor es **0.18 o más**. Ejemplo: la rodilla está un 18 % del ancho de cadera más cerca del centro que el tobillo.
- Cuándo no se mide: falta hombro, cadera, rodilla o tobillo de algún lado; el torso mide menos de 8 px; o el ancho de cadera es menos del **35 %** de la altura del torso. Ese último caso es un perfil, donde las caderas se superponen y el valgo no se puede leer.

**Torso demasiado adelante** (`torso`)

- Mensaje: `El torso se viene demasiado adelante. Pecho arriba.`
- Qué mide: el ángulo del segmento hombro–cadera contra la vertical. 0° es erguido. Hace falta el hombro del lado que se está siguiendo, con confianza de al menos 0.60.
- Mala posición: **62° o más**.
- Por qué ese corte: en el fondo de una sentadilla el torso se inclina. 62° ya es una inclinación grande, del tipo good morning, con más carga sobre la zona lumbar. Una sentadilla low bar profunda puede acercarse a este número sin ser un error grave; el corte está puesto para avisar tarde y no en cada descenso normal.

**Una rodilla baja más que la otra** (`asymmetry`)

- Mensaje: `Una rodilla baja más que la otra. Reparte el peso.`
- Qué mide: la diferencia absoluta, en grados, entre el ángulo de la rodilla que se sigue y el de la otra. La otra rodilla solo entra si cadera, rodilla y tobillo de ese lado pasan 0.60.
- Mala posición: diferencia de **22° o más**.
- El ángulo del lado seguido está suavizado. El del lado contrario sale del frame crudo. Una diferencia pequeña puede venir de ese desfase, por eso el corte no es de unos pocos grados.

**La rodilla pasa el pie** (`knee_travel`)

- Mensaje: `La rodilla pasa el pie. Siéntate más atrás.`
- Qué mide: cuántas longitudes de espinilla está la rodilla por delante del pie, en horizontal. Positivo significa por delante. Se usa el lado que se está siguiendo.
- Si la punta del pie se ve, tiene confianza, apunta hacia el mismo lado que el tobillo y está a más de 4 px de la cadera, la referencia es la punta. Mala posición: avance de **0.12** o más (un 12 % de la espinilla por delante de los dedos).
- Si la punta no sirve, la referencia es el tobillo y el corte es más alto, **0.42**, porque el pie todavía ocupa un tramo por delante del tobillo. Un avance moderado sobre el tobillo es normal y no se marca.
- Cuándo no se mide: la espinilla mide menos de 8 px, o la separación horizontal entre tobillo y cadera es menos del **35 %** de la espinilla. Eso es una vista frontal: el avance hacia la punta no se distingue y se deja para el valgo.

### Banca

Solo hay una alerta.

**Codos demasiado abiertos** (`elbow_flare`)

- Mensaje: `Codos demasiado abiertos. Acércalos al cuerpo.`
- Qué mide: la distancia entre los dos codos dividida entre la distancia entre los dos hombros. 1.0 sería el mismo ancho. Hacen falta los dos hombros y los dos codos.
- Mala posición: relación de **1.9 o más**. Los codos están casi al doble de ancho que los hombros.
- Cuándo no se mide: el brazo promedio mide menos de 8 px, o el ancho de hombros es menos del **45 %** de ese brazo. Eso ocurre de perfil, cuando un hombro tapa al otro. Desde el lado no se adivina la apertura.
- El ángulo del codo (el que cuenta la repetición y el rango) no decide esta alerta. Se puede tener un recorrido válido con los codos abiertos, y el cartel rojo aparece igual.

### Peso muerto

Prioridad: espalda inclinada, luego cadera que sube primero.

**Espalda muy inclinada** (`round_back`)

- Mensaje: `Espalda muy inclinada. Pecho arriba y espalda neutra.`
- Qué mide: el mismo ángulo hombro–cadera contra la vertical. En peso muerto el hombro forma parte de la cadena obligatoria, así que esta medida existe siempre que el ejercicio se está leyendo.
- Mala posición: **78° o más**. El torso está casi horizontal.
- Límite de esta medida: no distingue una espalda neutra e inclinada de una espalda flexionada. Un peso muerto convencional en el suelo ya va inclinado; 78° es el punto en el que el segmento hombro–cadera se considera demasiado cerrado, no una radiografía de la columna.

**La cadera sube antes que el pecho** (`hip_shoot`)

- Mensaje: `La cadera sube antes que el pecho. Empuja el piso.`
- Qué mide: el ángulo de rodilla (cadera–rodilla–tobillo) contra el ángulo de cadera (hombro–cadera–rodilla).
- Mala posición: rodilla a **150° o más** y, a la vez, cadera por debajo de **140°**. Las piernas ya casi se estiraron y el tronco sigue cerrado: la cadera se adelantó al pecho.
- No se marca en el bloqueo. Ahí los dos ángulos están altos (el bloqueo pide 160° en ambos), así que la cadera ya no está por debajo de 140°.

Como en peso muerto la repetición abre al sostener la posición de abajo, estas dos alertas pueden aparecer antes de que la barra despegue, si esa postura ya cruzó el corte.

## Qué no hace esta función

- No sustituye a un entrenador ni afirma que una posición sea segura.
- No mide la curva lumbar, la rotación de la barra, los talones despegados, la muñeca doblada ni la trayectoria de la barra.
- No usa la profundidad ni el bloqueo como señal de lesión. Esos cortes siguen sirviendo solo para decir si la repetición fue válida.
- No avisa de perfil sobre valgo o codos, ni de frente sobre la rodilla que se pasa del pie.
- No guarda el aviso en la serie ni lo muestra al reproducir el video.
- No enciende el rojo durante la espera inicial, aunque la postura ya se vea comprometida. Esa fue la condición pedida: primero tiene que haber empezado la repetición.

## Dónde cambiar un corte

Todos los números de esta función están en `LiftThresholds`, dentro de `lib/utils/lift_rules.dart`. Los de posición son:

| Constante | Valor | Uso |
| --- | ---: | --- |
| `squatKneePastToe` | 0.12 | Rodilla delante de la punta del pie |
| `squatKneePastAnkle` | 0.42 | Rodilla delante del tobillo, si no se ve el pie |
| `squatValgus` | 0.18 | Rodilla hacia la línea media |
| `squatTorsoRisk` | 62° | Torso de la sentadilla |
| `kneeAsymmetry` | 22° | Diferencia entre rodillas |
| `benchElbowFlare` | 1.9 | Codos contra hombros |
| `deadliftTorsoRisk` | 78° | Torso del peso muerto |
| `deadliftHipShootKnee` | 150° | Rodilla casi extendida en el tirón |
| `deadliftHipShootHip` | 140° | Cadera todavía cerrada en ese mismo momento |

Los de inicio de la repetición, que esta función también obedece, son `setupHoldMs` (500), `setupJitterDegrees` (12), `squatLockout` (148), `squatStart` (128), `benchLockout` (150), `benchStart` (120), `deadliftPhase` (120) y `deadliftLockout` (160).

La espera del cartel está en `FormAlertLatch`: 3 frames para mostrar y 4 para ocultar.
