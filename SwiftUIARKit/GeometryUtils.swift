//
//  GeometryUtils.swift
//  SwiftUIARKit
// this script returns the distance in a 3D space

import Foundation
import ARKit

class GeometryUtils {
    static func calculateDistance(first: SCNVector3, second: SCNVector3) -> Float {
        var distance:Float = sqrt( //calculate the distance between the two circles using pythagoras in 3D
            pow(second.x - first.x, 2) +
                pow(second.y - first.y, 2) +
                pow(second.z - first.z, 2)
        )
        
        distance *= 100 // convert in cm
        return abs(distance) //return positive value
    }
    
    static func calculateDistance(firstNode: SCNNode, secondNode:SCNNode) -> Float { //function overloading
        return calculateDistance(first: firstNode.position, second: secondNode.position)
    }
    
    static func calculateDepth(first: SCNVector3, second: SCNVector3, third: SCNVector3, fourth: SCNVector3, fifth: SCNVector3) -> Float {
        //TODO: needs work
        var depth = calculateDistance(first: second, second: third) / 2 + calculateDistance(first: fourth, second: fifth) / 2
        depth = abs(depth)
        return depth
        
//        var depth:Float = second.z - first.z
//        depth *= 100
//        return abs(depth)
    }
    
    static func calculateDepth(firstNode: SCNNode, secondNode:SCNNode, thirdNode:SCNNode, fourthNode:SCNNode, fifthNode:SCNNode) -> Float { //function overloading
        return calculateDepth(first: firstNode.position, second: secondNode.position, third: thirdNode.position, fourth: fourthNode.position, fifth: fifthNode.position)
    }
    
    static func createCircle(fromRaycastResult result:ARRaycastResult) -> SCNNode {
        //place a circle on the screen
        let circleGeometry = SCNSphere(radius: 0.010)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(red: 1, green: 90/225, blue: 0, alpha: 1)
        //change the color of the circles made (alpha = transparancy 1 means opaque)
        circleGeometry.materials = [material]
        let circleNode = SCNNode(geometry: circleGeometry)
        circleNode.simdWorldTransform = result.worldTransform
        
        return circleNode
    }
}
