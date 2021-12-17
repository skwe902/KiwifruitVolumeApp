//  Written by Andy K
//  ARDelgeate.swift
//  SwiftUIARKit

// use print() to print to console
// in swift -> function(variable : value/varType)

import Foundation
import ARKit
import UIKit
import Vision

class ARDelegate: NSObject, ARSCNViewDelegate, ObservableObject {
    @Published var message:String = "Starting AR"
    @Published var message2:String = "Tap anywhere on screen to measure volume"
    @Published var message3:String = "Kiwifruit Measurement App"
    
    typealias FinishedRunning = () -> ()
    var depthArray: [[Float32]] = []

    func setARView(_ arView: ARSCNView) {
        self.arView = arView
        let configuration = setupARConfiguration()
        arView.session.run(configuration)
        arView.delegate = self
        arView.scene = SCNScene()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapOnARView))
        arView.addGestureRecognizer(tapGesture)
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panOnARView))
        arView.addGestureRecognizer(panGesture)
    }
    
    func setupARConfiguration() -> ARConfiguration{
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        //if depth measurement is available (lidar)
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth){
            configuration.frameSemantics = .sceneDepth
        }
        return configuration
    }
    
    //MARK: RENDER RGB IMAGE
    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval){
        //this will run once per every frame
        // Get the capture image and the depthmap (which is a cvPixelBuffer) from the current ARFrame
        guard let capturedImage = arView?.session.currentFrame?.capturedImage else { return }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: capturedImage,
                                                        orientation: .leftMirrored, //is this needed for the depth map as well?
                                                        options: [:])
        do {
            try imageRequestHandler.perform([objectDetectionRequest])
        } catch {
            print("Failed to perform image request.")
        }
    }
    
    //MARK: tap / pan screen
    @objc func tapOnARView(sender: UITapGestureRecognizer) {
        //this gets the coordinates of the bounding box when the user taps on screen
        //get the coordinates of the circles in CGPoint(x,y) - centerPoint, upPoint, downPoint, leftPoint, rightPoint
        let locationArray = [centerPoint, upPoint, downPoint, leftPoint, rightPoint]
        for location in locationArray {
            if (location != nil){
                if let result = raycastResult(fromLocation: location!) {
                    addCircle(raycastResult: result)
                }
            }
            else{
                continue
            }
        }
        nodesUpdated()
        processLidarData()
    }
    
    @objc func panOnARView(sender: UIPanGestureRecognizer) {
        guard let arView = arView else { return }
        let location = sender.location(in: arView)
        switch sender.state {
        case .began:
            if let node = nodeAtLocation(location) {
                trackedNode = node
            }
        case .changed:
            if let node = trackedNode {
                if let result = raycastResult(fromLocation: location) {
                    moveNode(node, raycastResult:result)
                }
            }
        default:
            ()
        }
    }
    
    //MARK: LIDAR DATA
    func processLidarData(){
        guard let depthData = arView?.session.currentFrame?.sceneDepth?.depthMap, var cameraIntrinsics = arView?.session.currentFrame?.camera.intrinsics else { return }
        let depthWidth = CVPixelBufferGetWidth(depthData)
        let depthHeight = CVPixelBufferGetHeight(depthData)
        CVPixelBufferLockBaseAddress(depthData, CVPixelBufferLockFlags(rawValue: 0))
        let floatBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(depthData), to: UnsafeMutablePointer<Float32>.self)
        CVPixelBufferUnlockBaseAddress(depthData, CVPixelBufferLockFlags(rawValue: 0))
        
        // Camera-intrinsics units are in full camera-resolution pixels.
        //simd_float3x3(
