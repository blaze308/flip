# Optimistic UI Implementation Guide

This guide explains how to implement the optimistic UI strategy in your Flutter app for different types of backend operations.

## Strategy Overview

### Quick Actions (Like, Bookmark, Share, Follow)

- **Immediately update UI** when user taps
- **Send API request in background**
- **Revert UI if API fails**
- **Disable button during sync** (prevent double-tap)

### Slow Actions (OTP, Authentication, File Upload)

- **Show loading state** immediately
- **Notify user that operation is in progress**
- **Disable button to prevent double-tap**
- **Show success/error feedback**

## Implementation Examples

### 1. Quick Actions - Post Like

```dart
class PostWidget extends StatefulWidget {
  final PostModel post;
  const PostWidget({required this.post});
}

class _PostWidgetState extends State<PostWidget> with OptimisticUIMixin {
  late PostModel _post;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  Future<void> _toggleLike() async {
    final originalIsLiked = _post.isLiked;
    final originalLikes = _post.likes;

    await performOptimisticAction(
      buttonId: 'like_${_post.id}',
      optimisticUpdate: () {
        // Immediately update UI
        setState(() {
          _post = _post.copyWith(
            isLiked: !originalIsLiked,
            likes: originalIsLiked ? originalLikes - 1 : originalLikes + 1,
          );
        });
      },
      apiCall: () async {
        try {
          final result = await PostService.toggleLike(_post.id);
          return result.success;
        } catch (e) {
          return false;
        }
      },
      rollback: () {
        // Revert UI change if API fails
        setState(() {
          _post = _post.copyWith(
            isLiked: originalIsLiked,
            likes: originalLikes,
          );
        });
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update like: $error')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return OptimisticButton(
      onPressed: _toggleLike,
      isActive: _post.isLiked,
      activeColor: Colors.red,
      inactiveColor: Colors.grey,
      isDisabled: isButtonDisabled('like_${_post.id}'),
      child: Row(
        children: [
          Icon(_post.isLiked ? Icons.favorite : Icons.favorite_border),
          Text('${_post.likes}'),
        ],
      ),
    );
  }
}
```

### 2. Slow Actions - OTP Verification

```dart
class OtpScreen extends StatefulWidget {
  @override
  _OtpScreenState createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  ButtonState _verifyButtonState = const ButtonState();
  String _otpCode = '';

  Future<void> _verifyOtp() async {
    if (_otpCode.length != 6) {
      setState(() {
        _verifyButtonState = ButtonStateExtension.error(
          message: 'Please enter complete OTP code',
        );
      });
      return;
    }

    setState(() {
      _verifyButtonState = ButtonStateExtension.loading(
        message: 'Verifying OTP...',
      );
    });

    try {
      final result = await AuthService.verifyOtp(_otpCode);

      if (result.success) {
        setState(() {
          _verifyButtonState = ButtonStateExtension.success(
            message: 'Verification successful!',
          );
        });

        // Navigate after showing success
        Future.delayed(Duration(milliseconds: 500), () {
          Navigator.pushReplacementNamed(context, '/home');
        });
      } else {
        setState(() {
          _verifyButtonState = ButtonStateExtension.error(
            message: 'Invalid OTP. Please try again.',
          );
        });
      }
    } catch (e) {
      setState(() {
        _verifyButtonState = ButtonStateExtension.error(
          message: 'Verification failed. Please try again.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // OTP input fields here

        AuthButton(
          text: 'Verify',
          onPressed: _verifyOtp,
          buttonState: _verifyButtonState,
          isPrimary: true,
        ),
      ],
    );
  }
}
```

### 3. Follow/Unfollow User

