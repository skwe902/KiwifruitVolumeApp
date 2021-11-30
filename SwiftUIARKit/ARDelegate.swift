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
        configuration.planeDetection = .horizontal
        arView.session.run(configuration)
        
        arView.delegate = self
        arView.scene = SCNScene()
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapOnARView))
        arView.addGestureRecognizer(tapGesture)
    }
    
    
    @objc func tapOnARView(sender: UITapGestureRecognizer) {
        //guard let arView = arView else { return }
        //get the coordinates of the tapped circles in CGPoint struct
        //let location = sender.location(in: arView)
        let location = midPoint
        print(location)
        if let node = nodeAtLocation(location!) {
            removeCircle(node: node)
        }
        else if let result = raycastResult(fromLocation: location!) {
            addCircle(raycastResult: result)
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
    
    lazy var objectDetectionRequest: VNCoreMLRequest = {
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
        //midPoint = CGPoint(x: 100, y:100) <- needs implementation
        for observation in results where observation is VNRecognizedObjectObservation {
            guard let objectObservation = observation as? VNRecognizedObjectObservation,
                let topLabelObservation = objectObservation.labels.first,
                topLabelObservation.identifier == "kiwifruit",
                topLabelObservation.confidence > 0.9
                else { continue }
            
            let boundingBox = objectObservation.boundingBox
            // MARK: TODO
            //Need to automatically point all five points on tap
            midPoint = CGPoint(x: 1024-boundingBox.midX*1024,y: 1366-boundingBox.midY*1366)
            print(boundingBox.midX)
            print(boundingBox.midY)
        }
    }
    
    // MARK: - Private
    private var midPoint: CGPoint?
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
        if circles.count >= 2 { // if more than 2 circles are on the screen
            for circle in circles {
                circle.removeFromParentNode()
            }
            circles.removeAll()
        }
        
        arView?.scene.rootNode.addChildNode(circleNode)
        circles.append(circleNode)
        
        nodesUpdated()
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
    
    private func nodesUpdated() { //take the measurement and update the message
        if circles.count == 2 && count == 1{ //first measurement
            let distance = GeometryUtils.calculateDistance(firstNode: circles[0], secondNode: circles[1]) //calculate the distance between the two circles
            //print("X length = \(distance)")
            message = "X length " + String(format: "%.2f cm", distance)
            xDistance = distance / 2
            count = 2
        }
        else if circles.count == 2 && count == 2{ //second measurement
            let distance = GeometryUtils.calculateDistance(firstNode: circles[0], secondNode: circles[1])
            //print("Y length = \(distance)")
            yDistance = distance / 2
            if (xDistance < yDistance){
                volume = 4/3 * Float.pi * xDistance * yDistance * xDistance
                //print("Volume = \(volume)")
            }
            else{ //if yDistance is smaller or equal to xDistance
                volume = 4/3 * Float.pi * yDistance * yDistance * xDistance
                //print("Volume = \(volume)")
            }
            message = "Y length " + String(format: "%.2f cm", distance) + " / Add reference point"
            count = 3
        }
        else if circles.count == 1 && count == 1 {
            message = "add second X point"
        }
        else if circles.count == 1 && count == 2{
            message = "add second Y point"
        }
        else if circles.count == 1 && count == 3{
            message = "add center point"
        }
        else if circles.count == 2 && count == 3{
            let distance = GeometryUtils.calculateDistance(firstNode: circles[0], secondNode: circles[1])
            //print("Depth = \(distance)")
            zDistance = distance
            volume = 4/3 * Float.pi * xDistance * yDistance * zDistance
            message = "Volume " + String(format: "%.2f cm", volume)
            //print("Volume w. depth = \(volume)")
            count = 1
        }
    }
    
    private func raycastResult(fromLocation location: CGPoint) -> ARRaycastResult? {
        guard let arView = arView,
              let query = arView.raycastQuery(from: location,
                                        allowing: .existingPlaneGeometry,
                                        alignment: .horizontal) else { return nil }
        let results = arView.session.raycast(query)
        return results.first
    }
    
    func removeCircle(node:SCNNode) {
        node.removeFromParentNode()
        circles.removeAll(where: { $0 == node })
    }
}
