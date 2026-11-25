#1.SOLUCIÓN GUARDADA Y BRECHAS POR PRODUCTO
library(tidyverse)
library(grid)
source("utils/abreviar_cadenas.R")
source("utils/dibujar_tabla_brechas.R")
dir.create("output/tablas", showWarnings = FALSE, recursive = TRUE)
dir.create("output/graficos", showWarnings = FALSE, recursive = TRUE)

#Usamos la asignación guardada para conservar los mismos grupos en la comparación entre cadenas
obj <- readRDS("input/clustering_productos.rds")

#Calculamos la brecha respecto de la mediana de las cadenas que ofrecen cada producto para usar una referencia específica
#La cantidad de cadenas de referencia puede variar entre productos porque la muestra exige presencia en al menos dos mayoristas
datos <- obj$producto_cadena %>% inner_join(select(obj$productos, id_producto, cluster), by = "id_producto") %>%
  group_by(id_producto) %>% mutate(brecha = 100 * (precio / median(precio) - 1)) %>% ungroup()

#2.RESUMEN POR PERFIL Y CADENA
#Resumimos las brechas con su mediana para reducir la influencia de extremos y contamos referencias distintas para mostrar la cobertura de cada comparación
brechas <- datos %>% group_by(cluster, mayorista) %>% summarise(
  productos = n_distinct(id_producto), brecha_mediana = median(brecha), .groups = "drop")
write_csv(brechas, "output/tablas/10_brechas_por_cluster.csv")

#3.CUADRO DE COMPARACIÓN ENTRE PERFILES
#Mantenemos el mismo orden de cadenas en las tres columnas para facilitar su lectura
#Reservamos el redondeo y el signo positivo para el cuadro y conservamos las brechas numéricas en la tabla de resultados
#Interpretamos las diferencias como descripciones de grupos con presencia desigual entre cadenas y no como efectos causales
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
