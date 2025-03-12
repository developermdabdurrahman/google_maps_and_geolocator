import 'dart:async';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/material.dart';

class MapController extends GetxController {
  late GoogleMapController mapController;
  LatLng? currentPosition;
  List<LatLng> polylineCoordinates = [];
  StreamSubscription<Position>? positionStream;

  final markers = <Marker>{}.obs;
  final polylines = <Polyline>{}.obs;
  final searchResults = <Marker>{}.obs;
  final isLocationLoading = true.obs;

  final LatLng initialLocation = LatLng(23.8759, 90.3984);

  @override
  void onInit() {
    super.onInit();
    getUserLocation();
  }

  void onMapCreated(GoogleMapController controller) {
    mapController = controller;
    mapController.animateCamera(
      CameraUpdate.newLatLngZoom(initialLocation, 15),
    );

    markers.add(
      Marker(
        markerId: MarkerId("uttara_14"),
        position: initialLocation,
        infoWindow: InfoWindow(title: "Uttara 14"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ),
    );
  }

  Future<void> getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      Get.snackbar(
        'Location Services Disabled',
        'Please enable location services to use this feature.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        Get.snackbar(
          'Location Permission Denied',
          'This app needs location permission to work properly.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
    }

    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      (Position position) {
        LatLng newPosition = LatLng(position.latitude, position.longitude);
    
        if (currentPosition != null) {
          polylineCoordinates.add(currentPosition!);
        }
    
        currentPosition = newPosition;
        polylineCoordinates.add(newPosition);
        isLocationLoading.value = false;
        updateMap();
      },
      onError: (error) {
        print("Error getting location updates: $error");
        Get.snackbar(
          'Location Error',
          'Unable to get location updates',
          snackPosition: SnackPosition.BOTTOM,
        );
      },
    );
  }

  void updateMap() {
    if (currentPosition != null) {
      markers.value = {
        Marker(
          markerId: MarkerId("current_location"),
          position: currentPosition!,
          infoWindow: InfoWindow(
            title: "My current location",
            snippet:
                "${currentPosition!.latitude}, ${currentPosition!.longitude}",
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      };

      polylines.value = {
        Polyline(
          polylineId: PolylineId("route"),
          color: const Color(0xFF2196F3),
          width: 5,
          points: polylineCoordinates,
        ),
      };

      mapController.animateCamera(CameraUpdate.newLatLng(currentPosition!));
    }
  }

  Future<void> searchLocation(String query) async {
    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        LatLng searchPosition = LatLng(
          locations.first.latitude,
          locations.first.longitude,
        );
        searchResults.value = {
          Marker(
            markerId: MarkerId("search_location"),
            position: searchPosition,
            infoWindow: InfoWindow(
              title: query,
              snippet:
                  "${searchPosition.latitude}, ${searchPosition.longitude}",
            ),
          ),
        };
        mapController.animateCamera(CameraUpdate.newLatLng(searchPosition));
      }
    } catch (e) {
      print("Error searching location: $e");
    }
  }

  Future<void> onMapTapped(LatLng tappedPosition) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        tappedPosition.latitude,
        tappedPosition.longitude,
      );
      String locationName =
          placemarks.isNotEmpty
              ? placemarks.first.name ?? 'Unknown Location'
              : 'Unknown Location';

      markers.clear();
      markers.add(
        Marker(
          markerId: MarkerId(tappedPosition.toString()),
          position: tappedPosition,
          infoWindow: InfoWindow(
            title: locationName,
            snippet:
                "Latitude: ${tappedPosition.latitude}, Longitude: ${tappedPosition.longitude}",
          ),
        ),
      );

      mapController.animateCamera(CameraUpdate.newLatLng(tappedPosition));
    } catch (e) {
      print("Error tapped location: $e");
    }
  }

  @override
  void onClose() {
    positionStream?.cancel();
    super.onClose();
  }
}
