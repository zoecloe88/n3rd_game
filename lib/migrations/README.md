# Data Migrations

This directory contains data migration scripts for the application.

## Migration Structure

Migrations are versioned and executed in order. Each migration should:
- Be idempotent (safe to run multiple times)
- Have a rollback mechanism
- Log all changes
- Validate data integrity

## Adding a New Migration

1. Increment `_currentSchemaVersion` in `migration_service.dart`
2. Add a case in `_runMigration()` method
3. Implement the migration logic
4. Implement rollback logic in `_rollbackMigration()`
5. Test the migration thoroughly

## Migration Best Practices

- Always backup data before migration
- Test migrations on development data first
- Keep migrations small and focused
- Document what each migration does
- Ensure rollback is tested

















