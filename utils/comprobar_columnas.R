# Función reconstruida: evita que una entrada incompleta produzca resultados silenciosos.
comprobar_columnas <- function(datos, columnas, contexto = "Entrada") {
  faltan <- setdiff(columnas, names(datos))
  if (length(faltan)) {
    stop(contexto, ": faltan columnas: ", paste(faltan, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}
