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
    @Published var message:String = "starting AR"

    func setARView(_ arView: ARSCNView) {
        self.arView = arView
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        arView.session.run(configuration)
        arView.delegate = self
        arView.scene = SCNScene()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapOnARView))
        arView.addGestureRecognizer(tapGesture)
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panOnARView))
        arView.addGestureRecognizer(panGesture)
    }
    
    @objc func tapOnARView(sender: UITapGestureRecognizer) {
        //get the coordinates of the circles in CGPoint(x,y) - centerPoint, upPoint, downPoint, leftPoint, rightPoint
        let locationArray = [centerPoint, upPoint, downPoint, leftPoint, rightPoint]
        for location in locationArray {
            if let result = raycastResult(fromLocation: location!) {
                addCircle(raycastResult: result)
            }
        }
        nodesUpdated()
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
    
    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        // Get the capture image (which is a cvPixelBuffer) from the current ARFrame
        guard let capturedImage = arView?.session.currentFrame?.capturedImage else { return }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: capturedImage,
                                                        orientation: .leftMirrored,
                                                        options: [:])
        do {
            try imageRequestHandler.perform([objectDetectionRequest])
        } catch {
            print("Failed to perform image request.")
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
            centerPoint = CGPoint(x: 1024-boundingBox.midX*1024,y: 1366-boundingBox.midY*1366)
            downPoint = CGPoint(x: 1024-boundingBox.midX*1024,y: 1366-boundingBox.minY*1366)
            upPoint = CGPoint(x: 1024-boundingBox.midX*1024,y: 1366-boundingBox.maxY*1366)
            rightPoint = CGPoint(x: 1024-boundingBox.maxX*1024,y: 1366-boundingBox.midY*1366)
            leftPoint = CGPoint(x: 1024-boundingBox.minX*1024,y: 1366-boundingBox.midY*1366)
            print(1024-boundingBox.midX*1024)
            print(1366-boundingBox.midY*1366)
        }
    }
    
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
        //fix index out of range issue - wait for the values to be in the array
        if circles.indices.contains(1) && circles.indices.contains(2) && circles.indices.contains(3) && circles.indices.contains(4){
            let yDistance = GeometryUtils.calculateDistance(firstNode: circles[1], secondNode: circles[2])
            let xDistance = GeometryUtils.calculateDistance(firstNode: circles[3], secondNode: circles[4])
            //let depth = GeometryUtils.calculateDepth(firstNode: circles[0], secondNode: circles[1], thirdNode: circles[2], fourthNode: circles[3], fifthNode: circles[4])
            //calculate volume of spheroid = 4/3 * pi * a * b * c
            volume = 4/3 * Float.pi * xDistance/2 * yDistance/2 * xDistance/3.236 //depth -> golden ratio
            message = "Volume " + String(format: "%.2f cm3", volume)
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
    //MARK: Old nodesUpdated
//    private func nodesUpdated() { //take the measurement and update the message
//        if circles.count == 2 && count == 1{ //first measurement
//            let distance = GeometryUtils.calculateDistance(firstNode: circles[0], secondNode: circles[1]) //calculate the distance between the two circles
//            message = "X length " + String(format: "%.2f cm", distance)
//            xDistance = distance / 2
//            count = 2
//        }
//        else if circles.count == 2 && count == 2{ //second measurement
//            let distance = GeometryUtils.calculateDistance(firstNode: circles[0], secondNode: circles[1])
//            yDistance = distance / 2
//            if (xDistance < yDistance){
//                volume = 4/3 * Float.pi * xDistance * yDistance * xDistance
//            }
//            else{ //if yDistance is smaller or equal to xDistance
//                volume = 4/3 * Float.pi * yDistance * yDistance * xDistance
//            }
//            message = "Y length " + String(format: "%.2f cm", distance) + " / Add reference point"
//            count = 3
//        }
//        else if circles.count == 1 && count == 1 {
//            message = "add second X point"
//        }
//        else if circles.count == 1 && count == 2{
//            message = "add second Y point"
//        }
//        else if circles.count == 1 && count == 3{
//            message = "add center point"
//        }
//        else if circles.count == 2 && count == 3{
//            let distance = GeometryUtils.calculateDistance(firstNode: circles[0], secondNode: circles[1])
//            zDistance = distance
//            volume = 4/3 * Float.pi * xDistance * yDistance * zDistance
//            message = "Volume " + String(format: "%.2f cm", volume)
//            count = 1
//        }
//    }
    
