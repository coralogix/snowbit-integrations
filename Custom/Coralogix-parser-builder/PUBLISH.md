# Publishing to coralogix/snowbit-integrations

This guide explains how to publish the Coralogix Parser Builder to [coralogix/snowbit-integrations](https://github.com/coralogix/snowbit-integrations) under the **Custom** folder.

## Target location

```
snowbit-integrations/
  Custom/
    Coralogix-parser-builder/   ← your integration
      cli.py
      parser.py
      deploy_mgmt_api.py
      deploy_linux_parsers.py
      data/
      parsers/
      terraform/
      .cursor/
      .env.example
      .gitignore
      README.md
      CONTRIBUTING.md
      requirements.txt
```

## Prerequisites

- **Push access** to [coralogix/snowbit-integrations](https://github.com/coralogix/snowbit-integrations), or  
- **Fork** the repo and submit a Pull Request

## Steps

### 1. Clone snowbit-integrations

```bash
git clone https://github.com/coralogix/snowbit-integrations.git
cd snowbit-integrations
```

### 2. Create a branch

```bash
git checkout -b add-coralogix-parser-builder
```

### 3. Copy the parser builder

```bash
# From the directory containing coralogix-parser-builder
cp -r coralogix-parser-builder Custom/Coralogix-parser-builder
```

Or, if you're already in the snowbit-integrations repo:

```bash
cp -r /path/to/coralogix-parser-builder Custom/Coralogix-parser-builder
```

### 4. Remove files that shouldn't be committed

```bash
cd Custom/Coralogix-parser-builder
rm -rf venv/
rm -rf terraform/.terraform/
rm -f .env
```

### 5. Commit and push

```bash
cd ../..
git add Custom/Coralogix-parser-builder
git commit -m "Add Coralogix Parser Builder - create parsers for any log source"
git push origin add-coralogix-parser-builder
```

### 6. Open a Pull Request

1. Go to https://github.com/coralogix/snowbit-integrations
2. Create a Pull Request from `add-coralogix-parser-builder` to `master`
3. Add a description: "Adds Coralogix Parser Builder - a tool to create parsers for any log source and deploy to Coralogix. Supports chat-first workflow in Cursor."

---

## Alternative: One-time copy script

```bash
#!/bin/bash
# Run from coralogix-parser-builder directory
REPO=../snowbit-integrations  # or your clone path
DEST=$REPO/Custom/Coralogix-parser-builder
mkdir -p $DEST
rsync -av --exclude='venv' --exclude='terraform/.terraform' \
  --exclude='.env' --exclude='__pycache__' \
  . $DEST/
echo "Copied to $DEST"
```

---

## After publishing

- The integration will be available at:  
  `https://github.com/coralogix/snowbit-integrations/tree/master/Custom/Coralogix-parser-builder`
- Users can clone the repo or download just that folder
- Consider adding a link to the repo README if it has an integrations index
