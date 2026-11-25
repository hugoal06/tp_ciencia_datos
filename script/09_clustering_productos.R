#1.PRODUCTOS Y VARIABLES DEL CLUSTERING
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

#Exigimos unidades por bulto positivas y finitas para resumirlas y aplicar su logaritmo
#Resumimos primero por producto y cadena para que el precio representativo no dé más peso a los mayoristas con más registros
producto_cadena <- base %>% filter(is.finite(unidad_venta), unidad_venta > 0) %>%
  group_by(id_producto, mayorista) %>% summarise(
    precio = median(.data[[precio]]), unidades_bulto = median(unidad_venta), .groups = "drop")

#Construimos una fila por producto compartido entre al menos dos cadenas con precio, presencia y tamaño del bulto
productos <- producto_cadena %>% group_by(id_producto) %>% summarise(
  precio_representativo = median(precio), presencia = n_distinct(mayorista),
  unidades_bulto = median(unidades_bulto), .groups = "drop") %>% filter(presencia >= 2)

#2.TRANSFORMACIÓN Y ESTANDARIZACIÓN
#Ordenamos los códigos para mantener la correspondencia entre las filas y la asignación reproducible de grupos
productos <- arrange(productos, id_producto)

#Aplicamos logaritmos al precio y a las unidades para reducir la asimetría y la influencia de valores elevados
#Estandarizamos las tres variables para que sus unidades de medida no determinen por sí solas las distancias
matriz <- productos %>% transmute(log_precio = log(precio_representativo),
  presencia = presencia, log_unidades = log(unidades_bulto)) %>% scale()
if (any(!is.finite(matriz))) stop("Variables de clustering constantes o no finitas.")

#3.ESTIMACIÓN DE TRES GRUPOS
#Fijamos la semilla para reproducir los puntos de partida y probamos cincuenta inicializaciones para reducir la dependencia de una sola solución
#Evaluamos tres perfiles y contrastamos su variación interna con alternativas de uno a ocho grupos
set.seed(24)
modelo <- kmeans(matriz, centers = 3, nstart = 50, iter.max = 100)
productos <- productos %>% mutate(cluster = factor(modelo$cluster))

#Calculamos la silueta sobre todos los productos para medir su proximidad al grupo asignado frente a los demás
silueta <- silhouette(modelo$cluster, dist(matriz))
write_csv(tibble(productos = nrow(productos), k = 3, silueta_promedio = mean(silueta[, "sil_width"]),
  algoritmo = "Hartigan-Wong", semilla = 24, nstart = 50, iter_max = 100),
  "output/tablas/09_calidad_clustering.csv")

#4.DESCRIPCIÓN E INTERPRETACIÓN DE LOS PERFILES
#Resumimos los perfiles en unidades originales para interpretar el precio, la presencia y el tamaño del bulto
#Usamos la mediana de precios para nombrar los grupos y dejamos presencia y unidades en la tabla para revisar esa interpretación
#Los identificadores numéricos de los grupos no establecen por sí solos un orden económico
resumen <- productos %>% group_by(cluster) %>% summarise(productos = n(),
  precio_mediano = median(precio_representativo), precio_promedio = mean(precio_representativo),
  presencia_media = mean(presencia), unidades_mediana = median(unidades_bulto), .groups = "drop") %>%
  mutate(porcentaje = 100 * productos / sum(productos),
    perfil = case_when(precio_mediano == max(precio_mediano) ~ "Mayor precio y menor presencia",
      precio_mediano == min(precio_mediano) ~ "Menor precio y bultos más grandes",
      TRUE ~ "Precio intermedio y mayor presencia"))
write_csv(resumen, "output/tablas/09_perfiles_clusters.csv")
write_csv(productos, "output/tablas/09_asignacion_clusters.csv")

#5.CONTRASTE DE LAS ASIGNACIONES
#La contingencia con la asignación guardada permite distinguir cambios de agrupación de un intercambio de etiquetas
if (file.exists("auxiliar/productos_cluster_guardados.csv.gz")) {
  guardados <- read_csv("auxiliar/productos_cluster_guardados.csv.gz",
    col_types = cols(id_producto = col_character(), cluster = col_character()), show_col_types = FALSE)
  comparacion <- full_join(select(productos, id_producto, cluster),
    select(guardados, id_producto, cluster), by = "id_producto", suffix = c("_nuevo", "_guardado"))
  write_csv(count(comparacion, cluster_nuevo, cluster_guardado, name = "productos"),
            "output/tablas/09_contingencia_asignaciones.csv")
}

#6.VARIACIÓN INTERNA Y NÚMERO DE GRUPOS
#Reiniciamos la semilla para repetir también el diagnóstico del codo
#Comparamos la suma de cuadrados interna de uno a ocho grupos para valorar la mejora al añadir perfiles
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

#7.CUADRO DE PERFILES Y GUARDADO DE LA SOLUCIÓN
#Formateamos los resultados solo al preparar el cuadro y conservamos su precisión numérica en las tablas de resultados
datos_cuadro <- resumen %>% transmute(Perfil = perfil,
  Productos = formatC(productos, format = "d", big.mark = "."),
  Proporcion = paste0(formatC(porcentaje, format = "f", digits = 1, decimal.mark = ","), " %"),
  Precio = paste0("$", formatC(precio_mediano, format = "f", digits = 0, big.mark = ".", decimal.mark = ",")),
  Presencia = formatC(presencia_media, format = "f", digits = 2, decimal.mark = ","),
  Unidades = formatC(unidades_mediana, format = "f", digits = 1, decimal.mark = ","))
cuadro <- grid.grabExpr(dibujar_cuadro_clusters(datos_cuadro, nrow(productos)))
ggsave("output/graficos/09_perfiles_clusters.png", cuadro, width = 24, height = 16,
       units = "cm", dpi = 300, bg = "white")

#Guardamos la matriz, la asignación y los precios por cadena para que el análisis de brechas utilice exactamente esta solución
saveRDS(list(productos = productos, producto_cadena = producto_cadena, matriz = matriz,
  modelo = modelo, silueta = silueta, resumen = resumen), "input/clustering_productos.rds")
