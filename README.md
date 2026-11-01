# Actividad 3 - Sistema de asignación de profesores (SWI-Prolog)

**Facultad de Ciencias de la Información - UNACAR**

## Integrantes

| Nombre | Matrícula |
|---|---:|
| Raul Eduardo Covarrubias Ballester | 220952 |
| Ricardo Jose Chable Montero | 180283 |

---

## 1. Descripción general

El programa `servidor_unacar_final.pl` es un servidor HTTP desarrollado en SWI-Prolog para apoyar la asignación de profesores de la Facultad de Ciencias de la Información de la UNACAR. Permite recomendar y asignar profesores a academias, cuerpos académicos, proyectos, comisiones, cursos y cursos de capacitación, tomando en cuenta su especialidad, estudios, acreditaciones y capacitaciones tomadas.

También permite consultar la información de cada profesor y sus asignaciones, registrar estudios, acreditaciones y capacitaciones realizadas, consultar los catálogos de las entidades y revisar quiénes están asignados a una academia, cuerpo académico o proyecto.

La página `/home` presenta enlaces de ejemplo. Los endpoints de la API devuelven sus resultados en formato JSON. Los datos y los cambios se mantienen en memoria mientras el servidor está activo; al detenerlo o reiniciarlo, los registros agregados durante la ejecución se pierden.

## 2. Cómo ejecutarlo

