# ACME Client (Keyfactor EAB)

A command-line ACME client written in Go for registering an ACME account with [External Account Binding (EAB)](https://datatracker.ietf.org/doc/html/rfc8555#section-7.3.4) — designed for use with Keyfactor's ACME service — and requesting certificates once registered. Account credentials and the EAB HMAC key are encrypted at rest using a passphrase-derived key.

Built on top of [go-acme/lego](https://github.com/go-acme/lego).

## Features

- Interactive first-run setup that registers an ACME account using EAB credentials (Key ID + HMAC key)
- Generates an ECDSA (P-256) account private key
- Encrypts the account private key and EAB HMAC key with AES-256-GCM, using a passphrase put through Argon2id key derivation
- Accepts the EAB HMAC key in base64url, base64 (standard or no-padding), or hex, and normalizes it internally
- Validates the Keyfactor ACME server URL format before registering
- Requests certificates for one or more SANs (Subject Alternative Names), including wildcard domains
- Writes the issued certificate, issuer certificate, private key, and a JSON metadata file to a timestamped output directory
- Supports non-interactive use via a `-passphrase` flag or the `ACMECLIENT_PASSPHRASE` environment variable

## Requirements

- Go 1.21+ (or whatever your `go.mod` specifies)
- Network access to your Keyfactor ACME endpoint
- A valid EAB Key ID and EAB HMAC key, issued by Keyfactor

## Installation

```bash
go build -o acmeclient main.go
```

## Usage

### 1. First run — register the ACME account

Run the binary with no flags. Since no `config.json` exists yet, you'll be prompted to enter your account details:

```bash
./acmeclient
```

You'll be asked for:

- ACME account email
- EAB Key ID
- EAB HMAC Key
- Keyfactor ACME URL (e.g. `https://your-keyfactor-host/acme`)
- Whether validation is enabled (`true`/`false`/`t`/`f`)
- A passphrase used to encrypt the account private key and EAB HMAC key

On success, this creates a `config.json` file in the current directory containing your account URI, status, and the encrypted secrets. **This file should be treated as sensitive** — although the private key and HMAC key are encrypted, it still ties to your ACME account.

### 2. Subsequent runs — request a certificate

Once `config.json` exists, supply one or more SANs with `-san`:

```bash
./acmeclient -san example.com,www.example.com
```

The tool will:

1. Load and decrypt the ACME client from `config.json` (prompting for the passphrase if not supplied)
2. Request a certificate covering the given SANs
3. Write the certificate, issuer certificate, private key, and metadata to the output directory

If you run the binary without `-san`, it will just load the config and report the account status without requesting a certificate.

### Flags

| Flag          | Default    | Description                                                                 |
|---------------|------------|-------------------------------------------------------------------------------|
| `-san`        | *(empty)*  | Comma-separated list of domains/SANs to request a certificate for           |
| `-out`        | `output`   | Directory where certificate files will be written                          |
| `-passphrase` | *(empty)*  | Passphrase to decrypt the account private key (prefer the env var instead) |

### Non-interactive passphrase

To avoid interactive prompts (e.g. in CI/automation), set:

```bash
export ACMECLIENT_PASSPHRASE="your-passphrase"
./acmeclient -san example.com
```

The `-passphrase` flag takes precedence over the environment variable if both are set.

## Output

Each certificate request creates a new directory under the output path, named `<first-san>_<timestamp>`, containing:

- `<san>.crt` — the issued certificate
- `<san>.issuer.crt` — the issuer (CA) certificate, if returned
- `<san>.key` — the private key for the certificate
- `<san>.certificate.json` — metadata (domain, cert URLs, SANs, file paths, request time)

## Security notes

- The account private key and EAB HMAC key are stored in `config.json` encrypted with AES-256-GCM, using a key derived from your passphrase via Argon2id (3 iterations, 64 MB memory, 4 threads, 32-byte key).
- Losing the passphrase means losing access to the decrypted account key — there is no recovery path built in.
- Certificate private keys written to the output directory are **not** encrypted; restrict permissions/access on the output directory as appropriate for your environment (files are written with `0600`/`0700` permissions).

## Important: validation/challenge provider

This tool does not configure an ACME challenge provider (HTTP-01, DNS-01, etc.). If `validationEnabled` is `true` in your config, make sure a challenge provider is configured appropriately before requesting certificates, or certificate issuance will fail at the CA's validation step.

## License

MIT License
