# GitHub Actions - Stremini AI Build Setup

## Quick Setup (3 steps)

### 1. Add GitHub Repository Secrets
Go to: https://github.com/krishna98877/Stremini.ai/settings/secrets/actions

Add these secrets:
- `GROQ_API_KEY` - Your primary GROQ API key
- `GROQ_API_KEY_2` - Your secondary GROQ API key (optional)
- `COMPOSIO_CONSUMER_KEY` - Your Composio API key (if using Composio features)

### 2. Trigger Build
- Push to the `main` branch, OR
- Manually trigger via Actions tab → "Build APK" → "Run workflow"

### 3. Download APK
- Go to: https://github.com/krishna98877/Stremini.ai/actions
- Find the completed build
- Download `stremini-final.apk` from Artifacts

## API Key Details

### GROQ_API_KEY (Required)
- Primary API key for GROQ LLM service
- Get from: https://console.groq.com/keys
- Used in chat and AI inference

### GROQ_API_KEY_2 (Optional)
- Secondary/backup GROQ API key
- Useful if primary key reaches rate limits
- Can be left empty if not needed

### COMPOSIO_CONSUMER_KEY (Optional)
- For Composio integration features
- Only needed if using Composio tools

## Workflow Details

The GitHub Actions workflow (`build.yml`) performs:
1. Checks out code
2. Sets up Java 17 & Flutter environment
3. Caches Gradle dependencies
4. Gets Flutter dependencies
5. Creates `android/local.properties` with secrets
6. Builds release APK with `--dart-define` injections
7. Renames and uploads artifact (retained 30 days)

## Local Development

To build locally with API keys:

```bash
flutter pub get
flutter build apk --release \
  --dart-define=GROQ_API_KEY="your_groq_key_here" \
  --dart-define=GROQ_API_KEY_2="your_secondary_key_here"
```

Or add keys to `android/local.properties`:
```properties
groq.api.key=your_groq_key_here
groq.api.key.secondary=your_secondary_key_here
```

## Troubleshooting

**Build fails with "API key not found"**
- Check secrets are correctly added in GitHub Settings
- Verify secret names match exactly (case-sensitive)

**"Authentication failed" error**
- Regenerate keys at https://console.groq.com/keys
- Update the GitHub secret with new key

**APK download not available**
- Build may still be in progress
- Check the Actions tab for build status
- Artifacts are kept for 30 days

## Security Notes

- API keys are stored securely in GitHub Secrets
- Keys are never logged or exposed in build output
- Each push to main triggers a new build
- Artifact retention is set to 30 days
