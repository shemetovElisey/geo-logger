//
//  MapViewRepresentable.swift
//  Demo
//
//  Created by Elisey Shemetov on 05.01.2026.
//

import SwiftUI
import MapKit

struct MapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var isRecording: Bool
    @Binding var isReplaying: Bool
    
    let currentLocation: CLLocation?
    let locationHistory: [CLLocation]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.region = region
        
        // Add gesture recognizers to detect user interaction
        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        panGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(panGesture)
        
        let pinchGesture = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        pinchGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(pinchGesture)
        
        let rotationGesture = UIRotationGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleRotation(_:))
        )
        rotationGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(rotationGesture)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Remove old overlays and annotations
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        
        guard isRecording || isReplaying else { return }
        
        // Add route polyline if we have history
        if locationHistory.count > 1 {
            let coordinates = locationHistory.map { $0.coordinate }
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)
        }
        
        // Add current location annotation and update region if needed
        if let location = currentLocation {
            let annotation = LocationAnnotation(
                coordinate: location.coordinate,
                isRecording: isRecording,
                isReplaying: isReplaying
            )
            mapView.addAnnotation(annotation)
            
            // Update region to follow location only if user is not interacting
            if !context.coordinator.isUserInteracting {
                let newRegion = MKCoordinateRegion(
                    center: location.coordinate,
                    span: mapView.region.span
                )
                mapView.setRegion(newRegion, animated: true)
                region = newRegion
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: MapViewRepresentable
        var isUserInteracting = false
        private var interactionTimer: Timer?
        
        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            handleUserInteraction()
        }
        
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            handleUserInteraction()
        }
        
        @objc func handleRotation(_ gesture: UIRotationGestureRecognizer) {
            handleUserInteraction()
        }
        
        private func handleUserInteraction() {
            isUserInteracting = true
            
            // Reset the flag after a delay to allow programmatic updates again
            interactionTimer?.invalidate()
            interactionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                self?.isUserInteracting = false
            }
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = parent.isReplaying ? .systemGreen : .systemBlue
                renderer.lineWidth = 3.0
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let locationAnnotation = annotation as? LocationAnnotation else {
                return nil
            }
            
            let identifier = "LocationAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
            } else {
                annotationView?.annotation = annotation
            }
            
            // Create custom view
            let color: UIColor = locationAnnotation.isRecording ? .systemRed : (locationAnnotation.isReplaying ? .systemGreen : .systemBlue)
            let size: CGFloat = 16
            
            let circleView = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            circleView.backgroundColor = color
            circleView.layer.cornerRadius = size / 2
            circleView.layer.borderWidth = 3
            circleView.layer.borderColor = UIColor.white.cgColor
            
            annotationView?.addSubview(circleView)
            annotationView?.frame = circleView.frame
            
            // Add label if recording or replaying
            if locationAnnotation.isRecording || locationAnnotation.isReplaying {
                let label = UILabel(frame: CGRect(x: -10, y: size + 2, width: 30, height: 12))
                label.text = locationAnnotation.isRecording ? "REC" : "▶"
                label.font = .systemFont(ofSize: 8, weight: .bold)
                label.textColor = .white
                label.backgroundColor = color.withAlphaComponent(0.9)
                label.textAlignment = .center
                label.layer.cornerRadius = 3
                label.clipsToBounds = true
                annotationView?.addSubview(label)
            }
            
            return annotationView
        }
    }
}

class LocationAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let isRecording: Bool
    let isReplaying: Bool
    
    init(coordinate: CLLocationCoordinate2D, isRecording: Bool, isReplaying: Bool) {
        self.coordinate = coordinate
        self.isRecording = isRecording
        self.isReplaying = isReplaying
    }
}

