const { spawnSync } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
require("dotenv").config({ path: path.resolve(__dirname, "..", ".env") });

const databaseUrl = process.env.SUPABASE_DB_URL;
if (!databaseUrl) {
  console.error("Falta SUPABASE_DB_URL. Configúrala en el archivo .env.");
  process.exit(1);
}

let connection;
try {
  connection = new URL(databaseUrl);
} catch {
  console.error("SUPABASE_DB_URL no es una URL de PostgreSQL válida.");
  process.exit(1);
}

if (
  !["postgres:", "postgresql:"].includes(connection.protocol) ||
  !connection.password ||
  /YOUR-PASSWORD|REPLACE_WITH/i.test(connection.password)
) {
  console.error(
    "Revisa SUPABASE_DB_URL: debe incluir el protocolo PostgreSQL y la contraseña real.",
  );
  process.exit(1);
}

const backupDirectory = path.resolve(__dirname, "..", "backups");
fs.mkdirSync(backupDirectory, { recursive: true });

function findPgDump() {
  if (process.env.PG_DUMP_PATH) {
    return process.env.PG_DUMP_PATH;
  }

  const windowsPostgresDirectory = "C:\\Program Files\\PostgreSQL";
  if (process.platform === "win32" && fs.existsSync(windowsPostgresDirectory)) {
    const installedVersions = fs.readdirSync(windowsPostgresDirectory)
      .filter((name) => /^\d+$/.test(name))
      .sort((left, right) => Number(right) - Number(left));
    for (const version of installedVersions) {
      const candidate = path.join(
        windowsPostgresDirectory,
        version,
        "bin",
        "pg_dump.exe",
      );
      if (fs.existsSync(candidate)) return candidate;
    }
  }

  return "pg_dump";
}

const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
const backupSetDirectory = path.join(backupDirectory, `billtracker-${timestamp}`);
const backupFile = path.join(
  backupSetDirectory,
  "database-public.dump",
);
const functionsSource = path.resolve(__dirname, "..", "supabase", "functions");
const functionsBackup = path.join(backupSetDirectory, "edge-functions");

if (!fs.existsSync(functionsSource)) {
  console.error("No se encontró la carpeta supabase/functions.");
  process.exit(1);
}

fs.mkdirSync(backupSetDirectory, { recursive: true });

const environment = {
  ...process.env,
  PGHOST: connection.hostname,
  PGPORT: connection.port || "5432",
  PGUSER: decodeURIComponent(connection.username),
  PGPASSWORD: decodeURIComponent(connection.password),
  PGDATABASE: decodeURIComponent(connection.pathname.slice(1)),
  PGSSLMODE: "require",
};

const result = spawnSync(
  findPgDump(),
  [
    "--format=custom",
    "--no-owner",
    "--no-acl",
    "--schema=public",
    `--file=${backupFile}`,
  ],
  {
    env: environment,
    stdio: "inherit",
    windowsHide: true,
  },
);

if (result.error || result.status !== 0) {
  fs.rmSync(backupSetDirectory, { recursive: true, force: true });
  if (result.error?.code === "ENOENT") {
    console.error(
      "No se encontró pg_dump. Instala PostgreSQL Client Tools y agrega pg_dump al PATH.",
    );
  } else {
    console.error(
      `Falló pg_dump${result.status === null ? "" : ` (código ${result.status})`}.`,
    );
  }
  process.exit(1);
}

try {
  fs.cpSync(functionsSource, functionsBackup, { recursive: true });
} catch (error) {
  fs.rmSync(backupSetDirectory, { recursive: true, force: true });
  console.error("No se pudieron copiar las Edge Functions:", error.message);
  process.exit(1);
}

const { size } = fs.statSync(backupFile);
console.log(`Backup creado: ${backupSetDirectory}`);
console.log(`Base de datos pública: ${(size / 1024 / 1024).toFixed(2)} MB`);
console.log(`Edge Functions guardadas en: ${functionsBackup}`);
