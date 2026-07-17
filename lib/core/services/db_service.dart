import 'package:postgres/postgres.dart';
import 'package:flutter/foundation.dart';

class DbService {
  static const String _host = 'glassdata-postgres.c5e2qgumyvsg.ap-south-1.rds.amazonaws.com';
  static const int _port = 5432;
  static const String _dbName = 'glassdatadb';
  static const String _username = 'glassdata_admin';
  static const String _password = 'glassdatadb1234';

  Connection? _connection;

  Future<void> connect() async {
    if (_connection != null && _connection!.isOpen) return;
    try {
      _connection = await Connection.open(
        Endpoint(
          host: _host,
          port: _port,
          database: _dbName,
          username: _username,
          password: _password,
        ),
        settings: const ConnectionSettings(
          sslMode: SslMode.require, // AWS RDS usually requires SSL
        ),
      );
      debugPrint('Connected to PostgreSQL successfully.');
      await _initializeTables();
    } catch (e) {
      debugPrint('Failed to connect to PostgreSQL: $e');
      rethrow;
    }
  }

  Future<void> _initializeTables() async {
    if (_connection == null) return;
    
    const createTableQuery = '''
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        google_id VARCHAR(255) UNIQUE,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255),
        display_name VARCHAR(255),
        photo_url TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        last_login TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    ''';
    
    try {
      await _connection!.execute(createTableQuery);
      
      // Perform schema migrations if the table already existed with the old schema
      try {
        await _connection!.execute('ALTER TABLE users ALTER COLUMN google_id DROP NOT NULL;');
      } catch (e) {
        // Ignored if it's already dropped or doesn't apply
      }
      
      try {
        await _connection!.execute('ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255);');
      } catch (e) {
        // Ignored if column already exists
      }
      
      const createPrefsQuery = '''
        CREATE TABLE IF NOT EXISTS user_preferences (
          user_id INTEGER PRIMARY KEY REFERENCES users(id),
          categories TEXT,
          brand_rating INTEGER,
          cost_rating INTEGER,
          speed_rating INTEGER,
          reviews_rating INTEGER,
          impulse_rating INTEGER,
          routine_rating INTEGER
        );
      ''';
      await _connection!.execute(createPrefsQuery);

      debugPrint('Users table initialized with email/password support and user_preferences.');
    } catch (e) {
      debugPrint('Failed to initialize users table: $e');
    }
  }

  Future<int?> upsertUser({
    required String googleId,
    required String email,
    String? displayName,
    String? photoUrl,
  }) async {
    await connect();
    if (_connection == null) return null;

    final query = '''
      INSERT INTO users (google_id, email, display_name, photo_url, last_login)
      VALUES (@googleId, @email, @displayName, @photoUrl, CURRENT_TIMESTAMP)
      ON CONFLICT (email) 
      DO UPDATE SET 
        google_id = EXCLUDED.google_id,
        display_name = EXCLUDED.display_name,
        photo_url = EXCLUDED.photo_url,
        last_login = CURRENT_TIMESTAMP
      RETURNING id;
    ''';

    try {
      final result = await _connection!.execute(
        Sql.named(query),
        parameters: {
          'googleId': googleId,
          'email': email,
          'displayName': displayName,
          'photoUrl': photoUrl,
        },
      );
      debugPrint('User upserted successfully in Postgres via Google Auth.');
      if (result.isNotEmpty) {
        return result.first[0] as int;
      }
      return null;
    } catch (e) {
      debugPrint('Failed to upsert user: $e');
      rethrow;
    }
  }

  /// Creates a new user with email and hashed password
  /// If the user already exists (e.g. via Google Auth) but has no password,
  /// this links the password to their account.
  Future<void> createEmailUser({
    required String email,
    required String passwordHash,
    required String displayName,
  }) async {
    await connect();
    if (_connection == null) throw Exception('No DB Connection');

    final query = '''
      INSERT INTO users (email, password_hash, display_name, last_login)
      VALUES (@email, @passwordHash, @displayName, CURRENT_TIMESTAMP)
      ON CONFLICT (email)
      DO UPDATE SET
        password_hash = EXCLUDED.password_hash,
        display_name = COALESCE(users.display_name, EXCLUDED.display_name),
        last_login = CURRENT_TIMESTAMP
      WHERE users.password_hash IS NULL
      RETURNING id;
    ''';

    final result = await _connection!.execute(
      Sql.named(query),
      parameters: {
        'email': email,
        'passwordHash': passwordHash,
        'displayName': displayName,
      },
    );

    if (result.isEmpty) {
      // If result is empty, the ON CONFLICT WHERE condition wasn't met.
      // This means the email exists AND password_hash IS NOT NULL.
      throw Exception('Email already in use with a password.');
    }
  }

  /// Authenticates an email user by returning their row if the hash matches
  Future<Map<String, dynamic>?> authenticateEmailUser({
    required String email,
    required String passwordHash,
  }) async {
    await connect();
    if (_connection == null) throw Exception('No DB Connection');

    final query = '''
      SELECT id, email, display_name, photo_url, password_hash FROM users 
      WHERE email = @email
      LIMIT 1
    ''';

    final result = await _connection!.execute(
      Sql.named(query),
      parameters: {
        'email': email,
      },
    );

    if (result.isEmpty) throw Exception('Account not found. Please sign up first.');
    
    final row = result.first;
    final storedHash = row[4];
    
    if (storedHash == null) {
      throw Exception('This account uses Google Sign-In. Please click the Google button below, or use Sign Up to link a password.');
    }
    
    if (storedHash != passwordHash) {
      throw Exception('Invalid password.');
    }
    
    // Update last_login
    await _connection!.execute(
      Sql.named('UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE email = @email'),
      parameters: {'email': email},
    );

    return {
      'id': row[0],
      'email': row[1],
      'display_name': row[2],
      'photo_url': row[3],
    };
  }

  Future<bool> hasPreferences(int userId) async {
    await connect();
    if (_connection == null) return false;
    final result = await _connection!.execute(
      Sql.named('SELECT 1 FROM user_preferences WHERE user_id = @userId'),
      parameters: {'userId': userId}
    );
    return result.isNotEmpty;
  }

  Future<void> savePreferences({
    required int userId,
    required String categories,
    required int brandRating,
    required int costRating,
    required int speedRating,
    required int reviewsRating,
    required int impulseRating,
    required int routineRating,
  }) async {
    await connect();
    if (_connection == null) return;
    
    final query = '''
      INSERT INTO user_preferences (
        user_id, categories, brand_rating, cost_rating, speed_rating, 
        reviews_rating, impulse_rating, routine_rating
      ) VALUES (
        @userId, @categories, @brandRating, @costRating, @speedRating,
        @reviewsRating, @impulseRating, @routineRating
      ) ON CONFLICT (user_id) DO UPDATE SET
        categories = EXCLUDED.categories,
        brand_rating = EXCLUDED.brand_rating,
        cost_rating = EXCLUDED.cost_rating,
        speed_rating = EXCLUDED.speed_rating,
        reviews_rating = EXCLUDED.reviews_rating,
        impulse_rating = EXCLUDED.impulse_rating,
        routine_rating = EXCLUDED.routine_rating;
    ''';
    
    await _connection!.execute(
      Sql.named(query),
      parameters: {
        'userId': userId,
        'categories': categories,
        'brandRating': brandRating,
        'costRating': costRating,
        'speedRating': speedRating,
        'reviewsRating': reviewsRating,
        'impulseRating': impulseRating,
        'routineRating': routineRating,
      }
    );
  }

  Future<void> close() async {
    await _connection?.close();
    _connection = null;
  }
}
