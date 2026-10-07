// Fase R, paso R.1: mide la memoria de la app en el celular conectado por cable.
//
//   node scripts/medir_memoria.mjs --snap "después del login"      → una medición, con etiqueta
//   node scripts/medir_memoria.mjs --serie 60 --cada 2 "abriendo el Guía"
//                                                                   → una medición cada 2 s durante 60 s
//   node scripts/medir_memoria.mjs --informe                        → tabla para pegar en el informe
//
// Usa `adb shell dumpsys meminfo` (solo lectura: no toca la app ni el celular). Guarda todo en
// build/memoria_r1/ (no se commitea). Qué mide, en KB, en el celular real:
//   · PSS total (lo que Android le "cobra" a la app) y RSS
//   · por categoría: Java heap, Native heap (en Flutter incluye el heap de Dart y lo que decodifican las
//     imágenes), Code, Graphics (texturas / GPU), Private Other, System, Stack
//   · cuántas Views / Activities tiene, y cuánta memoria le queda libre al celular
//
// Requisitos: adb en el PATH o en %LOCALAPPDATA%\Android\Sdk\platform-tools, y la depuración USB autorizada.

import { execFileSync } from "node:child_process";
import { appendFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const PAQUETE = "com.example.capitanya_master";
const SALIDA = "build/memoria_r1";
const ENCABEZADO = [
  "hora", "etiqueta", "pid", "pss_total", "rss_total", "java_heap", "native_heap", "code", "stack", "graphics",
  "private_other", "system", "views", "activities", "mem_libre_celular", "mem_disponible_celular", "pantalla",
];

function adbPath() {
  const sdk = join(process.env.LOCALAPPDATA ?? "", "Android", "Sdk", "platform-tools", "adb.exe");
  return existsSync(sdk) ? sdk : "adb";
}
const ADB = adbPath();

function adb(...args) {
  return execFileSync(ADB, args, { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
}

function dispositivo() {
  const lineas = adb("devices").split("\n").slice(1).map((l) => l.trim().split(/\s+/));
  const ok = lineas.find((l) => l[1] === "device");
  if (!ok) throw new Error("No hay ningún celular conectado y autorizado (adb devices).");
  return ok[0];
}

const num = (texto, re) => {
  const m = texto.match(re);
  return m ? Number(m[1]) : null;
};

export function medir(etiqueta) {
  const d = dispositivo();
  const sh = (c) => adb("-s", d, "shell", c);
  let pid = "";
  try {
    pid = sh(`pidof ${PAQUETE}`).trim().split(/\s+/)[0] || ""; // sale con código 1 si la app no corre
  } catch {
    pid = "";
  }
  let fila = { hora: new Date().toLocaleTimeString("es-AR", { hour12: false }), etiqueta: String(etiqueta).replaceAll(",", ";"), pid };
  if (pid) {
    const t = sh(`dumpsys meminfo ${PAQUETE}`);
    guardarCrudo(etiqueta, t);
    fila = {
      ...fila,
      pss_total: num(t, /TOTAL PSS:\s+(\d+)/),
      rss_total: num(t, /TOTAL RSS:\s+(\d+)/),
      java_heap: num(t, /App Summary[\s\S]*?Java Heap:\s+(\d+)/),
      native_heap: num(t, /Native Heap:\s+(\d+)/),
      code: num(t, /\n\s+Code:\s+(\d+)/),
      stack: num(t, /\n\s+Stack:\s+(\d+)/),
      graphics: num(t, /Graphics:\s+(\d+)/),
      private_other: num(t, /Private Other:\s+(\d+)/),
      system: num(t, /\n\s+System:\s+(\d+)/),
      views: num(t, /Views:\s+(\d+)/),
      activities: num(t, /Activities:\s+(\d+)/),
    };
  }
  const mi = sh("cat /proc/meminfo");
  fila.mem_libre_celular = num(mi, /MemFree:\s+(\d+)/);
  fila.mem_disponible_celular = num(mi, /MemAvailable:\s+(\d+)/);
  // Solo el nombre del paquete en primer plano (no se mira el contenido de la pantalla).
  const foco = sh("dumpsys window | grep mCurrentFocus").match(/\{[^ ]+ [^ ]+ ([^/}\s]+)\//);
  fila.pantalla = foco ? foco[1] : "";
  return fila;
}

/** Guarda el volcado completo de meminfo (por si hace falta mirar el detalle: GL mtrack, EGL mtrack...). */
function guardarCrudo(etiqueta, texto) {
  mkdirSync(join(SALIDA, "crudo"), { recursive: true });
  const nombre = `${new Date().toLocaleTimeString("es-AR", { hour12: false }).replaceAll(":", "")}_${etiqueta.slice(0, 40).replace(/[^\w]+/g, "_")}.txt`;
  writeFileSync(join(SALIDA, "crudo", nombre), texto);
}

function guardar(archivo, fila) {
  mkdirSync(SALIDA, { recursive: true });
  const ruta = join(SALIDA, archivo);
  if (!existsSync(ruta)) writeFileSync(ruta, ENCABEZADO.join(",") + "\n");
  appendFileSync(ruta, ENCABEZADO.map((k) => JSON.stringify(fila[k] ?? "").replace(/^"|"$/g, "")).join(",") + "\n");
}

const mb = (kb) => (kb == null || kb === "" ? "—" : `${(Number(kb) / 1024).toFixed(0)}`);

function leerCsv(archivo) {
  const ruta = join(SALIDA, archivo);
  if (!existsSync(ruta)) return [];
  const [cab, ...filas] = readFileSync(ruta, "utf8").trim().split("\n");
  const ks = cab.split(",");
  return filas.map((l) => Object.fromEntries(l.split(",").map((v, i) => [ks[i], v])));
}

function informe() {
  const f = leerCsv("medidas.csv");
  const l = [
    "| # | Momento | PSS total (MB) | Java | Native | Code | Graphics | Private other | System | Views | Libre en el celular (MB) | Pantalla |",
    "|---|---|---|---|---|---|---|---|---|---|---|---|",
  ];
  f.forEach((r, i) => {
    l.push(
      `| ${i + 1} | ${r.etiqueta} | **${mb(r.pss_total)}** | ${mb(r.java_heap)} | ${mb(r.native_heap)} | ${mb(r.code)} | ` +
        `${mb(r.graphics)} | ${mb(r.private_other)} | ${mb(r.system)} | ${r.views || "—"} | ${mb(r.mem_disponible_celular)} | ${r.pantalla} |`,
    );
  });
  console.log(l.join("\n"));
  const serie = leerCsv("serie.csv");
  if (serie.length) {
    const max = serie.reduce((a, r) => (Number(r.pss_total) > Number(a.pss_total || 0) ? r : a), {});
    console.log(`\nSerie: ${serie.length} puntos; pico de PSS ${mb(max.pss_total)} MB a las ${max.hora} (${max.etiqueta}).`);
  }
}

const a = process.argv.slice(2);
if (a.includes("--informe")) {
  informe();
} else if (a.includes("--snap")) {
  const etiqueta = a[a.indexOf("--snap") + 1] ?? "";
  const fila = medir(etiqueta);
  guardar("medidas.csv", fila);
  console.log(
    fila.pid
      ? `${etiqueta}: PSS ${mb(fila.pss_total)} MB (Java ${mb(fila.java_heap)}, Native ${mb(fila.native_heap)}, Code ${mb(fila.code)}, ` +
          `Graphics ${mb(fila.graphics)}, Private ${mb(fila.private_other)}, System ${mb(fila.system)}) · views ${fila.views} · ` +
          `disponible en el celular ${mb(fila.mem_disponible_celular)} MB · pantalla ${fila.pantalla}`
      : `${etiqueta}: la app NO está corriendo (disponible en el celular ${mb(fila.mem_disponible_celular)} MB, pantalla ${fila.pantalla})`,
  );
} else if (a.includes("--serie")) {
  const segundos = Number(a[a.indexOf("--serie") + 1] ?? 30);
  const cada = Number(a.includes("--cada") ? a[a.indexOf("--cada") + 1] : 2);
  const etiqueta = a.filter((x, i) => !x.startsWith("--") && !(i > 0 && a[i - 1].startsWith("--")))[0] ?? "";
  const fin = Date.now() + segundos * 1000;
  while (Date.now() < fin) {
    const fila = medir(etiqueta);
    guardar("serie.csv", fila);
    console.log(`${fila.hora}  PSS ${mb(fila.pss_total)} MB  ${etiqueta}`);
    await new Promise((r) => setTimeout(r, cada * 1000));
  }
} else {
  console.log("Uso: --snap \"etiqueta\" | --serie <segundos> [--cada <s>] \"etiqueta\" | --informe");
}
