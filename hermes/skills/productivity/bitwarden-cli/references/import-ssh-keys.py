#!/usr/bin/env python3
"""
Import local SSH keys into Bitwarden as type‑5 items.

Requires:
- Bitwarden CLI (`bw`) installed and in PATH
- Already logged in and unlocked (BW_SESSION environment variable set)
"""

import os
import subprocess
import json
import base64
import sys
from pathlib import Path

def find_private_keys(ssh_dir, limit=10):
    """Return list of private key files sorted by modification time (newest first)."""
    keys = []
    for root, dirs, files in os.walk(ssh_dir):
        for f in files:
            if f.endswith('.pub'):
                continue
            if f in ('known_hosts', 'config', 'authorized_keys', 'environment'):
                continue
            if f.startswith('.'):
                continue
            path = os.path.join(root, f)
            # heuristic: check if file starts with typical private key header
            try:
                with open(path, 'r') as pf:
                    first_line = pf.readline()
                    if 'PRIVATE' in first_line or 'OPENSSH' in first_line:
                        keys.append(path)
                    else:
                        # maybe a key without header? skip
                        pass
            except Exception:
                pass
    # sort by mtime descending
    keys.sort(key=lambda x: os.path.getmtime(x), reverse=True)
    return keys[:limit]

def get_public_key_path(private_path):
    pub = private_path + '.pub'
    if os.path.exists(pub):
        return pub
    # maybe .pub file with different naming? Not handling for now.
    return None

def get_fingerprint(pub_path):
    try:
        result = subprocess.run(['ssh-keygen', '-l', '-f', pub_path], 
                                capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            # output like "256 SHA256:... comment (ECDSA)"
            parts = result.stdout.strip().split()
            if len(parts) >= 2:
                return parts[1]  # SHA256:...
    except Exception as e:
        print(f"Failed to compute fingerprint for {pub_path}: {e}", file=sys.stderr)
    return None

def read_key_file(path):
    with open(path, 'r') as f:
        return f.read().strip()

def create_ssh_item(name, private_key, public_key, fingerprint=None):
    item = {
        "type": 5,
        "name": name,
        "favorite": False,
        "reprompt": 0,
        "notes": f"Imported from local SSH key {name}",
        "fields": [],
        "passwordHistory": [],
        "sshKey": {
            "privateKey": private_key,
            "publicKey": public_key,
            "keyFingerprint": fingerprint if fingerprint else ""
        }
    }
    return item

def bw_create_with_session(item_json, session):
    """Create item using session."""
    json_str = json.dumps(item_json)
    b64 = base64.b64encode(json_str.encode()).decode()
    cmd = ['bw', '--session', session, 'create', 'item', b64]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    if proc.returncode != 0:
        return False, f"bw error: {proc.stderr}"
    try:
        result = json.loads(proc.stdout)
        return True, result
    except json.JSONDecodeError:
        return False, f"Invalid JSON: {proc.stdout[:200]}"

def main():
    ssh_dir = Path.home() / '.ssh'
    if not ssh_dir.exists():
        print("No ~/.ssh directory")
        return
    
    session = os.environ.get('BW_SESSION')
    if not session:
        print("BW_SESSION environment variable not set. Please unlock first:")
        print("  export BW_SESSION=$(bw unlock --raw \"your-master-password\")")
        return
    
    keys = find_private_keys(str(ssh_dir), limit=10)
    print(f"Found {len(keys)} private key(s)")
    
    imported = []
    for key_path in keys:
        key_name = os.path.basename(key_path)
        pub_path = get_public_key_path(key_path)
        if not pub_path:
            print(f"Skipping {key_path}: no matching .pub file")
            continue
        
        try:
            private_key = read_key_file(key_path)
            public_key = read_key_file(pub_path)
            fingerprint = get_fingerprint(pub_path)
        except Exception as e:
            print(f"Failed to read key {key_path}: {e}")
            continue
        
        item = create_ssh_item(f"SSH Key: {key_name}", private_key, public_key, fingerprint)
        
        print(f"Importing {key_name}...")
        success, result = bw_create_with_session(item, session)
        if success:
            item_id = result.get('id', 'unknown')
            imported.append((key_name, item_id))
            print(f"  -> Imported as {item_id}")
        else:
            print(f"  -> Failed: {result}")
    
    print("\nSummary:")
    if imported:
        print(f"Successfully imported {len(imported)} SSH key(s):")
        for name, iid in imported:
            print(f"  {name}: {iid}")
    else:
        print("No keys imported.")

if __name__ == '__main__':
    main()