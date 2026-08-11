#*******************************************************************************
# 0. Identification ------------------------------------------------------------
# Título: Diccionario de ítems fuente
# Institución: PNUD
# Responsable: Consultor técnico - MVM
# Resumen ejecutivo: Identidad esperada de cada variable fuente de los índices,
#                    para detectar cambios de cuestionario entre olas. Calibrado
#                    sobre ENUSC 2024.
# Fecha: 26 de julio de 2026
#*******************************************************************************

#* POR QUÉ EXISTE ESTE ARCHIVO
#*
#* Los índices de 2_recode.R se construyen con rangos POSICIONALES:
#* paste0("emper_p_inseg_lugares_", 1:11),
#* paste0("comper_p_mod_actividades_", 1:13), c(1:4, 6, 9:11), etc. Esas son posiciones del
#* cuestionario, no identidades. Si una ola nueva inserta, elimina o reordena un
#* ítem, el código selecciona un conjunto distinto sin que nada falle: los
#* índices se calculan igual, el MCA corre igual y las tablas salen igual de
#* bien formadas, pero miden otra cosa.
#*
#* validar_seleccion() detecta cambios en la CANTIDAD de variables por dimensión, pero no un
#* reordenamiento que mantenga la cantidad. Este diccionario cierra ese hueco:
#* fija qué ítem se espera en cada posición, comparando el texto de la etiqueta.
#*
#* Al pasar a una ola nueva, si un ítem cambió de posición o de redacción,
#* validar_items() falla nombrando la variable, lo esperado y lo encontrado. Ahí
#* hay que decidir si es el mismo ítem (actualizar el texto acá) o si cambió el
#* instrumento (revisar la construcción del índice).

