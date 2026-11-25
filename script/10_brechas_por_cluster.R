# OBJETIVO: describir brechas por cadena dentro de cada perfil.
# ORIGEN: bloque de brechas y función gráfica de RRR.hisory.Rhistory.
library(tidyverse)
library(grid)
source("utils/abreviar_cadenas.R")
source("utils/dibujar_tabla_brechas.R")
dir.create("output/tablas", showWarnings = FALSE, recursive = TRUE)
dir.create("output/graficos", showWarnings = FALSE, recursive = TRUE)
obj <- readRDS("input/clustering_productos.rds")
datos <- obj$producto_cadena %>% inner_join(select(obj$productos, id_producto, cluster), by = "id_producto") %>%
  group_by(id_producto) %>% mutate(brecha = 100 * (precio / median(precio) - 1)) %>% ungroup()
brechas <- datos %>% group_by(cluster, mayorista) %>% summarise(
  productos = n_distinct(id_producto), brecha_mediana = median(brecha), .groups = "drop")
write_csv(brechas, "output/tablas/10_brechas_por_cluster.csv")
tabla <- brechas %>% mutate(cadena = abreviar_cadenas(mayorista), perfil = paste("Perfil", cluster)) %>%
  select(cadena, perfil, brecha_mediana) %>% pivot_wider(names_from = perfil, values_from = brecha_mediana) %>%
  mutate(cadena = factor(cadena, levels = c("Makro", "Maxiconsumo", "Yaguar", "NINI", "Vital"))) %>%
  arrange(cadena) %>% mutate(cadena = as.character(cadena),
    across(starts_with("Perfil"), ~ paste0(if_else(round(.x, 2) > 0, "+", ""),
      formatC(round(.x, 2) + 0, format = "f", digits = 2, decimal.mark = ","), " %"))) %>%
  select(cadena, `Perfil 1`, `Perfil 2`, `Perfil 3`)
cuadro <- grid.grabExpr(dibujar_tabla_brechas(tabla))
ggsave("output/graficos/10_brechas_por_cluster.png", cuadro, width = 23, height = 14,
       units = "cm", dpi = 300, bg = "white")
# Los perfiles se estiman con cobertura desigual de cadenas; no equivalen a
# rubros rígidos ni convierten las diferencias observadas en efectos causales.
