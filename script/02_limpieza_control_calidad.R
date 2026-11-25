#1.BASE DE ENTRADA Y CONVERSIÓN NUMÉRICA
library(tidyverse)
source("utils/comprobar_columnas.R")
source("utils/abreviar_cadenas.R")
dir.create("output/tablas", showWarnings = FALSE, recursive = TRUE)
dir.create("output/graficos", showWarnings = FALSE, recursive = TRUE)
base <- readRDS("input/base_consolidada.rds")
procedencia <- read_csv("output/tablas/01_procedencia.csv", show_col_types = FALSE)
precio <- "precio_unitario_bulto_por_unidad_venta_con_iva"
comprobar_columnas(base, c("id_producto", "mayorista", precio), "Base consolidada")

#Convertimos precios y cantidades con el punto como separador decimal y registramos los valores que no se pueden interpretar
columnas_numericas <- intersect(c(precio, "precio_unitario_bulto_por_unidad_venta_sin_iva",
  "unidad_venta", "precio_bulto_con_iva", "precio_bulto_sin_iva",
  "productos_precio_unitario_con_iva_promo1", "productos_precio_unitario_sin_iva_promo1",
  "productos_precio_unitario_con_iva_promo2", "productos_precio_unitario_sin_iva_promo2"), names(base))
conversiones <- list()
for (col in columnas_numericas) {
  original <- as.character(base[[col]])
  convertido <- suppressWarnings(as.numeric(original))
  conversiones[[col]] <- tibble(variable = col,
    conversiones_fallidas = sum(!is.na(original) & trimws(original) != "" & is.na(convertido)))
  base[[col]] <- convertido
}
write_csv(bind_rows(conversiones), "output/tablas/02_conversiones.csv")

#Detenemos la limpieza ante conversiones fallidas para revisar el formato antes de utilizar las variables en el análisis
if (any(bind_rows(conversiones)$conversiones_fallidas > 0)) {
  stop("Existen números que no pudieron convertirse. Revisar 02_conversiones.csv y el formato decimal.")
}

#2.SELECCIÓN GEOGRÁFICA Y DE CADENAS
#Seleccionamos Provincia de Buenos Aires con el código numérico 06 y dejamos fuera a CABA
#Comprobamos la codificación provincial antes del filtro y mantenemos la selección recuperada con una advertencia cuando falta esa columna
n_importados <- nrow(base)
if ("sucursales_provincia" %in% names(base)) {
  write_csv(count(base, sucursales_provincia, name = "registros"),
            "output/tablas/02_provincias_originales.csv")
  codigos <- trimws(as.character(base$sucursales_provincia))
  if (!all(is.na(codigos) | codigos %in% as.character(0:99) |
           codigos %in% sprintf("%02d", 0:99))) {
    stop("La provincia no usa códigos numéricos reconocibles. Revisar la codificación original.")
  }
  base <- base[!is.na(codigos) & suppressWarnings(as.integer(codigos)) == 6, ]
} else {
  warning("No hay provincia recuperada: se conserva la selección guardada, sin certificar su geografía.")
}

#Restringimos la comparación a las cinco cadenas que forman la muestra del trabajo
permitidas <- c("Hipermercado Makro", "Maxiconsumo", "Mayorista Yaguar",
               "NINI Centro de compras mayoristas", "Supermayorista Vital")
base <- base %>% filter(mayorista %in% permitidas)

#3.VALIDEZ DE LOS REGISTROS Y COMPARACIÓN DEL TRATAMIENTO
#Tomamos la muestra geográfica de las cinco cadenas como referencia para medir el efecto de los filtros de validez
antes <- base

#Excluimos registros sin identificación y precios no positivos o no finitos para construir una muestra utilizable en las comparaciones
control <- antes %>% mutate(
  id_invalido = is.na(id_producto) | trimws(id_producto) == "",
  precio_invalido = !is.finite(.data[[precio]]) | .data[[precio]] <= 0,
  cadena_invalida = is.na(mayorista) | trimws(mayorista) == "")
write_csv(control %>% filter(id_invalido | precio_invalido | cadena_invalida),
          "output/tablas/02_observaciones_excluidas.csv")
