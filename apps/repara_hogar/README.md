# apps/repara_hogar

Proyecto Flutter real de REPARA Hogar (creado vía `flutter create`), todavía
un cascarón: compila, pasa su test por defecto y depende de `repara_core` y
`repara_ui` por `path:` -- pero no contiene ninguna pantalla real de Hogar
todavía. La app real sigue viviendo en la raíz del repositorio (`c:\dev\
repara\lib\`) y sigue siendo la única que se compila y despliega hoy.

Pendiente, en tareas separadas (cada una con su propia auditoría de
dependencias, igual que el resto de extracciones a `repara_ui`):
- Mover `lib/` (lo que es exclusivo de Hogar) aquí.
- Conectar Firebase a este proyecto (mismo proyecto `repara-hogar-app`,
  registrando una nueva app Android/iOS/web -- requiere `flutterfire
  configure` y confirmación expresa antes de tocar nada del proyecto
  Firebase real).
- `android/applicationId`: `com.riskrunner.repara.repara_hogar`.
  `PRODUCT_BUNDLE_IDENTIFIER` (iOS): `com.riskrunner.repara.reparaHogar` --
  Xcode no admite guiones bajos en el bundle id, Flutter lo adapta a
  camelCase automáticamente (mismo criterio ya aplicado en
  `apps/repara_pro`, que usa `reparaPro`).

Ver `docs/ARQUITECTURA_SEPARACION.md` en la raíz del repositorio para el
plan completo por fases (desactualizado respecto al estado real del
monorepo -- repara_core/repara_ui ya tienen contenido real).
