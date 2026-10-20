import type { FieldPacket, RowDataPacket } from 'mysql2';
import { createPool, type Pool, type PoolConnection } from 'mysql2/promise';
import type { H3Event } from 'h3';

export interface DatabaseColumnSchema {
  name: string;
  dataType: string;
  columnType: string;
  nullable: boolean;
  defaultValue: unknown;
  key: string;
  extra: string;
  comment: string;
}

export interface DatabaseForeignKeySchema {
  name: string;
  column: string;
  referencedTable: string;
  referencedColumn: string;
}

export interface DatabaseTableSchema {
  name: string;
  type: string;
  comment: string;
  columns: DatabaseColumnSchema[];
  foreignKeys: DatabaseForeignKeySchema[];
}

export interface DatabaseSchema {
  dialect: 'mysql';
  database: string;
  tables: DatabaseTableSchema[];
}

export interface ReadOnlyQueryResult {
  rows: RowDataPacket[];
  columns: string[];
}

interface DatabaseRuntimeConfig {
  dialect?: string;
  host?: string;
  port?: number | string;
  user?: string;
  password?: string;
  name?: string;
}

interface SchemaRow extends RowDataPacket {
  tableName: string;
  tableType: string;
  tableComment: string;
  columnName: string | null;
  dataType: string | null;
  columnType: string | null;
  nullable: 'YES' | 'NO' | null;
  defaultValue: unknown;
  columnKey: string | null;
  extra: string | null;
  columnComment: string | null;
}

interface ForeignKeyRow extends RowDataPacket {
  tableName: string;
  constraintName: string;
  columnName: string;
  referencedTable: string;
  referencedColumn: string;
}

let pool: Pool | undefined;

function getDatabaseConfig(event?: H3Event) {
  const config = useRuntimeConfig(event).database as DatabaseRuntimeConfig;
  const dialect = config.dialect || 'mysql';

  if (dialect !== 'mysql') {
    throw new Error(`Unsupported database dialect "${dialect}".`);
  }

  const database = config.name?.trim();
  const user = config.user?.trim();
  const host = config.host?.trim() || 'localhost';
  const port = Number(config.port ?? 3306);

  if (!database || !user) {
    throw new Error('Database configuration is incomplete. Set NUXT_DATABASE_NAME and NUXT_DATABASE_USER.');
  }

  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('Database port must be an integer between 1 and 65535.');
  }

  return {
    dialect,
    host,
    port,
    user,
    password: config.password ?? '',
    database,
  };
}

export function getDbConnection(event?: H3Event): Pool {
  const config = getDatabaseConfig(event);
  pool ??= createPool({
    host: config.host,
    port: config.port,
    user: config.user,
    password: config.password,
    database: config.database,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
  });

  return pool;
}

export async function runReadOnlyQuery(
  event: H3Event,
  sql: string,
): Promise<ReadOnlyQueryResult> {
  const connection = await getDbConnection(event).getConnection();

  try {
    await connection.query('SET TRANSACTION READ ONLY');
    await connection.beginTransaction();

    const [rows, fields] = await connection.query<RowDataPacket[]>({
      sql,
      timeout: 10_000,
    });

    return {
      rows,
      columns: (fields as FieldPacket[]).map(field => field.name),
    };
  } finally {
    try {
      await connection.rollback();
    } finally {
      connection.release();
    }
  }
}

export async function getDatabaseSchema(event?: H3Event): Promise<DatabaseSchema> {
  const config = getDatabaseConfig(event);
  const connection = getDbConnection(event);

  const [tableRows] = await connection.query<SchemaRow[]>(
    `SELECT
      t.TABLE_NAME AS tableName,
      t.TABLE_TYPE AS tableType,
      t.TABLE_COMMENT AS tableComment,
      c.COLUMN_NAME AS columnName,
      c.DATA_TYPE AS dataType,
      c.COLUMN_TYPE AS columnType,
      c.IS_NULLABLE AS nullable,
      c.COLUMN_DEFAULT AS defaultValue,
      c.COLUMN_KEY AS columnKey,
      c.EXTRA AS extra,
      c.COLUMN_COMMENT AS columnComment
    FROM information_schema.TABLES t
    LEFT JOIN information_schema.COLUMNS c
      ON c.TABLE_SCHEMA = t.TABLE_SCHEMA
      AND c.TABLE_NAME = t.TABLE_NAME
    WHERE t.TABLE_SCHEMA = ?
    ORDER BY t.TABLE_NAME, c.ORDINAL_POSITION`,
    [config.database],
  );

  const [foreignKeyRows] = await connection.query<ForeignKeyRow[]>(
    `SELECT
      TABLE_NAME AS tableName,
      CONSTRAINT_NAME AS constraintName,
      COLUMN_NAME AS columnName,
      REFERENCED_TABLE_NAME AS referencedTable,
      REFERENCED_COLUMN_NAME AS referencedColumn
    FROM information_schema.KEY_COLUMN_USAGE
    WHERE TABLE_SCHEMA = ?
      AND REFERENCED_TABLE_NAME IS NOT NULL
    ORDER BY TABLE_NAME, CONSTRAINT_NAME, ORDINAL_POSITION`,
    [config.database],
  );

  const tables = new Map<string, DatabaseTableSchema>();

  for (const row of tableRows) {
    let table = tables.get(row.tableName);
    if (!table) {
      table = {
        name: row.tableName,
        type: row.tableType,
        comment: row.tableComment,
        columns: [],
        foreignKeys: [],
      };
      tables.set(row.tableName, table);
    }

    if (row.columnName !== null) {
      table.columns.push({
        name: row.columnName,
        dataType: row.dataType ?? '',
        columnType: row.columnType ?? '',
        nullable: row.nullable === 'YES',
        defaultValue: row.defaultValue,
        key: row.columnKey ?? '',
        extra: row.extra ?? '',
        comment: row.columnComment ?? '',
      });
    }
  }

  for (const row of foreignKeyRows) {
    tables.get(row.tableName)?.foreignKeys.push({
      name: row.constraintName,
      column: row.columnName,
      referencedTable: row.referencedTable,
      referencedColumn: row.referencedColumn,
    });
  }

  return {
    dialect: 'mysql',
    database: config.database,
    tables: [...tables.values()],
  };
}

export async function closeDbConnection(): Promise<void> {
  if (!pool) {
    return;
  }

  const connection = pool;
  await connection.end();
  pool = undefined;
}
