#1.CATÁLOGO DE NINI Y PRECIOS PROMOCIONALES
library(tidyverse)
source("utils/comprobar_columnas.R")
dir.create("output/tablas", showWarnings = FALSE, recursive = TRUE)
dir.create("output/graficos", showWarnings = FALSE, recursive = TRUE)
base <- readRDS("input/base_limpia.rds")
precio <- "precio_unitario_bulto_por_unidad_venta_con_iva"
cols_promo <- c("productos_precio_unitario_con_iva_promo1", "productos_precio_unitario_con_iva_promo2")
comprobar_columnas(base, c("mayorista", precio, cols_promo), "Datos para promociones")

#Usamos los registros de NINI de la misma base limpia para mantener los filtros geográficos y de validez del análisis general
nini <- base %>% filter(mayorista == "NINI Centro de compras mayoristas")
if (!nrow(nini)) stop("No hay observaciones de NINI.")

#Descartamos precios promocionales no positivos o no finitos porque no identifican una oferta válida
matriz <- as.matrix(nini[cols_promo])
matriz[!is.finite(matriz) | matriz <= 0] <- NA_real_

#Elegimos la menor oferta positiva de cada registro para resumir las dos promociones sin duplicar observaciones
mejor <- pmin(matriz[, 1], matriz[, 2], na.rm = TRUE)
mejor[!is.finite(mejor)] <- NA_real_

#2.PROMOCIONES PUBLICADAS Y DESCUENTOS EFECTIVOS
#Distinguimos la existencia de una oferta de una rebaja efectiva respecto del precio unitario de lista
#Expresamos la rebaja como porcentaje del precio de lista y dejamos sin tasa los registros que no tienen descuento
nini <- nini %>% mutate(precio_promocional = mejor,
  promocion_publicada = !is.na(precio_promocional),
  descuento_efectivo = promocion_publicada & precio_promocional < .data[[precio]],
  descuento_pct = if_else(descuento_efectivo, 100 * (1 - precio_promocional / .data[[precio]]), NA_real_))

#3.INCIDENCIA Y MAGNITUD DE LOS DESCUENTOS
#Calculamos la incidencia de promociones y descuentos sobre todo el catálogo de NINI incluido en la muestra
#Resumimos la magnitud del descuento únicamente entre los registros con una rebaja efectiva
resumen <- nini %>% summarise(registros = n(), media = mean(.data[[precio]]),
  mediana = median(.data[[precio]]), promociones_publicadas = sum(promocion_publicada),
  porcentaje_promociones_publicadas = 100 * mean(promocion_publicada),
  descuentos_efectivos = sum(descuento_efectivo),
  porcentaje_descuentos_efectivos = 100 * mean(descuento_efectivo),
  descuento_mediano_pct = if (any(descuento_efectivo)) median(descuento_pct, na.rm = TRUE) else NA_real_)
write_csv(resumen, "output/tablas/04_nini_resumen.csv")
write_csv(select(nini, id_producto, all_of(precio), precio_promocional,
                 promocion_publicada, descuento_efectivo, descuento_pct),
          "output/tablas/04_nini_promociones.csv")

#4.DISTRIBUCIÓN DE LOS DESCUENTOS EFECTIVOS
#Mostramos solo las rebajas efectivas y usamos intervalos de cinco puntos porcentuales para comparar sus frecuencias
g <- ggplot(filter(nini, descuento_efectivo), aes(x = descuento_pct)) +
  geom_histogram(binwidth = 5, fill = "#277F81", color = "white") +
  labs(title = "Descuentos efectivos publicados en NINI", x = "Descuento (%)", y = "Registros",
       caption = "Fuente: elaboración propia con datos del SEPA. Menor oferta positiva por registro.") + theme_minimal()
ggsave("output/graficos/04_nini_descuentos.png", g, width = 9, height = 5, dpi = 300)
