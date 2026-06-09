# 1Password to Coralogix Lambda

AWS Lambda function that fetches events from 1Password Events API and forwards them to Coralogix for logging and monitoring.

## Features

- Fetches sign-in attempts, item usages, and audit events from 1Password
- Forwards events to Coralogix in real-time
- Supports all Coralogix regions
- Configurable application and subsystem names

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `ONEPASSWORD_TOKEN` | Yes | - | 1Password Events API token |
| `CORALOGIX_PRIVATE_KEY` | Yes | - | Coralogix Send-Your-Data API key |
| `CORALOGIX_REGION` | No | `eu1` | Coralogix region code (see below) |
| `CORALOGIX_APPLICATION` | No | `1Password` | Application name in Coralogix |
| `CORALOGIX_SUBSYSTEM` | No | `Events` | Subsystem name in Coralogix |

### Coralogix Regions

| Region Code | Domain | Location |
|-------------|--------|----------|
| `eu1` | eu1.coralogix.com | Europe (Ireland) |
| `eu2` | eu2.coralogix.com | Europe (Stockholm) |
| `ap1` | ap1.coralogix.com | Asia Pacific (Mumbai) |
| `ap2` | ap2.coralogix.com | Asia Pacific (Singapore) |
| `us1` | us1.coralogix.com | US (Ohio) |
| `us2` | us2.coralogix.com | US (Virginia) |

## Deployment

### 1. Create Deployment Package

```bash
# Create a directory for the package
mkdir package
cd package

# Install dependencies
pip install -r ../requirements.txt -t .

# Copy the lambda function
cp ../lambda_function.py .

# Create the zip file
zip -r ../deployment.zip .
```

### 2. Create Lambda Function

1. Go to AWS Lambda Console
2. Click "Create function"
3. Choose "Author from scratch"
4. Configure:
   - Function name: `1password-coralogix`
   - Runtime: Python 3.11 or later
   - Architecture: x86_64
5. Click "Create function"

### 3. Upload Code

1. In the Lambda function page, go to "Code" tab
2. Click "Upload from" → ".zip file"
3. Upload `deployment.zip`

### 4. Configure Environment Variables

1. Go to "Configuration" → "Environment variables"
2. Add the following variables:

```
ONEPASSWORD_TOKEN=your-1password-events-api-token
CORALOGIX_PRIVATE_KEY=your-coralogix-api-key
CORALOGIX_REGION=eu2
CORALOGIX_APPLICATION=1Password
CORALOGIX_SUBSYSTEM=SecurityEvents
```

### 5. Configure Timeout

1. Go to "Configuration" → "General configuration"
2. Set timeout to at least 60 seconds (recommended: 120 seconds)

### 6. Set Up EventBridge Trigger

1. Go to "Configuration" → "Triggers"
2. Click "Add trigger"
3. Select "EventBridge (CloudWatch Events)"
4. Create a new rule:
   - Rule name: `1password-coralogix-schedule`
   - Schedule expression: `rate(5 minutes)`
5. Click "Add"

## Getting API Keys

### 1Password Events API Token

1. Sign in to your 1Password Business account
2. Go to Integrations → Directory
3. Click "Events Reporting"
4. Generate a new API token
5. Copy the token and store it securely

### Coralogix API Key

1. Sign in to your Coralogix account
2. Go to Data Flow → API Keys
3. Copy your "Send Your Data" API key

## Testing

### Manual Test

1. Go to the Lambda function "Test" tab
2. Create a test event with empty JSON: `{}`
3. Click "Test"
4. Check the execution results and CloudWatch logs

### Verify in Coralogix

1. Go to your Coralogix dashboard
2. Navigate to Explore → Logs
3. Filter by application name (e.g., `1Password`)
4. You should see incoming events from 1Password

## Troubleshooting

### No Events Appearing

- Verify environment variables are set correctly
- Check CloudWatch logs for errors
- Ensure the 1Password token has correct permissions
- Verify the Coralogix region matches your account

### Timeout Errors

- Increase Lambda timeout (Configuration → General configuration)
- Check if 1Password API is responding

### Authentication Errors

- Regenerate 1Password Events API token
- Verify Coralogix API key is correct
- Ensure you're using the correct Coralogix region

## License

MIT
