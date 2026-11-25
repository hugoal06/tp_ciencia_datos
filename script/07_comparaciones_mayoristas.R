# OBJETIVO: comparar las cadenas por pares con inferencia robusta y ajuste Tukey.
# ORIGEN: bloque emmeans recuperado de Rhistory(1).txt; entradas/salidas adaptadas.
library(tidyverse)
library(fixest)
library(emmeans)
source("utils/abreviar_cadenas.R")
dir.create("output/tablas", showWarnings = FALSE, recursive = TRUE)
dir.create("output/graficos", showWarnings = FALSE, recursive = TRUE)
obj <- readRDS("input/modelo_precios.rds")
modelo <- obj$modelo
datos <- obj$datos
# La entrada se pasa explícitamente para recuperar el modelo en una sesión nueva.
# Los contrastes de EMM son válidos aunque el modelo absorba el intercepto.
medias <- emmeans(modelo, ~ mayorista, data = datos,
  vcov. = vcov(modelo, cluster = ~ id_producto),
  df = n_distinct(datos$id_producto) - 1)
pares <- contrast(medias, method = "pairwise", adjust = "tukey")
tabla <- as.data.frame(summary(pares, infer = c(TRUE, TRUE), adjust = "tukey")) %>%
  mutate(razon_precios = exp(estimate), diferencia_porcentual = 100 * expm1(estimate),
         significativo = p.value < .05,
         valor_p_ajustado_presentacion = format.pval(p.value, digits = 4, eps = .0001))
# Los valores p se guardan con su precisión numérica; nunca se sustituyen por cero.
write_csv(tabla, "output/tablas/07_comparaciones_tukey.csv")
g <- ggplot(tabla, aes(x = diferencia_porcentual, y = reorder(contrast, diferencia_porcentual))) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
  geom_point(aes(color = significativo), size = 3) +
  scale_color_manual(values = c("TRUE" = "#277F81", "FALSE" = "#64717A"),
                     labels = c("FALSE" = "No significativa", "TRUE" = "Significativa")) +
  labs(title = "Diferencias de precios entre mayoristas", x = "Diferencia del primero respecto del segundo (%)",
       y = NULL, color = "Ajuste Tukey",
       caption = "Fuente: elaboración propia con datos del SEPA. Efectos fijos y errores agrupados por producto.") + theme_minimal()
ggsave("output/graficos/07_comparaciones_mayoristas.png", g, width = 13, height = 7, dpi = 300)
