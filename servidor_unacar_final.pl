/*
  Sistema de asignacion de profesores - Facultad de Ciencias de la Informacion, UNACAR.

  Ejecutar:
      swipl -s servidor_unacar_final.pl

  Abrir en el navegador:
      http://localhost:9090/home

  Detener desde la consola de SWI-Prolog:
      ?- http_stop_server(9090, []).

  Nota:
  Los estudios, acreditaciones, capacitaciones tomadas y asignaciones se
  almacenan en memoria durante la ejecucion del servidor. Al reiniciarlo,
  los cambios realizados mediante los endpoints se pierden.
*/

:- use_module(library(http/http_server)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/html_write)).
:- use_module(library(http/http_json)).
:- use_module(library(lists)).

% Datos que pueden registrarse o modificarse durante la ejecucion.
:- dynamic estudio/4.
:- dynamic acreditacion/3.
:- dynamic capacitacion_tomada/2.
:- dynamic asignacion/3.

% =====================================================
% BASE DE CONOCIMIENTO
% =====================================================

% profesor(Empleado, Nombre, Grado, Especialidad, CursosDominadosOrdenados).
% El primer curso de la lista es el que mas domina el profesor.
profesor(101, 'Ana Lopez', maestria, programacion, [c1, c2]).
profesor(102, 'Luis Perez', doctorado, bases_datos, [c2, c1]).
profesor(103, 'Maria Gomez', licenciatura, redes, [c3]).

% estudio(Empleado, Nivel, Area, Institucion).
estudio(101, licenciatura, informatica, unacar).
estudio(101, maestria, programacion, unacar).
estudio(102, licenciatura, informatica, unacar).
estudio(102, maestria, bases_datos, unacar).
estudio(102, doctorado, bases_datos, unacar).
estudio(103, licenciatura, redes, unacar).

% acreditacion(Empleado, Nombre, Area).
% El area permite considerar la acreditacion en el perfil del profesor.
acreditacion(101, 'Certificacion en Python', programacion).
acreditacion(102, 'Certificacion en SQL', bases_datos).

% academia(Id, Nombre, Area, Materias, Lider).
academia(a1, 'Academia de Programacion', programacion, [c1, c2], 101).
academia(a2, 'Academia de Redes', redes, [c3], 103).

% cuerpo_academico(Id, Nombre, LineaInvestigacion, Lider, Estatus).
cuerpo_academico(ca1, 'Tecnologias de Informacion', bases_datos, 102, en_formacion).

% proyecto(Id, Nombre, Objetivo, Entregables, Lider, Inicio, Entrega, Area).
proyecto(p1, 'Sistema Escolar', 'Administrar alumnos', ['Aplicacion'], 102,
         '2026-03-01', '2026-12-01', bases_datos).
proyecto(p2, 'Aplicacion Educativa', 'Ensenar programacion', ['Prototipo'], 101,
         '2026-03-15', '2026-12-15', programacion).

% comision(Id, Nombre, Objetivo, Area).
comision(co1, 'Comision de Planes', 'Revisar planes de estudio', programacion).

% curso(Id, Creditos, Nombre, Objetivo, Academia, Area).
curso(c1, 6, 'Programacion I', 'Aprender a programar', a1, programacion).
curso(c2, 6, 'Bases de Datos', 'Disenar bases de datos', a1, bases_datos).
curso(c3, 5, 'Redes I', 'Conocer redes', a2, redes).

% capacitacion(Id, Nombre, Objetivo, Horas, Inicio, Conclusion, Area).
capacitacion(cap1, 'Python Docente', 'Mejorar la ensenanza', 20,
             '2026-03-01', '2026-03-05', programacion).
capacitacion(cap2, 'Redes Avanzadas', 'Actualizar conocimientos', 15,
             '2026-04-10', '2026-04-13', redes).

% Historial de capacitaciones tomadas.
capacitacion_tomada(101, cap1).

% =====================================================
% REGLAS DE PERFIL Y COMPATIBILIDAD
% =====================================================