```dart
class UserProfileWidget extends StatefulWidget {
  final UserModel user;
  const UserProfileWidget({required this.user});
}

class _UserProfileWidgetState extends State<UserProfileWidget> with OptimisticUIMixin {
  late bool _isFollowing;
  late int _followersCount;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.user.isFollowing;
    _followersCount = widget.user.followersCount;
  }

  Future<void> _toggleFollow() async {
    final originalIsFollowing = _isFollowing;
    final originalFollowersCount = _followersCount;

    await performOptimisticAction(
      buttonId: 'follow_${widget.user.id}',
      optimisticUpdate: () {
        setState(() {
          _isFollowing = !originalIsFollowing;
          _followersCount = originalIsFollowing
              ? originalFollowersCount - 1
              : originalFollowersCount + 1;
        });
      },
      apiCall: () async {
        try {
          final result = await PostService.toggleFollow(widget.user.id);
          return result.success;
        } catch (e) {
          return false;
        }
      },
      rollback: () {
        setState(() {
          _isFollowing = originalIsFollowing;
          _followersCount = originalFollowersCount;
        });
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update follow status')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LoadingButton(
      text: _isFollowing ? 'Unfollow' : 'Follow',
      onPressed: _toggleFollow,
      buttonState: ButtonState(
        isDisabled: isButtonDisabled('follow_${widget.user.id}'),
      ),
      backgroundColor: _isFollowing ? Colors.grey : Colors.blue,
    );
  }
}
```

## Available Widgets

### OptimisticButton

For quick actions like like, bookmark, share:

- Shows active/inactive states
- Handles disabled state during API calls
- Provides visual feedback

### LoadingButton

For general purpose buttons with loading states:

- Shows loading spinner
- Customizable loading text
- Handles disabled state

### AuthButton

Specialized for authentication flows:

- Shows loading, success, error states
- Displays status messages
- Optimized for OTP and login screens

## Best Practices

### 1. Always Handle Rollback

```dart
// ✅ Good - Always provide rollback
await performOptimisticAction(
  optimisticUpdate: () => updateUI(),
  rollback: () => revertUI(),
  // ...
);

// ❌ Bad - No rollback handling
setState(() => updateUI());
apiCall(); // What if this fails?
```

### 2. Provide User Feedback

```dart
// ✅ Good - Show error to user
onError: (error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Operation failed: $error')),
  );
},

// ❌ Bad - Silent failure
onError: (error) {
  // User has no idea what happened
},
```

### 3. Use Appropriate Button Types

```dart
// ✅ Good - Use OptimisticButton for quick actions
OptimisticButton(
  onPressed: _toggleLike,
  isActive: post.isLiked,
  // ...
);

// ✅ Good - Use AuthButton for auth flows
AuthButton(
  text: 'Send OTP',
  buttonState: _sendButtonState,
  // ...
);
```

### 4. Prevent Double-Tap

```dart
// ✅ Good - Button automatically disabled during operation
OptimisticButton(
  isDisabled: isButtonDisabled('like_${post.id}'),
  // ...
);

// ❌ Bad - User can tap multiple times
GestureDetector(
  onTap: _toggleLike, // No protection against double-tap
  // ...
);
```

## Error Handling

### Network Errors

- Automatically rolled back by OptimisticUIService
- Show user-friendly error messages
- Allow retry if appropriate

### Validation Errors

- Show immediately without API call
- Use ButtonStateExtension.error()
- Clear error after timeout

### Success States

- Show brief success feedback
- Navigate or update UI as needed
- Clear success state automatically

## Testing

### Unit Tests

```dart
testWidgets('should rollback on API failure', (tester) async {
  // Mock API to fail
  when(mockPostService.toggleLike(any)).thenThrow(Exception());

  // Tap like button
  await tester.tap(find.byKey(Key('like_button')));
  await tester.pump();

  // Verify UI was updated optimistically
  expect(find.text('1'), findsOneWidget); // Like count increased

  // Wait for API call to fail and rollback
  await tester.pumpAndSettle();

  // Verify UI was rolled back
  expect(find.text('0'), findsOneWidget); // Like count reverted
});
```

### Integration Tests

- Test real network conditions
- Verify rollback behavior
- Test button disabled states
- Verify error messages

This implementation provides a smooth, responsive user experience while maintaining data consistency and providing appropriate feedback for different types of operations.
