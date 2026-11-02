/// Rewarded-ad boundary. The game only asks "did the player earn the reward?".
abstract class AdService {
  Future<bool> showRewarded();
}

/// PLACEHOLDER: no real ad network yet. Pretends an ad played for one second.
/// Replace with a real implementation (e.g. AdMob) before release.
class StubAdService implements AdService {
  @override
  Future<bool> showRewarded() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return true;
  }
}
