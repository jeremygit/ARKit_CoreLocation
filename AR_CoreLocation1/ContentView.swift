//
//  ContentView.swift
//  AR_CoreLocation1
//
//  Created by Jeremy Heritage on 28/8/20.
//  Copyright © 2020 Jeremy Heritage. All rights reserved.
//

import SwiftUI
import RealityKit
import ARKit
import CoreLocation

struct ContentView: View {
    var body: some View {
        ARViewContainer()
        .edgesIgnoringSafeArea(.all)
    }
}

struct ARViewContainer: UIViewRepresentable {

    func makeUIView(context: Context) -> ARView {
        let worldARView = WorldView(frame: .zero)
        // Add the box anchor to the scene
        // arView.scene.anchors.append(boxAnchor)
        return worldARView

    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

class WorldView: ARView, ARSessionDelegate, CLLocationManagerDelegate {
    
    private let locationManager: CLLocationManager = CLLocationManager()
    
    private let locations: [CLLocation] = {
        return [
            // St Peters
            CLLocation(latitude: -33.912188, longitude: 151.175821),
            // Blue Mountains
            CLLocation(latitude: -33.700001, longitude: 150.300003),
            // Dubbo
            CLLocation(latitude: -32.256943, longitude: 148.601105),
            // Broken Hill
            CLLocation(latitude: -31.956667, longitude: 141.467773),
            // Sydney
            CLLocation(latitude: -33.865143, longitude: 151.209900)
        ]
    }()
    
    private var location: CLLocation?
    
    required init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        self.testSupport()
        self.setupConfiguration()
        self.setupLocationManagement()
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onTap(recognizer:)))
        self.addGestureRecognizer(tapGesture)
    }
    
    @objc required dynamic init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func testSupport() {
//          A12 processor
//        print("ARGeoTrackingConfiguration.isSupported")
//        print(ARGeoTrackingConfiguration.isSupported)
    }
    
    func setupConfiguration() {
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravityAndHeading
        config.planeDetection = [.horizontal, .vertical]
        self.session.run(config, options: [.resetTracking])
        self.session.delegate = self
    }
    
    // Location
    func setupLocationManagement() {
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        self.locationManager.requestWhenInUseAuthorization()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // do stuff
        if self.location == nil {
            print("Settting location")
            print(locations)
            self.location = locations.last
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        //
        switch status {
        case .restricted,.denied,.notDetermined:
            print("error")
        default:
            self.locationManager.startUpdatingLocation()
        }
    }
    
    
    // Marker
    func renderMarkers() {
        guard let userLocation = self.location
        else {
            return
        }

        var i = 0
        for loc in self.locations {
            
            DispatchQueue.main.async {
                let distance = userLocation.distance(from: loc)
                
                var distanceTransform = matrix_identity_float4x4
                distanceTransform.columns.3.x = 0
                distanceTransform.columns.3.y = 0
                distanceTransform.columns.3.z = -Float(min(distance/5000, 50))
                
                print("distance")
                print(distance)
                
                let angle = self.matrixAngleBearing(userLocation: userLocation, to: loc)
                let transformMatrix = self.matrixRotateHorizontally(matrix: distanceTransform, around: angle)
                
                print(transformMatrix)
                print(angle)
                
                var label = ""
                switch i {
                    case 0: label = "St Peters"
                    case 1: label = "Blue Mountains"
                    case 2: label = "Dubbo"
                    case 3: label = "Broken Hill"
                    case 4: label = "Sydney"
                    default:
                    label = ""
                }
                
                let textMesh = MeshResource.generateText(label, extrusionDepth: 0.2, font: .italicSystemFont(ofSize: 0.1), containerFrame: CGRect(), alignment: .left, lineBreakMode: .byCharWrapping)
                let textEntity = ModelEntity(mesh: textMesh)
                let mesh = MeshResource.generateBox(width: 0.2, height: 0.2, depth: 0.2)
                let meshMaterial = SimpleMaterial(color: .red, isMetallic: true)
                let meshModelEntity = ModelEntity(mesh: mesh, materials: [meshMaterial])
                // let meshAnchor = AnchorEntity(plane: .horizontal)
                let meshAnchor = AnchorEntity(world: SIMD3<Float>(x: transformMatrix.columns.3.x, y: transformMatrix.columns.3.y, z: transformMatrix.columns.3.z))
                meshAnchor.addChild(meshModelEntity)
                meshAnchor.addChild(textEntity)
                // meshAnchor.transform.translation = SIMD3<Float>(x: transformMatrix.columns.3.x, y: transformMatrix.columns.3.y, z: transformMatrix.columns.3.z)
                self.scene.addAnchor(meshAnchor)
                // self.scene.anchors.append()
                
                i += 1
            }
            
        }

    }
    
    func matrixAngleBearing(userLocation: CLLocation, to: CLLocation) -> Double {
        let latA = userLocation.coordinate.latitude * .pi / 180
        let lonA = userLocation.coordinate.longitude * .pi / 180
        let latB = to.coordinate.latitude * .pi / 180
        let lonB = to.coordinate.longitude * .pi / 180
        let lonDelta = lonB - lonA
        
        let y = sin(lonDelta) * cos(latB)
        let x = cos(latA) * sin(latB) - sin(latA) * cos(latB) * cos(lonDelta)
        var angle = atan2(y, x)
        if angle < 0 { angle += .pi * 2 } // Angle should not be less than -2π, so just adjusting it up once should be sufficient.
        return angle
    }
    
    func matrixRotateHorizontally(matrix: simd_float4x4, around radians: Double) -> simd_float4x4 {
        // var rotY = GLKMatrix4MakeYRotation(Float(radians))
        var roty = matrix_identity_float4x4
        roty.columns.0.x = cos(Float(radians))
        roty.columns.0.z = -sin(Float(radians))
        roty.columns.2.x = sin(Float(radians))
        roty.columns.2.z = cos(Float(radians))
        // .inverse or send negative angle
        return simd_mul(roty.inverse, matrix)
    }
    
    // Gestures
    @objc func onTap(recognizer: UITapGestureRecognizer) {
        self.renderMarkers()
    }
    
    // AR Delegate
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        //
        // print("didUpdate")
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        //
        print("-------------------------------didAdd")
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
