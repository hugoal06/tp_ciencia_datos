# OBJETIVO: construir la muestra producto-mayorista y auditar su comparabilidad.
# ORIGEN: medianas y filtros recuperados de RR.histori.Rhistory y RRR.hisory.Rhistory;
# auditoría de formatos reconstruida. Compartir código no prueba equivalencia física.
library(tidyverse)
source("utils/comprobar_columnas.R")
dir.create("output/tablas", showWarnings = FALSE, recursive = TRUE)
base <- readRDS("input/base_limpia.rds")
precio <- "precio_unitario_bulto_por_unidad_venta_con_iva"
comprobar_columnas(base, c("id_producto", "mayorista", "unidad_venta",
                         "productos_descripcion", "productos_marca", precio))
# Las sucursales reciben igual peso dentro de la mediana de cada producto-cadena.
tabla <- base %>% group_by(id_producto, mayorista) %>% summarise(
  precio_mediano = median(.data[[precio]]), sucursales = n_distinct(id_sucursal_unico),
  unidades_bulto = if (any(is.finite(unidad_venta) & unidad_venta > 0))
    median(unidad_venta[is.finite(unidad_venta) & unidad_venta > 0]) else NA_real_, .groups = "drop")
auditoria <- base %>% group_by(id_producto) %>% summarise(
  cadenas = n_distinct(mayorista),
  descripciones_distintas = n_distinct(str_squish(str_to_upper(productos_descripcion)), na.rm = TRUE),
  marcas_distintas = n_distinct(str_squish(str_to_upper(productos_marca)), na.rm = TRUE),
  formatos_distintos = n_distinct(unidad_venta[is.finite(unidad_venta) & unidad_venta > 0]),
  unidades_faltantes_o_invalidas = sum(!is.finite(unidad_venta) | unidad_venta <= 0), .groups = "drop") %>%
  mutate(requiere_revision = descripciones_distintas > 1 | marcas_distintas > 1 |
           formatos_distintos > 1 | unidades_faltantes_o_invalidas > 0,
    decision = if_else(requiere_revision, "Pendiente de validación comercial manual", "Sin alertas automáticas; equivalencia no certificada"))
write_csv(auditoria, "output/tablas/05_auditoria_comparabilidad.csv")
# Se conserva el criterio histórico id_producto + presencia >= 2 para poder
# contrastar el PDF. No se excluyen alertas de formato sin una decisión documentada.
comparables <- tabla %>% group_by(id_producto) %>% filter(n_distinct(mayorista) >= 2) %>%
  mutate(mediana_producto = median(precio_mediano),
         precio_relativo = precio_mediano / mediana_producto,
         log_precio_relativo = log(precio_relativo)) %>% ungroup()
write_csv(tibble(productos = n_distinct(comparables$id_producto),
  observaciones = nrow(comparables), mayoristas = n_distinct(comparables$mayorista),
  productos_con_alertas = sum(auditoria$requiere_revision & auditoria$cadenas >= 2)),
  "output/tablas/05_muestra_comparable.csv")
# Contraste contra la tabla efectivamente recuperada; no se fuerza la coincidencia.
if (file.exists("auxiliar/tabla_producto_mayorista_guardada.csv.gz")) {
  guardada <- read_csv("auxiliar/tabla_producto_mayorista_guardada.csv.gz",
    col_types = cols(id_producto = col_character()), show_col_types = FALSE)
  contraste <- full_join(select(comparables, id_producto, mayorista, precio_mediano),
    select(guardada, id_producto, mayorista, precio_mediano),
    by = c("id_producto", "mayorista"), suffix = c("_recalculado", "_guardado")) %>%
    mutate(diferencia = precio_mediano_recalculado - precio_mediano_guardado)
  write_csv(contraste, "output/tablas/05_contraste_tabla_guardada.csv")
}
saveRDS(tabla, "input/precios_por_cadena.rds")
saveRDS(comparables, "input/productos_comparables.rds")
write_csv(comparables, "output/tablas/05_productos_comparables.csv")
