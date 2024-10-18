import UIKit
import Metal

class ViewController: UIViewController {

    let metalView = MetalView(frame: .zero, device: MTLCreateSystemDefaultDevice()!)

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .green
        view.addSubview(metalView)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        metalView.frame = view.bounds
    }

    override var prefersStatusBarHidden: Bool { true }
}