1. Instalar SWI-Prolog desde [https://www.swi-prolog.org](https://www.swi-prolog.org).
2. Guardar `servidor_unacar_final.pl` y abrir una terminal en la carpeta donde se encuentra.
3. Ejecutar el servidor con el comando:

   ```bash
   swipl -s servidor_unacar_final.pl
   ```

4. Abrir en el navegador:

   `http://localhost:9090/home`

5. Para detener el servidor desde la consola de SWI-Prolog, ejecutar:

   ```prolog
   http_stop_server(9090, []).
   ```

   También se puede cerrar la sesión con `halt.`.

## 3. Base de conocimiento

La información inicial se representa mediante hechos de Prolog. Los principales predicados y sus campos son:

| Hecho | Campos |
|---|---|
| `profesor/5` | Número de empleado, nombre, grado académico inicial, especialidad y lista de cursos que domina, ordenada de mayor a menor dominio. |
| `estudio/4` | Número de empleado, nivel (licenciatura, maestría o doctorado), área e institución. |
| `acreditacion/3` | Número de empleado, nombre de la acreditación y área. |
| `academia/5` | Identificador, nombre, área, materias asignadas y líder. |
| `cuerpo_academico/5` | Identificador, nombre, línea de investigación, líder y estatus. |
| `proyecto/8` | Identificador, nombre, objetivo, entregables, líder, fecha de inicio, fecha de entrega y área. |
| `comision/4` | Identificador, nombre, objetivo y área. |
| `curso/6` | Identificador, créditos, nombre, objetivo, academia y área. |
| `capacitacion/7` | Identificador, nombre, objetivo, número de horas, fecha de inicio, fecha de conclusión y área. |
| `capacitacion_tomada/2` | Número de empleado e identificador de la capacitación que ya tomó. |
| `asignacion/3` | Tipo de destino, identificador del destino y número de empleado asignado. |

Los predicados `estudio/4`, `acreditacion/3`, `capacitacion_tomada/2` y `asignacion/3` son **dinámicos**. Esto permite agregar o quitar registros durante la ejecución del servidor mediante los endpoints correspondientes.

Los integrantes de las academias, cuerpos académicos y proyectos se obtienen a partir de `asignacion/3`; no se almacenan como una lista independiente dentro de esos hechos. El líder se encuentra registrado en el hecho de cada academia, cuerpo académico o proyecto.

Los datos de profesores, academias, cuerpos académicos, proyectos, comisiones, cursos y capacitaciones que aparecen inicialmente en el archivo son datos de ejemplo definidos directamente en el código.

## 4. Reglas de perfil, compatibilidad y selección

### Perfil (`perfil/2`)

Un profesor tiene perfil en un área cuando se cumple al menos una de estas condiciones:

- Su especialidad corresponde al área.
- Tiene registrado un estudio en esa área.
- Tiene una acreditación relacionada con esa área.
- Ha tomado una capacitación cuya área corresponde a esa área.

Por lo tanto, las capacitaciones y acreditaciones también contribuyen a determinar las áreas del perfil del profesor.

### Aptitud (`apto/3`)

Este predicado determina si un profesor puede ser recomendado para un destino:

| Destino | Condición de compatibilidad |
|---|---|
| Academia | Tiene perfil en el área de la academia o domina alguna de las materias asignadas a ella. |
| Cuerpo académico | Tiene perfil en la línea de investigación del cuerpo académico. |
| Proyecto | Tiene perfil en el área del proyecto. |
| Comisión | Tiene perfil en el área de la comisión. |
| Curso | Domina el curso, es decir, aparece en su lista de cursos dominados. |
| Capacitación | Tiene perfil en el área de la capacitación y todavía no tiene registrada esa capacitación como tomada. |

La recomendación de profesores para un curso se ordena mediante un puntaje. Solo los profesores que dominan el curso participan en ese ranking.

### Selección del mejor profesor para un curso (`puntaje/3`)

El puntaje considera el orden de dominio del curso, el grado académico más alto registrado, los estudios relacionados con el área del curso, las capacitaciones tomadas de esa área y las acreditaciones de esa área.

La fórmula utilizada es:

```text
Puntaje total = puntaje base
              + puntos por grado académico
              + puntos por estudios relacionados
              + puntos por capacitaciones relacionadas
              + puntos por acreditaciones relacionadas
```

Los valores aplicados son:

| Criterio | Puntos |
|---|---:|
| Puntaje base | 100 menos la posición del curso en la lista de cursos dominados. |
| Doctorado (grado académico más alto) | 30 |
| Maestría (grado académico más alto) | 20 |
| Licenciatura (grado académico más alto) | 10 |
| Estudios relacionados con el área del curso | Doctorado: 20; maestría: 15; licenciatura: 10. Se toma el valor más alto de los estudios registrados en esa área. |
| Cada capacitación tomada relacionada con el área del curso | 10 |
| Cada acreditación relacionada con el área del curso | 8 |

El grado académico más alto se obtiene comparando el grado inicial registrado en `profesor/5` con los niveles de los estudios registrados en `estudio/4`. Así, un estudio nuevo de maestría o doctorado puede actualizar el grado que utiliza el cálculo del puntaje.

Los profesores se ordenan de mayor a menor puntaje. En caso de empate, se utiliza primero la posición del curso en la lista de dominio y después el número de empleado.

El endpoint de asignación de cursos valida que el profesor solicitado sea el primero del ranking. Por lo tanto, no permite asignar el curso a otro profesor que tenga una puntuación menor.

## 5. Endpoints

Los siguientes ejemplos se pueden abrir desde el navegador usando `http://localhost:9090` seguido de la ruta indicada. Los parámetros se envían en la URL.

### Página principal y consultas

| Endpoint | Descripción |
|---|---|
| `/home` | Página principal con enlaces de ejemplo a las funciones del servidor. |
| `/api/profesores` | Lista los profesores registrados y muestra su grado académico más alto, especialidad y cursos dominados. |
| `/api/profesor?empleado=101` | Consulta un profesor: datos generales, grado académico más alto, cursos dominados, estudios, acreditaciones, capacitaciones tomadas, asignaciones y liderazgos. |
| `/api/asignaciones` | Lista todas las asignaciones registradas, indicando tipo, identificador del destino, empleado y nombre del profesor. |

### Recomendaciones y selección

| Endpoint | Descripción |
|---|---|
| `/api/recomendar?tipo=academia&id=a1` | Lista profesores compatibles con la academia indicada. También acepta `cuerpo`, `proyecto`, `comision` y `capacitacion` como valores de `tipo`. |
| `/api/recomendar?tipo=curso&id=c1` | Lista a los profesores que dominan el curso, ordenados de mayor a menor puntaje, e identifica al mejor candidato. |
| `/api/mejor_profesor?curso=c1` | Devuelve el mejor profesor para el curso y el desglose de su puntuación. |

Los valores válidos para `tipo` son `academia`, `cuerpo`, `proyecto`, `comision`, `curso` y `capacitacion`.

### Asignar y quitar asignaciones

| Endpoint | Descripción |
|---|---|
| `/api/asignar?tipo=academia&id=a1&empleado=101` | Asigna al profesor si existe, el destino es válido y su perfil es compatible. Para `tipo=curso`, además exige que sea el mejor candidato según el puntaje. |
| `/api/desasignar?tipo=academia&id=a1&empleado=101` | Elimina la asignación indicada. |
| `/api/integrantes?tipo=academia&id=a1` | Consulta el líder y los profesores asignados a una academia. También acepta `cuerpo` y `proyecto`. |

Al asignar, el servidor comprueba que el tipo y el destino sean válidos, que el profesor exista, que no esté asignado previamente al mismo destino y que cumpla la regla de compatibilidad. Si el destino es un curso, también comprueba que el profesor tenga la mayor puntuación.

**Nota:** la versión actual no implementa una validación de traslapes de fechas entre proyectos o capacitaciones.

### Catálogos

| Endpoint | Descripción |
|---|---|
| `/api/catalogo?tipo=academia` | Lista las academias. |
| `/api/catalogo?tipo=cuerpo` | Lista los cuerpos académicos. |
| `/api/catalogo?tipo=proyecto` | Lista los proyectos. |
| `/api/catalogo?tipo=comision` | Lista las comisiones. |
| `/api/catalogo?tipo=curso` | Lista los cursos. |
| `/api/catalogo?tipo=capacitacion` | Lista los cursos de capacitación. |

### Registro del historial académico y de capacitación

| Endpoint | Descripción |
|---|---|
| `/api/registrar_estudio?empleado=103&nivel=maestria&area=redes&institucion=UNACAR` | Registra un estudio para el profesor. Los niveles permitidos son `licenciatura`, `maestria` y `doctorado`. |
| `/api/registrar_acreditacion?empleado=103&nombre=Certificacion_Redes&area=redes` | Registra una acreditación y su área. |
| `/api/registrar_capacitacion?empleado=103&id=cap2` | Registra que el profesor ya tomó una capacitación que debe existir en el catálogo. |

Hay una diferencia entre **asignar a un profesor a una capacitación** y **registrar que ya la tomó**. Para asignarlo se utiliza `/api/asignar?tipo=capacitacion&id=cap2&empleado=103`. Cuando la capacitación ya fue realizada, se registra en el historial mediante `/api/registrar_capacitacion?empleado=103&id=cap2`.

## 6. Códigos de respuesta

| Código HTTP | Significado en los endpoints |
|---|---|
| 200 | La consulta o modificación se procesó correctamente. Algunas validaciones informativas, como que una asignación ya exista, también devuelven un mensaje con este código. |
| 400 | Parámetros de tipo o nivel no válidos, perfil incompatible o intento de asignar un curso a alguien que no es el mejor candidato. |
| 404 | No se encontró el profesor, destino, curso, capacitación o asignación solicitada. |

La versión actual no utiliza el código HTTP 409 para conflictos de fechas.

## 7. Ejemplo de uso

El siguiente ejemplo utiliza a María Gómez (empleado `103`) y la capacitación `cap2`, que corresponde al área de redes:

1. Registrar que María tomó la capacitación de redes:

   `/api/registrar_capacitacion?empleado=103&id=cap2`

2. Consultar el mejor profesor para Redes I (`c3`):

   `/api/mejor_profesor?curso=c3`

3. Asignar al profesor recomendado al curso Redes I:

   `/api/asignar?tipo=curso&id=c3&empleado=103`

4. Consultar los datos, el historial y las asignaciones de María:

   `/api/profesor?empleado=103`

Este flujo muestra cómo una capacitación tomada se incorpora al perfil del profesor y puede contribuir al puntaje utilizado para recomendarlo para un curso de su área.

## 8. Consideraciones

- Los datos iniciales están definidos como hechos dentro del archivo Prolog.
- Los estudios, acreditaciones, capacitaciones tomadas y asignaciones agregados durante la ejecución se guardan en memoria y se pierden al detener o reiniciar el servidor.
- Los endpoints de registro, asignación y eliminación modifican el estado del servidor.
- El servidor utiliza el puerto `9090`.
