// Enums stored as text in SQLite. The names match the server's enums and Backend Schema 2.

enum VisitType { maternal, child, malaria, nutrition }

/// Per-record upload status shown in the UI: local (saved, not queued), queued, synced, failed.
enum SyncState { local, queued, synced, failed }

/// Urgent-alert progress: sending -> sent_sms -> confirmed | unconfirmed (slice 6).
enum DispatchState { sending, sentSms, confirmed, unconfirmed }

enum OutboxOp { upsert, delete }
