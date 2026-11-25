#1.CANASTA PRESENTE EN LAS CINCO CADENAS
library(tidyverse)
source("utils/comprobar_columnas.R")
source("utils/abreviar_cadenas.R")
dir.create("output/tablas", showWarnings = FALSE, recursive = TRUE)
dir.create("output/graficos", showWarnings = FALSE, recursive = TRUE)
base <- readRDS("input/base_limpia.rds")
precios <- readRDS("input/precios_por_cadena.rds")
comprobar_columnas(base, c("id_producto", "productos_descripcion"))

#Exigimos los mismos productos en las cinco cadenas para comparar sus precios sin cambios en la composición de la canasta
#Tomamos la mediana entre cadenas como referencia de cada producto y expresamos las diferencias como brechas porcentuales
canasta <- precios %>% group_by(id_producto) %>% filter(n_distinct(mayorista) == 5) %>%
  mutate(precio_referencia = median(precio_mediano),
         brecha_pct = 100 * (precio_mediano / precio_referencia - 1)) %>% ungroup()

#2.CLASIFICACIÓN DE LOS PRODUCTOS
#Usamos una descripción por código para añadir el rubro sin multiplicar las observaciones
#Normalizamos mayúsculas y espacios y clasificamos según los prefijos de las descripciones comerciales
#Reservamos la categoría Revisar para los productos que no coinciden con las reglas
catalogo <- base %>% semi_join(canasta, by = "id_producto") %>% group_by(id_producto) %>%
  summarise(descripcion = first(productos_descripcion), .groups = "drop") %>%
  mutate(descripcion = str_squish(str_to_upper(descripcion)), rubro = case_when(
    str_detect(descripcion, "^(QUITAM|BLOQ|LIMP |ESPO |LANA ACERO)") ~ "Limpieza del hogar",
    str_detect(descripcion, "^(DEO|CRE SO|CREM CORP|ACOND|SHAMP|CEP |JAB |CD KOLYNOS)") ~ "Cuidado personal",
    str_detect(descripcion, "^(ACETO|JUGO LIMON|NUEZ MOSC|PIMIENTA|SAL |SALERO|SALSA|MAYO|MOSTAZA)") ~ "Condimentos y salsas",
    str_detect(descripcion, "^(GALLE|CEREAL|YERBA|FID |ARROZ|APER |NESTUM|LECHE)") ~ "Alimentos y bebidas",
    TRUE ~ "Revisar"))
write_csv(catalogo, "output/tablas/11_clasificacion_productos.csv")
write_csv(count(catalogo, rubro, name = "productos"), "output/tablas/11_productos_por_rubro.csv")

#Detenemos el análisis cuando quedan productos sin clasificar para revisar el catálogo antes de interpretar los rubros
if (any(catalogo$rubro == "Revisar" | is.na(catalogo$rubro))) {
  stop("Hay productos sin rubro. Revisar 11_clasificacion_productos.csv; no se excluyen silenciosamente.")
}

#Registramos el tamaño observado de la canasta y su coincidencia con los 54 productos de la presentación
write_csv(tibble(productos = n_distinct(canasta$id_producto),
  observaciones = nrow(canasta), coincide_54_productos = n_distinct(canasta$id_producto) == 54),
  "output/tablas/11_dimension_canasta.csv")

#3.ORDEN DE LAS CADENAS Y LOS RUBROS
#Fijamos el mismo orden en todos los paneles para facilitar la comparación de posiciones
datos <- left_join(canasta, catalogo, by = "id_producto") %>%
  mutate(cadena = factor(abreviar_cadenas(mayorista), levels = c("Makro", "Maxiconsumo", "Vital", "Yaguar", "NINI")),
         rubro = factor(rubro, levels = c("Alimentos y bebidas", "Condimentos y salsas", "Cuidado personal", "Limpieza del hogar")))

