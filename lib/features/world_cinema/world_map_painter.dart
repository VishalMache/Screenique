import 'dart:convert';
import 'package:flutter/material.dart';
import 'country_mapper.dart';

class GeoJsonParser {
  static Map<String, Path> parse(String geoJsonString, Size mapSize) {
    final Map<String, dynamic> data = json.decode(geoJsonString);
    final List features = data['features'] ?? [];
    final Map<String, Path> countryPaths = {};

    for (var feature in features) {
      final properties = feature['properties'];
      final iso = (properties['ISO_A2'] ?? properties['ISO3166-1-Alpha-2'])?.toString();
      if (iso == null || iso.isEmpty || iso == '-99') continue; // Skip invalid or unknown ISOs

      final geometry = feature['geometry'];
      if (geometry == null) continue;

      final type = geometry['type'];
      final coordinates = geometry['coordinates'];
      
      Path path = Path();

      if (type == 'Polygon') {
        _addPolygonToPath(path, coordinates, mapSize);
      } else if (type == 'MultiPolygon') {
        for (var polygon in coordinates) {
          _addPolygonToPath(path, polygon, mapSize);
        }
      }
      
      // Some countries (like US or FR) might have multiple scattered territories in the geojson.
      // We union them if we already encountered the ISO.
      if (countryPaths.containsKey(iso)) {
        // Simple append - Path.addPath works but union is more complex. We'll just add it to the existing path.
        countryPaths[iso]!.addPath(path, Offset.zero);
      } else {
        countryPaths[iso] = path;
      }
    }

    return countryPaths;
  }

  static void _addPolygonToPath(Path path, List rings, Size mapSize) {
    if (rings.isEmpty) return;
    
    // The first ring is the outer boundary. Subsequent rings are holes.
    // For simplicity, we just draw the outer boundary and ignore holes for the map visualization.
    final outerRing = rings[0];
    if (outerRing.isEmpty) return;

    bool first = true;
    for (var coord in outerRing) {
      final lon = (coord[0] as num).toDouble();
      final lat = (coord[1] as num).toDouble();
      
      // Equirectangular projection
      final x = (lon + 180) * (mapSize.width / 360);
      final y = (90 - lat) * (mapSize.height / 180);

      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
  }
}

class WorldMapPainter extends CustomPainter {
  final Map<String, Path> countryPaths;
  final Set<String> exploredCountries;
  final String? activeCountry; // Currently tapped/highlighted
  
  WorldMapPainter({
    required this.countryPaths,
    required this.exploredCountries,
    this.activeCountry,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw 3 copies side-by-side to simulate an infinite 360 globe wrap
    for (int i = -1; i <= 1; i++) {
      canvas.save();
      canvas.translate(i * size.width, 0);
      
      // 1. Background (Oceans)
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), 
        Paint()..color = const Color(0xFFF4F4EC)
      );

      // 1.5 Draw Vintage Grid (Graticules)
      final gridPaint = Paint()
        ..color = const Color(0x1A111111) // 10% opacity black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
        
      for (double x = 0; x <= size.width; x += size.width / 24) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (double y = 0; y <= size.height; y += size.height / 12) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }

      // 2. Draw all countries
      final Paint fillPaint = Paint()..style = PaintingStyle.fill;
      final Paint borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF111111)
        ..strokeWidth = 0.5;

      for (var entry in countryPaths.entries) {
        final iso = entry.key;
        final path = entry.value;
        
        if (iso == activeCountry) {
          // Tapped state
          fillPaint.color = const Color(0xFF111111);
        } else if (exploredCountries.contains(iso)) {
          // Explored stamp state
          fillPaint.color = const Color(0x66D32F2F); // ~40% opacity red
        } else {
          // Unexplored state
          fillPaint.color = const Color(0xFFD9D4C7);
        }
        
        canvas.drawPath(path, fillPaint);
        
        // If explored, draw a red border too
        if (exploredCountries.contains(iso) && iso != activeCountry) {
          borderPaint.color = const Color(0xFFD32F2F);
          borderPaint.strokeWidth = 1.0;
        } else {
          borderPaint.color = const Color(0xFF111111);
          borderPaint.strokeWidth = 0.5;
        }
        
        canvas.drawPath(path, borderPaint);

        // 3. Draw Country Names (Only for explored or active to keep it clean)
        if (exploredCountries.contains(iso) || iso == activeCountry) {
          final bounds = path.getBounds();
          final center = bounds.center;
          
          // Draw a small locator dot
          canvas.drawCircle(
            center, 
            2.5, 
            Paint()..color = (iso == activeCountry ? const Color(0xFFF4F4EC) : const Color(0xFF111111))
          );
          
          final name = CountryMapper.getName(iso).toUpperCase();
          
          final textPainter = TextPainter(
            text: TextSpan(
              text: name,
              style: TextStyle(
                color: iso == activeCountry ? const Color(0xFFF4F4EC) : const Color(0xFF111111),
                fontSize: 10.0,
                fontFamily: 'Impact',
                letterSpacing: 1.0,
              ),
            ),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
          );
          
          textPainter.layout();
          
          // Draw a solid rect behind the text so it stands out from map lines
          final textRect = Rect.fromCenter(
            center: Offset(center.dx, center.dy + 12),
            width: textPainter.width + 6,
            height: textPainter.height + 4,
          );
          
          canvas.drawRect(
            textRect, 
            Paint()..color = (iso == activeCountry ? const Color(0xFF111111) : const Color(0xFFF4F4EC))
          );
          
          // Paint the text centered below the dot
          textPainter.paint(
            canvas,
            Offset(center.dx - (textPainter.width / 2), center.dy + 12 - (textPainter.height / 2)),
          );
        }
      }
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant WorldMapPainter oldDelegate) {
    return oldDelegate.exploredCountries != exploredCountries ||
           oldDelegate.activeCountry != activeCountry;
  }
  
  // Hit testing with proximity fallback for small countries
  String? hitTestCountry(Offset position) {
    // Normalize position to 0..2000 (primary map width) to support 360 wrap
    // We assume the mapSize is exactly 2000 as defined in world_cinema_screen.dart
    final normalizedX = position.dx % 2000.0;
    final normalizedPosition = Offset(normalizedX, position.dy);

    // 1. Exact hit
    for (var entry in countryPaths.entries) {
      if (entry.value.contains(normalizedPosition)) {
        return entry.key;
      }
    }
    
    // 2. Proximity fallback (find closest country within 24dp)
    String? closestIso;
    double minDistance = 24.0; 
    
    for (var entry in countryPaths.entries) {
      final bounds = entry.value.getBounds();
      final center = bounds.center;
      final distance = (normalizedPosition - center).distance;
      if (distance < minDistance) {
        minDistance = distance;
        closestIso = entry.key;
      }
    }
    
    return closestIso;
  }
}
