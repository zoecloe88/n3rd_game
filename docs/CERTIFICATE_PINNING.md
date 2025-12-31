# Certificate Pinning Guide

## Overview

Certificate pinning is a security mechanism that ensures your app only accepts connections from servers with specific, trusted certificates. This prevents man-in-the-middle (MITM) attacks by validating that the server's certificate matches a known, trusted certificate hash.

> **Related**: This is part of the comprehensive security strategy. See [Security Guide](./SECURITY.md) for an overview of all security measures.

## Why Certificate Pinning?

- **Prevent MITM Attacks**: Ensures connections are made to legitimate servers
- **Enhanced Security**: Adds an extra layer of security beyond standard SSL/TLS
- **Production Best Practice**: Recommended for production applications handling sensitive data

## How It Works

1. **Certificate Hash Storage**: The app stores SHA-256 hashes of trusted certificates
2. **Connection Validation**: When connecting to a server, the app validates the certificate
3. **Hash Comparison**: The server's certificate hash is compared against stored hashes
4. **Connection Allowed/Denied**: Connection proceeds only if hash matches

## Implementation

### Current Implementation

The app uses `SecureHttpClient` service located at `lib/services/secure_http_client.dart`. This service:

- Validates certificates against pinned hashes
- Provides secure HTTP methods (GET, POST, PUT, DELETE)
- Handles timeouts and error logging
- Supports environment-specific configuration

### Configuration

Certificate pinning is configured in `lib/config/app_config.dart`:

```dart
static CertificatePinningConfig? getCertificatePinningConfig(String host) {
  switch (host) {
    case 'your-api-host.com':
      return const CertificatePinningConfig(
        certificateHashes: [
          'your-certificate-hash-here',
        ],
        description: 'Your API Service',
      );
    default:
      return null;
  }
}
```

### Getting Certificate Hashes

To get certificate hashes for your servers:

#### Method 1: Using OpenSSL (Recommended)

```bash
# 1. Get certificate from server
openssl s_client -connect your-host.com:443 -showcerts < /dev/null 2>/dev/null | openssl x509 -outform PEM > cert.pem

# 2. Extract public key and calculate SHA-256 hash
openssl x509 -in cert.pem -pubkey -noout | \
  openssl pkey -pubin -outform der | \
  openssl dgst -sha256 -binary | \
  openssl enc -base64
```

#### Method 2: Using Online Tools

1. Visit: https://www.ssllabs.com/ssltest/
2. Enter your domain
3. View certificate details
4. Extract public key hash

#### Method 3: Using Certificate Chain

For servers with certificate chains, pin the intermediate and root certificates:

```bash
# Get full certificate chain
openssl s_client -connect your-host.com:443 -showcerts < /dev/null > chain.pem

# Extract each certificate and calculate hashes
# Process each certificate in the chain
```

### Adding Certificate Hashes

1. **Get Certificate Hash**: Use one of the methods above
2. **Add to AppConfig**: Update `getCertificatePinningConfig()` in `app_config.dart`
3. **Test**: Verify the app connects successfully
4. **Deploy**: Deploy to production

**Example:**

```dart
case 'api.example.com':
  return const CertificatePinningConfig(
    certificateHashes: [
      'ABC123...XYZ789',  // Primary certificate hash
      'DEF456...UVW012',  // Backup certificate hash (for rotation)
    ],
    description: 'Example API',
  );
```

### Using SecureHttpClient

Replace standard HTTP calls with `SecureHttpClient`:

**Before:**
```dart
import 'package:http/http.dart' as http;

final response = await http.get(Uri.parse('https://api.example.com/data'));
```

**After:**
```dart
import 'package:n3rd_game/services/secure_http_client.dart';

final response = await SecureHttpClient.instance.get(
  Uri.parse('https://api.example.com/data'),
);
```

### Environment Configuration

Certificate pinning behavior can be controlled via environment variables:

- **Debug Mode**: Disabled by default (can be enabled with `ENABLE_CERT_PINNING_DEBUG=true`)
- **Production Mode**: Always enabled

To enable in debug mode:
```bash
flutter run --dart-define=ENABLE_CERT_PINNING_DEBUG=true
```

## Best Practices

### 1. Pin Multiple Certificates

Always pin at least two certificates:
- Current certificate
- Backup certificate (for rotation)

This prevents app breakage when certificates are rotated.

### 2. Gradual Rollout

- Start with non-critical endpoints
- Monitor for connection failures
- Gradually expand to all endpoints

### 3. Certificate Rotation

When rotating certificates:
1. Add new certificate hash to the list
2. Deploy app update
3. Wait for sufficient adoption
4. Remove old certificate hash

### 4. Error Handling

The `SecureHttpClient` automatically:
- Logs certificate validation failures
- Provides clear error messages
- Handles timeouts gracefully

### 5. Testing

Test certificate pinning:
- In debug mode (with `ENABLE_CERT_PINNING_DEBUG=true`)
- With invalid certificates (should fail)
- With valid certificates (should succeed)
- After certificate rotation

## Troubleshooting

### Issue: App can't connect after enabling pinning

**Symptoms:**
- Connection timeouts
- Certificate validation errors in logs

**Solutions:**
1. Verify certificate hash is correct
2. Check if certificate has been rotated
3. Ensure hash is base64 encoded SHA-256
4. Test with pinning disabled first

### Issue: Certificate validation fails

**Symptoms:**
- "Certificate pinning validation failed" in logs
- Connection refused errors

**Solutions:**
1. Re-extract certificate hash
2. Verify server certificate hasn't changed
3. Check for certificate chain issues
4. Ensure hash format is correct (base64)

### Issue: App works in debug but fails in production

**Symptoms:**
- Works in debug mode
- Fails in release builds

**Solutions:**
1. Verify certificate pinning is enabled in production
2. Check certificate hashes are correct
3. Ensure production certificates match development
4. Review error logs for specific failures

## Security Considerations

### What Certificate Pinning Protects Against

- ✅ Man-in-the-middle attacks
- ✅ Certificate authority compromises
- ✅ Malicious proxy servers
- ✅ Network-level attacks

### What Certificate Pinning Doesn't Protect Against

- ❌ Application-level vulnerabilities
- ❌ Server-side security issues
- ❌ API key exposure
- ❌ Client-side code vulnerabilities

### Additional Security Measures

Certificate pinning should be used alongside:
- HTTPS/TLS encryption
- API key restrictions
- Firestore security rules
- Input validation
- Rate limiting

## Monitoring

Monitor certificate pinning:
- Check error logs for validation failures
- Track connection success rates
- Monitor for certificate rotation events
- Alert on unusual validation patterns

## Related Documentation

- [Secure HTTP Client](../lib/services/secure_http_client.dart)
- [App Config](../lib/config/app_config.dart)
- [Security Guide](./SECURITY.md)
- [Security Guide](./SECURITY.md) - Comprehensive security overview
- [Setup Guide - API Key Restrictions](./SETUP_GUIDE.md#api-key-restrictions)

## Support

If you encounter issues:
1. Check error logs in Firebase Crashlytics
2. Verify certificate hashes are correct
3. Test with pinning disabled
4. Review server certificate details
5. Contact support if needed

---

**Last Updated:** January 2025  
**Status:** Production Ready



