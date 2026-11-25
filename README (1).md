# Comparación de precios mayoristas con datos SEPA

Trabajo final de Ciencia de Datos para Economía y Negocios · Grupo 24

**Integrantes:** Lautaro Ortiz y Hugo Alonso Ledesma

## Objetivo e hipótesis

Analizamos si existen diferencias sistemáticas entre los precios publicados por Makro, Maxiconsumo, Yaguar, NINI y Vital al comparar las mismas referencias comerciales. El trabajo parte de la descripción del catálogo de NINI y amplía el análisis a cinco cadenas mayoristas.

- **H0:** controlando por producto, los efectos de mayorista sobre el precio son iguales.
- **H1:** controlando por producto, al menos un mayorista presenta un efecto diferente.

Además, identificamos perfiles de productos y descomponemos la variabilidad de las brechas de precios para distinguir las diferencias entre cadenas de la heterogeneidad dentro de cada una.

## Datos y alcance

La fuente es el [Sistema Electrónico de Publicidad de Precios Argentinos, SEPA Mayorista](https://datos.gob.ar/dataset/produccion-precios-claros---sepa-mayorista), disponible en Datos Argentina. El sistema publica información diaria suministrada por los comercios.

Los archivos originales conservados en el proyecto registran últimas actualizaciones del **16 y 17 de septiembre de 2026**. Se trabaja con un corte transversal, no con una serie temporal. El ámbito declarado en la presentación es la Provincia de Buenos Aires; la copia recuperada utilizada en la ejecución no permite volver a confirmar ese alcance geográfico.

Cada observación corresponde a un producto publicado en una sucursal. Un mismo artículo puede aparecer en distintas sucursales y cadenas. La variable principal es `precio_unitario_bulto_por_unidad_venta_con_iva`, expresada en pesos argentinos.

| Base generada en la ejecución comprobada | Tamaño |
| --- | ---: |
| Registros producto-sucursal | 246.781 |
| Productos distintos | 23.758 |
| Cadenas mayoristas | 5 |
| Sucursales | 56 |

Estos recuentos proceden de `output/tablas/03_dimension_base.csv`. La presentación informa 246.780 observaciones, una menos que la ejecución comprobada. Se documenta esta diferencia conservando los resultados generados por los scripts.

| Muestras reportadas en la presentación | Tamaño |
| --- | ---: |
| Productos presentes en al menos dos cadenas | 7.530 |
| Observaciones producto-mayorista del modelo | 19.515 |
| Canasta común a las cinco cadenas | 54 productos y 270 observaciones |

El diccionario de columnas, sus tipos y valores faltantes se genera en `output/tablas/03_diccionario_variables.csv`.

### Archivos de entrada y procedencia

El archivo `auxiliar/manifest_archivos.csv` indica las rutas de comercios, sucursales y productos de cada cadena, su nombre y la codificación de los archivos. Las uniones utilizan `id_comercio`, `id_bandera` e `id_sucursal`, con controles de unicidad y correspondencia de las claves.

El script 01 contempla dos vías de importación:

- **Archivos originales:** lee los archivos indicados en el manifiesto y une los precios con la información de comercios y sucursales.
- **Copia recuperada:** cuando no están disponibles todas las entradas originales, lee `auxiliar/base_recuperada.csv.gz` y registra las limitaciones de esa recuperación.

**En la ejecución comprobada se utilizó la copia recuperada**, según `output/tablas/01_procedencia.csv`: modo `recuperacion_parcial` y `filtro_geografico_verificable = FALSE`. El registro indica que se recuperaron 22 columnas y que faltan provincia, localidad y nombre de sucursal. Esta vía permite ejecutar el análisis a partir de la selección guardada, pero no reconstruye la descarga original ni permite verificar de nuevo su cobertura geográfica.

El script 02 incluye un filtro por el código numérico 06 cuando la columna de provincia está disponible. La ejecución documentada conserva la selección recuperada y su ámbito geográfico queda sin revalidar.

`auxiliar/diccionario_recuperado.csv` aporta las descripciones de las variables. Las tablas guardadas `tabla_producto_mayorista_guardada.csv.gz` y `productos_cluster_guardados.csv.gz`, si están presentes en `auxiliar/`, se utilizan para contrastar precios y asignaciones de grupos. Los archivos `.csv.gz` se leen directamente desde R.

## Análisis realizado

### Limpieza y descripción

Se controlan conversiones numéricas, identificadores, precios positivos y finitos, faltantes y claves repetidas. Se comparan el tamaño de la muestra y las medidas de precios antes y después de los filtros de validez.

Los candidatos a atípicos se identifican mediante los límites `Q1 − 1,5 × RIC` y `Q3 + 1,5 × RIC`, aplicados al precio en niveles. Se conservan porque la heterogeneidad de los productos puede generar precios extremos reales. El precio máximo se registra junto con su cantidad y precio por bulto para revisar su consistencia. Los gráficos de precios utilizan una escala logarítmica, indicada en sus ejes.

El análisis de NINI distingue entre una promoción publicada y un descuento efectivo. Para cada registro se toma la menor oferta positiva de las dos promociones y se considera rebaja efectiva solo cuando es inferior al precio de lista.

### Comparación entre mayoristas

Se obtiene la mediana del precio por producto y cadena y se conservan los códigos presentes en al menos dos mayoristas. Una auditoría registra diferencias de descripción, marca y unidades por bulto que requieren revisar la equivalencia comercial de las referencias.

El modelo utiliza el logaritmo del precio mediano, efectos fijos por producto y errores estándar agrupados por producto. La prueba de Wald evalúa conjuntamente las diferencias entre cadenas. Las comparaciones por pares utilizan la misma agrupación de errores y el ajuste de Tukey. Los residuos se examinan mediante histograma, gráfico Q-Q y dispersión frente a los valores ajustados.

### Clustering y brechas por perfil

Se construye una fila por producto compartido entre al menos dos cadenas con tres características: precio representativo, presencia entre mayoristas y unidades por bulto. Se aplican logaritmos al precio y a las unidades y se estandarizan las tres variables.

K-means utiliza **tres grupos, semilla 24, 50 inicializaciones y un máximo de 100 iteraciones**. Se calcula la silueta sobre todos los productos y se compara la variación interna de soluciones de uno a ocho grupos mediante el gráfico del codo.

La asignación se guarda para calcular después las brechas de precios por cadena y perfil. Los números de grupo identifican la solución estimada; no representan por sí solos un orden de precios.

### Rubros y descomposición de la variabilidad

La canasta común reúne productos presentes en las cinco cadenas. Se clasifican en alimentos y bebidas, condimentos y salsas, cuidado personal y limpieza del hogar. Las referencias sin clasificación se señalan para revisión.

La brecha se calcula como `100 × (precio mediano de la cadena / mediana del producto entre cadenas − 1)`. Los gráficos muestran su distribución y su mediana por cadena y rubro.

La descomposición separa la suma de cuadrados total en diferencias entre las brechas medias de las cadenas y desviaciones de los productos respecto de la media de su cadena. Cada observación producto-cadena recibe el mismo peso y se comprueba que ambos componentes sumen la variabilidad total.

## Estructura del repositorio

| Ruta | Contenido |
| --- | --- |
| `raw/` | Datos originales de productos, conservados sin modificar |
| `auxiliar/` | Comercios, sucursales, manifiesto, diccionario y archivos de apoyo o recuperación |
| `input/` | Bases procesadas y objetos guardados que utilizan las etapas siguientes |
| `output/tablas/` | Recuentos, controles, descriptivas, resultados del modelo, perfiles y descomposición |
| `output/graficos/` | Gráficos generados en R y exportados con `ggsave()` |
| `script/` | Los doce scripts numerados del análisis |
| `utils/` | Funciones propias utilizadas mediante `source()` |
| Archivo `.Rproj` en la raíz | Proyecto de RStudio desde el que se ejecuta el código |
| `README.md` | Descripción del trabajo e instrucciones de reproducción |

## Cómo ejecutar el proyecto

### Preparación inicial

1. Descarga o clona el repositorio completo. Si lo descargas como ZIP, extráelo conservando todas las carpetas.
2. **Antes de ejecutar cualquier script, abre el archivo `.Rproj` de la carpeta raíz en RStudio.** Esto sitúa R en el directorio desde el que se resuelven las rutas relativas.
3. Instala los paquetes necesarios una sola vez, si todavía no están disponibles:

```r
install.packages(c("tidyverse", "fixest", "emmeans", "cluster"))
```

El paquete `grid`, utilizado para dibujar los cuadros de resultados, forma parte de la instalación de R. Las versiones del entorno de estimación quedan registradas en `output/tablas/06_versiones_paquetes.txt`.

4. Conserva `utils/` y `auxiliar/` junto a `script/` en la raíz del proyecto. No es necesario abrir un CSV manualmente, seleccionar archivos mediante ventanas ni restaurar un historial o un espacio de trabajo.

### Scripts y archivos principales

Los scripts se ejecutan en orden del 01 al 12. Cada etapa lee los archivos guardados por las anteriores y puede iniciarse en una sesión nueva una vez que existen sus entradas.

| Script | Función | Archivos principales que genera |
| --- | --- | --- |
| `01_importacion_consolidacion.R` | Importar y unir las fuentes y registrar su procedencia | `input/base_consolidada.rds`; `output/tablas/01_procedencia.csv` |
| `02_limpieza_control_calidad.R` | Seleccionar la muestra y controlar validez, faltantes y extremos | `input/base_limpia.rds`; tablas `02_*.csv`; `02_control_atipicos.png` |
| `03_descripcion_base.R` | Describir variables, dimensiones, composición y precios | Tablas `03_*.csv`; `03_composicion.png`; `03_distribucion_precios.png` |
| `04_analisis_nini.R` | Describir el catálogo de NINI, sus promociones y descuentos | `04_nini_resumen.csv`; `04_nini_promociones.csv`; `04_nini_descuentos.png` |
| `05_productos_comparables.R` | Agregar precios por cadena y auditar referencias compartidas | `input/precios_por_cadena.rds`; `input/productos_comparables.rds`; tablas `05_*.csv` |
| `06_modelo_precios.R` | Estimar el modelo y realizar el contraste global | `input/modelo_precios.rds`; `06_contraste_global.csv`; `06_coeficientes.csv`; resumen y versiones en TXT |
| `07_comparaciones_mayoristas.R` | Comparar cadenas por pares con ajuste de Tukey | `07_comparaciones_tukey.csv`; `07_comparaciones_mayoristas.png` |
| `08_diagnostico_modelo.R` | Examinar residuos y ajuste | `08_residuos_ajustados.csv`; histograma, Q-Q y dispersión `08_*.png` |
| `09_clustering_productos.R` | Estimar y describir los tres perfiles | `input/clustering_productos.rds`; tablas `09_*.csv`; `09_codo.png`; `09_perfiles_clusters.png` |
| `10_brechas_por_cluster.R` | Comparar precios dentro de cada perfil | `10_brechas_por_cluster.csv`; `10_brechas_por_cluster.png` |
| `11_comparacion_por_rubros.R` | Comparar la canasta común por rubro | `input/canasta_cinco_cadenas.rds`; tablas `11_*.csv`; `11_exploratorio_rubros.png`; `11_comunicativo_rubros.png` |
| `12_descomposicion_variabilidad.R` | Separar la variabilidad entre cadenas y dentro de ellas | Tablas `12_*.csv`; `12_descomposicion_variabilidad.png` |

Los CSV y TXT de resultados se guardan en `output/tablas/` y las imágenes en `output/graficos/`. Los controles de contraste de los scripts 05 y 09 se generan cuando están disponibles sus tablas de referencia en `auxiliar/`.

Desde la consola de RStudio, con el `.Rproj` abierto, puede ejecutarse la secuencia completa:

```r
source("script/01_importacion_consolidacion.R")
source("script/02_limpieza_control_calidad.R")
source("script/03_descripcion_base.R")
source("script/04_analisis_nini.R")
source("script/05_productos_comparables.R")
source("script/06_modelo_precios.R")
source("script/07_comparaciones_mayoristas.R")
source("script/08_diagnostico_modelo.R")
source("script/09_clustering_productos.R")
source("script/10_brechas_por_cluster.R")
source("script/11_comparacion_por_rubros.R")
source("script/12_descomposicion_variabilidad.R")
```

Por ejemplo, el script 06 necesita que el 05 haya guardado `input/productos_comparables.rds`, y el 10 necesita la solución guardada por el 09. No basta con tener esos objetos cargados en el entorno.

Las funciones de `utils/` son `comprobar_columnas.R`, `abreviar_cadenas.R`, `dibujar_cuadro_clusters.R` y `dibujar_tabla_brechas.R`. Deben conservarse con esos nombres y ubicaciones.

**Comprobación realizada por el grupo:** ejecución de los doce scripts en orden desde el proyecto `.Rproj` en RStudio, utilizando `auxiliar/base_recuperada.csv.gz`. Esta comprobación confirma la ejecución del flujo a partir de la copia recuperada; no acredita una reconstrucción desde la descarga original ni una nueva validación geográfica.

## Resultados y conclusiones

Los resultados presentados en el TP respaldan la existencia de diferencias de precios entre cadenas al controlar por producto. Makro presenta precios relativos superiores a las otras cuatro cadenas; la diferencia estimada frente a NINI es del **23,88 %**. Entre Yaguar y Vital no se detecta una diferencia estadísticamente significativa.

La presentación identifica tres perfiles: precio intermedio y mayor presencia, mayor precio y menor presencia y menor precio con bultos más grandes. La silueta promedio informada, **0,336**, indica separación limitada y aconseja interpretarlos como perfiles exploratorios. Makro mantiene la mayor brecha mediana en los tres perfiles y NINI presenta brechas negativas.

En los cuatro rubros de la canasta común, Makro presenta la mayor brecha mediana. La descomposición atribuye aproximadamente el **39 %** de la variabilidad a diferencias entre cadenas y el **61 %** a diferencias entre productos dentro de cada cadena. Por tanto, la posición media de un mayorista no determina el precio relativo de todos sus artículos.

## Limitaciones

Los datos representan precios publicados y no ventas, cantidades compradas o cuotas de mercado. Los resultados corresponden al corte utilizado y no establecen causalidad. Compartir un identificador no garantiza por sí solo que dos presentaciones sean comercialmente equivalentes; la auditoría documenta las alertas detectadas.

Las comparaciones por perfil tienen presencia desigual de cadenas y la canasta común de 54 productos no representa todo el surtido. En la ejecución comprobada, la ausencia de provincia, localidad y nombre de sucursal en la copia recuperada impide certificar de nuevo la cobertura territorial declarada. La diferencia de un registro respecto de la presentación se recoge en la descripción de la base.
