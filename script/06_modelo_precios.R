# OBJETIVO: estimar diferencias entre cadenas controlando efectos fijos por producto.
# ORIGEN: reconstrucción explícita a partir del PDF y de las llamadas al modelo
# en Rhistory(1).txt. No se presenta como recuperación de la línea original.
library(tidyverse)
library(fixest)
source("utils/comprobar_columnas.R")
dir.create("output/tablas", showWarnings = FALSE, recursive = TRUE)
datos <- readRDS("input/productos_comparables.rds")
comprobar_columnas(datos, c("id_producto", "mayorista", "precio_mediano"))
datos <- datos %>% mutate(log_precio = log(precio_mediano), mayorista = factor(mayorista))
# Agrupar por producto contempla dependencia dentro de cada referencia.
# Log(precio) y log(precio/mediana_producto) dan los mismos coeficientes de cadena
# cuando se incluyen efectos fijos por producto; aquí se usa la ecuación del PDF.
modelo <- feols(log_precio ~ mayorista | id_producto, data = datos,
                vcov = ~ id_producto)
# El contraste conjunto evalúa las cuatro diferencias frente a la referencia.
contraste <- as.list(wald(modelo, keep = "^mayorista", print = FALSE))
if (!is.list(contraste) || !all(c("stat", "p", "df1", "df2") %in% names(contraste))) {
  stop("El formato devuelto por fixest::wald no es el esperado. Revisar la versión de fixest.")
}
global <- tibble(observaciones = nobs(modelo), productos = n_distinct(datos$id_producto),
  mayoristas = n_distinct(datos$mayorista), estadistico_f_wald = as.numeric(contraste$stat),
  gl_numerador = as.numeric(contraste$df1), gl_denominador = as.numeric(contraste$df2),
  valor_p = as.numeric(contraste$p),
  valor_p_presentacion = format.pval(as.numeric(contraste$p), digits = 4, eps = 2.2e-16),
  errores = "Robustos agrupados por producto",
  cadena_referencia = levels(datos$mayorista)[1],
  especificacion = "log(precio_mediano) ~ mayorista | id_producto")
write_csv(global, "output/tablas/06_contraste_global.csv")
ct <- as.data.frame(coeftable(modelo)) %>% rownames_to_column("termino")
write_csv(ct, "output/tablas/06_coeficientes.csv")
writeLines(capture.output(summary(modelo)), "output/tablas/06_resumen_modelo.txt")
writeLines(capture.output(sessionInfo()), "output/tablas/06_versiones_paquetes.txt")
saveRDS(list(modelo = modelo, datos = datos), "input/modelo_precios.rds")
