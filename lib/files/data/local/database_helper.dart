// lib/data/local/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'package:sqrprojectatlabendsem/files/domain/entities/scan_result.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  DatabaseHelper._();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sqr.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE scans (
            id TEXT PRIMARY KEY,
            qr_hash TEXT NOT NULL,
            raw_payload TEXT NOT NULL,
            payload_type TEXT NOT NULL,
            domain TEXT,
            intent TEXT,
            risk_score INTEGER,
            risk_level TEXT,
            context TEXT,
            user_decision TEXT,
            redirect_chain TEXT,
            scanned_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE flagged_domains (
            domain TEXT PRIMARY KEY,
            reason TEXT NOT NULL,
            flagged_at TEXT NOT NULL
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_scans_hash ON scans(qr_hash)',
        );
        await db.execute(
          'CREATE INDEX idx_scans_domain ON scans(domain)',
        );
      },
    );
  }

  // ─── Scans ───────────────────────────────────────────────────────────────

  Future<void> insertScan(ScanResult result) async {
    final db = await database;
    await db.insert(
      'scans',
      _scanToMap(result),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllScans() async {
    final db = await database;
    return db.query('scans', orderBy: 'scanned_at DESC');
  }

  Future<bool> isHashSeen(String hash) async {
    final db = await database;
    final result = await db.query(
      'scans',
      where: 'qr_hash = ?',
      whereArgs: [hash],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<String?> getPreviousDecisionForHash(String hash) async {
    final db = await database;
    final result = await db.query(
      'scans',
      columns: ['user_decision'],
      where: 'qr_hash = ?',
      whereArgs: [hash],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return result.first['user_decision'] as String?;
  }

  Future<void> updateDecision(String id, String decision) async {
    final db = await database;
    await db.update(
      'scans',
      {'user_decision': decision},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearHistory() async {
    final db = await database;
    await db.delete('scans');
  }

  // ─── Flagged Domains ─────────────────────────────────────────────────────

  Future<void> flagDomain(String domain, String reason) async {
    final db = await database;
    await db.insert(
      'flagged_domains',
      {
        'domain': domain,
        'reason': reason,
        'flagged_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> isDomainFlagged(String domain) async {
    final db = await database;
    final result = await db.query(
      'flagged_domains',
      where: 'domain = ?',
      whereArgs: [domain],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  Map<String, dynamic> _scanToMap(ScanResult r) {
    return {
      'id': r.id,
      'qr_hash': r.payloadHash,
      'raw_payload': r.rawPayload,
      'payload_type': r.payloadType.name,
      'domain': r.urlAnalysis?.domain,
      'intent': r.urlAnalysis?.intent.name,
      'risk_score': r.riskAssessment?.score,
      'risk_level': r.riskAssessment?.level.name,
      'context': r.context?.name,
      'user_decision': r.userDecision,
      'redirect_chain': r.redirectChain.join('||'),
      'scanned_at': r.scannedAt.toIso8601String(),
    };
  }
}
