# OBJETIVO: separar la variación de las brechas entre y dentro de las cadenas.
# ORIGEN: cálculos recuperados de RRRR.hisory.Rhistory (idéntico a .Rhistory).
# Se calcula la canasta desde precios_por_cadena.rds para no depender del script 11.
library(tidyverse)
dir.create("output/tablas", showWarnings = FALSE, recursive = TRUE)
dir.create("output/graficos", showWarnings = FALSE, recursive = TRUE)
precios <- readRDS("input/precios_por_cadena.rds")
datos <- precios %>% group_by(id_producto) %>% filter(n_distinct(mayorista) == 5) %>%
  mutate(brecha = 100 * (precio_mediano / median(precio_mediano) - 1)) %>% ungroup()
if (!nrow(datos)) stop("No hay productos presentes en las cinco cadenas.")
media_general <- mean(datos$brecha)
medias <- datos %>% group_by(mayorista) %>% summarise(cantidad = n(), media_cadena = mean(brecha), .groups = "drop")
suma_total <- sum((datos$brecha - media_general)^2)
suma_entre <- sum(medias$cantidad * (medias$media_cadena - media_general)^2)
datos <- left_join(datos, medias, by = "mayorista")
suma_dentro <- sum((datos$brecha - datos$media_cadena)^2)
stopifnot(isTRUE(all.equal(suma_total, suma_entre + suma_dentro)))
if (suma_total <= 0) stop("La variación total es cero; no se pueden calcular participaciones.")
tabla <- tibble(componente = c("Entre cadenas", "Dentro de las cadenas"),
  suma_cuadrados = c(suma_entre, suma_dentro)) %>%
  mutate(proporcion = suma_cuadrados / suma_total, porcentaje = 100 * proporcion)
write_csv(tabla, "output/tablas/12_descomposicion_variabilidad.csv")
write_csv(datos, "output/tablas/12_datos_descomposicion.csv")
write_csv(medias, "output/tablas/12_medias_cadenas.csv")
write_csv(tibble(productos = n_distinct(datos$id_producto), observaciones = nrow(datos),
  cadenas = n_distinct(datos$mayorista), coincide_muestra_pdf = n_distinct(datos$id_producto) == 54 && nrow(datos) == 270),
  "output/tablas/12_dimension_canasta.csv")
# Dos barras evitan confundir el porcentaje de varianza con una brecha de precio.
g <- ggplot(tabla, aes(x = reorder(componente, porcentaje), y = porcentaje, fill = componente)) +
  geom_col(width = .6, show.legend = FALSE) + coord_flip() +
  scale_fill_manual(values = c("Entre cadenas" = "#277F81", "Dentro de las cadenas" = "#AFC8D1")) +
  geom_text(aes(label = scales::percent(proporcion, accuracy = 1, decimal.mark = ",")), hjust = -.15) +
  scale_y_continuous(limits = c(0, 100), labels = scales::label_number(suffix = " %")) +
  labs(title = "Descomposición de la variabilidad de las brechas",
    subtitle = paste(n_distinct(datos$id_producto), "productos comunes;", nrow(datos), "observaciones producto-cadena"),
    x = NULL, y = "Participación en la variabilidad total (%)",
    caption = "Fuente: elaboración propia con datos del SEPA. Descomposición descriptiva, sin interpretación causal.") + theme_minimal()
ggsave("output/graficos/12_descomposicion_variabilidad.png", g, width = 11, height = 5, dpi = 300)
