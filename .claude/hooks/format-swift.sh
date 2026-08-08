#!/bin/bash
# PostToolUse hook: Detecta violaciones de formato Swift y reporta vía additionalContext
# Se ejecuta después de Edit/Write en archivos .swift
# NO auto-corrige — solo reporta para que Claude se auto-corrija

set -euo pipefail

# Leer JSON de stdin
INPUT=$(cat)

# Extraer file_path del tool_input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Si no hay file_path, salir silenciosamente
if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Solo procesar archivos .swift
if [[ "$FILE_PATH" != *.swift ]]; then
    exit 0
fi

# Ignorar directorios de build
if [[ "$FILE_PATH" == *DerivedData* ]] || [[ "$FILE_PATH" == *Build* ]] || [[ "$FILE_PATH" == *.build/* ]]; then
    exit 0
fi

# Verificar que el archivo existe
if [ ! -f "$FILE_PATH" ]; then
    exit 0
fi

# Ejecutar detección de violaciones con Python3
export SWIFT_CHECK_FILE="$FILE_PATH"
VIOLATIONS=$(python3 << 'PYTHON_SCRIPT'
import os
import sys

file_path = os.environ.get("SWIFT_CHECK_FILE", "")
if not file_path:
    sys.exit(0)

try:
    with open(file_path, "r") as f:
        lines = f.readlines()
except (FileNotFoundError, PermissionError):
    sys.exit(0)

violations = []

# --- Regla 5: Newline después de ( o antes de ) ---
# Excepciones: trailing closures, SwiftUI view builders, closures como parámetros
i = 0
while i < len(lines):
    line = lines[i].rstrip("\n")
    stripped = line.strip()

    # Ignorar comentarios
    if stripped.startswith("//") or stripped.startswith("*") or stripped.startswith("/*"):
        i += 1
        continue

    # Detectar ( seguido de newline (línea termina en "(" sin contenido después)
    if stripped.endswith("(") and i + 1 < len(lines):
        next_line = lines[i + 1].strip().rstrip("\n")

        # Excepciones: si la siguiente línea es una closure o view builder
        is_closure = next_line.startswith("{") or next_line.endswith("{")
        is_view_builder = next_line.startswith("@ViewBuilder") or next_line.startswith("@State")

        if not is_closure and not is_view_builder:
            # Verificar si combinar ambas líneas cabría en 140 chars
            combined = line.rstrip() + " " + next_line.lstrip()
            if len(combined) <= 140:
                violations.append(
                    f"  Linea {i + 1}: Newline despues de '(' -- "
                    f"la expresion podria caber en una linea ({len(combined)} chars)"
                )

    # Detectar línea que empieza con ) sola (newline antes de cierre)
    if stripped == ")" and i > 0:
        prev_line = lines[i - 1].rstrip("\n")
        combined = prev_line.rstrip() + ")"
        if len(combined) <= 140:
            violations.append(
                f"  Linea {i + 1}: Newline antes de ')' -- "
                f"el cierre podria ir al final de la linea anterior ({len(combined)} chars)"
            )

    i += 1

# --- Reglas 2-3: Líneas > 140 caracteres ---
in_multiline_string = False
for i, line in enumerate(lines):
    raw = line.rstrip("\n")

    # Rastrear strings multilínea (triple quotes)
    triple_count = raw.count('"""')
    if triple_count % 2 != 0:
        in_multiline_string = not in_multiline_string
        continue
    if in_multiline_string:
        continue

    stripped = raw.strip()

    # Ignorar comentarios, imports, URLs en strings
    if stripped.startswith("//") or stripped.startswith("*") or stripped.startswith("/*"):
        continue
    if stripped.startswith("import "):
        continue
    if "http://" in stripped or "https://" in stripped:
        continue

    # Ignorar strings largos literales
    if stripped.startswith('"') or stripped.startswith('"""'):
        continue

    if len(raw) > 140:
        violations.append(
            f"  Linea {i + 1}: Excede 140 caracteres ({len(raw)} chars)"
        )

if violations:
    print("\n".join(violations))
PYTHON_SCRIPT
)

# Si hay violaciones, reportar vía additionalContext
if [ -n "$VIOLATIONS" ]; then
    # Construir JSON con python3 para escapado correcto
    python3 -c "
import sys, json

file_path = sys.argv[1]
violations = sys.argv[2]

context = (
    'FORMATO SWIFT -- Violaciones detectadas en ' + file_path + ':\\n'
    + violations + '\\n\\n'
    + 'Reglas (CLAUDE.md):\\n'
    + '- Preferir una linea si <=140 chars\\n'
    + '- No newline despues de ( ni antes de ) si cabe en una linea\\n'
    + '- Dividir solo si >140 chars o mejora legibilidad\\n\\n'
    + 'Por favor corrige estas violaciones en tu siguiente edicion.'
)

print(json.dumps({'additionalContext': context}))
" "$FILE_PATH" "$VIOLATIONS"
fi

exit 0
