#if WITH_FIX
using System.Runtime.InteropServices;
using Microsoft.Maui.Controls.Handlers.Compatibility;
using Microsoft.Maui.Controls.Platform.Compatibility;
using ObjCRuntime;
using UIKit;

namespace ShellTabRailRepro;

// App-side workaround, built only with -p:DefineConstants=WITH_FIX.
public class FixedShellRenderer : ShellRenderer
{
    protected override IShellItemRenderer CreateShellItemRenderer(ShellItem item)
        => new TraitFixShellItemRenderer(this) { ShellItem = item };
}

// ShellItemRenderer.TraitCollectionDidChange never calls UITabBarController's implementation.
// On iOS 27 that is where UIKit re-evaluates how many tabs fit before More, so after a size class
// change (e.g. folding a foldable iPhone) the bar keeps every tab and the rail collapses.
public class TraitFixShellItemRenderer : ShellItemRenderer
{
    [StructLayout(LayoutKind.Sequential)]
    struct ObjCSuper
    {
        public IntPtr Receiver;
        public IntPtr SuperClass;
    }

    [DllImport("/usr/lib/libobjc.dylib", EntryPoint = "objc_msgSendSuper")]
    static extern void MsgSendSuper(ref ObjCSuper super, IntPtr selector, IntPtr arg);

    static readonly IntPtr TabBarControllerClass = Class.GetHandle(typeof(UITabBarController));
    static readonly IntPtr TraitCollectionDidChangeSelector = Selector.GetHandle("traitCollectionDidChange:");

    public TraitFixShellItemRenderer(IShellContext context) : base(context) { }

    public override void TraitCollectionDidChange(UITraitCollection previousTraitCollection)
    {
        // UITabBarController's own implementation; a C# base call only reaches ShellItemRenderer's override
        var super = new ObjCSuper { Receiver = Handle, SuperClass = TabBarControllerClass };
        MsgSendSuper(ref super, TraitCollectionDidChangeSelector, previousTraitCollection?.Handle ?? IntPtr.Zero);

        base.TraitCollectionDidChange(previousTraitCollection);

        // UIKit's re-evaluation resets this, which adds an Edit button to the More page; Shell hides it
        if (CustomizableViewControllers?.Length > 0)
            CustomizableViewControllers = Array.Empty<UIViewController>();
    }
}
#endif
