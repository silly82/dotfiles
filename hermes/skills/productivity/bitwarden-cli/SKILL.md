---
name: bitwarden-cli
description: "Bitwarden CLI: install, configure, login, unlock, SSH keys."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [macos, linux]
metadata:
  hermes:
    tags: [Bitwarden, Password-Manager, CLI, SSH-Keys, Secrets]
    related_skills: []
---

# Bitwarden CLI Skill

This skill enables working with the Bitwarden password manager via its official CLI (`bw`). It covers installation, configuration with custom self‑hosted servers, authentication (API key or interactive), unlocking the vault, and retrieving stored items such as SSH keys and passwords.

## Trigger

Load this skill when the user asks to:
- Check if `bw` (Bitwarden CLI) is installed
- Install Bitwarden CLI via Nix, Homebrew, or official script
- Configure a custom server (self‑hosted instance)
- Login with API key or interactive password
- Unlock the vault and retrieve SSH keys or other secrets
- List, search, or export items from the vault

### User Preferences (Silvan)

- Prefers concise, direct answers in German.
- When asked for a choice, may answer "ja" (yes) to the first option; interpret as affirmative.
- For SSH key deployment, wants actionable steps ("was muss ich wo pasten") rather than lengthy explanations.
- Uses Nix for installation (`nix profile install nixpkgs#bitwarden-cli`).
- Own self‑hosted Bitwarden server at `https://vault.zwx.ch`.
- Uses API‑key login (Client‑ID: `user.9ba7a7ca‑8b05‑4e7d‑9208‑dc8898c51c51` – keep secret).
- Master password known (provided in session).

## Installation

### Detection

First verify if `bw` is already available:

```bash
which bw 2>/dev/null || bw --version 2>/dev/null || echo "Bitwarden CLI not found"
```

### Installation Methods

**Preferred (Nix)** – for Silvan's environment:
```bash
nix profile install nixpkgs#bitwarden-cli
```

**Homebrew (macOS)** – if Nix not available:
```bash
brew install bitwarden-cli
```

**Official Script** – for other platforms:
```bash
curl -L https://vault.bitwarden.com/download/cli/latest/macos/bw.zip -o bw.zip
unzip bw.zip
sudo mv bw /usr/local/bin/
```

**Node.js (npm)** – not recommended but possible:
```bash
npm install -g @bitwarden/cli
```

After installation, verify:
```bash
bw --version
```

## Configuration

### Set a Custom Server

If using a self‑hosted Bitwarden instance (e.g., `https://vault.example.com`):

```bash
bw config server https://vault.example.com
```

To revert to the official Bitwarden cloud:
```bash
bw config server https://vault.bitwarden.com
```

Check current configuration:
```bash
bw config server
```

## Authentication

### API Key Login (Recommended for Automation)

1. Obtain Client ID and Client Secret from Bitwarden Web Vault: **Settings → Account → Security → API Key**
2. Login using environment variables (non‑interactive):

```bash
export BW_CLIENTID="user.xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export BW_CLIENTSECRET="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
bw login --apikey
```

Or pass them directly (they will be prompted):
```bash
bw login --apikey
# Enter Client ID and Client Secret when prompted
```

### Interactive Login

For interactive sessions where you can type the master password:

```bash
bw login your-email@example.com
# Enter master password when prompted
```

### Status Check

```bash
bw status
```

Expected output includes `serverUrl`, `userEmail`, `userId`, and `status` (`locked` or `unlocked`).

## Unlocking the Vault

After login, the vault is still **locked** (encrypted). To decrypt and access secrets:

### Interactive Unlock

```bash
bw unlock
# Enter master password when prompted
```

After successful unlock, the command prints a **session key**. Save it as an environment variable for subsequent commands:

