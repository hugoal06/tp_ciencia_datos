# OBJETIVO: visualizar residuos, normalidad y relación con los valores ajustados.
# ORIGEN: histograma recuperado de Rhistory(1).txt; Q-Q y dispersión reconstruidos.
library(tidyverse)
library(fixest)
dir.create("output/tablas", showWarnings = FALSE, recursive = TRUE)
dir.create("output/graficos", showWarnings = FALSE, recursive = TRUE)
obj <- readRDS("input/modelo_precios.rds")
modelo <- obj$modelo
diagnostico <- tibble(id_producto = obj$datos$id_producto,
  mayorista = obj$datos$mayorista, residuos = as.numeric(resid(modelo)),
  ajustados = as.numeric(fitted(modelo)))
write_csv(diagnostico, "output/tablas/08_residuos_ajustados.csv")
# Los diagnósticos son descriptivos. La covarianza robusta no elimina extremos
# ni corrige una especificación incorrecta; tampoco demuestra independencia.
g <- ggplot(diagnostico, aes(x = residuos)) +
  geom_histogram(bins = 50, fill = "#2A9D8F", color = "white") +
  geom_vline(xintercept = 0, color = "#D97706") +
  labs(title = "Distribución de los residuos", x = "Residuo en logaritmos", y = "Observaciones",
       caption = "Fuente: elaboración propia con datos del SEPA.") + theme_minimal()
ggsave("output/graficos/08_histograma_residuos.png", g, width = 9, height = 6, dpi = 300)
g <- ggplot(diagnostico, aes(sample = residuos)) + stat_qq(alpha = .25) + stat_qq_line(color = "#D97706") +
  labs(title = "Normalidad de los residuos: gráfico Q-Q", x = "Cuantil normal teórico", y = "Cuantil observado",
       caption = "Fuente: elaboración propia con datos del SEPA.") + theme_minimal()
ggsave("output/graficos/08_qq_residuos.png", g, width = 9, height = 6, dpi = 300)
g <- ggplot(diagnostico, aes(x = ajustados, y = residuos)) + geom_point(alpha = .12, size = .6) +
  geom_hline(yintercept = 0, color = "#D97706") +
  labs(title = "Residuos frente a precios ajustados", x = "Logaritmo del precio ajustado", y = "Residuo en logaritmos",
       caption = "Fuente: elaboración propia con datos del SEPA.") + theme_minimal()
ggsave("output/graficos/08_residuos_ajustados.png", g, width = 9, height = 6, dpi = 300)