% Un area forma parte del perfil si proviene de la especialidad,
% de los estudios, de una acreditacion o de una capacitacion tomada.
perfil(E, Area) :- profesor(E, _, _, Area, _).
perfil(E, Area) :- estudio(E, _, Area, _).
perfil(E, Area) :- acreditacion(E, _, Area).
perfil(E, Area) :-
    capacitacion_tomada(E, IdCapacitacion),
    capacitacion(IdCapacitacion, _, _, _, _, _, Area).

% Compatibilidad para cada tipo de asignacion.
apto(academia, Id, E) :-
    academia(Id, _, Area, Materias, _),
    (perfil(E, Area) ; (member(Curso, Materias), domina(E, Curso))).

apto(cuerpo, Id, E) :-
    cuerpo_academico(Id, _, Area, _, _),
    perfil(E, Area).

apto(proyecto, Id, E) :-
    proyecto(Id, _, _, _, _, _, _, Area),
    perfil(E, Area).

apto(comision, Id, E) :-
    comision(Id, _, _, Area),
    perfil(E, Area).

apto(curso, Id, E) :-
    curso(Id, _, _, _, _, _),
    domina(E, Id).

apto(capacitacion, Id, E) :-
    capacitacion(Id, _, _, _, _, _, Area),
    perfil(E, Area),
    \+ capacitacion_tomada(E, Id).

domina(E, Curso) :-
    profesor(E, _, _, _, Cursos),
    member(Curso, Cursos).

% =====================================================
% PUNTUACION PARA ELEGIR AL MEJOR PROFESOR DE UN CURSO
% =====================================================

% Puntos por grado academico mas alto registrado del profesor.
puntos_grado(doctorado, 30).
puntos_grado(maestria, 20).
puntos_grado(licenciatura, 10).
puntos_grado(_, 0).

% Puntos por el nivel mas alto de estudios relacionado con el area del curso.
puntos_nivel(doctorado, 20).
puntos_nivel(maestria, 15).
puntos_nivel(licenciatura, 10).
puntos_nivel(_, 0).

% Determina el grado academico mas alto considerando tanto el grado
% inicial del profesor como todos los estudios registrados posteriormente.
prioridad_grado(licenciatura, 1).
prioridad_grado(maestria, 2).
prioridad_grado(doctorado, 3).

nivel_registrado(E, Nivel) :-
    profesor(E, _, Nivel, _, _),
    nivel_valido(Nivel).
nivel_registrado(E, Nivel) :-
    estudio(E, Nivel, _, _),
    nivel_valido(Nivel).

grado_actual(E, Grado) :-
    findall(Prioridad-Nivel,
            (nivel_registrado(E, Nivel), prioridad_grado(Nivel, Prioridad)),
            Niveles),
    Niveles \= [],
    keysort(Niveles, NivelesOrdenados),
    last(NivelesOrdenados, _-Grado).

puntaje_estudios(E, Area, Puntos) :-
    findall(Valor,
            (estudio(E, Nivel, Area, _), puntos_nivel(Nivel, Valor)),
            Valores),
    ( Valores = [] -> Puntos = 0 ; max_list(Valores, Puntos) ).

% Cada capacitacion tomada relacionada con el curso suma 10 puntos.
puntaje_capacitaciones(E, Area, Puntos) :-
    findall(Id,
            (capacitacion_tomada(E, Id),
             capacitacion(Id, _, _, _, _, _, Area)),
            Capacitaciones),
    length(Capacitaciones, Cantidad),
    Puntos is Cantidad * 10.

% Cada acreditacion relacionada con el curso suma 8 puntos.
puntaje_acreditaciones(E, Area, Puntos) :-
    findall(Nombre, acreditacion(E, Nombre, Area), Acreditaciones),
    length(Acreditaciones, Cantidad),
    Puntos is Cantidad * 8.

