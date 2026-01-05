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
    let currentLocation: CLLocation?
    let locationHistory: [CLLocation]
    let isRecording: Bool
    let isReplaying: Bool
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.region = region
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update region
        if abs(mapView.region.center.latitude - region.center.latitude) > 0.0001 ||
           abs(mapView.region.center.longitude - region.center.longitude) > 0.0001 {
            mapView.setRegion(region, animated: true)
        }
        
        // Remove old overlays and annotations
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        
        // Add route polyline if we have history
        if locationHistory.count > 1 {
            let coordinates = locationHistory.map { $0.coordinate }
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)
        }
        
        // Add current location annotation
        if let location = currentLocation {
            let annotation = LocationAnnotation(
                coordinate: location.coordinate,
                isRecording: isRecording,
                isReplaying: isReplaying
            )
            mapView.addAnnotation(annotation)
            
            // Center on location if needed
            if locationHistory.isEmpty || locationHistory.last?.coordinate.latitude != location.coordinate.latitude {
                mapView.setCenter(location.coordinate, animated: true)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable
        
        init(_ parent: MapViewRepresentable) {
            self.parent = parent
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

