# Función recuperada de RRR.hisory.Rhistory; parametrizada para evitar objetos globales.
dibujar_cuadro_clusters <- function(datos_cuadro, total_productos) {
grid.newpage()
grid.text(
"Perfiles de productos identificados",
x = 0.04, y = 0.94, just = "left",
gp = gpar(fontsize = 18, fontface = "bold", col = "#183249")
)
grid.text(
paste0("K-means · ", format(total_productos, big.mark = "."), " productos · Tres grupos"),
x = 0.04, y = 0.87, just = "left",
gp = gpar(fontsize = 11, col = "#52616C")
)
limites <- c(0.04, 0.39, 0.50, 0.61, 0.74, 0.86, 0.98)
centros <- (head(limites, -1) + tail(limites, -1)) / 2
encabezados <- c(
"Perfil", "Productos", "Proporción",
"Precio\nmediano", "Presencia\nmedia",
"Unidades por bulto\n(mediana)"
)
grid.rect(
x = 0.51, y = 0.74, width = 0.94, height = 0.12,
gp = gpar(fill = "#183249", col = NA)
)
for (j in seq_along(encabezados)) {
grid.text(
encabezados[j],
x = if (j == 1) 0.055 else centros[j],
y = 0.74,
just = if (j == 1) "left" else "centre",
gp = gpar(fontsize = 10, fontface = "bold", col = "white")
)
}
for (i in seq_len(nrow(datos_cuadro))) {
posicion_y <- 0.60 - (i - 1) * 0.16
grid.rect(
x = 0.51, y = posicion_y,
width = 0.94, height = 0.16,
gp = gpar(
fill = if (i %% 2 == 1) "#EDF3F6" else "#FFFFFF",
col = "#DCE4E9"
)
)
for (j in seq_len(ncol(datos_cuadro))) {
grid.text(
as.character(datos_cuadro[[j]][i]),
x = if (j == 1) 0.055 else centros[j],
y = posicion_y,
just = if (j == 1) "left" else "centre",
gp = gpar(
fontsize = 11,
col = "#183249",
fontface = if (j == 1) "bold" else "plain"
)
)
}
}
grid.text(
"Presencia media: cantidad de cadenas que comercializan el producto.",
x = 0.04, y = 0.13, just = "left",
gp = gpar(fontsize = 9, col = "#52616C")
)
grid.text(
"Fuente: elaboración propia con datos del SEPA.",
x = 0.04, y = 0.07, just = "left",
gp = gpar(fontsize = 9, col = "#52616C")
)
}