% El orden de dominio aporta la puntuacion base; los estudios,
% el grado, las capacitaciones y las acreditaciones complementan el total.
detalle_puntaje(E, Curso, Total, Posicion, PGrado, PEstudios, PCapacitaciones, PAcreditaciones) :-
    curso(Curso, _, _, _, _, Area),
    profesor(E, _, _, _, Cursos),
    grado_actual(E, Grado),
    nth1(Posicion, Cursos, Curso),
    PBase is 100 - Posicion,
    puntos_grado(Grado, PGrado),
    puntaje_estudios(E, Area, PEstudios),
    puntaje_capacitaciones(E, Area, PCapacitaciones),
    puntaje_acreditaciones(E, Area, PAcreditaciones),
    Total is PBase + PGrado + PEstudios + PCapacitaciones + PAcreditaciones.

puntaje(E, Curso, Total) :-
    detalle_puntaje(E, Curso, Total, _, _, _, _, _).

% Devuelve todos los profesores que dominan el curso, ordenados de mayor
% a menor puntuacion. En caso de empate se usa primero el orden de dominio
% y despues el numero de empleado.
recomendaciones_curso(Curso, Lista) :-
    findall(orden(Negativo, Posicion, E)-
            _{empleado:E, nombre:Nombre, grado:Grado, puntaje:Total,
              orden_dominio:Posicion},
            (detalle_puntaje(E, Curso, Total, Posicion, _, _, _, _),
             Negativo is -Total,
             profesor(E, Nombre, _, _, _),
             grado_actual(E, Grado)),
            Pares),
    keysort(Pares, ParesOrdenados),
    valores_pares(ParesOrdenados, Lista).

valores_pares([], []).
valores_pares([_-Valor|Resto], [Valor|Valores]) :-
    valores_pares(Resto, Valores).

mejor_candidato(Curso, Mejor) :-
    recomendaciones_curso(Curso, [Primero|_]),
    get_dict(empleado, Primero, Mejor).

% Solo es candidato para asignacion de curso si domina el curso y,
% ademas, es el primero en la lista ordenada por puntuacion.
es_mejor_candidato(Curso, E) :-
    apto(curso, Curso, E),
    mejor_candidato(Curso, E).

% =====================================================
% RUTAS HTTP (ENDPOINTS)
% =====================================================

:- http_handler(root(.), home_page, []).
:- http_handler(root(home), home_page, []).
:- http_handler(root(api/profesores), api_profesores, []).
:- http_handler(root(api/profesor), api_profesor, []).
:- http_handler(root(api/recomendar), api_recomendar, []).
:- http_handler(root(api/mejor_profesor), api_mejor_profesor, []).
:- http_handler(root(api/asignar), api_asignar, []).
:- http_handler(root(api/desasignar), api_desasignar, []).
:- http_handler(root(api/asignaciones), api_asignaciones, []).
:- http_handler(root(api/integrantes), api_integrantes, []).
:- http_handler(root(api/catalogo), api_catalogo, []).
:- http_handler(root(api/registrar_estudio), api_registrar_estudio, []).
:- http_handler(root(api/registrar_acreditacion), api_registrar_acreditacion, []).
:- http_handler(root(api/registrar_capacitacion), api_registrar_capacitacion, []).

% =====================================================
% PAGINA DE INICIO
% =====================================================

