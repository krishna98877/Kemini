# Fix: Correct import path for GroqClient in chat_provider.dart

## Issue
Build failed with error:
```
lib/providers/chat_provider.dart:10:8: Error: Error when reading 'lib/features/chat/data/groq_client.dart': No such file or directory
```

## Root Cause
`chat_provider.dart` imports GroqClient from wrong path:
```dart
import '../features/chat/data/groq_client.dart';  // ❌ WRONG - file is in services/
```

Actual location: `lib/services/groq_client.dart`

## Fix
Update line 10 in `chat_provider.dart`:

```dart
import '../services/groq_client.dart';  // ✅ CORRECT
```

This resolves the missing file error and allows compilation to proceed.
