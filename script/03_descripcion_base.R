# OBJETIVO: describir la estructura, las variables y la distribución de precios.
# ORIGEN: tablas recuperadas de Rhistory(1).txt; cálculos y gráficos reconstruidos.
library(tidyverse)
source("utils/comprobar_columnas.R")
source("utils/abreviar_cadenas.R")
dir.create("output/tablas", showWarnings = FALSE, recursive = TRUE)
dir.create("output/graficos", showWarnings = FALSE, recursive = TRUE)
base <- readRDS("input/base_limpia.rds")
precio <- "precio_unitario_bulto_por_unidad_venta_con_iva"
comprobar_columnas(base, c("id_producto", "mayorista", "id_sucursal_unico", precio))
diccionario_fuente <- read_csv("auxiliar/diccionario_recuperado.csv", show_col_types = FALSE)
diccionario <- tibble(variable = names(base),
  clase_r = map_chr(base, ~ class(.x)[1]), nulos = map_int(base, ~ sum(is.na(.x))),
  distintos = map_int(base, ~ n_distinct(.x, na.rm = TRUE))) %>%
  left_join(diccionario_fuente, by = "variable") %>%
  mutate(descripcion = coalesce(descripcion, if_else(variable == "atipico_ric",
    "Indicador reconstruido de precio fuera de los límites intercuartílicos", "Pendiente de describir")),
    porcentaje_nulos = 100 * nulos / nrow(base))
write_csv(diccionario, "output/tablas/03_diccionario_variables.csv")
write_csv(tibble(registros = nrow(base), productos = n_distinct(base$id_producto),
                 mayoristas = n_distinct(base$mayorista), sucursales = n_distinct(base$id_sucursal_unico)),
          "output/tablas/03_dimension_base.csv")
composicion <- base %>% count(mayorista, name = "registros") %>%
  mutate(porcentaje = 100 * registros / sum(registros))
write_csv(composicion, "output/tablas/03_composicion.csv")
estadisticas <- base %>% summarise(n = n(), media = mean(.data[[precio]]),
  mediana = median(.data[[precio]]), desvio = sd(.data[[precio]]),
  minimo = min(.data[[precio]]), q1 = quantile(.data[[precio]], .25),
  q3 = quantile(.data[[precio]], .75), maximo = max(.data[[precio]]))
write_csv(estadisticas, "output/tablas/03_estadisticas_generales.csv")
por_cadena <- base %>% group_by(mayorista) %>% summarise(n = n(),
  media = mean(.data[[precio]]), mediana = median(.data[[precio]]),
  q1 = quantile(.data[[precio]], .25), q3 = quantile(.data[[precio]], .75), .groups = "drop")
write_csv(por_cadena, "output/tablas/03_precios_por_mayorista.csv")
g <- ggplot(composicion, aes(x = reorder(abreviar_cadenas(mayorista), registros), y = registros)) +
  geom_col(fill = "#277F81") + coord_flip() + scale_y_continuous(labels = scales::label_number(big.mark = ".")) +
  labs(title = "Composición de la base por mayorista", x = NULL, y = "Registros",
       caption = "Fuente: elaboración propia con datos del SEPA. Los registros no representan ventas.") + theme_minimal()
ggsave("output/graficos/03_composicion.png", g, width = 9, height = 5, dpi = 300)
g <- ggplot(base, aes(x = .data[[precio]])) + geom_histogram(bins = 60, fill = "#277F81", color = "white") +
  scale_x_log10(labels = scales::label_number(big.mark = ".", decimal.mark = ",")) +
  labs(title = "Distribución del precio unitario con IVA", x = "Precio (ARS, escala logarítmica)",
       y = "Registros", caption = "Fuente: elaboración propia con datos del SEPA.") + theme_minimal()
ggsave("output/graficos/03_distribucion_precios.png", g, width = 9, height = 5, dpi = 300)