//            [[1627.7137, 0.0, 0.0], [0.0, 1627.7137, 0.0], [931.7529, 729.14325, 1.0]])
        let depthResolution = simd_float2(x: Float(depthWidth), y: Float(depthHeight))
        let scaleRes = simd_float2(x: Float( (arView?.session.currentFrame?.camera.imageResolution.width)!) / depthResolution.x, y: Float((arView?.session.currentFrame?.camera.imageResolution.height)!) / depthResolution.y)
        //scaleRes = ~7.5 -> to compensate for RGB resolution to lidar resolution
        cameraIntrinsics[0][0] /= scaleRes.x
        cameraIntrinsics[1][1] /= scaleRes.y
        cameraIntrinsics[2][0] /= scaleRes.x
        cameraIntrinsics[2][1] /= scaleRes.y
        //simd_float3x3([[216.78749, 0.0, 0.0], [0.0, 216.78749, 0.0], [126.18921, 96.61844, 1.0]])
        
        if(depthArray.isEmpty){
            for x in 0...depthWidth-1{
                var distancesLine = [Float32]()
                for y in (0...depthHeight-1).reversed(){
                    let distanceAtXYPoint = floatBuffer[y * depthWidth + x]
                    distancesLine.append(distanceAtXYPoint)
                }
                depthArray.append(distancesLine)
            }
            print("The array has finished")
            lidarVolume(cameraIntrinsics: cameraIntrinsics)
        }
        else{
            depthArray.removeAll()
            for x in 0...depthWidth-1{
                var distancesLine = [Float32]()
                for y in (0...depthHeight-1).reversed(){
                    let distanceAtXYPoint = floatBuffer[y * depthWidth + x]
                    distancesLine.append(distanceAtXYPoint)
                }
                depthArray.append(distancesLine)
            }
            print("The array has finished")
            lidarVolume(cameraIntrinsics: cameraIntrinsics)
        }
    }
    
    func lidarVolume(cameraIntrinsics: simd_float3x3){
        //MARK: TODO:
        let lidarCenter = GeometryUtils.convertToLidarCoord(screenCoord: centerPoint)
        let lidarRight = GeometryUtils.convertToLidarCoord(screenCoord: rightPoint)
        let lidarLeft = GeometryUtils.convertToLidarCoord(screenCoord: leftPoint)
        let lidarUp = GeometryUtils.convertToLidarCoord(screenCoord: downPoint)
        let lidarDown = GeometryUtils.convertToLidarCoord(screenCoord: upPoint)
        
        var centerRW = SCNVector3()
        var leftRW = SCNVector3()
        var rightRW = SCNVector3()
        var upRW = SCNVector3()
        var downRW = SCNVector3()
        
        //get Real World co-ordinates
        if lidarCenter != nil {
            let zrw = depthArray[Int(lidarCenter!.x)][Int(lidarCenter!.y)] //get depth
            let xrw = (Float(lidarCenter!.x) - cameraIntrinsics[2][0]) * zrw / cameraIntrinsics[0][0]
            let yrw = (Float(lidarCenter!.y) - cameraIntrinsics[2][1]) * zrw / cameraIntrinsics[1][1]
            centerRW = SCNVector3(x: xrw, y: yrw, z: zrw)
            print(centerRW)
        }
        if lidarLeft != nil{
            let zrw = depthArray[Int(lidarLeft!.x)][Int(lidarLeft!.y)] //get depth
            let xrw = (Float(lidarLeft!.x) - cameraIntrinsics[2][0]) * zrw / cameraIntrinsics[0][0]
            let yrw = (Float(lidarLeft!.y) - cameraIntrinsics[2][1]) * zrw / cameraIntrinsics[1][1]
            leftRW = SCNVector3(x: xrw, y: yrw, z: zrw)
            print("This is the left point: \(leftRW)")
        }
        if lidarRight != nil{
            let zrw = depthArray[Int(lidarRight!.x)][Int(lidarRight!.y)] //get depth
            let xrw = (Float(lidarRight!.x) - cameraIntrinsics[2][0]) * zrw / cameraIntrinsics[0][0]
            let yrw = (Float(lidarRight!.y) - cameraIntrinsics[2][1]) * zrw / cameraIntrinsics[1][1]
            rightRW = SCNVector3(x: xrw, y: yrw, z: zrw)
            print("This is the right point: \(rightRW)")
        }
        if lidarUp != nil{
            let zrw = depthArray[Int(lidarUp!.x)][Int(lidarUp!.y)] //get depth
            let xrw = (Float(lidarUp!.x) - cameraIntrinsics[2][0]) * zrw / cameraIntrinsics[0][0]
            let yrw = (Float(lidarUp!.y) - cameraIntrinsics[2][1]) * zrw / cameraIntrinsics[1][1]
            upRW = SCNVector3(x: xrw, y: yrw, z: zrw)
            print("This is the up point: \(upRW)")
        }
        if lidarDown != nil{
            let zrw = depthArray[Int(lidarDown!.x)][Int(lidarDown!.y)] //get depth
            let xrw = (Float(lidarDown!.x) - cameraIntrinsics[2][0]) * zrw / cameraIntrinsics[0][0]
            let yrw = (Float(lidarDown!.y) - cameraIntrinsics[2][1]) * zrw / cameraIntrinsics[1][1]
            downRW = SCNVector3(x: xrw, y: yrw, z: zrw)
            print("This is the down point: \(downRW)")
        }
        
        //calculate the width and the height of the kiwifruit
        let width = GeometryUtils.calculateDistance(first: leftRW, second: rightRW)
        print("Calculated Kiwi Width: \(width)")
        let height = GeometryUtils.calculateDistance(first: upRW, second: downRW)
        print("Calculated Kiwi Height: \(height)")
        
        message = "Width: " + String(format: "%.2f cm", width) + " / Height: " + String(format: "%.2f cm", height)
        message2 = "Left: " + "(" + String(leftRW.x) + "," + String(leftRW.y) + "," + String(leftRW.z) + ")" + "/ Right: " + "(" + String(rightRW.x) + "," + String(rightRW.y) + "," + String(rightRW.z) + ")"
        message3 = "Up: " + "(" + String(upRW.x) + "," + String(upRW.y) + "," + String(upRW.z) + ")" + "/ Down: " + "(" + String(downRW.x) + "," + String(downRW.y) + "," + String(downRW.z) + ")"
        
        //crop the lidar reading to just show the kiwifruit
        if lidarCenter != nil && lidarUp != nil && lidarDown != nil && lidarLeft != nil && lidarRight != nil{
            let extractedLidar = depthArray[Int(lidarUp!.y)...Int(lidarDown!.y)].map{$0[Int(lidarLeft!.x)...Int(lidarRight!.x)].compactMap{$0}}
            let row = extractedLidar.count
            let col = extractedLidar[0].count
            //print(extractedLidar)
        }
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        print("camera did change \(camera.trackingState)")
        switch camera.trackingState {
        case .limited(_):
            message = "Device Starting" //tracking limited
        case .normal:
            message =  "Ready to Measure" //tracking ready
        case .notAvailable:
            message = "Cannot Measure" //cannot track
        }
    }
    