```bash
export BW_SESSION="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

### Non‑Interactive Unlock with Known Password

If you already know the master password (e.g., from user input):

```bash
export BW_SESSION=$(bw unlock --raw "your-master-password")
```

**Warning:** Passing passwords on the command line may leave traces in shell history. Prefer interactive prompts or environment variables.

### Verify Unlock Status

```bash
bw status | jq -r .status  # should be "unlocked"
```

## Working with Items

### List All Items

```bash
bw list items
```

Pipe to `jq` for filtering and formatting.

### Search by Keyword

```bash
bw list items --search "ssh"
```

### Retrieve a Specific Item by ID

First get the item ID from listing, then:

```bash
bw get item <item-id>
```

### Filter by Item Type

Common types:
- `1` – Login
- `2` – Secure Note
- `3` – Card
- `4` – Identity
- `5` – **SSH Key**

List only SSH keys:

```bash
bw list items | jq -r '.[] | select(.type == 5) | .name'
```

Get SSH key details (public key, fingerprint):

```bash
bw get item <ssh-key-id> | jq -r '.sshKey.publicKey, .sshKey.keyFingerprint'
```

**Important:** The private key is **redacted** in CLI JSON output (`[REDACTED PRIVATE KEY]`). To obtain the private key, use the Bitwarden web GUI or export via the web interface.

### Import Local SSH Keys into Vault

To import existing SSH key pairs from `~/.ssh/` into Bitwarden as type‑5 items:

1. **Ensure you are unlocked and have a session key:**
   ```bash
   export BW_SESSION=$(bw unlock --raw "your-master-password")
   ```

2. **Create a JSON template for an SSH key item:**
   ```bash
   cat > ssh-key-template.json <<EOF
   {
     "type": 5,
     "name": "SSH Key: key-name",
     "favorite": false,
     "reprompt": 0,
     "notes": "Imported from local SSH key key-name",
     "fields": [],
     "passwordHistory": [],
     "sshKey": {
       "privateKey": "$(cat ~/.ssh/key-name)",
       "publicKey": "$(cat ~/.ssh/key-name.pub)",
       "keyFingerprint": "$(ssh-keygen -l -f ~/.ssh/key-name.pub | awk '{print $2}')"
     }
   }
   EOF
   ```

3. **Base64‑encode and create the item:**
   ```bash
   bw create item $(cat ssh-key-template.json | base64)
   ```

   Or use a Python script to automate multiple keys (see `references/import-ssh-keys.py`).

4. **Verify the import:**
   ```bash
   bw list items | jq -r '.[] | select(.type == 5) | .name'
   ```

### Retrieve Passwords, Usernames, URIs

```bash
# Get password for a specific item
bw get password <item-id>

# Get username
bw get username <item-id>

# Get URIs
bw get uri <item-id>
```

### Sync Local Cache

```bash
bw sync
```

## Common Workflows

### 1. Initial Setup with Self‑Hosted Server

```bash
# Install
nix profile install nixpkgs#bitwarden-cli

# Configure custom server
bw config server https://vault.example.com

# Login with API key (or interactive)
export BW_CLIENTID="..."
export BW_CLIENTSECRET="..."
bw login --apikey

# Unlock
export BW_SESSION=$(bw unlock --raw "master-password")

# Sync and list SSH keys
bw sync
bw list items | jq -r '.[] | select(.type == 5) | .name'
```

### 2. Export SSH Public Key to File

```bash
SSH_KEY_ID=$(bw list items | jq -r '.[] | select(.type == 5) | .id' | head -1)
bw get item $SSH_KEY_ID | jq -r '.sshKey.publicKey' > ~/.ssh/bitwarden_key.pub
chmod 644 ~/.ssh/bitwarden_key.pub
```

### 3. Check Vault Status and Sync

```bash
bw status
bw sync
```

### 4. Import Multiple Local SSH Keys

Use the provided Python script `references/import-ssh-keys.py` to batch‑import SSH keys from `~/.ssh/`:

```bash
# Ensure you are unlocked
export BW_SESSION=$(bw unlock --raw "master-password")

# Run the script (from within the skill directory or copy it)
python3 /path/to/skill/references/import-ssh-keys.py
```

The script:
- Finds private keys in `~/.ssh/` (excluding known config files)
- Matches them with `.pub` files
- Computes fingerprints
- Creates Bitwarden items (type 5) for each key pair

See the script source for customization (e.g., scanning other directories).

## Pitfalls & Troubleshooting

### Private Key Redaction

The CLI intentionally redacts private SSH keys in JSON output. This is a security feature, not a bug. To obtain the private key, use the Bitwarden web GUI or export via the web interface.

### Session Expiry

The `BW_SESSION` key is valid until the vault is locked again (via `bw lock`) or the CLI cache is cleared. If commands start failing with authentication errors, re‑unlock:

```bash
export BW_SESSION=$(bw unlock --raw "master-password")
```

### Custom Server Certificate Issues

If the self‑hosted server uses a self‑signed certificate, you may need to set `NODE_EXTRA_CA_CERTS` or use `--insecure` flag (not officially supported).

### Missing jq

Many filtering examples rely on `jq`. Install it if missing:

```bash
# Nix
nix profile install nixpkgs#jq

# Homebrew
brew install jq

# apt
sudo apt install jq
```

### `bw` Command Not Found After Installation

Ensure the installation directory is in `$PATH`. Nix installations go to `~/.nix-profile/bin/`. Add to PATH if needed:

```bash
export PATH="$HOME/.nix-profile/bin:$PATH"
```

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `BW_CLIENTID` | Client ID for API key login |
| `BW_CLIENTSECRET` | Client secret for API key login |
| `BW_SESSION` | Session key after unlocking |
| `BW_PASSWORD` | Master password (can be used with `--passwordenv`) |

## Related Skills

None yet.