# Recodificación recuperada de RR.histori.Rhistory y RRR.hisory.Rhistory.
# Se extrae como función porque la utilizan varios scripts.
abreviar_cadenas <- function(x) {
  dplyr::recode(as.character(x),
    "Hipermercado Makro" = "Makro",
    "Maxiconsumo" = "Maxiconsumo",
    "Mayorista Yaguar" = "Yaguar",
    "NINI Centro de compras mayoristas" = "NINI",
    "Supermayorista Vital" = "Vital"
  )
}
