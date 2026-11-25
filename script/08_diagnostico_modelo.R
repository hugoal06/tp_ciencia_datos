#1.RESIDUOS Y VALORES AJUSTADOS
library(tidyverse)
library(fixest)
dir.create("output/tablas", showWarnings = FALSE, recursive = TRUE)
dir.create("output/graficos", showWarnings = FALSE, recursive = TRUE)
obj <- readRDS("input/modelo_precios.rds")
modelo <- obj$modelo

#Reconstruimos residuos y ajustados de la misma estimación para mantener las observaciones del modelo
#Conservamos las claves de producto y cadena para localizar los casos que generen patrones o valores extremos
diagnostico <- tibble(id_producto = obj$datos$id_producto,
  mayorista = obj$datos$mayorista, residuos = as.numeric(resid(modelo)),
  ajustados = as.numeric(fitted(modelo)))
write_csv(diagnostico, "output/tablas/08_residuos_ajustados.csv")

#2.DISTRIBUCIÓN DE LOS RESIDUOS
#Inspeccionamos las colas y la concentración alrededor de cero para identificar asimetrías y posibles valores extremos
g <- ggplot(diagnostico, aes(x = residuos)) +
  geom_histogram(bins = 50, fill = "#2A9D8F", color = "white") +
  geom_vline(xintercept = 0, color = "#D97706") +
  labs(title = "Distribución de los residuos", x = "Residuo en logaritmos", y = "Observaciones",
       caption = "Fuente: elaboración propia con datos del SEPA.") + theme_minimal()
ggsave("output/graficos/08_histograma_residuos.png", g, width = 9, height = 6, dpi = 300)

#3.COMPARACIÓN CON LA DISTRIBUCIÓN NORMAL
#Comparamos los cuantiles de los residuos con los de una normal para evaluar las desviaciones de esa distribución
g <- ggplot(diagnostico, aes(sample = residuos)) + stat_qq(alpha = .25) + stat_qq_line(color = "#D97706") +
  labs(title = "Normalidad de los residuos: gráfico Q-Q", x = "Cuantil normal teórico", y = "Cuantil observado",
       caption = "Fuente: elaboración propia con datos del SEPA.") + theme_minimal()
ggsave("output/graficos/08_qq_residuos.png", g, width = 9, height = 6, dpi = 300)

#4.RESIDUOS FRENTE AL AJUSTE
#Revisamos la relación entre residuos y ajustados para detectar patrones sistemáticos y cambios en la dispersión
#Interpretamos los gráficos como diagnósticos descriptivos que acompañan la inferencia con errores agrupados
#La covarianza robusta no elimina los extremos ni corrige una especificación inadecuada
#La elección de errores agrupados no demuestra independencia entre observaciones
g <- ggplot(diagnostico, aes(x = ajustados, y = residuos)) + geom_point(alpha = .12, size = .6) +
  geom_hline(yintercept = 0, color = "#D97706") +
  labs(title = "Residuos frente a precios ajustados", x = "Logaritmo del precio ajustado", y = "Residuo en logaritmos",
       caption = "Fuente: elaboración propia con datos del SEPA.") + theme_minimal()
ggsave("output/graficos/08_residuos_ajustados.png", g, width = 9, height = 6, dpi = 300)
