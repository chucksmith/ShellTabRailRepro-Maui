using Foundation;

namespace ShellTabRailRepro;

// iOS 27 requires the UIScene lifecycle; without it the app aborts at launch.
[Register("SceneDelegate")]
public class SceneDelegate : MauiUISceneDelegate
{
}
