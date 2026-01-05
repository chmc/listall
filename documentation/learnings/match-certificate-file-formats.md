# Match Certificate File Formats

## Date: 2026-01-05

## Problem
When manually adding certificates to a fastlane Match repository, the `.p12` files were failing to import with "MAC verification failed during PKCS12 import (wrong password?)" errors, even when using empty passwords.

## Root Cause
Match does NOT use actual PKCS12 bundles for `.p12` files. Despite the file extension, Match stores **PEM-encoded RSA private keys** in `.p12` files, not PKCS12 bundles.

## File Format Reference

### `.cer` files
- Format: **DER-encoded X.509 certificate** (binary format)
- NOT PEM format with `-----BEGIN CERTIFICATE-----` headers
- This is the raw certificate downloaded from Apple Developer Portal

### `.p12` files (despite the extension!)
- Format: **PEM-encoded RSA private key**
- Starts with `-----BEGIN RSA PRIVATE KEY-----`
- NOT a PKCS12 bundle
- Must be in traditional RSA format, not PKCS8 format

### Match Encryption
Both files are encrypted using Match v2 format:
- Prefix: `match_encrypted_v2__` (double underscore)
- Algorithm: AES-256-GCM
- Key derivation: PBKDF2-HMAC-SHA256 with 10,000 iterations

## How to Add Certificates Manually

1. **Export the private key from your .p12 to PEM format:**
   ```bash
   # If you have a combined PEM file
   openssl rsa -in combined.pem -out private_key.pem

   # Or if you have a PKCS12 file
   openssl pkcs12 -in cert.p12 -nocerts -nodes | openssl rsa -out private_key.pem
   ```

2. **Ensure the .cer is in DER format:**
   ```bash
   # Download directly from Apple (already DER format)
   # Or convert from PEM to DER
   openssl x509 -in cert.pem -outform DER -out cert.cer
   ```

3. **Encrypt both files with Match encryption format:**
   ```ruby
   require 'openssl'
   require 'base64'
   require 'securerandom'

   def encrypt_v2(data, password)
     cipher = OpenSSL::Cipher.new('aes-256-gcm')
     cipher.encrypt
     salt = SecureRandom.random_bytes(8)
     key_iv = OpenSSL::KDF.pbkdf2_hmac(password, salt: salt,
       iterations: 10_000, length: 32 + 12 + 24, hash: "sha256")
     cipher.key = key_iv[0..31]
     cipher.iv = key_iv[32..43]
     cipher.auth_data = key_iv[44..-1]
     encrypted_data = cipher.update(data) + cipher.final
     auth_tag = cipher.auth_tag
     Base64.encode64("match_encrypted_v2__" + salt + auth_tag + encrypted_data)
   end

   # Encrypt .cer (binary DER data)
   cer_data = File.binread('cert.cer')
   File.write('CERT_ID.cer', encrypt_v2(cer_data, ENV['MATCH_PASSWORD']))

   # Encrypt .p12 (PEM RSA key text)
   key_data = File.read('private_key.pem')
   File.write('CERT_ID.p12', encrypt_v2(key_data, ENV['MATCH_PASSWORD']))
   ```

## Common Mistakes

1. **Creating actual PKCS12 bundles** - Match doesn't use these
2. **Using PKCS8 key format** (`BEGIN PRIVATE KEY`) instead of RSA format (`BEGIN RSA PRIVATE KEY`)
3. **Using PEM format for .cer files** - Match expects DER format
4. **Using wrong encryption (OpenSSL cli)** - Match uses Ruby's OpenSSL with specific parameters

## Verification

To verify a working Match repo file:
```ruby
# Decrypt and check format
def decrypt_v2(encrypted_data, password)
  data = Base64.decode64(encrypted_data)
  return nil unless data.start_with?("match_encrypted_v2__")
  # ... decryption code ...
end

# .cer should start with 0x30 (DER format)
cer = decrypt_v2(File.read('CERT_ID.cer'), password)
puts "CER is DER: #{cer[0] == "\x30"}"

# .p12 should start with "-----BEGIN RSA PRIVATE KEY-----"
p12 = decrypt_v2(File.read('CERT_ID.p12'), password)
puts "P12 is RSA key: #{p12.start_with?('-----BEGIN RSA PRIVATE KEY-----')}"
```

## Related Issues
- GitHub fastlane/fastlane discussions about PKCS12 import failures
- OpenSSL 3.x compatibility issues with macOS Security framework (not the actual issue here)