home_page(_Request) :-
    reply_html_page(title('Sistema de Profesores UNACAR'), [
        h1('Sistema de asignacion de profesores - UNACAR'),
        p('Los registros realizados se conservan mientras el servidor esta activo.'),
        h2('Profesores y perfiles'),
        ul([
            li(a(href('/api/profesores'), 'Ver profesores')),
            li(a(href('/api/profesor?empleado=101'), 'Consultar profesor 101 y su historial'))
        ]),
        h2('Recomendaciones'),
        ul([
            li(a(href('/api/recomendar?tipo=academia&id=a1'), 'Recomendar para academia')),
            li(a(href('/api/recomendar?tipo=cuerpo&id=ca1'), 'Recomendar para cuerpo academico')),
            li(a(href('/api/recomendar?tipo=proyecto&id=p1'), 'Recomendar para proyecto')),
            li(a(href('/api/recomendar?tipo=comision&id=co1'), 'Recomendar para comision')),
            li(a(href('/api/recomendar?tipo=curso&id=c1'), 'Recomendar profesores para curso, ordenados por puntuacion')),
            li(a(href('/api/mejor_profesor?curso=c1'), 'Consultar al mejor profesor para curso')),
            li(a(href('/api/recomendar?tipo=capacitacion&id=cap2'), 'Recomendar para capacitacion'))
        ]),
        h2('Asignaciones y consultas'),
        ul([
            li(a(href('/api/asignar?tipo=academia&id=a1&empleado=101'), 'Asignar profesor a academia')),
            li(a(href('/api/asignar?tipo=curso&id=c1&empleado=101'), 'Asignar mejor profesor al curso c1')),
            li(a(href('/api/asignaciones'), 'Ver todas las asignaciones')),
            li(a(href('/api/integrantes?tipo=academia&id=a1'), 'Ver lider e integrantes de academia')),
            li(a(href('/api/integrantes?tipo=cuerpo&id=ca1'), 'Ver lider e integrantes de cuerpo academico')),
            li(a(href('/api/integrantes?tipo=proyecto&id=p1'), 'Ver lider e integrantes de proyecto')),
            li(a(href('/api/desasignar?tipo=academia&id=a1&empleado=101'), 'Ejemplo: quitar asignacion de academia'))
        ]),
        h2('Catalogos'),
        ul([
            li(a(href('/api/catalogo?tipo=academia'), 'Catalogo de academias')),
            li(a(href('/api/catalogo?tipo=cuerpo'), 'Catalogo de cuerpos academicos')),
            li(a(href('/api/catalogo?tipo=proyecto'), 'Catalogo de proyectos')),
            li(a(href('/api/catalogo?tipo=comision'), 'Catalogo de comisiones')),
            li(a(href('/api/catalogo?tipo=curso'), 'Catalogo de cursos')),
            li(a(href('/api/catalogo?tipo=capacitacion'), 'Catalogo de capacitaciones'))
        ]),
        h2('Registro de historial'),
        ul([
            li(a(href('/api/registrar_estudio?empleado=103&nivel=maestria&area=redes&institucion=UNACAR'), 'Registrar estudio')),
            li(a(href('/api/registrar_acreditacion?empleado=103&nombre=Certificacion_Redes&area=redes'), 'Registrar acreditacion')),
            li(a(href('/api/registrar_capacitacion?empleado=103&id=cap2'), 'Ejemplo: registrar capacitacion tomada'))
        ])
    ]).

% =====================================================
% ENDPOINT: LISTAR PROFESORES
% =====================================================

api_profesores(_Request) :-
    findall(_{empleado:E, nombre:N, grado:G, especialidad:A, cursos_dominados:C},
            (profesor(E, N, _, A, C), grado_actual(E, G)),
            Lista),
    reply_json_dict(Lista).

% =====================================================
% ENDPOINT: CONSULTAR UN PROFESOR Y TODO SU PERFIL
% =====================================================

api_profesor(Request) :-
    http_parameters(Request, [empleado(E, [integer])]),
    ( profesor(E, Nombre, _, Area, Cursos), grado_actual(E, Grado) ->
        findall(_{nivel:N, area:A, institucion:I}, estudio(E, N, A, I), Estudios),
        findall(_{nombre:N, area:A}, acreditacion(E, N, A), Acreditaciones),
        findall(_{id:Id, nombre:N, area:A},
                (capacitacion_tomada(E, Id), capacitacion(Id, N, _, _, _, _, A)),
                Capacitaciones),
        findall(_{tipo:T, id:Id}, asignacion(T, Id, E), Asignaciones),
        findall(_{tipo:T, id:Id, nombre:N}, liderazgo(E, T, Id, N), Liderazgos),
        reply_json_dict(_{empleado:E, nombre:Nombre, grado:Grado,
            especialidad:Area, cursos_dominados:Cursos, estudios:Estudios,
            acreditaciones:Acreditaciones, capacitaciones_tomadas:Capacitaciones,
            asignaciones:Asignaciones, liderazgos:Liderazgos})
    ; reply_json_dict(_{error:'Profesor no encontrado'}, [status(404)])
    ).

