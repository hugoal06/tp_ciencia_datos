#1.ARCHIVOS DE ENTRADA
library(tidyverse)
source("utils/comprobar_columnas.R")
dir.create("input", showWarnings = FALSE, recursive = TRUE)
dir.create("output/tablas", showWarnings = FALSE, recursive = TRUE)

#El manifiesto fija las rutas y la codificación de los archivos de cada cadena para mantener la misma selección de datos
#Comprobamos la disponibilidad de todas las entradas antes de elegir entre la importación original y la copia recuperada
manifest <- read_csv("auxiliar/manifest_archivos.csv", col_types = cols(.default = col_character()))
rutas <- c(manifest$comercio, manifest$sucursales, manifest$productos)
usar_crudos <- nrow(manifest) > 0 && all(!is.na(rutas)) && all(file.exists(rutas))

#2.IMPORTACIÓN Y UNIÓN DE LOS ORIGINALES
if (usar_crudos) {
  bases <- vector("list", nrow(manifest))
  inventario <- vector("list", nrow(manifest))
  for (i in seq_len(nrow(manifest))) {
    m <- manifest[i, ]

    #Leemos los identificadores como texto para conservar los ceros iniciales y mantener compatibles las claves de unión
    #Usamos la codificación indicada para cada cadena para conservar sus nombres y descripciones
    comercio <- read_delim(m$comercio, delim = "|", col_types = cols(.default = col_character()),
                           locale = locale(encoding = m$encoding), show_col_types = FALSE)
    sucursales <- read_delim(m$sucursales, delim = "|", col_types = cols(.default = col_character()),
                             locale = locale(encoding = m$encoding), show_col_types = FALSE)
    productos <- read_delim(m$productos, delim = "|", col_types = cols(.default = col_character()),
                            locale = locale(encoding = m$encoding), show_col_types = FALSE)

    #Identificamos cada bandera dentro de su comercio y añadimos la sucursal para ubicar los registros de precios
    clave_comercio <- c("id_comercio", "id_bandera")
    clave_sucursal <- c(clave_comercio, "id_sucursal")
    comprobar_columnas(comercio, clave_comercio, "Comercios")
    comprobar_columnas(sucursales, clave_sucursal, "Sucursales")
    comprobar_columnas(productos, c(clave_sucursal, "id_producto"), "Productos")

    #Exigimos claves únicas en comercios y sucursales para evitar que las uniones multipliquen las observaciones
    if (anyDuplicated(comercio[clave_comercio]) || anyDuplicated(sucursales[clave_sucursal])) {
      stop("Claves duplicadas en comercios o sucursales: revisar antes de unir.")
    }

    #Revisamos la correspondencia de los productos con ambas tablas antes de incorporar su identificación y ubicación
    no_sucursal <- anti_join(productos, sucursales, by = clave_sucursal)
    no_comercio <- anti_join(productos, comercio, by = clave_comercio)
    if (nrow(no_sucursal) || nrow(no_comercio)) {
      stop("Hay productos sin correspondencia de comercio o sucursal. Revisar las claves.")
    }

    #Construimos la clave de sucursal con comercio, bandera y local para distinguir identificadores que se repiten entre cadenas
    bases[[i]] <- productos %>%
      left_join(comercio, by = clave_comercio, relationship = "many-to-one") %>%
      left_join(sucursales, by = clave_sucursal, relationship = "many-to-one") %>%
      mutate(mayorista = m$cadena,
             id_sucursal_unico = paste(id_comercio, id_bandera, id_sucursal, sep = "_"))
    inventario[[i]] <- tibble(cadena = m$cadena, registros = nrow(bases[[i]]))
  }
  base_consolidada <- bind_rows(bases)

  #Registramos la procedencia y el tamaño de cada cadena para poder contrastar la consolidación con los archivos de entrada
  origen <- tibble(modo = "crudos", filtro_geografico_verificable = TRUE,
                   detalle = "Unión reconstruida desde archivos originales indicados en el manifest.")
  write_csv(bind_rows(inventario), "output/tablas/01_inventario_importacion.csv")
} else {
  #3.RECUPERACIÓN PARCIAL
  #Recurrimos a la copia recuperada cuando no están disponibles todas las entradas originales
  #Dejamos señalado que faltan provincia, localidad y nombre de sucursal y que esta vía no permite verificar el alcance geográfico
  if (!file.exists("auxiliar/base_recuperada.csv.gz")) {
    stop("Faltan los archivos crudos y auxiliar/base_recuperada.csv.gz. Completar el manifest.")
  }
  base_consolidada <- read_csv("auxiliar/base_recuperada.csv.gz",
    col_types = cols(.default = col_character()), show_col_types = FALSE)
  origen <- tibble(modo = "recuperacion_parcial", filtro_geografico_verificable = FALSE,
    detalle = paste("22 columnas recuperadas; faltan provincia, localidad y nombre de sucursal.",
                    "No se puede confirmar el alcance geográfico ni rehacer la descarga original."))
  warning("Se usan los datos recuperados: la procedencia geográfica queda pendiente de verificar.")
}

#4.GUARDADO DE LA BASE Y SU PROCEDENCIA
#Guardamos la base y su origen para que la limpieza pueda comenzar en una sesión nueva
saveRDS(base_consolidada, "input/base_consolidada.rds")
write_csv(origen, "output/tablas/01_procedencia.csv")
