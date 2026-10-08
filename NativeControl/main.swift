import UIKit

let symbols = ["newspaper", "video", "calendar", "gearshape", "person.badge.plus", "map", "person.text.rectangle", "info.circle"]
let titles = ["News", "Videos", "Events", "Settings", "Join", "Near You", "Voting", "About"]
let args = ProcessInfo.processInfo.arguments
let useTabAPI = args.contains("-uitab")

// -nosuper mimics MAUI ShellItemRenderer: overrides traitCollectionDidChange without calling super
// -images mimics MAUI ShellItemRenderer.TraitCollectionDidChange: on a vertical size class change, every
// tabBar.items[i].image (More's included) is replaced by a re-rendered bitmap (18 pt compact / 25 pt regular)
func resized(_ image: UIImage?, regular: Bool) -> UIImage? {
    guard let image = image else { return nil }
    let side: CGFloat = regular ? 25 : 18
    let size = CGSize(width: side, height: side)
    return UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
}
class NoSuperTabBarController: UITabBarController {
    func st(_ tag: String) -> String {
        return "TABTEST T \(tag): items=\(tabBar.items?.count ?? -1) cust=\(customizableViewControllers?.count ?? -1) bounds=\(NSCoder.string(for: view.bounds.size)) tabbar=\(NSCoder.string(for: tabBar.bounds.size)) h=\(traitCollection.horizontalSizeClass.rawValue) v=\(traitCollection.verticalSizeClass.rawValue)"
    }
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        NSLog("%@", st("willTransition to \(NSCoder.string(for: size))"))
        super.viewWillTransition(to: size, with: coordinator)
        NSLog("%@", st("willTransition after super"))
        coordinator.animate(alongsideTransition: { _ in NSLog("%@", self.st("transition animate")) }, completion: { _ in NSLog("%@", self.st("transition complete")) })
    }
    override func viewWillLayoutSubviews() { NSLog("%@", st("willLayout")); super.viewWillLayoutSubviews() }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); NSLog("%@", st("didLayout")) }
    override func setViewControllers(_ vcs: [UIViewController]?, animated: Bool) {
        NSLog("%@", st("setViewControllers n=\(vcs?.count ?? -1) animated=\(animated)"))
        super.setViewControllers(vcs, animated: animated)
    }
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        NSLog("%@", st("traitChange from h=\(previous?.horizontalSizeClass.rawValue ?? -1) v=\(previous?.verticalSizeClass.rawValue ?? -1)"))
        if !args.contains("-nosuper") { super.traitCollectionDidChange(previous) }
        NSLog("TabTest traitCollectionDidChange v %ld -> %ld", previous?.verticalSizeClass.rawValue ?? -1, traitCollection.verticalSizeClass.rawValue)
        if args.contains("-images"), previous?.verticalSizeClass != traitCollection.verticalSizeClass {
            let regular = traitCollection.verticalSizeClass == .regular
            for item in tabBar.items ?? [] { item.image = resized(item.image, regular: regular) }
            NSLog("TabTest replaced %ld item images", tabBar.items?.count ?? -1)
        }
    }
}

// -container mimics MAUI ShellRenderer: tab bar controller is a child VC whose view frame is set only in the
// parent's viewDidLayoutSubviews (no autoresizing mask). -container-auto: same, but with an autoresizing mask.
class ContainerVC: UIViewController {
    let child: UIViewController
    let auto: Bool
    init(_ c: UIViewController, auto: Bool) { child = c; self.auto = auto; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(child)
        view.addSubview(child.view)
        view.sendSubviewToBack(child.view)
        child.view.frame = view.bounds
        child.view.autoresizingMask = auto ? [.flexibleWidth, .flexibleHeight] : []
        child.didMove(toParent: self)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        child.view.frame = view.bounds
    }
}

func page(_ i: Int) -> UIViewController {
    let vc = UIViewController()
    vc.view.backgroundColor = .systemBackground
    let label = UILabel()
    label.text = "\(titles[i])  [\(useTabAPI ? "UITab API" : "viewControllers API")]"
    label.translatesAutoresizingMaskIntoConstraints = false
    vc.view.addSubview(label)
    NSLayoutConstraint.activate([label.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
                                 label.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor)])
    return vc
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        let tbc = (args.contains("-nosuper") || args.contains("-images") || args.contains("-trace")) ? NoSuperTabBarController() : UITabBarController()
        if useTabAPI {
            tbc.tabs = titles.indices.map { i in
                UITab(title: titles[i], image: UIImage(systemName: symbols[i]), identifier: titles[i]) { _ in page(i) }
            }
        } else {
            tbc.viewControllers = titles.indices.map { i in
                let vc: UIViewController = args.contains("-navs") ? UINavigationController(rootViewController: page(i)) : page(i)
                vc.tabBarItem = UITabBarItem(title: titles[i], image: UIImage(systemName: symbols[i]), tag: i)
                return vc
            }
            if ProcessInfo.processInfo.arguments.contains("-mauilike") { tbc.customizableViewControllers = [] }
        }
        NSLog("TabTest launch: args=%@ api=%@ hSizeClass=%ld bounds=%@", args.dropFirst().joined(separator: " "), useTabAPI ? "UITab" : "viewControllers",
              ws.traitCollection.horizontalSizeClass.rawValue, NSCoder.string(for: ws.coordinateSpace.bounds))
if args.contains("-font") {
    // same as DiEM25 CustomTabBarAppearanceTracker: 12 pt medium titles via the appearance proxy
    UITabBarItem.appearance().setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 12, weight: .medium)], for: .normal)
    UITabBarItem.appearance().setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 12, weight: .medium)], for: .selected)
}
let w = UIWindow(windowScene: ws)
        if args.contains("-container") { w.rootViewController = ContainerVC(tbc, auto: false) }
        else if args.contains("-container-auto") { w.rootViewController = ContainerVC(tbc, auto: true) }
        else { w.rootViewController = tbc }
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            NSLog("TABTEST dump: items=%ld vcs=%ld cust=%ld sel=%ld hSize=%ld vSize=%ld bounds=%@", tbc.tabBar.items?.count ?? -1, tbc.viewControllers?.count ?? -1,
                  tbc.customizableViewControllers?.count ?? -1, tbc.selectedIndex, tbc.traitCollection.horizontalSizeClass.rawValue,
                  tbc.traitCollection.verticalSizeClass.rawValue, NSCoder.string(for: tbc.view.bounds.size))
        }
        w.makeKeyAndVisible()
        window = w
    }
    func windowScene(_ ws: UIWindowScene, didUpdate previousCoordinateSpace: UICoordinateSpace,
                     interfaceOrientation: UIInterfaceOrientation, traitCollection previous: UITraitCollection) {
        NSLog("TabTest update: hSizeClass %ld -> %ld bounds=%@", previous.horizontalSizeClass.rawValue,
              ws.traitCollection.horizontalSizeClass.rawValue, NSCoder.string(for: ws.coordinateSpace.bounds))
    }
}

class AppDelegate: UIResponder, UIApplicationDelegate {}

UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self))
