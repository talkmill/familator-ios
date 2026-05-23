# Familator iOS

## Worktree setup

After creating a new git worktree, copy `Config.xcconfig` from the main repo root into the worktree:

```
cp /Users/talkmill/programming/familator-ios/Config.xcconfig <worktree-path>/Config.xcconfig
```

This file is gitignored and contains Supabase/Google credentials needed to build.

## Tests

```
xcodebuild test -project Familator.xcodeproj -scheme Familator -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -quiet
```
