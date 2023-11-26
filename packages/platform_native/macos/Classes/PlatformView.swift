//
//  platform.view.swift
//  FlutterAlib
//
//  Created by renan jegouzo on 30/10/2023.
//

import AppKit
import FlutterMacOS
import MetalKit

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
class PlatformViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger
    let gpu:GPU = GPU()
    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }
    func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
        return PlatformView(
            frame: CGRect(x: 0, y: 0, width: 16, height: 9),  // view gets a layout event with real frame size
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger,
            gpu:gpu)
    }
    func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
class PlatformView: NSView {
    let gpu:GPU
    let renderer:Renderer
    var view: MTKView?
    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?,
        gpu: GPU
    ) {
        self.gpu = gpu
        self.renderer = Renderer(gpu:gpu,id:viewId)
        super.init(frame: frame)
        view = MTKView(
            frame: CGRect(x: 0, y: 0, width: frame.width, height: frame.height),
            device: gpu.device)
        view!.delegate = renderer
        view!.autoResizeDrawable = true
        view!.colorPixelFormat = .bgra8Unorm
        view!.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        //view!.layer?.isOpaque = false
        super.addSubview(view!)
    }
    required init?(coder: NSCoder) {
        self.gpu = GPU()
        self.renderer = Renderer(gpu:gpu,id:0)
        super.init(coder: coder)
    }
    deinit {
    }
    
    public override func layout() {
        view?.frame = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
        super.layout()
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
class Renderer: NSViewController, MTKViewDelegate {
    var gpu:GPU?
    var id:Int64
    init(gpu:GPU,id:Int64) {
        self.id = id
        self.gpu=gpu
        super.init(nibName: "ViewController", bundle: Bundle.main)
    }
    required init?(coder: NSCoder) {
        self.id = 0
        super.init(coder: coder)
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
    func draw(in view: MTKView) {
        guard let gpu = gpu else { return }
        guard let commandBuffer = gpu.commandQueue.makeCommandBuffer() else { return }
        guard let passDescriptor = view.currentRenderPassDescriptor else { return }
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else { return }
        let da = 3.1414 * 2 / 3
        let a0 = Date().timeIntervalSince1970 + Double(id)
        let a1 = a0 + da
        let a2 = a1 + da
        let vertexData: [Float] = [ Float(cos(a0) * 0.5), Float(sin(a0) * 0.5), 0, 1, 0, 0,
                                    Float(cos(a1) * 0.5), Float(sin(a1) * 0.5), 0, 0, 1, 0,
                                    Float(cos(a2) * 0.5), Float(sin(a2) * 0.5), 0, 0, 0, 1 ]
        encoder.setVertexBytes(vertexData, length: vertexData.count * MemoryLayout<Float>.stride, index: 0)
        encoder.setRenderPipelineState(gpu.pipelineState!)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////

// https://gist.github.com/mayoff/3afb1623bb739caaf499778921711d75
class GPU {
    let device:MTLDevice = MTLCreateSystemDefaultDevice()!
    let commandQueue:MTLCommandQueue
    var pipelineState:MTLRenderPipelineState?
    init() {
        commandQueue = device.makeCommandQueue()!
        let shaders = """
          #include <metal_stdlib>
          using namespace metal;
          struct VertexIn {
              packed_float3 position;
              packed_float3 color;
          };
          struct VertexOut {
              float4 position [[position]];
              float4 color;
          };
          vertex VertexOut vertex_main(device const VertexIn *vertices [[buffer(0)]],
                                       uint vertexId [[vertex_id]]) {
              VertexOut out;
              out.position = float4(vertices[vertexId].position, 1);
              out.color = float4(vertices[vertexId].color, 1);
              return out;
          }
          fragment float4 fragment_main(VertexOut in [[stage_in]]) {
              return in.color;
          }
          """
        do {
            let library = try device.makeLibrary(source: shaders, options: nil)
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertex_main")
            pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragment_main")
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {}
    }
}
