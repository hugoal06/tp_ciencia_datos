#1.MUESTRA PRODUCTO-MAYORISTA
library(tidyverse)
library(fixest)
source("utils/comprobar_columnas.R")
dir.create("output/tablas", showWarnings = FALSE, recursive = TRUE)
datos <- readRDS("input/productos_comparables.rds")
comprobar_columnas(datos, c("id_producto", "mayorista", "precio_mediano"))

#Usamos el logaritmo del precio mediano para reducir la asimetría y expresar las diferencias entre cadenas como razones de precios
#La primera categoría del factor queda como referencia y la registramos junto con los resultados
datos <- datos %>% mutate(log_precio = log(precio_mediano), mayorista = factor(mayorista))

#2.MODELO CON EFECTOS FIJOS POR PRODUCTO
#Los efectos fijos controlan las diferencias de nivel entre referencias y absorben también la normalización por la mediana de cada producto
#Agrupamos los errores por producto para admitir heterocedasticidad y dependencia entre sus observaciones
modelo <- feols(log_precio ~ mayorista | id_producto, data = datos,
                vcov = ~ id_producto)

#3.CONTRASTE CONJUNTO DE LOS MAYORISTAS
#La prueba de Wald contrasta que todas las diferencias de cadena frente a la categoría de referencia sean cero
contraste <- as.list(wald(modelo, keep = "^mayorista", print = FALSE))

#Comprobamos el formato de la prueba para evitar guardar estadísticos o grados de libertad mal identificados
if (!is.list(contraste) || !all(c("stat", "p", "df1", "df2") %in% names(contraste))) {
  stop("El formato devuelto por fixest::wald no es el esperado. Revisar la versión de fixest.")
}

#Conservamos el valor p numérico y añadimos un formato de presentación para mostrar valores muy pequeños mediante un límite
global <- tibble(observaciones = nobs(modelo), productos = n_distinct(datos$id_producto),
  mayoristas = n_distinct(datos$mayorista), estadistico_f_wald = as.numeric(contraste$stat),
  gl_numerador = as.numeric(contraste$df1), gl_denominador = as.numeric(contraste$df2),
  valor_p = as.numeric(contraste$p),
  valor_p_presentacion = format.pval(as.numeric(contraste$p), digits = 4, eps = 2.2e-16),
  errores = "Robustos agrupados por producto",
  cadena_referencia = levels(datos$mayorista)[1],
  especificacion = "log(precio_mediano) ~ mayorista | id_producto")

#4.RESULTADOS Y OBJETO DEL MODELO
write_csv(global, "output/tablas/06_contraste_global.csv")
ct <- as.data.frame(coeftable(modelo)) %>% rownames_to_column("termino")
write_csv(ct, "output/tablas/06_coeficientes.csv")
writeLines(capture.output(summary(modelo)), "output/tablas/06_resumen_modelo.txt")

#Registramos las versiones de R y de los paquetes para documentar el entorno de estimación
writeLines(capture.output(sessionInfo()), "output/tablas/06_versiones_paquetes.txt")

#Guardamos el modelo junto con sus datos para recalcular las comparaciones y los diagnósticos en nuevas sesiones
saveRDS(list(modelo = modelo, datos = datos), "input/modelo_precios.rds")
