# Función recuperada de RRR.hisory.Rhistory; recibe la tabla explícitamente.
dibujar_tabla_brechas <- function(tabla_brechas) {
grid.newpage()
grid.text(
"Brechas de precios por cadena y perfil",
x = 0.04, y = 0.94, just = "left",
gp = gpar(fontsize = 17, fontface = "bold", col = "#183249")
)
grid.text(
"Diferencias medianas respecto de la referencia de cada producto",
x = 0.04, y = 0.87, just = "left",
gp = gpar(fontsize = 11, col = "#52616C")
)
posiciones <- c(0.065, 0.495, 0.685, 0.88)
encabezados <- c("Mayorista", "Perfil 1", "Perfil 2", "Perfil 3")
grid.rect(
x = 0.51, y = 0.76,
width = 0.94, height = 0.09,
gp = gpar(fill = "#183249", col = NA)
)
for (j in seq_along(encabezados)) {
grid.text(
encabezados[j],
x = posiciones[j],
y = 0.76,
just = if (j == 1) "left" else "centre",
gp = gpar(fontsize = 12, fontface = "bold", col = "white")
)
}
for (i in seq_len(nrow(tabla_brechas))) {
posicion_y <- 0.66 - (i - 1) * 0.105
es_makro <- tabla_brechas$cadena[i] == "Makro"
fondo <- if (es_makro) {
"#F9EEE7"
} else if (i %% 2 == 0) {
"#FFFFFF"
} else {
"#EDF3F6"
}
grid.rect(
x = 0.51, y = posicion_y,
width = 0.94, height = 0.105,
gp = gpar(fill = fondo, col = "#DCE4E9")
)
for (j in seq_len(ncol(tabla_brechas))) {
grid.text(
as.character(tabla_brechas[[j]][i]),
x = posiciones[j],
y = posicion_y,
just = if (j == 1) "left" else "centre",
gp = gpar(
fontsize = 13,
col = if (es_makro) "#B84F16" else "#183249",
fontface = if (es_makro || j == 1) "bold" else "plain"
)
)
}
}
grid.text(
"Referencia: mediana de las cadenas que ofrecen cada producto.",
x = 0.04, y = 0.13, just = "left",
gp = gpar(fontsize = 9, col = "#52616C")
)
grid.text(
"Comparaciones descriptivas con cobertura desigual entre cadenas.",
x = 0.04, y = 0.09, just = "left",
gp = gpar(fontsize = 9, col = "#52616C")
)
grid.text(
"Fuente: elaboración propia con datos del SEPA.",
x = 0.04, y = 0.045, just = "left",
gp = gpar(fontsize = 9, col = "#52616C")
)
}
