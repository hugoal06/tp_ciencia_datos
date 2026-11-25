#1.CANASTA COMÚN Y BRECHAS PORCENTUALES
library(tidyverse)
dir.create("output/tablas", showWarnings = FALSE, recursive = TRUE)
dir.create("output/graficos", showWarnings = FALSE, recursive = TRUE)

#Reconstruimos la canasta común desde los precios guardados para ejecutar la descomposición sin depender del gráfico por rubro
precios <- readRDS("input/precios_por_cadena.rds")

#Usamos brechas respecto de la mediana de cada producto para comparar artículos con niveles de precios distintos
#Cada combinación de producto y cadena recibe el mismo peso en la descomposición
datos <- precios %>% group_by(id_producto) %>% filter(n_distinct(mayorista) == 5) %>%
  mutate(brecha = 100 * (precio_mediano / median(precio_mediano) - 1)) %>% ungroup()
if (!nrow(datos)) stop("No hay productos presentes en las cinco cadenas.")

#2.COMPONENTES DE LA SUMA DE CUADRADOS
#Tomamos la media general de las brechas como centro de la variabilidad total
media_general <- mean(datos$brecha)
medias <- datos %>% group_by(mayorista) %>% summarise(cantidad = n(), media_cadena = mean(brecha), .groups = "drop")
suma_total <- sum((datos$brecha - media_general)^2)

#Ponderamos la distancia de cada media de cadena a la media general por su cantidad de observaciones
suma_entre <- sum(medias$cantidad * (medias$media_cadena - media_general)^2)
datos <- left_join(datos, medias, by = "mayorista")

#Medimos la variabilidad interna con las desviaciones de cada producto respecto de la brecha media de su cadena
suma_dentro <- sum((datos$brecha - datos$media_cadena)^2)

#Comprobamos la identidad entre la suma de cuadrados total y sus dos componentes antes de calcular las participaciones
stopifnot(isTRUE(all.equal(suma_total, suma_entre + suma_dentro)))
if (suma_total <= 0) stop("La variación total es cero; no se pueden calcular participaciones.")

#3.PARTICIPACIÓN DE CADA COMPONENTE
#Dividimos cada suma de cuadrados por la variabilidad total para expresar su participación en porcentaje
tabla <- tibble(componente = c("Entre cadenas", "Dentro de las cadenas"),
  suma_cuadrados = c(suma_entre, suma_dentro)) %>%
  mutate(proporcion = suma_cuadrados / suma_total, porcentaje = 100 * proporcion)
write_csv(tabla, "output/tablas/12_descomposicion_variabilidad.csv")
write_csv(datos, "output/tablas/12_datos_descomposicion.csv")
write_csv(medias, "output/tablas/12_medias_cadenas.csv")

#Registramos el tamaño de la canasta para contrastar los resultados con los 54 productos y 270 observaciones de la presentación
write_csv(tibble(productos = n_distinct(datos$id_producto), observaciones = nrow(datos),
  cadenas = n_distinct(datos$mayorista), coincide_muestra_pdf = n_distinct(datos$id_producto) == 54 && nrow(datos) == 270),
  "output/tablas/12_dimension_canasta.csv")

#4.REPRESENTACIÓN DE LA DESCOMPOSICIÓN
#Usamos dos barras para comparar participaciones de variabilidad sin confundirlas con brechas de precios
#Fijamos la escala completa de cero a cien por ciento para representar ambas participaciones en su proporción real
#Interpretamos la partición como una descripción de esta canasta y no como un efecto causal de las cadenas
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
