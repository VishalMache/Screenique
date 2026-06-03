import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'world_map_painter.dart';
import '../../services/world_cinema_service.dart';
import '../../data/cinematic_languages.dart';
import 'country_dossier_sheet.dart';
import 'country_search_sheet.dart';
import 'dart:async';

class WorldCinemaScreen extends StatefulWidget {
  const WorldCinemaScreen({super.key});

  @override
  State<WorldCinemaScreen> createState() => _WorldCinemaScreenState();
}

class _WorldCinemaScreenState extends State<WorldCinemaScreen> {
  final WorldCinemaService _service = WorldCinemaService();
  
  Map<String, Path> _countryPaths = {};
  Set<String> _exploredCountries = {};
  Set<String> _highlightedCountries = {};
  String? _activeCountry;
  String? _selectedLanguageCode;
  bool _isLoadingMap = true;
  
  // A standard map size to base our projection on.
  // The CustomPaint will scale this to fit the screen.
  final Size _baseMapSize = const Size(2000, 1000); 
  final TransformationController _transformationController = TransformationController();
  
  @override
  void initState() {
    super.initState();
    _initMapData();
    
    // Center the map on continental Europe/Africa on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      final scale = 0.5; // Starting zoom level
      
      // Center of the map is 1000, 500
      final dx = (size.width / 2) - (1000 * scale);
      final dy = (size.height / 2) - (500 * scale);
      
      _transformationController.value = Matrix4.identity()
        ..translate(dx, dy)
        ..scale(scale);
    });
  }

  Future<void> _initMapData() async {
    try {
      // 1. Load GeoJSON String
      final String geoJsonStr = await rootBundle.loadString('assets/world.geojson');
      
      // 2. Parse into Paths (compute could be used if this is too slow on main thread)
      final paths = GeoJsonParser.parse(geoJsonStr, _baseMapSize);
      
      // 3. Fetch user's explored archive
      final explored = await _service.getExploredCountries();
      
      if (mounted) {
        setState(() {
          _countryPaths = paths;
          _exploredCountries = explored;
          _isLoadingMap = false;
        });
      }
    } catch (e) {
      debugPrint("Error initializing map data: $e");
      if (mounted) setState(() => _isLoadingMap = false);
    }
  }

  void _handleTap(TapDownDetails details) {
    if (_countryPaths.isEmpty) return;
    
    // Scale tap position to base map size
    // Wait, the tap is on the CustomPaint, whose size matches the InteractiveViewer child.
    // The InteractiveViewer child is a SizedBox of _baseMapSize.
    final position = details.localPosition;
    
    // Hit test using painter logic directly
    final painter = WorldMapPainter(
      countryPaths: _countryPaths,
      exploredCountries: _exploredCountries,
    );
    
    final tappedIso = painter.hitTestCountry(position);
    
    if (tappedIso != null) {
      _showCountryDossier(tappedIso);
    }
  }

  void _showCountryDossier(String iso) {
    setState(() => _activeCountry = iso);
    
    // The country name requires mapping ISO to Name. 
    // We can extract this from a helper or GeoJSON if needed, but for now we'll pass ISO
    // and let the dossier resolve the name or we can extract it quickly here.
    // Actually, passing the ISO is enough, the Dossier can resolve it.
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
        builder: (context) => CountryDossierSheet(
          isoCode: iso, 
          languageFilter: _selectedLanguageCode,
        ),
      ).then((_) {
        // When closed, refresh explored stats in case they added a movie, and clear active
        _refreshExploredStats();
        if (mounted) setState(() => _activeCountry = null);
      });
    }

    void _selectLanguage(String? code) {
      setState(() {
        if (_selectedLanguageCode == code) {
          // Deselect
          _selectedLanguageCode = null;
          _highlightedCountries.clear();
        } else {
          _selectedLanguageCode = code;
          if (code != null) {
            final langData = CinematicLanguages.languages.firstWhere((l) => l['code'] == code);
            _highlightedCountries = Set<String>.from(langData['countries'] as List);
          } else {
            _highlightedCountries.clear();
          }
        }
      });
    }
  
  Future<void> _refreshExploredStats() async {
    final explored = await _service.getExploredCountries();
    if (mounted) {
      setState(() => _exploredCountries = explored);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4EC),
      body: _isLoadingMap
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF111111)))
          : Stack(
              children: [
                // 1. The Interactive Map
                Positioned.fill(
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 0.1,
                    maxScale: 6.0,
                    constrained: false, // Allows the child to be larger than screen
                    boundaryMargin: EdgeInsets.all(MediaQuery.of(context).size.width),
                    child: GestureDetector(
                      onTapDown: _handleTap,
                      child: SizedBox(
                        width: _baseMapSize.width,
                        height: _baseMapSize.height,
                        child: CustomPaint(
                          painter: WorldMapPainter(
                            countryPaths: _countryPaths,
                            exploredCountries: _exploredCountries,
                            highlightedCountries: _highlightedCountries,
                            activeCountry: _activeCountry,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // 2. UI Overlay: Expanded Search Bar
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (context) => FractionallySizedBox(
                          heightFactor: 0.8,
                          child: CountrySearchSheet(
                            onSelect: (iso) => _showCountryDossier(iso),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      height: 54,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F4EC),
                        border: Border.all(color: const Color(0xFF111111), width: 2),
                        boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(4, 4))],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded, color: Color(0xFF111111), size: 24),
                          const SizedBox(width: 12),
                          const Text(
                            "SEARCH ATLAS...",
                            style: TextStyle(
                              color: Color(0xFF111111),
                              fontFamily: 'Impact',
                              fontSize: 18,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const Spacer(),
                          // Optional: subtle icon to indicate it's a global search
                          const Icon(Icons.public, color: Color(0xFF111111), size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // 3. Language Pills
                Positioned(
                  bottom: 90, // Above the close button
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: 40,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: CinematicLanguages.languages.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final lang = CinematicLanguages.languages[index];
                        final isSelected = _selectedLanguageCode == lang['code'];
                        return GestureDetector(
                          onTap: () => _selectLanguage(lang['code']),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF111111) : const Color(0xFFF4F4EC),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF111111), width: 1.5),
                              boxShadow: isSelected 
                                  ? const [BoxShadow(color: Color(0xFFFFB300), offset: Offset(2, 2))]
                                  : const [BoxShadow(color: Color(0xFF111111), offset: Offset(2, 2))],
                            ),
                            child: Center(
                              child: Text(
                                lang['name'].toString().toUpperCase(),
                                style: TextStyle(
                                  color: isSelected ? const Color(0xFFF4F4EC) : const Color(0xFF111111),
                                  fontFamily: 'Impact',
                                  fontSize: 14,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                
                // 4. Back Button
                Positioned(
                  bottom: 30,
                  left: MediaQuery.of(context).size.width / 2 - 25,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF111111), width: 1.5),
                        boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(2, 2))],
                      ),
                      child: const Icon(Icons.close_rounded, color: Color(0xFFF4F4EC)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