% =====================================================
% ENDPOINT: RECOMENDAR PROFESORES
% =====================================================

api_recomendar(Request) :-
    http_parameters(Request, [tipo(Tipo, []), id(Id, [])]),
    ( tipo_valido(Tipo), existe(Tipo, Id) ->
        ( Tipo = curso ->
            recomendaciones_curso(Id, Profesores),
            ( Profesores = [Primero|_] -> get_dict(empleado, Primero, Mejor) ; Mejor = null ),
            reply_json_dict(_{tipo:Tipo, id:Id, profesores:Profesores, mejor_profesor:Mejor})
        ; findall(_{empleado:E, nombre:N},
                  (profesor(E, N, _, _, _), once(apto(Tipo, Id, E))),
                  Lista),
          reply_json_dict(_{tipo:Tipo, id:Id, profesores:Lista})
        )
    ; reply_json_dict(_{error:'Tipo o identificador no valido'}, [status(400)])
    ).

% =====================================================
% ENDPOINT: MEJOR PROFESOR PARA UN CURSO
% =====================================================

api_mejor_profesor(Request) :-
    http_parameters(Request, [curso(Curso, [])]),
    ( curso(Curso, _, NombreCurso, _, _, _) ->
        ( mejor_candidato(Curso, E) ->
            profesor(E, Nombre, _, _, _),
            grado_actual(E, Grado),
            detalle_puntaje(E, Curso, Total, Posicion, PGrado, PEstudios,
                            PCapacitaciones, PAcreditaciones),
            reply_json_dict(_{curso:Curso, nombre_curso:NombreCurso,
                empleado:E, nombre:Nombre, grado:Grado, puntaje:Total,
                orden_dominio:Posicion,
                puntos_grado:PGrado, puntos_estudios:PEstudios,
                puntos_capacitaciones:PCapacitaciones,
                puntos_acreditaciones:PAcreditaciones})
        ; reply_json_dict(_{error:'No hay profesores que dominen el curso'}, [status(404)])
        )
    ; reply_json_dict(_{error:'Curso no encontrado'}, [status(404)])
    ).

% =====================================================
% ENDPOINT: ASIGNAR PROFESOR
% =====================================================

api_asignar(Request) :-
    http_parameters(Request, [tipo(Tipo, []), id(Id, []), empleado(E, [integer])]),
    ( \+ tipo_valido(Tipo) ->
        reply_json_dict(_{error:'Tipo no valido'}, [status(400)])
    ; \+ existe(Tipo, Id) ->
        reply_json_dict(_{error:'Destino no encontrado'}, [status(404)])
    ; \+ profesor(E, _, _, _, _) ->
        reply_json_dict(_{error:'Profesor no encontrado'}, [status(404)])
    ; asignacion(Tipo, Id, E) ->
        reply_json_dict(_{mensaje:'El profesor ya esta asignado a este destino'})
    ; \+ apto(Tipo, Id, E) ->
        reply_json_dict(_{error:'El perfil del profesor no es compatible'}, [status(400)])
    ; Tipo = curso ->
        asignar_mejor_curso(Id, E)
    ; registrar_asignacion(Tipo, Id, E)
    ).

% Para cursos, solo se registra al profesor con la puntuacion mas alta.
asignar_mejor_curso(Id, E) :-
    ( es_mejor_candidato(Id, E) ->
        registrar_asignacion(curso, Id, E)
    ; mejor_candidato(Id, Mejor) ->
        reply_json_dict(_{error:'Para este curso debe asignarse el profesor con mayor puntuacion',
                          mejor_profesor:Mejor}, [status(400)])
    ; reply_json_dict(_{error:'No hay profesores que dominen el curso'}, [status(404)])
    ).

registrar_asignacion(Tipo, Id, E) :-
    assertz(asignacion(Tipo, Id, E)),
    reply_json_dict(_{mensaje:'Asignacion realizada', tipo:Tipo, id:Id, empleado:E}).

% =====================================================
% ENDPOINT: DESASIGNAR PROFESOR
% =====================================================

