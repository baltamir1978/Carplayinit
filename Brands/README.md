# Emblemas

Los logos **no vienen con el proyecto**: son marcas registradas y no se distribuyen aquí.
La app funciona sin ellos — cuando falta el asset dibuja un monograma con las iniciales
de la marca en el color corporativo.

## Añadir un emblema

1. Consigue el PNG (fondo transparente, ~512×512) o el PDF vectorial.
2. Renómbralo `logo-<id>.png`, con el `id` que usa `Shared/brands.json` —
   `logo-byd.png`, `logo-leapmotor.png`, `logo-landrover.png`, `logo-seat.png`…
   El catálogo trae 24 marcas; el `id` de cada una está en ese JSON.
3. Arrástralo dentro del imageset correspondiente en `Brands/Brands.xcassets`,
   en la casilla **1x** (el `preserves-vector-representation` hace el resto si es PDF).
   Los tres coches precargados ya tienen su imageset creado; para el resto,
   **New Image Set** y llámalo exactamente `logo-<id>`.

No hace falta tocar código: `BrandMark` busca el asset por nombre y, si aparece, lo usa.
Para volver al monograma, basta con vaciar el imageset.
