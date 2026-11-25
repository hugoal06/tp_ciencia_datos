#1.MODELO Y DATOS DE ESTIMACIÓN
library(tidyverse)
library(fixest)
library(emmeans)
source("utils/abreviar_cadenas.R")
dir.create("output/tablas", showWarnings = FALSE, recursive = TRUE)
dir.create("output/graficos", showWarnings = FALSE, recursive = TRUE)

#Leemos los datos junto con el modelo para reconstruir las comparaciones en una sesión nueva
obj <- readRDS("input/modelo_precios.rds")
modelo <- obj$modelo
datos <- obj$datos

#2.COMPARACIONES CON ERRORES AGRUPADOS
#Usamos la matriz de covarianzas agrupada por producto y grados de libertad basados en la cantidad de productos
medias <- emmeans(modelo, ~ mayorista, data = datos,
  vcov. = vcov(modelo, cluster = ~ id_producto),
  df = n_distinct(datos$id_producto) - 1)

#Ajustamos con Tukey la familia de comparaciones por pares para controlar la multiplicidad de pruebas
pares <- contrast(medias, method = "pairwise", adjust = "tukey")

#Transformamos las diferencias en logaritmos a porcentajes del primer mayorista respecto del segundo
#Definimos significación al 5 % sobre los valores p ajustados y añadimos su formato de presentación
tabla <- as.data.frame(summary(pares, infer = c(TRUE, TRUE), adjust = "tukey")) %>%
  mutate(razon_precios = exp(estimate), diferencia_porcentual = 100 * expm1(estimate),
         significativo = p.value < .05,
         valor_p_ajustado_presentacion = format.pval(p.value, digits = 4, eps = .0001))

#Conservamos los valores p numéricos en la tabla y reservamos el formato abreviado para su presentación
write_csv(tabla, "output/tablas/07_comparaciones_tukey.csv")

#3.DIFERENCIAS PORCENTUALES ENTRE PARES
#Ordenamos los contrastes por su diferencia porcentual y usamos el cero como referencia de igualdad
#Distinguimos mediante el color las comparaciones significativas después del ajuste de Tukey
g <- ggplot(tabla, aes(x = diferencia_porcentual, y = reorder(contrast, diferencia_porcentual))) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
  geom_point(aes(color = significativo), size = 3) +
  scale_color_manual(values = c("TRUE" = "#277F81", "FALSE" = "#64717A"),
                     labels = c("FALSE" = "No significativa", "TRUE" = "Significativa")) +
  labs(title = "Diferencias de precios entre mayoristas", x = "Diferencia del primero respecto del segundo (%)",
       y = NULL, color = "Ajuste Tukey",
       caption = "Fuente: elaboración propia con datos del SEPA. Efectos fijos y errores agrupados por producto.") + theme_minimal()
ggsave("output/graficos/07_comparaciones_mayoristas.png", g, width = 13, height = 7, dpi = 300)
