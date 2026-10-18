import SwiftUI
import MapKit

// Shows WHERE THE PHONE WAS when a Wallet-captured bank notification
// arrived (Android capture, see TransactionLocationDto) -- never the real
// merchant location, the notification itself never carries coordinates.
// The caption below the map says so explicitly so this never reads as an
// Apple-Pay-style "this is where you bought it" claim. iOS never captures
// this itself (no notification-listener API on the platform); this view is
// read-only display of what Android already sent and synced down.
struct TransactionLocationMapView: View {
    let latitude: Double
    let longitude: Double
    let device: String?

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private var cameraPosition: MapCameraPosition {
        .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Map(initialPosition: cameraPosition, interactionModes: []) {
                Marker("", coordinate: coordinate)
            }
            .frame(height: 160)
            .cornerRadius(12)
            .allowsHitTesting(false)

            Text(captionText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var captionText: String {
        if let device, !device.isEmpty {
            return "No es la ubicación del comercio, sino la del teléfono (\(device)) al momento de capturar la notificación."
        }
        return "No es la ubicación del comercio, sino la del teléfono al momento de capturar la notificación."
    }
}

#Preview {
    Form {
        TransactionLocationMapView(latitude: -25.2968, longitude: -57.5947, device: "SM-S928B")
    }
}
