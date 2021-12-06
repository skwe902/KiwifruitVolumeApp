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
    
    //MARK: Lidar Reading
    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval){
        //this will run once per every frame
        // Get the capture image and the depthmap (which is a cvPixelBuffer) from the current ARFrame
        guard let capturedImage = arView?.session.currentFrame?.capturedImage, let depthData = arView?.session.currentFrame?.sceneDepth?.depthMap else { return }
        let depthWidth = CVPixelBufferGetWidth(depthData)
        let depthHeight = CVPixelBufferGetHeight(depthData)
        CVPixelBufferLockBaseAddress(depthData, CVPixelBufferLockFlags(rawValue: 0))
        let floatBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(depthData), to: UnsafeMutablePointer<Float32>.self)
        CVPixelBufferUnlockBaseAddress(depthData, CVPixelBufferLockFlags(rawValue: 0))
        
        if (globalFlag == 1){
            if(depthArray.isEmpty){
                for y in 0...depthHeight-1{
                    var distancesLine = [Float32]()
                    for x in 0...depthWidth-1{
                        let distanceAtXYPoint = floatBuffer[y * depthWidth + x]
                        distancesLine.append(distanceAtXYPoint)
                    }
                    depthArray.append(distancesLine)
                }
                globalFlag = 0 //reset flag
                done = 1
            }
            else{
                depthArray.removeAll()
                for y in 0...depthHeight-1{
                    var distancesLine = [Float32]()
                    for x in 0...depthWidth-1{
                        let distanceAtXYPoint = floatBuffer[y * depthWidth + x]
                        distancesLine.append(distanceAtXYPoint)
                    }
                    depthArray.append(distancesLine)
                }
                print("The array has finished")
                globalFlag = 0 //reset flag
                done = 1
                print(depthArray[96][128])
            }
            //message = String(depthArray[96][128]) + "m"
            //SwiftUI] Publishing changes from background threads is not allowed; make sure to publish values from the main thread (via operators like receive(on:)) on model updates.
        }
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: capturedImage,
                                                        orientation: .leftMirrored, //is this needed for the depth map as well?
                                                        options: [:])
        do {
            try imageRequestHandler.perform([objectDetectionRequest])
        } catch {
            print("Failed to perform image request.")
        }
    }
    
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
        
        globalFlag = 1 //set a flag to communicate with renderer func
        if(done == 1){ //once renderer func says it has finished processing the data
            print("detected screen tap")
            print(depthArray[96][128])
            for locations in locationArray{
                if (locations != nil){
                    var lidarArray: [CGPoint?] = []
                    let lidarCoord = GeometryUtils.convertToLidarCoord(screenCoord: locations!)
                    //MARK: ERROR HERE
                    lidarArray.append(lidarCoord)
                    //print(lidarCoord.x)
                    //print(lidarCoord.y)
                }
                else{
                    continue
                }
            }
            done = 0
        }
        nodesUpdated()
    }
//    camera did change normal
//    detected screen tap
//    0.82910156
//    The array has finished
//    0.8300781
//    detected screen tap
//    0.8300781
//    The array has finished
//    1.0332031
//    detected screen tap
//    1.0332031
//    The array has finished
//    0.6855469
//    detected screen tap
//    0.6855469
//    The array has finished
//    0.9716797
    
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
            centerPoint = CGPoint(x: 1024-boundingBox.midX*1024,y: 1366-boundingBox.midY*1366)
            upPoint = CGPoint(x: 1024-boundingBox.midX*1024,y: 1366-boundingBox.minY*1366)
            downPoint = CGPoint(x: 1024-boundingBox.midX*1024,y: 1366-boundingBox.maxY*1366)
            leftPoint = CGPoint(x: 1024-boundingBox.maxX*1024,y: 1366-boundingBox.midY*1366)
            rightPoint = CGPoint(x: 1024-boundingBox.minX*1024,y: 1366-boundingBox.midY*1366)
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
        //nodesUpdated()
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
            message = "Volume " + String(format: "%.2f cm3", volume)
            message2 = "X length: " + String(format: "%.2f cm", xDistance)
            message3 = "Y length: " + String(format: "%.2f cm", yDistance)
        }
    }
    
    private func raycastResult(fromLocation location: CGPoint) -> ARRaycastResult? {
        guard let arView = arView,
              let query = arView.raycastQuery(from: location,
                                        allowing: .existingPlaneGeometry,
                                        alignment: .any) else { return nil }
                //let query = arView.raycastQuery(from: location, allowing: .existingPlaneInfinite, alignment: .any) else {return nil}
        let results = arView.session.raycast(query)
        return results.first
    }
    
    func removeCircle(node:SCNNode) {
        node.removeFromParentNode()
        circles.removeAll(where: { $0 == node })
    }
}

    