api_desasignar(Request) :-
    http_parameters(Request, [tipo(Tipo, []), id(Id, []), empleado(E, [integer])]),
    ( \+ tipo_valido(Tipo) ->
        reply_json_dict(_{error:'Tipo no valido'}, [status(400)])
    ; \+ existe(Tipo, Id) ->
        reply_json_dict(_{error:'Destino no encontrado'}, [status(404)])
    ; \+ profesor(E, _, _, _, _) ->
        reply_json_dict(_{error:'Profesor no encontrado'}, [status(404)])
    ; retract(asignacion(Tipo, Id, E)) ->
        reply_json_dict(_{mensaje:'Asignacion eliminada', tipo:Tipo, id:Id, empleado:E})
    ; reply_json_dict(_{error:'No se encontro esa asignacion'}, [status(404)])
    ).

% =====================================================
% ENDPOINT: LISTAR TODAS LAS ASIGNACIONES
% =====================================================

api_asignaciones(_Request) :-
    findall(_{tipo:T, id:Id, empleado:E, nombre:N},
            (asignacion(T, Id, E), profesor(E, N, _, _, _)),
            Lista),
    reply_json_dict(Lista).

% =====================================================
% ENDPOINT: VER LIDER E INTEGRANTES DE ACADEMIA, CUERPO O PROYECTO
% =====================================================

api_integrantes(Request) :-
    http_parameters(Request, [tipo(Tipo, []), id(Id, [])]),
    ( destino_con_lider(Tipo, Id, Lider) ->
        profesor(Lider, NombreLider, _, _, _),
        LiderInfo = _{empleado:Lider, nombre:NombreLider},
        findall(_{empleado:E, nombre:N},
                (asignacion(Tipo, Id, E), profesor(E, N, _, _, _)),
                Integrantes),
        reply_json_dict(_{tipo:Tipo, id:Id, lider:LiderInfo, integrantes:Integrantes})
    ; reply_json_dict(_{error:'No se encontro la academia, cuerpo o proyecto indicado'}, [status(404)])
    ).

destino_con_lider(academia, Id, Lider) :- academia(Id, _, _, _, Lider).
destino_con_lider(cuerpo, Id, Lider) :- cuerpo_academico(Id, _, _, Lider, _).
destino_con_lider(proyecto, Id, Lider) :- proyecto(Id, _, _, _, Lider, _, _, _).

% =====================================================
% ENDPOINT: CONSULTAR CATALOGOS
% =====================================================

api_catalogo(Request) :-
    http_parameters(Request, [tipo(Tipo, [])]),
    ( catalogo(Tipo, Lista) ->
        reply_json_dict(_{tipo:Tipo, elementos:Lista})
    ; reply_json_dict(_{error:'Tipo de catalogo no valido'}, [status(400)])
    ).

catalogo(academia, Lista) :-
    findall(_{id:Id, nombre:N, area:A, materias:M, lider:L},
            academia(Id, N, A, M, L), Lista).

catalogo(cuerpo, Lista) :-
    findall(_{id:Id, nombre:N, linea_investigacion:Linea, lider:L, estatus:E},
            cuerpo_academico(Id, N, Linea, L, E), Lista).

catalogo(proyecto, Lista) :-
    findall(_{id:Id, nombre:N, objetivo:O, entregables:Ent, lider:L,
              fecha_inicio:Inicio, fecha_entrega:Entrega, area:A},
            proyecto(Id, N, O, Ent, L, Inicio, Entrega, A), Lista).

catalogo(comision, Lista) :-
    findall(_{id:Id, nombre:N, objetivo:O, area:A},
            comision(Id, N, O, A), Lista).

catalogo(curso, Lista) :-
    findall(_{id:Id, creditos:C, nombre:N, objetivo:O, academia:Aca, area:A},
            curso(Id, C, N, O, Aca, A), Lista).

catalogo(capacitacion, Lista) :-
    findall(_{id:Id, nombre:N, objetivo:O, horas:H, fecha_inicio:Inicio,
              fecha_conclusion:Fin, area:A},
            capacitacion(Id, N, O, H, Inicio, Fin, A), Lista).

