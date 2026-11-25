# OBJETIVO: estimar y describir tres perfiles de productos comparables.
# ORIGEN: bloque de RRR.hisory.Rhistory, con rutas y persistencia reconstruidas.
# Este historial corresponde a la revisión posterior: log(precio), presencia y
# log(unidades), estandarización, semilla 24, 50 inicios e iter.max = 100.
library(tidyverse)
library(cluster)
library(grid)
source("utils/comprobar_columnas.R")
source("utils/dibujar_cuadro_clusters.R")
dir.create("output/tablas", showWarnings = FALSE, recursive = TRUE)
dir.create("output/graficos", showWarnings = FALSE, recursive = TRUE)
base <- readRDS("input/base_limpia.rds")
precio <- "precio_unitario_bulto_por_unidad_venta_con_iva"
comprobar_columnas(base, c("id_producto", "mayorista", "unidad_venta", precio))
producto_cadena <- base %>% filter(is.finite(unidad_venta), unidad_venta > 0) %>%
  group_by(id_producto, mayorista) %>% summarise(
    precio = median(.data[[precio]]), unidades_bulto = median(unidad_venta), .groups = "drop")
productos <- producto_cadena %>% group_by(id_producto) %>% summarise(
  precio_representativo = median(precio), presencia = n_distinct(mayorista),
  unidades_bulto = median(unidades_bulto), .groups = "drop") %>% filter(presencia >= 2)
# Mantener el orden de id_producto ayuda a reproducir la asignación original.
productos <- arrange(productos, id_producto)
matriz <- productos %>% transmute(log_precio = log(precio_representativo),
  presencia = presencia, log_unidades = log(unidades_bulto)) %>% scale()
if (any(!is.finite(matriz))) stop("Variables de clustering constantes o no finitas.")
set.seed(24)
modelo <- kmeans(matriz, centers = 3, nstart = 50, iter.max = 100)
productos <- productos %>% mutate(cluster = factor(modelo$cluster))
# La silueta se calcula sobre toda la muestra, sin sustituirla por una muestra aleatoria.
silueta <- silhouette(modelo$cluster, dist(matriz))
write_csv(tibble(productos = nrow(productos), k = 3, silueta_promedio = mean(silueta[, "sil_width"]),
  algoritmo = "Hartigan-Wong", semilla = 24, nstart = 50, iter_max = 100),
  "output/tablas/09_calidad_clustering.csv")
resumen <- productos %>% group_by(cluster) %>% summarise(productos = n(),
  precio_mediano = median(precio_representativo), precio_promedio = mean(precio_representativo),
  presencia_media = mean(presencia), unidades_mediana = median(unidades_bulto), .groups = "drop") %>%
  mutate(porcentaje = 100 * productos / sum(productos),
    perfil = case_when(precio_mediano == max(precio_mediano) ~ "Mayor precio y menor presencia",
      precio_mediano == min(precio_mediano) ~ "Menor precio y bultos más grandes",
      TRUE ~ "Precio intermedio y mayor presencia"))
# Los nombres son una interpretación descriptiva: comprobar también presencia
# y unidades en la tabla; los números de cluster no tienen significado económico.
write_csv(resumen, "output/tablas/09_perfiles_clusters.csv")
write_csv(productos, "output/tablas/09_asignacion_clusters.csv")
# Se contrasta contra la asignación recuperada. Una permutación de las etiquetas
# no altera el agrupamiento; la tabla de contingencia permite comprobarlo.
if (file.exists("auxiliar/productos_cluster_guardados.csv.gz")) {
  guardados <- read_csv("auxiliar/productos_cluster_guardados.csv.gz",
    col_types = cols(id_producto = col_character(), cluster = col_character()), show_col_types = FALSE)
  comparacion <- full_join(select(productos, id_producto, cluster),
    select(guardados, id_producto, cluster), by = "id_producto", suffix = c("_nuevo", "_guardado"))
  write_csv(count(comparacion, cluster_nuevo, cluster_guardado, name = "productos"),
            "output/tablas/09_contingencia_asignaciones.csv")
}
set.seed(24)
tabla_codo <- map_dfr(1:8, function(k) {
  aux <- kmeans(matriz, centers = k, nstart = 50, iter.max = 100)
  tibble(grupos = k, variacion_interna = aux$tot.withinss)
})
write_csv(tabla_codo, "output/tablas/09_codo.csv")
g <- ggplot(tabla_codo, aes(x = grupos, y = variacion_interna)) + geom_line(color = "#183249") +
  geom_point(color = "#277F81") + geom_vline(xintercept = 3, linetype = "dashed", color = "#B84F16") +
  scale_x_continuous(breaks = 1:8) + labs(title = "Variación interna según el número de grupos",
    x = "Cantidad de grupos", y = "Suma de cuadrados dentro de los grupos",
    caption = "Fuente: elaboración propia con datos del SEPA. Variables estandarizadas.") + theme_minimal()
ggsave("output/graficos/09_codo.png", g, width = 9, height = 5, dpi = 300)
datos_cuadro <- resumen %>% transmute(Perfil = perfil,
  Productos = formatC(productos, format = "d", big.mark = "."),
  Proporcion = paste0(formatC(porcentaje, format = "f", digits = 1, decimal.mark = ","), " %"),
  Precio = paste0("$", formatC(precio_mediano, format = "f", digits = 0, big.mark = ".", decimal.mark = ",")),
  Presencia = formatC(presencia_media, format = "f", digits = 2, decimal.mark = ","),
  Unidades = formatC(unidades_mediana, format = "f", digits = 1, decimal.mark = ","))
cuadro <- grid.grabExpr(dibujar_cuadro_clusters(datos_cuadro, nrow(productos)))
ggsave("output/graficos/09_perfiles_clusters.png", cuadro, width = 24, height = 16,
       units = "cm", dpi = 300, bg = "white")
saveRDS(list(productos = productos, producto_cadena = producto_cadena, matriz = matriz,
  modelo = modelo, silueta = silueta, resumen = resumen), "input/clustering_productos.rds")
