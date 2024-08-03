import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart' hide Image;
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:vibration/vibration.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'story.dart';

final currentStoryNodeProvider = StateProvider<String>((ref) => 'start');
final vibrationEnabledProvider = StateProvider<bool>((ref) => true);
final textAnimationCompleteProvider = StateProvider<bool>((ref) => false);
final backgroundOpacityProvider = StateProvider<double>((ref) => 0.5);

class StoryPage extends ConsumerStatefulWidget {
  final Map<String, StoryNode> storyMap;
  final VoidCallback onExit;

  const StoryPage({Key? key, required this.storyMap, required this.onExit})
      : super(key: key);

  @override
  _StoryPageState createState() => _StoryPageState();
}

class _StoryPageState extends ConsumerState<StoryPage> {
  late AudioPlayer _audioPlayer;
  int _nodeChanges = 0;
  final double _volume = 0.3;
  final InAppReview inAppReview = InAppReview.instance;
  final int _vibrationStrength = 64;

  @override
  void initState() {
    super.initState();
    _initAudio();
    print("StoryPage initialized");
  }

  Future<void> _initAudio() async {
    _audioPlayer = AudioPlayer();
    try {
      await _audioPlayer.setAsset('assets/background_music.mp3');
      await _audioPlayer.setLoopMode(LoopMode.all);
      await _audioPlayer.setVolume(_volume);
      await _audioPlayer.play();
      print("Audio initialized successfully");
    } catch (e) {
      print("Error initializing audio: $e");
    }
  }

  Future<String> _getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name') ?? 'Adventurer';
  }

  Future<void> _requestReview() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool hasRated = prefs.getBool('has_rated') ?? false;
      final int lastRatingPrompt = prefs.getInt('last_rating_prompt') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (!hasRated && now - lastRatingPrompt > 432000000) {
        // 5 days in milliseconds
        if (await inAppReview.isAvailable()) {
          final userName = await _getUserName();
          _showCustomReviewDialog(userName);
          await prefs.setInt('last_rating_prompt', now);
          print("Review requested for user: $userName");
        }
      }
    } catch (e) {
      print("Error requesting review: $e");
    }
  }

  Future<void> _showCustomReviewDialog(String userName) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Hello, $userName!'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('We hope you\'re enjoying your adventure so far!'),
                SizedBox(height: 10),
                Text('Would you like to share your experience and rate our app?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Not Now'),
              onPressed: () {
                Navigator.of(context).pop();
                print("User declined to rate");
              },
            ),
            TextButton(
              child: Text('Rate Now'),
              onPressed: () async {
                Navigator.of(context).pop();
                await inAppReview.requestReview();
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('has_rated', true);
                print("User agreed to rate");
              },
            ),
          ],
        );
      },
    );
  }

  void _onNodeChange() {
    _nodeChanges++;
    if (_nodeChanges % 10 == 0) {
      _requestReview();
    }
    ref.read(textAnimationCompleteProvider.notifier).state = false;
    print("Node changed to ${ref.read(currentStoryNodeProvider)}, textAnimationComplete set to false");
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    print("StoryPage disposed");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentNode = ref.watch(currentStoryNodeProvider);
    final storyNode = widget.storyMap[currentNode] ?? widget.storyMap['start']!;
    final backgroundOpacity = ref.watch(backgroundOpacityProvider);

    print("Building StoryPage with currentNode: $currentNode");

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) {
          return;
        }
        widget.onExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Story'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: widget.onExit,
          ),
          actions: [
            Builder(
              builder: (context) => IconButton(
                icon: Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
            ),
          ],
        ),
        endDrawer: _buildDrawer(),
        body: Stack(
          children: [
            Opacity(
              opacity: backgroundOpacity,
              child: Image.asset(
                'assets/background_image.jpg',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildStoryText(storyNode),
                    _buildAnimation(storyNode),
                    _buildChoices(storyNode),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    final vibrationEnabled = ref.watch(vibrationEnabledProvider);
    final backgroundOpacity = ref.watch(backgroundOpacityProvider);
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text('Menu'),
            ),
            ListTile(
              title: Text('Main Menu'),
              onTap: () {
                Navigator.pop(context);
                widget.onExit();
                print("Exiting to main menu");
              },
            ),
            SwitchListTile(
              title: Text('Vibration'),
              value: vibrationEnabled,
              onChanged: (bool value) {
                ref.read(vibrationEnabledProvider.notifier).state = value;
                Navigator.pop(context);
                print("Vibration setting changed to: $value");
              },
            ),
            ListTile(
              title: Text('Background Opacity'),
              subtitle: Slider(
                value: backgroundOpacity,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                onChanged: (double value) {
                  ref.read(backgroundOpacityProvider.notifier).state = value;
                  print("Background opacity changed to: $value");
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryText(StoryNode storyNode) {
    return Container(
      padding: EdgeInsets.all(16),
      child: AnimatedTextKit(
        animatedTexts: [
          TypewriterAnimatedText(
            storyNode.text,
            textStyle: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
            speed: Duration(milliseconds: 50),
          ),
        ],
        totalRepeatCount: 1,
        onFinished: () {
          ref.read(textAnimationCompleteProvider.notifier).state = true;
          print("Text animation completed");
        },
      ),
    );
  }

  Widget _buildAnimation(StoryNode storyNode) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      child: RiveAnimation.asset(
        'assets/${storyNode.animation}',
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildChoices(StoryNode storyNode) {
    final textAnimationComplete = ref.watch(textAnimationCompleteProvider);
    
    return textAnimationComplete
      ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: storyNode.choices.map((choice) => 
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: AnimatedButton(
                  text: choice.text,
                  onPressed: () {
                    ref.read(currentStoryNodeProvider.notifier).state = choice.nextNode;
                    _onNodeChange();
                  },
                  vibrationStrength: _vibrationStrength,
                ),
              ),
            )
          ).toList(),
        )
      : SizedBox.shrink();
  }
}

class AnimatedButton extends ConsumerStatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final int vibrationStrength;

  const AnimatedButton({
    Key? key,
    required this.text,
    required this.onPressed,
    required this.vibrationStrength,
  }) : super(key: key);

  @override
  _AnimatedButtonState createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends ConsumerState<AnimatedButton> {
  late RiveAnimationController _controller;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = OneShotAnimation(
      'button_animation',
      autoplay: false,
      onStop: () {
        setState(() {
          _isAnimating = false;
        });
        widget.onPressed();
      },
    );
    print("AnimatedButton initialized");
  }

  @override
  void dispose() {
    _controller.dispose();
    print("AnimatedButton disposed");
    super.dispose();
  }

  Future<void> _startAnimation() async {
    final vibrationEnabled = ref.read(vibrationEnabledProvider);
    if (!_isAnimating) {
      setState(() {
        _isAnimating = true;
      });
      _controller.isActive = true;
      print("Button animation started");
      if (vibrationEnabled) {
        try {
          if (await Vibration.hasVibrator() ?? false) {
            Vibration.vibrate(
                duration: 200, amplitude: widget.vibrationStrength);
            print("Vibration triggered");
          }
        } catch (e) {
          print("Error triggering vibration: $e");
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _startAnimation,
      child: Container(
        height: 50,
        child: Stack(
          children: [
            RiveAnimation.asset(
              'assets/button_animation.riv',
              controllers: [_controller],
              fit: BoxFit.cover,
            ),
            Center(
              child: Text(
                widget.text,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
