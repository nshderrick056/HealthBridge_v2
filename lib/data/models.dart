// The domain enums, plus the one that only the storage layer needs.
export '../domain/entities/enums.dart';

/// What an outbox row asks the server to do.
enum OutboxOp { upsert, delete }
