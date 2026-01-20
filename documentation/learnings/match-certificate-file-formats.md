---
title: Match Certificate File Formats Are Not Standard PKCS12
date: 2026-01-05
severity: HIGH
category: fastlane
tags: [match, certificates, encryption, pkcs12, pem, der]
symptoms:
  - "MAC verification failed during PKCS12 import (wrong password?)"
  - Certificate import fails with empty password
  - Manually added certificates not working
root_cause: Match stores PEM-encoded RSA private keys in .p12 files, not actual PKCS12 bundles
solution: Use correct file formats - DER for .cer files, PEM RSA keys for .p12 files, encrypted with Match v2 format
files_affected:
  - Match repo certs/*/*.cer
  - Match repo certs/*/*.p12
related:
  - macos-installer-certificate-type.md
---

## Match File Format Reference

### .cer files
- Format: **DER-encoded X.509 certificate** (binary)
- NOT PEM format
- Raw certificate from Apple Developer Portal

### .p12 files (NOT actual PKCS12!)
- Format: **PEM-encoded RSA private key**
- Starts with `-----BEGIN RSA PRIVATE KEY-----`
- NOT PKCS8 format (`BEGIN PRIVATE KEY`)

### Encryption
Both files encrypted with Match v2:
- Prefix: `match_encrypted_v2__`
- Algorithm: AES-256-GCM
- Key derivation: PBKDF2-HMAC-SHA256, 10,000 iterations

## Manual Certificate Addition

```bash
# Export private key to PEM RSA format
openssl pkcs12 -in cert.p12 -nocerts -nodes | openssl rsa -out private_key.pem

# Ensure .cer is DER format (download from Apple is already DER)
openssl x509 -in cert.pem -outform DER -out cert.cer
```

Then encrypt both with Match v2 Ruby encryption (see Match source code for details).

## Common Mistakes

1. Creating actual PKCS12 bundles - Match doesn't use these
2. Using PKCS8 key format instead of RSA format
3. Using PEM format for .cer files
4. Using OpenSSL CLI encryption instead of Match's Ruby implementation
