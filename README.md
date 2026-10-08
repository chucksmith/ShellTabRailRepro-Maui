# ShellTabRailRepro

Minimal repro for a .NET MAUI Shell bug on iOS 27: after a size class change (folding the iPhone Duo simulator), the Shell tab bar never goes back to using More. In folded landscape the 8-tab rail then overflows and iOS collapses it into a single button that can't be used.

## Cause

`ShellItemRenderer.TraitCollectionDidChange` (`src/Controls/src/Core/Compatibility/Handlers/Shell/iOS/ShellItemRenderer.cs`, added in dotnet/maui#29093) overrides `traitCollectionDidChange:` and never calls `base`. On iOS 27, `UITabBarController`'s own implementation is where UIKit re-evaluates how many tabs fit before More, so that re-evaluation never happens. The `maxTabs = 5` constants in the same file only drive `IsInMoreTab` (push/pop routing) and are not involved.

## Contents

- `ShellTabRailRepro/`: stock `dotnet new maui` app with an 8-tab `TabBar`, plus the UIScene manifest and `SceneDelegate` that iOS 27 requires (without them the template app aborts at launch). Microsoft.Maui.Controls 10.0.110.
- `ShellTabRailRepro/Platforms/iOS/TraitFixShellItemRenderer.cs`: app-side workaround, compiled only with `WITH_FIX`.
- `NativeControl/`: plain UIKit app with the same 8 tabs, for comparison. `-nosuper` adds a `traitCollectionDidChange` override that skips `super`, as MAUI's does, and reproduces the bug natively.

## Environment

Xcode 27.1 RC (27A9275), iOS 27.1 simulator runtime 24A94232, "iPhone Duo" device type. .NET for iOS 26.5 needs `-p:ValidateXcodeVersion=false` to build with Xcode 27.1.

## Steps

```sh
export DEVELOPER_DIR=/Applications/Xcode-27.1.0-Release.Candidate.app/Contents/Developer
U=<iPhone Duo UDID>

cd ShellTabRailRepro
dotnet build -f net10.0-ios -p:RuntimeIdentifier=iossimulator-arm64 -p:ValidateXcodeVersion=false
xcrun simctl install $U bin/Debug/net10.0-ios/iossimulator-arm64/ShellTabRailRepro.app
```

1. Fold the device (Device Hub, or `hinge -d $U close` from https://github.com/artemnovichkov/hinge) and rotate it to landscape in Device Hub.
2. Launch the app: the rail shows 4 tabs + More.
3. Unfold, then fold again (`hinge -d $U open`, `hinge -d $U close`): the rail collapses into one button. `tabBar.items` now holds all 8 tabs.

With `-p:DefineConstants=WITH_FIX` the rail comes back as 4 tabs + More after every refold (10/10 runs).

Native control:

```sh
cd NativeControl
mkdir -p TabTest.app && cp Info.plist TabTest.app/
xcrun --sdk iphonesimulator swiftc -module-name TabTest -target arm64-apple-ios18.0-simulator main.swift -o TabTest.app/TabTest
codesign -s - TabTest.app && xcrun simctl install $U TabTest.app
xcrun simctl launch --terminate-running-process $U at.chuck.tabtest            # always 4 + More after refold
xcrun simctl launch --terminate-running-process $U at.chuck.tabtest -nosuper   # same bug as MAUI
```

## Suggested fix

In `ShellItemRenderer.TraitCollectionDidChange`, call `base.TraitCollectionDidChange(previousTraitCollection)` first, then restore `CustomizableViewControllers = Array.Empty<UIViewController>()` (UIKit's re-evaluation resets it, which adds an Edit button to the More page).
