path = r"C:\CapitanYA\capitan11.5.2026\lib\widgets\map_selector_widget.dart"
with open(path, "r", encoding="utf-8", errors="replace") as f:
    lines = f.readlines()

lines[720] = "    String instructStr = _routePoints.isEmpty\n"
lines[721] = "        ? 'Toca para colocar Punto A'\n"
lines[722] = "        : 'Toca para agregar más puntos';\n"

with open(path, "w", encoding="utf-8", newline="\n") as f:
    f.writelines(lines)

print("ok")
