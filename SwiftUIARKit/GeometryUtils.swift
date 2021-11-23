//
//  GeometryUtils.swift
//  SwiftUIARKit
// this script returns the distance in a 3D space

import Foundation
import ARKit

class GeometryUtils {
    static func calculateDistance(first: SCNVector3, second: SCNVector3) -> Float {
        var distance:Float = sqrt( //calculate the distance between the two circles using pythagoras
            pow(second.x - first.x, 2) +
                pow(second.y - first.y, 2) +
                pow(second.z - first.z, 2)
        )
        
        distance *= 100 // convert in cm
        return abs(distance) //return the absolute value of the distance
    }
    
    static func calculateDistance(firstNode: SCNNode, secondNode:SCNNode) -> Float { //function overloading
        return calculateDistance(first: firstNode.position, second: secondNode.position)
    }
    
    static func createCircle(fromRaycastResult result:ARRaycastResult) -> SCNNode { //draw a circle
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
