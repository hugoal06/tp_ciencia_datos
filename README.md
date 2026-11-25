# Comparación de precios mayoristas con datos SEPA

Trabajo final de Ciencia de Datos para Economía y Negocios · Grupo 24

**Integrantes:** Lautaro Ortiz y Hugo Alonso Ledesma

## Objetivo e hipótesis

Analizamos si existen diferencias sistemáticas en los precios publicados por cinco cadenas mayoristas de la Provincia de Buenos Aires cuando se comparan las mismas referencias comerciales. El trabajo parte de la descripción del catálogo de NINI y amplía la comparación a Makro, Maxiconsumo, Yaguar y Vital.

- **H0:** controlando por producto, los efectos de mayorista sobre el precio son iguales.
- **H1:** controlando por producto, al menos un mayorista presenta un efecto diferente.

Además, exploramos perfiles de productos y evaluamos cuánto de la variabilidad de sus brechas de precios corresponde a diferencias entre cadenas y cuánto permanece dentro de ellas.

## Datos y cobertura

La fuente es el [Sistema Electrónico de Publicidad de Precios Argentinos, SEPA Mayorista](https://datos.gob.ar/dataset/produccion-precios-claros---sepa-mayorista), publicado en Datos Argentina. El sistema reúne precios informados por los comercios y tiene frecuencia de actualización diaria.

Trabajamos con un corte transversal: los archivos utilizados registran últimas actualizaciones del **16 y 17 de septiembre de 2026**, según el campo `comercio_ultima_actualizacion`. Estas fechas corresponden a los archivos conservados y no constituyen una serie temporal.

Cada observación representa un producto publicado en una sucursal. Un mismo código puede aparecer en varias sucursales y cadenas. Los precios se expresan en pesos argentinos y la variable principal es el precio unitario con IVA: `precio_unitario_bulto_por_unidad_venta_con_iva`.

| Etapa o muestra | Registros | Productos distintos |
| --- | ---: | ---: |
| Base preparada de Provincia de Buenos Aires | 246.781 | 23.758 |
| Base analítica después de la exclusión adicional | 246.780 | 23.757 |
| Productos presentes en al menos dos cadenas | 19.515 observaciones producto-mayorista | 7.530 |
| Canasta común a las cinco cadenas | 270 observaciones producto-mayorista | 54 |

La base analítica contiene **5 cadenas, 56 sucursales y 27 columnas**. La presentación destaca diez variables de identificación, producto, ubicación y precio. En la base analítica, el precio principal no tiene faltantes; `precio_bulto_con_iva` presenta 42, aproximadamente el 0,02 % de los registros.

La cifra de 23.758 productos incluida en la presentación corresponde a la base preparada. Al aplicar la exclusión adicional que figura en la base analítica guardada, queda un producto menos.

### Archivos auxiliares y cruces

Los archivos `comercio*.csv` identifican las cadenas y sus fechas de actualización. Los archivos `sucursales*.csv` aportan la ubicación de los locales. Ambos proceden del mismo paquete SEPA que los precios.

El cruce de precios con sucursales utiliza `id_comercio`, `id_bandera` e `id_sucursal`. El script 01 registra los casos sin ubicación y detiene la ejecución si los encuentra. Después restringe la muestra a Provincia de Buenos Aires, identificada con `AR-B`. La importación inicial comprende siete cadenas; cinco tienen observaciones en la muestra geográfica utilizada.

Los archivos `mayoristas_recuperados.csv`, `decisiones_limpieza_recuperadas.csv` y `exclusiones_analisis_recuperadas.csv` conservan los nombres y las decisiones identificadas en las bases guardadas del proyecto. Permiten reproducir la muestra sin depender de una sesión anterior de R.

## Análisis y resultados

### Descripción y control de calidad

Se revisan duplicados exactos, conversiones numéricas, faltantes, consistencia entre precio unitario y precio del bulto y valores potencialmente atípicos. Se generan estadísticas antes y después del tratamiento.

La distribución de precios es asimétrica: la mediana es de **$3.925**, frente a una media aproximada de **$7.194**. El máximo de **$1.900.100** corresponde a un SMART TV UHD NOBLEX de 75 pulgadas y se conserva como producto comercial real, según la revisión presentada en el TP.

La presentación retoma también el análisis inicial de NINI: promociones en el 14,4 % de las observaciones y un descuento mediano del 15 %. Estos resultados históricos no se recalculan en los scripts 01–04.

### Comparación controlando por producto

Se obtiene la mediana del precio de cada producto dentro de cada cadena y se conservan las referencias presentes en al menos dos mayoristas. Se estima un modelo del logaritmo del precio relativo con efectos fijos por producto y errores estándar agrupados por producto. La normalización del precio por la mediana de cada referencia queda absorbida por esos efectos fijos.

La prueba conjunta de los efectos de cadena rechaza H0. Las comparaciones por pares aplican el ajuste de Tukey. Makro presenta precios relativos superiores a las otras cuatro cadenas; la diferencia estimada frente a NINI es del **23,88 %**. Entre Yaguar y Vital no se detecta una diferencia estadísticamente significativa.

### Perfiles mediante k-means

El TP presenta un clustering de 7.530 productos a partir del precio representativo, la presencia entre mayoristas y las unidades por bulto, con logaritmos para precio y unidades y estandarización de las tres variables.

| Perfil presentado | Productos | Proporción |
| --- | ---: | ---: |
| Precio intermedio y mayor presencia | 2.693 | 35,8 % |
| Mayor precio y menor presencia | 3.053 | 40,5 % |
| Menor precio y bultos más grandes | 1.784 | 23,7 % |

La silueta promedio informada es **0,336**. Los grupos se interpretan como perfiles exploratorios con separación limitada. **La reproducción de esta versión está pendiente de incorporar el código en `script/05_kmeans.R`.**

### Canasta común, gráficos por rubro y descomposición

Se comparan 54 productos presentes en las cinco cadenas: 12 de alimentos y bebidas, 18 de condimentos y salsas, 18 de cuidado personal y 6 de limpieza del hogar.

La brecha se calcula como `100 × (precio mediano de la cadena / mediana del mismo producto entre cadenas − 1)`. Cada producto recibe el mismo peso. Los gráficos exploratorio y comunicativo muestran la distribución y la mediana de esas brechas por cadena y rubro. Makro presenta la mayor brecha mediana en los cuatro rubros.

La descomposición separa la suma de cuadrados total en diferencias entre las brechas medias de las cadenas y desviaciones respecto de la media de cada cadena. En esta canasta, aproximadamente el **39 %** de la variabilidad corresponde al componente entre cadenas y el **61 %** al componente dentro de ellas.

## Estructura del repositorio

| Ruta | Contenido |
| --- | --- |
| `raw/` | Archivos originales de productos, sin modificar |
| `auxiliar/` | Archivos de comercios y sucursales y CSV de apoyo a la reconstrucción |
| `input/` | Bases procesadas y muestras utilizadas en los análisis |
| `output/tablas/` | Descriptivas, diccionario, controles y resultados numéricos |
| `output/graficos/` | Gráficos exportados desde R |
| `output/` | También contiene los objetos RDS del modelo y su diagnóstico |
| `script/` | Scripts numerados según el orden de ejecución |
| `utils/` | Funciones propias, cada una en su archivo y cargada mediante `source()` |
| `README.md` | Descripción del proyecto e instrucciones de reproducción |

## Instrucciones de reproducción

### Preparación

1. Descarga o clona el repositorio completo y abre el proyecto `.Rproj` desde su carpeta raíz en RStudio.
2. Instala previamente los paquetes necesarios, si aún no están disponibles:

```r
install.packages(c("tidyverse", "fixest"))
```

3. Comprueba que los archivos de productos de los comercios **60, 61, 62, 63, 64, 66 y 70** estén en `raw/`, con nombres como `productos60.csv`. Sus archivos `comercio60.csv`, `sucursales60.csv` y equivalentes deben estar en `auxiliar/`, junto con los tres CSV de apoyo indicados anteriormente.
4. Si incluyes `productos68.csv`, conserva también sus archivos de comercio y sucursales. Ese archivo de productos está vacío y no aporta observaciones.

Las rutas son relativas a la raíz del proyecto. Cada script lee sus entradas desde disco y guarda sus resultados, por lo que puede ejecutarse en una sesión nueva de R. No es necesario cargar archivos de historial ni restaurar un espacio de trabajo.

### Orden, entradas y salidas principales

| Script | Entradas principales | Resultados principales |
| --- | --- | --- |
| `01_importacion_limpieza.R` | Productos en `raw/`, comercios, sucursales y decisiones en `auxiliar/` | Bases por cadena, base nacional y `input/base_buenos_aires.rds`, su CSV y la base previa al tratamiento; controles de importación |
| `02_descriptivas.R` | Base preparada y base previa al tratamiento | `tabla_descripcion_base.csv`, `tabla_descripcion_variables.csv` y descriptivas en `output/tablas/`; gráficos de precios y composición en `output/graficos/` |
| `03_faltantes_outliers.R` | Bases anteriores y exclusión adicional | `input/base_buenos_aires_analisis.rds`; `descriptivas_antes_despues.csv` y controles en `output/tablas/`; gráficos de diagnóstico |
| `04_inferencia.R` | Base analítica | `input/tabla_producto_mayorista.rds` y su CSV; modelos en `output/`; `tabla_prueba_global_mayoristas.csv`, `coeficientes_mayoristas.csv` y `comparaciones_robustas_mayoristas.csv` en `output/tablas/`; diagnósticos |
| `05_kmeans.R` | Pendiente de completar | Archivo vacío reservado para la versión de clustering utilizada en la presentación |
| `06_graficos.R` | `input/base_buenos_aires.csv` | `output/graficos/grupo_24_exploratorio.jpg` y `grupo_24_comunicativo.jpg` |
| `07_descomposicion_varianza.R` | Base preparada en CSV o ZIP | `input/datos_descomposicion.csv`, `output/tablas/tabla_descomposicion.csv` y `output/graficos/descomposicion_variabilidad.jpg` |

Para ejecutar las etapas disponibles, desde la raíz del proyecto:

```r
source("script/01_importacion_limpieza.R")
source("script/02_descriptivas.R")
source("script/03_faltantes_outliers.R")
source("script/04_inferencia.R")
source("script/06_graficos.R")
source("script/07_descomposicion_varianza.R")
```

El script 01 regenera el CSV que utiliza el 06. Los scripts 06 y 07 trabajan con la base preparada; la exclusión adicional afecta a un producto sin presencia en las cinco cadenas y no modifica la canasta común.

Cuando se incorpore el código definitivo del clustering, se ejecutará el 05 después del 04 y se documentarán aquí sus entradas, salidas y paquetes adicionales.

## Estado de la reproducción

La reproducción completa queda pendiente de incorporar el script 05 y de ejecutar todos los scripts desde una copia nueva del repositorio en R. Se contrastaron mediante cálculos independientes la reconstrucción de las bases, la tabla de productos comparables, las estimaciones del modelo y la descomposición; esto no sustituye la ejecución completa en R.

Hay diferencias que deben tenerse en cuenta al contrastar código y presentación:

- **Atípicos:** los 20.611 candidatos informados en el PDF corresponden al criterio intercuartílico aplicado globalmente al precio en niveles de la base analítica. El script 03 incorpora otro diagnóstico: rango intercuartílico del logaritmo del precio por cadena en la muestra previa al tratamiento. Los recuentos de ambos criterios no son equivalentes y las marcas del diagnóstico no implican eliminación automática.
- **Comparaciones:** el script 04 utiliza errores agrupados por producto tanto en la prueba global como en las comparaciones. Corrige la tabla histórica de comparaciones, cuyos errores estándar eran ordinarios. Se conservan las diferencias porcentuales estimadas y se recalculan los errores, intervalos y valores p.
- **Limpieza heredada:** se mantienen las exclusiones registradas para conservar la muestra. Algunas clasificaciones de envases requieren revisión y la exclusión adicional del producto `CR.OXIG ISSUE 20/30V.SACH 50 cc`, con precio 1,45, no conserva su justificación original. Los CSV de apoyo identifican estas decisiones.
- **Formatos comerciales:** compartir `id_producto` permite enlazar referencias, pero no garantiza por sí solo que sus presentaciones sean equivalentes. Los scripts agrupan por ese código; la validación de descripción, formato y cantidad debe respaldar la interpretación de las comparaciones.

## Conclusiones y limitaciones

Los resultados respaldan la existencia de diferencias de precios entre cadenas al controlar por producto. Sin embargo, la dispersión dentro de cada cadena y el 61 % de variabilidad interna en la canasta común muestran que su posición media no determina el precio relativo de cada artículo.

El análisis describe precios publicados para el ámbito y el corte temporal indicados. No mide ventas, cantidades compradas, cuotas de mercado ni efectos causales. Las comparaciones descriptivas de catálogos completos pueden reflejar diferencias de composición; la canasta común de 54 productos tampoco representa todo el surtido.

Los próximos pasos son completar la reproducción del clustering, documentar las decisiones de limpieza pendientes, controlar explícitamente las presentaciones y promociones, evaluar la sensibilidad a valores extremos e incorporar otras fechas.