base <- control %>% filter(!id_invalido, !precio_invalido, !cadena_invalida) %>%
  select(-id_invalido, -precio_invalido, -cadena_invalida)

#Contamos los faltantes de cada columna antes y después para hacer visibles las consecuencias de las exclusiones
faltantes <- bind_rows(
  tibble(etapa = "antes", variable = names(antes), nulos = map_int(antes, ~ sum(is.na(.x)))),
  tibble(etapa = "despues", variable = names(base), nulos = map_int(base, ~ sum(is.na(.x)))))
write_csv(faltantes, "output/tablas/02_faltantes.csv")

#Comparamos el tamaño de la muestra y la tendencia central del precio para cuantificar el efecto del tratamiento
resumen <- bind_rows(
  antes %>% summarise(etapa = "antes", n = n(), media = mean(.data[[precio]], na.rm = TRUE),
                       mediana = median(.data[[precio]], na.rm = TRUE)),
  base %>% summarise(etapa = "despues", n = n(), media = mean(.data[[precio]]),
                      mediana = median(.data[[precio]])))
write_csv(resumen, "output/tablas/02_antes_despues.csv")

#4.DETECCIÓN DE ATÍPICOS Y REVISIÓN DEL MÁXIMO
#Aplicamos el rango intercuartílico al conjunto de precios para señalar candidatos a revisión
#Conservamos esos candidatos porque la variedad de productos puede generar diferencias de precio reales
q <- quantile(base[[precio]], c(.25, .75))
ric <- q[2] - q[1]
limite_inferior <- unname(q[1] - 1.5 * ric)
limite_superior <- unname(q[2] + 1.5 * ric)
base <- base %>% mutate(atipico_ric = .data[[precio]] < limite_inferior |
                                      .data[[precio]] > limite_superior)
write_csv(tibble(n_importados = n_importados, n_validos = nrow(base),
  atipicos = sum(base$atipico_ric), limite_inferior, limite_superior,
  tratamiento = "Conservar; el precio depende también del tipo de producto."),
  "output/tablas/02_control_calidad.csv")
write_csv(filter(base, atipico_ric), "output/tablas/02_atipicos.csv")

#Revisamos el precio máximo junto con las unidades y el precio del bulto para evaluar su consistencia interna
maximo <- base %>% filter(.data[[precio]] == max(.data[[precio]]))
if (all(c("unidad_venta", "precio_bulto_con_iva") %in% names(maximo))) {
  #Admitimos diferencias menores de dos centavos para contemplar redondeos entre el precio unitario y el total del bulto
  maximo <- maximo %>% mutate(
    diferencia_bulto = precio_bulto_con_iva - .data[[precio]] * unidad_venta,
    consistente_bulto = is.finite(diferencia_bulto) & abs(diferencia_bulto) < .02)
}
write_csv(maximo, "output/tablas/02_revision_precio_maximo.csv")

#Identificamos claves repetidas sin eliminarlas automáticamente porque pueden corresponder a distintas presentaciones
write_csv(base %>% count(id_producto, mayorista, id_sucursal_unico) %>% filter(n > 1),
          "output/tablas/02_duplicados_por_clave.csv")

#5.DIAGNÓSTICO VISUAL Y BASE LIMPIA
#Usamos una escala logarítmica para mostrar conjuntamente precios con órdenes de magnitud distintos
#Conservamos el indicador de atípicos en la base para seguir identificando los casos durante el análisis
g <- ggplot(base, aes(x = abreviar_cadenas(mayorista), y = .data[[precio]])) +
  geom_boxplot(outlier.alpha = .1, fill = "#BFDAD8") + scale_y_log10(labels = scales::label_number(big.mark = ".", decimal.mark = ",")) +
  labs(title = "Precios y valores extremos por mayorista", x = "Mayorista",
       y = "Precio unitario con IVA (ARS, escala logarítmica)",
       caption = "Fuente: elaboración propia con datos del SEPA.") + theme_minimal()
ggsave("output/graficos/02_control_atipicos.png", g, width = 10, height = 6, dpi = 300)
saveRDS(base, "input/base_limpia.rds")
