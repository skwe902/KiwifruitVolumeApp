//  Written by Andy K
//  ARDelgeate.swift
//  SwiftUIARKit

// use print() to print to console
// in swift -> function(variable : value/varType)

import Foundation
import ARKit
import UIKit

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
        
//        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panOnARView))
//        arView.addGestureRecognizer(panGesture)
    }
    
//    @objc func panOnARView(sender: UIPanGestureRecognizer) {
//        //for swipe
//        guard let arView = arView else { return }
//        let location = sender.location(in: arView)
//        switch sender.state {
//        case .began:
//            if let node = nodeAtLocation(location) {
//                trackedNode = node
//            }
//        case .changed:
//            if let node = trackedNode {
//                if let result = raycastResult(fromLocation: location) {
//                    moveNode(node, raycastResult:result)
//                }
//            }
//        default:
//            ()
//        }
//
//    }
    
    @objc func tapOnARView(sender: UITapGestureRecognizer) {
        guard let arView = arView else { return }
        //get the coordinates of the tapped circles in CGPoint struct
        let location = sender.location(in: arView)
        //let location = CGPoint(x:100,y:100) create a point at (100,100)
        print(location)
        if let node = nodeAtLocation(location) {
            removeCircle(node: node)
        }
        else if let result = raycastResult(fromLocation: location) {
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
    
    // MARK: - ARSessionDelegate
    
    // Pass camera frames received from ARKit to Vision (when not already processing one)
    /// - Tag: ConsumeARFrames
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Do not enqueue other buffers for processing while another Vision task is still running.
        // The camera stream has only a finite amount of buffers available; holding too many buffers for analysis would starve the camera.
        guard currentBuffer == nil, case .normal = frame.camera.trackingState else {
            return
        }
        
        // Retain the image buffer for Vision processing.
        self.currentBuffer = frame.capturedImage
        classifyCurrentImage()
    }
    
    // MARK: - Vision classification
    
    // Vision classification request and model
    /// - Tag: ClassificationRequest
    private lazy var classificationRequest: VNCoreMLRequest = {
        do {
            // Instantiate the model from its generated Swift class.
            let model = try VNCoreMLModel(for: kiwi1000_2.model)
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                self?.processClassifications(for: request, error: error)
            })
            
            // Crop input images to square area at center, matching the way the ML model was trained.
            //request.imageCropAndScaleOption = .centerCrop
            
            // Use CPU for Vision processing to ensure that there are adequate GPU resources for rendering.
            request.usesCPUOnly = true
            
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()
    
    // The pixel buffer being held for analysis; used to serialize Vision requests.
    private var currentBuffer: CVPixelBuffer?
    
    // Queue for dispatching vision classification requests
    private let visionQueue = DispatchQueue(label: "com.example.apple-samplecode.ARKitVision.serialVisionQueue")
    
    // Run the Vision+ML classifier on the current image buffer.
    /// - Tag: ClassifyCurrentImage
    private func classifyCurrentImage() {
        // Most computer vision tasks are not rotation agnostic so it is important to pass in the orientation of the image with respect to device.
        let orientation = CGImagePropertyOrientation(UIDevice.current.orientation)
        
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: currentBuffer!, orientation: orientation)
        visionQueue.async {
            do {
                // Release the pixel buffer when done, allowing the next buffer to be processed.
                defer { self.currentBuffer = nil }
                try requestHandler.perform([self.classificationRequest])
            } catch {
                print("Error: Vision request failed with error \"\(error)\"")
            }
        }
    }
    
    // Classification results
    private var identifierString = ""
    private var confidence: VNConfidence = 0.0
    
    // Handle completion of the Vision request and choose results to display.
    /// - Tag: ProcessClassifications
    func processClassifications(for request: VNRequest, error: Error?) {
        guard let results = request.results else {
            print("Unable to classify image.\n\(error!.localizedDescription)")
            return
        }
        // The `results` will always be `VNClassificationObservation`s, as specified by the Core ML model in this project.
        let classifications = results as! [VNClassificationObservation]
        
        // Show a label for the highest-confidence result (but only above a minimum confidence threshold).
        if let bestResult = classifications.first(where: { result in result.confidence > 0.5 }),
            let label = bestResult.identifier.split(separator: ",").first {
            identifierString = String(label)
            confidence = bestResult.confidence
        } else {
            identifierString = ""
            confidence = 0
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.displayClassifierResults()
        }
    }
    
    // Show the classification results in the UI.
    private func displayClassifierResults() {
        guard !self.identifierString.isEmpty else {
            return // No object was classified.
        }
        let message = String(format: "Detected \(self.identifierString) with %.2f", self.confidence * 100) + "% confidence"
        statusViewController.showMessage(message)
    }
    
    // MARK: - Private

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
        //TODO: check if the AR can measure depth and use that to create a more accurate measurement
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