% =====================================================
% ENDPOINT: REGISTRAR ESTUDIO DE UN PROFESOR
% =====================================================

api_registrar_estudio(Request) :-
    http_parameters(Request, [
        empleado(E, [integer]), nivel(Nivel, []), area(Area, []), institucion(Institucion, [])
    ]),
    ( \+ profesor(E, _, _, _, _) ->
        reply_json_dict(_{error:'Profesor no encontrado'}, [status(404)])
    ; \+ nivel_valido(Nivel) ->
        reply_json_dict(_{error:'Nivel no valido. Use licenciatura, maestria o doctorado'}, [status(400)])
    ; estudio(E, Nivel, Area, Institucion) ->
        reply_json_dict(_{mensaje:'Ese estudio ya esta registrado'})
    ; assertz(estudio(E, Nivel, Area, Institucion)),
      reply_json_dict(_{mensaje:'Estudio registrado', empleado:E, nivel:Nivel,
                        area:Area, institucion:Institucion})
    ).

% =====================================================
% ENDPOINT: REGISTRAR ACREDITACION DE UN PROFESOR
% =====================================================

api_registrar_acreditacion(Request) :-
    http_parameters(Request, [
        empleado(E, [integer]), nombre(Nombre, []), area(Area, [])
    ]),
    ( \+ profesor(E, _, _, _, _) ->
        reply_json_dict(_{error:'Profesor no encontrado'}, [status(404)])
    ; acreditacion(E, Nombre, Area) ->
        reply_json_dict(_{mensaje:'Esa acreditacion ya esta registrada'})
    ; assertz(acreditacion(E, Nombre, Area)),
      reply_json_dict(_{mensaje:'Acreditacion registrada', empleado:E,
                        nombre:Nombre, area:Area})
    ).

% =====================================================
% ENDPOINT: REGISTRAR CAPACITACION TOMADA
% =====================================================

api_registrar_capacitacion(Request) :-
    http_parameters(Request, [empleado(E, [integer]), id(Id, [])]),
    ( \+ profesor(E, _, _, _, _) ->
        reply_json_dict(_{error:'Profesor no encontrado'}, [status(404)])
    ; \+ capacitacion(Id, _, _, _, _, _, _) ->
        reply_json_dict(_{error:'Capacitacion no encontrada en el catalogo'}, [status(404)])
    ; capacitacion_tomada(E, Id) ->
        reply_json_dict(_{mensaje:'El profesor ya tiene registrada esa capacitacion'})
    ; assertz(capacitacion_tomada(E, Id)),
      reply_json_dict(_{mensaje:'Capacitacion tomada registrada', empleado:E, capacitacion:Id})
    ).

% =====================================================
% PREDICADOS AUXILIARES
% =====================================================

nivel_valido(licenciatura).
nivel_valido(maestria).
nivel_valido(doctorado).

tipo_valido(academia).
tipo_valido(cuerpo).
tipo_valido(proyecto).
tipo_valido(comision).
tipo_valido(curso).
tipo_valido(capacitacion).

existe(academia, Id) :- academia(Id, _, _, _, _).
existe(cuerpo, Id) :- cuerpo_academico(Id, _, _, _, _).
existe(proyecto, Id) :- proyecto(Id, _, _, _, _, _, _, _).
existe(comision, Id) :- comision(Id, _, _, _).
existe(curso, Id) :- curso(Id, _, _, _, _, _).
existe(capacitacion, Id) :- capacitacion(Id, _, _, _, _, _, _).

% Consulta los cargos de liderazgo para incluirlos en el endpoint del profesor.
liderazgo(E, academia, Id, Nombre) :- academia(Id, Nombre, _, _, E).
liderazgo(E, cuerpo, Id, Nombre) :- cuerpo_academico(Id, Nombre, _, E, _).
liderazgo(E, proyecto, Id, Nombre) :- proyecto(Id, Nombre, _, _, E, _, _, _).

% El servidor inicia despues de registrar todas las rutas.
:- initialization(http_server([port(9090)])).