//MARK: ML kiwifruit Detection
    
    lazy var objectDetectionRequest: VNCoreMLRequest = {
        //load the ML model
        do {
            let model = try VNCoreMLModel(for: kiwi1000_2(configuration: MLModelConfiguration()).model)
            let request = VNCoreMLRequest(model: model) { [weak self] request, error in
                self?.processDetections(for: request, error: error)
            }
            return request
        } catch {
            fatalError("Failed to load Vision ML model.")
        }
    }()
    
    func processDetections(for request: VNRequest, error: Error?) {
        guard error == nil else {
            print("Object detection error: \(error!.localizedDescription)")
            return
        }
        
        guard let results = request.results else { return }
        for observation in results where observation is VNRecognizedObjectObservation {
            guard let objectObservation = observation as? VNRecognizedObjectObservation,
                let topLabelObservation = objectObservation.labels.first,
                topLabelObservation.identifier == "kiwifruit",
                topLabelObservation.confidence > 0.9
                else { continue }
            //get the bounding box around the kiwifruit
            let boundingBox = objectObservation.boundingBox
            //Set all the 5 points around the detected kiwifruit
            //translate to the coordinates on the screen
            let screenWidth  = UIScreen.main.bounds.width
            let screenHeight = UIScreen.main.bounds.height
            centerPoint = CGPoint(x: screenWidth-boundingBox.midX*screenWidth,y: screenHeight-boundingBox.midY*screenHeight)
            upPoint = CGPoint(x: screenWidth-boundingBox.midX*screenWidth,y: screenHeight-boundingBox.minY*screenHeight)
            downPoint = CGPoint(x: screenWidth-boundingBox.midX*screenWidth,y: screenHeight-boundingBox.maxY*screenHeight)
            leftPoint = CGPoint(x: screenWidth-boundingBox.maxX*screenWidth,y: screenHeight-boundingBox.midY*screenHeight)
            rightPoint = CGPoint(x: screenWidth-boundingBox.minX*screenWidth,y: screenHeight-boundingBox.midY*screenHeight)
//            print("up X: \(upPoint!.x)")
//            print("up Y: \(upPoint!.y)")
//            print("down X: \(downPoint!.x)")
//            print("down Y: \(downPoint!.y)")
//            print("left X: \(leftPoint!.x)")
//            print("left Y: \(leftPoint!.y)")
//            print("right X: \(rightPoint!.x)")
//            print("right Y: \(rightPoint!.y)")
        }
    }
    
    var globalFlag: Int = 0
    var done: Int = 0
    // MARK: - Private
    private var centerPoint: CGPoint?
    private var upPoint: CGPoint?
    private var downPoint: CGPoint?
    private var rightPoint: CGPoint?
    private var leftPoint: CGPoint?
    private var arView: ARSCNView?
    private var circles:[SCNNode] = []
    private var trackedNode:SCNNode?
    var count: Int = 1
    private var xDistance: Float = 0
    private var yDistance: Float = 0
    private var zDistance: Float = 0
    private var volume: Float = 0
    
    private func addCircle(raycastResult: ARRaycastResult) {
        //MARK: -> issue here
        let circleNode = GeometryUtils.createCircle(fromRaycastResult: raycastResult)
        if circles.count >= 5 {
            for circle in circles {
                circle.removeFromParentNode()
            }
            circles.removeAll()
        }
        arView?.scene.rootNode.addChildNode(circleNode)
        circles.append(circleNode)
    }
    
    private func moveNode(_ node:SCNNode, raycastResult:ARRaycastResult) {
        node.simdWorldTransform = raycastResult.worldTransform
        nodesUpdated()
    }
    
    private func nodeAtLocation(_ location:CGPoint) -> SCNNode? {
        guard let arView = arView else { return nil }
        let result = arView.hitTest(location, options: nil)
        return result.first?.node
    }
    
    private func nodesUpdated(){
        //circles = center, up, down, left right
        if circles.indices.contains(0) && circles.indices.contains(1) && circles.indices.contains(2) && circles.indices.contains(3) && circles.indices.contains(4){
            let yDistance = GeometryUtils.calculateDistance(firstNode: circles[1], secondNode: circles[2])
            let xDistance = GeometryUtils.calculateDistance(firstNode: circles[3], secondNode: circles[4])
            //let depth = GeometryUtils.calculateDepth(firstNode: circles[0], secondNode: circles[1], thirdNode: circles[2], fourthNode: circles[3], fifthNode: circles[4])
            //calculate volume of spheroid = 4/3 * pi * a * b * c
            volume = 4/3 * Float.pi * xDistance/2 * yDistance/2 * xDistance/3.236 //depth -> golden ratio
//            message = "Volume " + String(format: "%.2f cm3", volume)
//            message2 = "Width: " + String(format: "%.2f cm", xDistance)
//            message3 = "Height: " + String(format: "%.2f cm", yDistance)
        }
    }
    
    private func raycastResult(fromLocation location: CGPoint) -> ARRaycastResult? {
        guard let arView = arView,
              let query = arView.raycastQuery(from: location,
                                        allowing: .existingPlaneGeometry,
                                        alignment: .any) else { return nil }
        let results = arView.session.raycast(query)
        return results.first
    }
    
    func removeCircle(node:SCNNode) {
        node.removeFromParentNode()
        circles.removeAll(where: { $0 == node })
    }
}

    
