# Contributing to N3RD Game

Thank you for your interest in contributing to N3RD Game! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Code Style](#code-style)
- [Testing](#testing)
- [Pull Request Process](#pull-request-process)
- [Commit Message Format](#commit-message-format)
- [Code Review Checklist](#code-review-checklist)

## Code of Conduct

- Be respectful and inclusive
- Welcome newcomers and help them learn
- Focus on constructive feedback
- Respect different viewpoints and experiences

## Getting Started

1. **Fork the repository**
2. **Clone your fork:**
   ```bash
   git clone https://github.com/your-username/n3rd_game.git
   cd n3rd_game
   ```

3. **Set up the development environment:**
   ```bash
   flutter pub get
   ```

4. **Create a branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Workflow

### Branch Naming

- `feature/` - New features
- `fix/` - Bug fixes
- `refactor/` - Code refactoring
- `docs/` - Documentation updates
- `test/` - Test additions/updates
- `chore/` - Maintenance tasks

### Before You Start

1. Check existing issues and pull requests
2. Discuss major changes in an issue first
3. Ensure your changes align with project goals

## Code Style

### Dart Style Guide

Follow the [Effective Dart](https://dart.dev/guides/language/effective-dart) style guide:

- Use `dart format` before committing
- Follow existing code patterns
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions focused and small

### Linting

The project uses `flutter_lints`. Run:

```bash
flutter analyze
```

All linter errors must be fixed before submitting a PR.

### File Organization

- One class per file (except related classes)
- Group related files in directories
- Use descriptive file names

### Naming Conventions

- **Classes**: PascalCase (`GameService`)
- **Variables**: camelCase (`gameState`)
- **Constants**: lowerCamelCase with `const` (`const maxScore = 100`)
- **Private members**: Prefix with `_` (`_privateField`)

## Testing

### Test Requirements

- **New features** must include tests
- **Bug fixes** must include regression tests
- **Test coverage** must be maintained at 80%+

### Running Tests

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/services/auth_service_test.dart
```

### Writing Tests

- Use descriptive test names
- Follow AAA pattern (Arrange, Act, Assert)
- Test edge cases and error conditions
- Mock external dependencies

Example:
```dart
test('should authenticate user with valid credentials', () async {
  // Arrange
  final service = AuthService();
  final email = 'test@example.com';
  final password = 'SecurePass123!';
  
  // Act
  final result = await service.signIn(email, password);
  
  // Assert
  expect(result, isNotNull);
  expect(service.currentUser, isNotNull);
});
```

## Pull Request Process

### Before Submitting

1. **Update tests**: Ensure all tests pass
2. **Run linter**: Fix all linter errors
3. **Update documentation**: Update relevant docs
4. **Check coverage**: Ensure coverage doesn't decrease

### PR Checklist

- [ ] Code follows style guidelines
- [ ] All tests pass
- [ ] Linter errors fixed
- [ ] Documentation updated
- [ ] Test coverage maintained
- [ ] No breaking changes (or documented)
- [ ] Commit messages follow format

### PR Description

Include:
- **What**: Description of changes
- **Why**: Reason for changes
- **How**: Implementation approach
- **Testing**: How changes were tested
- **Screenshots**: If UI changes

### Review Process

1. Automated checks must pass
2. At least one maintainer review required
3. Address review comments
4. Maintainer approval before merge

## Commit Message Format

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Code style (formatting)
- `refactor`: Code refactoring
- `test`: Test additions/changes
- `chore`: Maintenance tasks

### Examples

```
feat(game): add shuffle mode difficulty levels

Add easy, medium, hard, and insane difficulty levels
for shuffle mode with configurable shuffle intervals.

Closes #123
```

```
fix(auth): handle expired token gracefully

Previously, expired tokens caused crashes. Now they
trigger automatic re-authentication.

Fixes #456
```

## Code Review Checklist

### For Authors

- [ ] Code is clean and readable
- [ ] Tests are comprehensive
- [ ] Documentation is updated
- [ ] No hardcoded values
- [ ] Error handling is proper
- [ ] Performance considerations addressed

### For Reviewers

- [ ] Code follows style guide
- [ ] Logic is correct
- [ ] Tests are adequate
- [ ] No security issues
- [ ] Performance is acceptable
- [ ] Documentation is clear

## Security

- **Never commit secrets** (API keys, passwords, etc.)
- Use environment variables for sensitive data
- Follow security best practices
- Report security issues privately

## Questions?

- Open an issue for questions
- Check existing documentation
- Review closed PRs for examples

## Thank You!

Your contributions make this project better. Thank you for taking the time to contribute!

---

**Last Updated:** December 2024



















