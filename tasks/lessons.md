# Lessons

Patrones aprendidos de correcciones reales en este repo. Se lee al empezar una
sesión y se escribe **inmediatamente después** de que Ernesto corrija algo, no al
final. Una lección que no se escribe en el momento se repite.

---

## El gate se corre local antes de pushear, no en el CI

**Qué pasó:** el workflow de CI no llegó a subir en el push inicial de la 1.0.0,
así que SwiftLint nunca corrió sobre el código. Cuando por fin subió, salieron 16
violaciones de golpe — comas finales, `Self` en referencias estáticas, orden de
modificadores — todas triviales, todas evitables.

**Regla:** `make verify` (lint + test + build) antes de cada push. El CI es la
red de seguridad, no el primer lugar donde se entera uno.

---

## Un token de `gh` sin scope `workflow` no puede pushear `.github/workflows/`

**Qué pasó:** dos veces, en dos repos distintos, el push se rompió al llegar al
archivo del workflow.

**Regla:** con el remote en SSH el push no pasa por el scope del OAuth. Si
aparece el error, `git remote set-url origin git@github.com:...` y listo — no
hace falta reescribir la historia ni sacar el archivo del commit.

---

## Copiar un disparador de CI de otro repo sin mirar cómo se trabaja aquí

**Qué pasó:** al alinear el CI con Cococel se copió el trigger de
`pull_request` solamente. Cococel siempre pasa por PR; en este repo se empuja a
`develop` directo, así que todos los push quedaron sin lint, sin tests y sin
build.

**Regla:** al copiar una convención de otro proyecto, separar la *forma* (que sí
se copia) del *flujo de trabajo* (que hay que verificar). Y si un workflow
dispara por push y por PR, el grupo de concurrency va sobre `github.ref`, no
sobre `github.event.pull_request.number`, que en un push viene vacío.
