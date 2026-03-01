# Sparkle + GitHub Releases Setup Guide

This guide will help you set up automated updates for BF6 Stats Tracker using Sparkle and GitHub Releases.

## Quick Summary

Your app is already configured with Sparkle. You just need to:
1. Generate signing keys
2. Set up GitHub Secrets  
3. Activate the release workflow
4. Create your first release

## Step 1: Generate Sparkle Signing Keys

```bash
# Download Sparkle tools
curl -L -o Sparkle.tar.xz https://github.com/sparkle-project/Sparkle/releases/download/2.8.1/Sparkle-2.8.1.tar.xz
tar -xf Sparkle.tar.xz

# Generate keys
./bin/generate_keys
```

Save the output:
- **Public Key**: Already in your Info.plist ✓
- **Private Key**: Add to GitHub Secrets (next step)

## Step 2: Set Up GitHub Secrets

Go to: https://github.com/MikeManzo/BF6StatsTracker/settings/secrets/actions

Add these 6 secrets:

| Secret Name | How to Get It |
|------------|---------------|
| `SPARKLE_PRIVATE_KEY` | Private key from `generate_keys` above |
| `CERTIFICATES_P12` | Export Developer ID cert from Keychain → convert to base64: `base64 -i cert.p12 \| pbcopy` |
| `CERTIFICATES_PASSWORD` | Password used when exporting the .p12 |
| `APPLE_ID` | Your Apple ID email |
| `APPLE_ID_PASSWORD` | App-specific password from https://appleid.apple.com |
| `TEAM_ID` | 10-char ID from https://developer.apple.com/account |

## Step 3: Activate Release Workflow

```bash
cd /Users/mike/Documents/Dev/BF6StatsTracker

# Activate the workflow
mv .github/workflows/release.yml.example .github/workflows/release.yml

# Commit and push
git add .github/workflows/release.yml
git commit -m "Add automated release workflow"
git push
```

## Step 4: Create Your First Release

```bash
# Update version if needed
./Scripts/increment_build.sh

# Commit your changes
git add .
git commit -m "Prepare for v1.0.0 release"
git push

# Create and push tag
git tag v1.0.0
git push origin v1.0.0
```

The GitHub Actions workflow will automatically:
- ✓ Build your app
- ✓ Code sign with Developer ID
- ✓ Notarize with Apple
- ✓ Create DMG
- ✓ Generate appcast.xml
- ✓ Create GitHub Release
- ✓ Make updates available

## That's It!

Users will now see automatic update notifications in your app.

## Future Releases

Just tag and push:

```bash
git tag v1.0.1
git push origin v1.0.1
```

GitHub Actions handles everything else automatically.

## Troubleshooting

**Build fails?**
- Check all 6 GitHub Secrets are set correctly
- Verify certificate is valid: `security find-identity -p codesigning -v`

**Notarization fails?**
- Use app-specific password, not regular Apple ID password
- Generate at: https://appleid.apple.com → Security → App-Specific Passwords

**Updates don't appear?**
- Check appcast URL is accessible: https://raw.githubusercontent.com/MikeManzo/BF6StatsTracker/main/appcast.xml
- Verify new version number is higher than current
- Check Console.app for Sparkle debug logs

## Support Links

- Sparkle Docs: https://sparkle-project.org/documentation/
- Your release workflow: .github/workflows/release.yml.example
- GitHub Releases: https://github.com/MikeManzo/BF6StatsTracker/releases