#Calculamos los tamaños por rubro desde el catálogo para contar cada producto una sola vez
conteos <- count(catalogo, rubro, name = "n")
etiquetas <- setNames(paste0(conteos$rubro, " · ", conteos$n, " productos"), conteos$rubro)

#4.GRÁFICO EXPLORATORIO
#Cada punto representa un producto y una cadena y las cajas resumen el 50 % central de sus brechas
#Desplazamos los puntos solo verticalmente para conservar su brecha porcentual exacta
#Fijamos la semilla para mantener esa separación visual entre ejecuciones
set.seed(24)
g <- ggplot(datos, aes(x = brecha_pct, y = cadena)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
  geom_boxplot(outlier.shape = NA, fill = "#DCEAE8", width = .55) +
  geom_jitter(height = .12, width = 0, alpha = .6, color = "#277F81", size = 1.2) +
  facet_wrap(~ rubro, ncol = 2, labeller = labeller(rubro = etiquetas)) +
  scale_x_continuous(labels = scales::label_number(suffix = " %", decimal.mark = ",")) +
  labs(title = "Distribución de las brechas de precios por rubro",
    subtitle = paste(n_distinct(canasta$id_producto), "productos presentes en las cinco cadenas"),
    x = "Diferencia respecto de la mediana del mismo producto (%)", y = NULL,
    caption = "Fuente: elaboración propia con datos del SEPA. Las cajas muestran el 50 % central.") + theme_minimal()
ggsave("output/graficos/11_exploratorio_rubros.png", g, width = 12, height = 8, dpi = 300)

#5.BRECHAS MEDIANAS Y GRÁFICO COMUNICATIVO
#Usamos la mediana de las brechas para resumir la posición de cada cadena dentro de un rubro
resumen <- datos %>% group_by(rubro, cadena) %>% summarise(brecha_mediana = median(brecha_pct), .groups = "drop") %>%
  mutate(etiqueta = paste0(if_else(brecha_mediana > 0, "+", ""),
    formatC(brecha_mediana, format = "f", digits = 1, decimal.mark = ","), " %"))
write_csv(resumen, "output/tablas/11_brechas_por_rubro.csv")

#Adaptamos el título al resultado observado para destacar a Makro únicamente cuando encabeza todos los rubros
maximos <- resumen %>% group_by(rubro) %>% filter(brecha_mediana == max(brecha_mediana)) %>% ungroup()
titulo <- if (all(as.character(maximos$cadena) == "Makro"))
  "Makro presenta la mayor brecha mediana en los cuatro rubros" else "Brechas medianas de precios por cadena y rubro"

#Mantenemos el cero como referencia de la comparación y destacamos a Makro con el mismo color entre paneles
#Añadimos el porcentaje sobre cada barra para facilitar la lectura de magnitudes y signos
g <- ggplot(resumen, aes(x = brecha_mediana, y = cadena)) +
  geom_vline(xintercept = 0, color = "grey50") +
  geom_col(aes(fill = cadena == "Makro"), width = .6, show.legend = FALSE) +
  scale_fill_manual(values = c("FALSE" = "#BFD1D8", "TRUE" = "#B84F16")) +
  geom_text(aes(label = etiqueta, hjust = if_else(brecha_mediana >= 0, -.1, 1.1)), size = 3) +
  facet_wrap(~ rubro, ncol = 2, labeller = labeller(rubro = etiquetas)) +
  scale_x_continuous(labels = scales::label_number(suffix = " %"), expand = expansion(mult = .3)) +
  labs(title = titulo, x = "Brecha mediana respecto del precio de referencia (%)", y = NULL,
    caption = "Fuente: elaboración propia con datos del SEPA. Referencia: mediana del mismo producto entre cadenas.") + theme_minimal()
ggsave("output/graficos/11_comunicativo_rubros.png", g, width = 12, height = 8, dpi = 300)

#Conservamos la canasta como dato procesado para reutilizarla sin reconstruir los gráficos
saveRDS(canasta, "input/canasta_cinco_cadenas.rds")
