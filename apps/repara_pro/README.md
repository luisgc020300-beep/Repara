# apps/repara_pro

Proyecto Flutter real de REPARA Pro (creado vía `flutter create`), todavía
un cascarón: compila, pasa su test por defecto y depende de `repara_core` y
`repara_ui` por `path:` -- pero no contiene ninguna pantalla real de Pro
todavía. La app real sigue viviendo en la raíz del repositorio
(`c:\dev\repara\lib\screens\pro\` y servicios asociados) y sigue siendo la
única que se compila y despliega hoy.

Pendiente, en tareas separadas (cada una con su propia auditoría de
dependencias, igual que el resto de extracciones a `repara_ui`):
- Mover `lib/screens/pro/` y los servicios exclusivos de Pro aquí.
- Conectar Firebase a este proyecto (mismo proyecto `repara-hogar-app`,
  registrando una nueva app Android/iOS/web -- requiere `flutterfire
  configure` y confirmación expresa antes de tocar nada del proyecto
  Firebase real).
- `android/applicationId`/`PRODUCT_BUNDLE_IDENTIFIER`: generados como
  `com.riskrunner.repara.repara_pro` (mismo org que la app actual,
  `com.riskrunner.repara.repara`) -- revisar antes de publicar.

Ver `docs/ARQUITECTURA_SEPARACION.md` en la raíz del repositorio para el
plan completo por fases (desactualizado respecto al estado real del
monorepo -- repara_core/repara_ui ya tienen contenido real).