# Texto esperado del ítem (lo que va después del último "?" en la etiqueta de la
# variable)
DIC_ITEMS <- list(
    #* Calibrado sobre ENUSC 2024.
        "2024" = c(
        "emper_p_inseg_lugares_1" = "Trasladándose en su vehículo",
        "emper_p_inseg_lugares_2" = "Esperando transporte público",
        "emper_p_inseg_lugares_3" = "Trasladándose en buses o micros de transporte público",
        "emper_p_inseg_lugares_4" = "Trasladándose en taxis o colectivos",
        "emper_p_inseg_lugares_5" = "Trasladándose en vehículos de aplicación, tales como Uber, Cabify, Didi o similar",
        "emper_p_inseg_lugares_6" = "Trasladándose en Metro, Biotrén, Merval o Metrotren",
        "emper_p_inseg_lugares_7" = "En un restaurante, bar, pub, café, discoteque u otro lugar de recreación",
        "emper_p_inseg_lugares_8" = "En un terminal de buses o ferrocarriles",
        "emper_p_inseg_lugares_9" = "En un terminal aéreo o aeropuerto",
        "emper_p_inseg_lugares_10" = "En centros comerciales o malls",
        "emper_p_inseg_lugares_11" = "En una bencinera o servicentro",
        "emper_p_inseg_oscuro_1" = "Caminando solo/a por su barrio cuando ya está oscuro",
        "emper_p_inseg_dia_1" = "Caminando solo/a por su barrio durante el día",
        "emper_p_inseg_oscuro_2" = "Solo/a en su casa cuando ya está oscuro",
        "emper_p_inseg_dia_2" = "Solo/a en su casa durante el día",
        "perper_p_expos_delito" = "Considerando el tipo de actividades que realiza o los lugares por los que transita habitualmente, ¿cree usted que será víctima de algún delito en los próximos doce meses",
        "perper_p_delito_pronostico_1" = "Robo en su vivienda",
        "perper_p_delito_pronostico_2" = "Robo o hurto de su vehículo o portonazo",
        "perper_p_delito_pronostico_3" = "Robo o hurto de algún objeto dejado dentro del vehículo o parte de él",
        "perper_p_delito_pronostico_4" = "Vandalismo o daño a su vivienda o vehículo",
        "perper_p_delito_pronostico_5" = "Robo o asalto, como robo con violencia, cogoteo, robo por sorpresa o lanzazo",
        "perper_p_delito_pronostico_6" = "Hurto",
        "perper_p_delito_pronostico_7" = "Agresiones físicas o lesiones",
        "perper_p_delito_pronostico_8" = "Amenazas o extorsión",
        "perper_p_delito_pronostico_9" = "Delitos económicos como fraude o estafa",
        "perper_p_delito_pronostico_10" = "Delitos cibernéticos",
        "perper_p_delito_pronostico_11" = "Acoso callejero o sexual",
        "perper_p_delito_pronostico_77" = "Otros delitos",
        "perper_p_delito_pronostico_88" = "No sabe",
        "perper_p_delito_pronostico_99" = "No responde",
        "pergen_p_aumento_pais" = "Pensando en la delincuencia, usted diría que durante los últimos doce meses, la delincuencia en el PAÍS...",
        "pergen_p_aumento_com" = "Pensando en la delincuencia, usted diría que durante los últimos doce meses, la delincuencia en su COMUNA...",
        "pergen_p_aumento_barrio" = "Pensando en la delincuencia, usted diría que durante los últimos doce meses, la delincuencia en su BARRIO...",
        "comper_p_mod_actividades_1" = "Caminar solo/a",
        "comper_p_mod_actividades_2" = "Realizar actividades al aire libre",
        "comper_p_mod_actividades_3" = "Usar celular y/o artículos electrónicos en público",
        "comper_p_mod_actividades_4" = "Tomar micros o buses",
        "comper_p_mod_actividades_5" = "Tomar taxis o colectivos",
        "comper_p_mod_actividades_6" = "Tomar o usar Uber, Cabify, Didi o similares",
        "comper_p_mod_actividades_7" = "Caminar por ciertas áreas o lugares",
        "comper_p_mod_actividades_8" = "Salir de noche",
        "comper_p_mod_actividades_9" = "Usar joyas, reloj u objetos de lujo",
        "comper_p_mod_actividades_10" = "Ir al banco",
        "comper_p_mod_actividades_11" = "Llevar o usar dinero en efectivo",
        "comper_p_mod_actividades_12" = "Realizar actividades deportiva, de recreación o esparcimiento en recintos cerrados",
        "comper_p_mod_actividades_13" = "Manejar vehículos, motos y/o estacionar fuera de la vivienda",
        "comper_costos_medidas" = "Considerar lo invertido en seguridad de su vivienda, automóvil y en conjunto a las personas de su barrio",
        "comgen_medidas_perro" = "Indique él o los elementos de seguridad que dispone su vivienda o edificio. Perro u otro animal con fines de protección del inmueble",
        "comgen_medidas_alarma_privada" = "Indique él o los elementos de seguridad que dispone su vivienda o edificio. Alarma instalada por empresa de seguridad",
        "comgen_medidas_camaras_vigilancia" = "Indique él o los elementos de seguridad que dispone su vivienda o edificio. Cámaras de vigilancia",
        "comgen_medidas_rejas" = "Indique él o los elementos de seguridad que dispone su vivienda o edificio. Rejas u otro tipo de protecciones en puertas y ventanas",
        "comgen_medidas_cerco" = "Indique él o los elementos de seguridad que dispone su vivienda o edificio. Cerco eléctrico en reja o muro perimetral de la propiedad",
        "comgen_medidas_proteccion" = "Indique él o los elementos de seguridad que dispone su vivienda o edificio. Protecciones no eléctricas en reja o muro de la propiedad",
        "comgen_medidas_seguro" = "Indique él o los elementos de seguridad que dispone su vivienda o edificio. Seguro de cadena y/o cerradura de seguridad",
        "comgen_medidas_foco" = "Indique él o los elementos de seguridad que dispone su vivienda o edificio. Foco lumínico con sensor de movimiento",
        "comgen_vecinos_medidas_whatsapp" = "Tenemos un grupo de WhatsApp u otra red",
        "comgen_vecinos_medidas_vigilancia" = "Tenemos un sistema de vigilancia entre las personas del barrio",
        "comgen_vecinos_medidas_al_comunit" = "Tenemos un sistema de alarma comunitaria",
        "comgen_vecinos_medidas_coord_pol" = "Hemos hablado con las policías para coordinar medidas de seguridad",
        "comgen_vecinos_medidas_coord_mun" = "Hemos hablado con agentes del municipio para coordinar medidas de seguridad",
        "comgen_vecinos_medidas_televig" = "Tenemos un sistema de cámaras de televigilancia",
        "comgen_vecinos_medidas_privad" = "Tenemos contratados vigilantes privados"
    ),
    #* Calibrado sobre ENUSC 2025. Las 11 diferencias respecto de 2024 son
    #* cosméticas: correcciones de tipeo ("él o los" -> "el o los",
    #* "deportiva" -> "deportivas") y puntuación. Ninguna cambia el contenido
    #* del ítem, así que las posiciones siguen midiendo lo mismo.
    #*
    #* Los 13 ítems de p_mod_actividades se extraen con el patrón entre comillas
    #* (ver ESPERADO$patrones), por eso su texto coincide con el de 2024 pese a
    #* que el enunciado se reformuló por completo.
    "2025" = c(
        "emper_p_inseg_lugares_1" = "Trasladándose en su vehículo",
        "emper_p_inseg_lugares_2" = "Esperando transporte público",
        "emper_p_inseg_lugares_3" = "Trasladándose en buses o micros de transporte público",
        "emper_p_inseg_lugares_4" = "Trasladándose en taxis o colectivos",
        "emper_p_inseg_lugares_5" = "Trasladándose en vehículos de aplicación, tales como Uber, Cabify, Didi o similar",
        "emper_p_inseg_lugares_6" = "Trasladándose en Metro, Biotrén, Merval o Metrotren",
        "emper_p_inseg_lugares_7" = "En un restaurante, bar, pub, café, discoteque u otro lugar de recreación",
        "emper_p_inseg_lugares_8" = "En un terminal de buses o ferrocarriles",
        "emper_p_inseg_lugares_9" = "En un terminal aéreo o aeropuerto",
        "emper_p_inseg_lugares_10" = "En centros comerciales o malls",
        "emper_p_inseg_lugares_11" = "En una bencinera o servicentro",
        "emper_p_inseg_oscuro_1" = "Caminando solo/a por su barrio cuando ya está oscuro",
        "emper_p_inseg_dia_1" = "Caminando solo/a por su barrio durante el día",
        "emper_p_inseg_oscuro_2" = "Solo/a en su casa cuando ya está oscuro",
        "emper_p_inseg_dia_2" = "Solo/a en su casa durante el día",
        "perper_p_expos_delito" = "Considerando el tipo de actividades que realiza o los lugares por los que transita habitualmente, ¿cree usted que será víctima de algún delito en los próximos doce meses",
        "perper_p_delito_pronostico_1" = "Robo en su vivienda",
        "perper_p_delito_pronostico_2" = "Robo o hurto de su vehículo o portonazo",
        "perper_p_delito_pronostico_3" = "Robo o hurto de algún objeto dejado dentro del vehículo o parte de él",
        "perper_p_delito_pronostico_4" = "Vandalismo o daño a su vivienda o vehículo",
        "perper_p_delito_pronostico_5" = "Robo o asalto, como robo con violencia, cogoteo, robo por sorpresa o lanzazo",
        "perper_p_delito_pronostico_6" = "Hurto",
        "perper_p_delito_pronostico_7" = "Agresiones físicas o lesiones",
        "perper_p_delito_pronostico_8" = "Amenazas o extorsión",
        "perper_p_delito_pronostico_9" = "Delitos económicos como fraude o estafa",
        "perper_p_delito_pronostico_10" = "Delitos cibernéticos",
        "perper_p_delito_pronostico_11" = "Acoso callejero o sexual",
        "perper_p_delito_pronostico_77" = "Otros delitos",
        "perper_p_delito_pronostico_88" = "No sabe",
        "perper_p_delito_pronostico_99" = "No responde",
        "pergen_p_aumento_pais" = "Pensando en la delincuencia, usted diría que durante los últimos doce meses, la delincuencia en el PAÍS...",
        "pergen_p_aumento_com" = "Pensando en la delincuencia, usted diría que durante los últimos doce meses, la delincuencia en su COMUNA...",
        "pergen_p_aumento_barrio" = "Pensando en la delincuencia, usted diría que durante los últimos doce meses, la delincuencia en su BARRIO...",
        "comper_p_mod_actividades_1" = "Caminar solo/a",
        "comper_p_mod_actividades_2" = "Realizar actividades al aire libre",
        "comper_p_mod_actividades_3" = "Usar celular y/o artículos electrónicos en público",
        "comper_p_mod_actividades_4" = "Tomar micros o buses",
        "comper_p_mod_actividades_5" = "Tomar taxis o colectivos",
        "comper_p_mod_actividades_6" = "Tomar o usar Uber, Cabify, Didi o similares",
        "comper_p_mod_actividades_7" = "Caminar por ciertas áreas o lugares",
        "comper_p_mod_actividades_8" = "Salir de noche",
        "comper_p_mod_actividades_9" = "Usar joyas, reloj u objetos de lujo",
        "comper_p_mod_actividades_10" = "Ir al banco",
        "comper_p_mod_actividades_11" = "Llevar o usar dinero en efectivo",
        "comper_p_mod_actividades_12" = "Realizar actividades deportivas, de recreación o esparcimiento en recintos cerrados",
        "comper_p_mod_actividades_13" = "Manejar vehículos, motos y/o estacionar fuera de su vivienda",
        "comper_costos_medidas" = "Considerar lo invertido en seguridad de su vivienda, automóvil y en conjunto a las personas de su barrio. Sumar todos los costos de estas medidas.",
        "comgen_medidas_perro" = "Indique el o los elementos de seguridad que dispone su vivienda o edificio. Perro u otro animal con fines de protección del inmueble",
        "comgen_medidas_alarma_privada" = "Indique el o los elementos de seguridad que dispone su vivienda o edificio. Alarma instalada por empresa de seguridad",
        "comgen_medidas_camaras_vigilancia" = "Indique el o los elementos de seguridad que dispone su vivienda o edificio. Cámaras de vigilancia",
        "comgen_medidas_rejas" = "Indique el o los elementos de seguridad que dispone su vivienda o edificio. Rejas u otro tipo de protecciones en puertas y ventanas",
        "comgen_medidas_cerco" = "Indique el o los elementos de seguridad que dispone su vivienda o edificio. Cerco eléctrico en reja o muro perimetral de la propiedad",
        "comgen_medidas_proteccion" = "Indique el o los elementos de seguridad que dispone su vivienda o edificio. Protecciones no eléctricas en reja o muro de la propiedad",
        "comgen_medidas_seguro" = "Indique el o los elementos de seguridad que dispone su vivienda o edificio. Seguro de cadena y/o cerradura de seguridad",
        "comgen_medidas_foco" = "Indique el o los elementos de seguridad que dispone su vivienda o edificio. Foco lumínico con sensor de movimiento",
        "comgen_vecinos_medidas_whatsapp" = "Tenemos un grupo de WhatsApp u otra red",
        "comgen_vecinos_medidas_vigilancia" = "Tenemos un sistema de vigilancia entre las personas del barrio",
        "comgen_vecinos_medidas_al_comunit" = "Tenemos un sistema de alarma comunitaria",
        "comgen_vecinos_medidas_coord_pol" = "Hemos hablado con las policías para coordinar medidas de seguridad",
        "comgen_vecinos_medidas_coord_mun" = "Hemos hablado con agentes del municipio para coordinar medidas de seguridad",
        "comgen_vecinos_medidas_televig" = "Tenemos un sistema de cámaras de televigilancia",
        "comgen_vecinos_medidas_privad" = "Tenemos contratados vigilantes privados"
    )
)
