import MetalKit

public protocol Interpolatable {
    static func lerp(_ l: Self, _ r: Self, _ k: Float) -> Self
}

extension Float: Interpolatable {
    public static func lerp(_ l: Float, _ r: Float, _ k: Float) -> Float {
        l + k * (r - l)
    }
}

class MetalView: MTKView, MTKViewDelegate {
    var uniforms = Uniforms()
    var commandQueue: MTLCommandQueue

    var shapePipelineState: MTLComputePipelineState!
    var blurPipelineState: MTLComputePipelineState!
    var aberrationPipelineState: MTLComputePipelineState!
    var backTexture: MTLTexture!

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override init(frame frameRect: CGRect, device: (any MTLDevice)?) {
        self.commandQueue = device!.makeCommandQueue()!
        super.init(frame: frameRect, device: device)
        self.shapePipelineState = self.makePipelineState("computeShape")
        self.blurPipelineState = self.makePipelineState("blurCompute")
        self.aberrationPipelineState = self.makePipelineState("aberrationCompute")

        self.delegate = self
        self.framebufferOnly = false

//        Task {
//            try await Task.sleep(for: .seconds(1))
//            startAnimation()
//        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        uniforms.aspect = Float(size.width / size.height)
        uniforms.rad = 0.35
        uniforms.circleMul = 1
        self.backTexture = self.makeTexture(size: size)
    }

// MARK: MetalView.swift
    var currentShapeIsCircle: Bool = true
    var animationStartTime: Float = -Float.greatestFiniteMagnitude // initial low value
    var animationDuration: Float = 1 // 1 second

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        swapShape()
    }

    func startAnimation() {
        animationStartTime = uniforms.time
    }

    func swapShape() {
        currentShapeIsCircle.toggle()
        startAnimation()
    }

    func draw(in view: MTKView) {
        uniforms.time += 1 / Float(preferredFramesPerSecond)

        let deltaTime = uniforms.time - animationStartTime
        let progress = Float(deltaTime / animationDuration)
        if progress <= 1 {
            let fromMul = Float.lerp(1, 0, progress)
            let toMul = Float.lerp(0, 1, progress)
            if currentShapeIsCircle {
                uniforms.circleMul = toMul
                uniforms.fireMul = fromMul
            } else {
                uniforms.circleMul = fromMul
                uniforms.fireMul = toMul
            }
//            print("•", Int(uniforms.circleMul * 100), Int(uniforms.fireMul * 100))
        }

        let buf = commandQueue.makeCommandBuffer()!
        let drawable = view.currentDrawable!

        let size = MTLSize(width: drawable.texture.width, height: drawable.texture.height, depth: 1)
        let width = shapePipelineState.threadExecutionWidth
        let height = shapePipelineState.maxTotalThreadsPerThreadgroup / width
        let threadsPerGroup = MTLSizeMake(width, height, 1)

        let shapeCommand = buf.makeComputeCommandEncoder()!
        shapeCommand.setComputePipelineState(shapePipelineState)
        shapeCommand.setBytes(&uniforms, length: MemoryLayout.size(ofValue: uniforms), index: 0)
        shapeCommand.setTexture(drawable.texture, index: 0)
        shapeCommand.dispatchThreads(size, threadsPerThreadgroup: threadsPerGroup)
        shapeCommand.endEncoding()

        let blurCommand = buf.makeComputeCommandEncoder()!
        blurCommand.setComputePipelineState(blurPipelineState)
        blurCommand.setTexture(backTexture, index: 0)
        blurCommand.setTexture(drawable.texture, index: 1)
        blurCommand.dispatchThreads(size, threadsPerThreadgroup: threadsPerGroup)
        blurCommand.endEncoding()

        let aberrationCommand = buf.makeComputeCommandEncoder()!
        aberrationCommand.setComputePipelineState(aberrationPipelineState)
        aberrationCommand.setTexture(drawable.texture, index: 0)
        aberrationCommand.setTexture(backTexture, index: 1)
        aberrationCommand.dispatchThreads(size, threadsPerThreadgroup: threadsPerGroup)
        aberrationCommand.endEncoding()

        buf.present(drawable)
        buf.commit()
    }

    func makePipelineState(_ functionName: String) -> MTLComputePipelineState {
        let library = device!.makeDefaultLibrary()!
        let function = library.makeFunction(name: functionName)!
        return try! device!.makeComputePipelineState(function: function)
    }

    func makeTexture(size: CGSize) -> MTLTexture {
        let desc = MTLTextureDescriptor()
        desc.width = Int(size.width)
        desc.height = Int(size.height)
        desc.usage = [.shaderRead, .shaderWrite]
        desc.storageMode = .private
        desc.pixelFormat = self.colorPixelFormat

        return device!.makeTexture(descriptor: desc)!
    }
}
