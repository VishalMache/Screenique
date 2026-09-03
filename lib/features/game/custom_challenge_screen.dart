import 'package:flutter/material.dart';
import '../../models/game_models.dart';
import '../../models/movie_model.dart';
import 'choose_difficulty_screen.dart';

class CustomChallengeScreen extends StatefulWidget {
  const CustomChallengeScreen({super.key});

  @override
  State<CustomChallengeScreen> createState() => _CustomChallengeScreenState();
}

class _CustomChallengeScreenState extends State<CustomChallengeScreen> {
  // Genre selection
  int? _selectedGenreId;
  String? _selectedGenreName;

  // Era selection
  int? _selectedYearFrom;
  int? _selectedYearTo;
  String? _selectedEraName;

  // Director — search
  final TextEditingController _directorController = TextEditingController();
  int? _selectedPersonId;
  String? _selectedPersonName;
  bool _searchingDirector = false;

  static const List<Map<String, dynamic>> _genres = [
    {'id': 28, 'name': 'Action', 'emoji': '💥'},
    {'id': 35, 'name': 'Comedy', 'emoji': '😂'},
    {'id': 18, 'name': 'Drama', 'emoji': '🎭'},
    {'id': 27, 'name': 'Horror', 'emoji': '👻'},
    {'id': 10749, 'name': 'Romance', 'emoji': '❤️'},
    {'id': 878, 'name': 'Sci-Fi', 'emoji': '🚀'},
    {'id': 53, 'name': 'Thriller', 'emoji': '🕵️'},
    {'id': 14, 'name': 'Fantasy', 'emoji': '🧙'},
    {'id': 12, 'name': 'Adventure', 'emoji': '🏔️'},
    {'id': 80, 'name': 'Crime', 'emoji': '🔫'},
    {'id': 16, 'name': 'Animation', 'emoji': '🎨'},
    {'id': 99, 'name': 'Documentary', 'emoji': '📷'},
  ];

  static const List<Map<String, dynamic>> _eras = [
    {'name': '80s', 'from': 1980, 'to': 1989, 'emoji': '🎞️'},
    {'name': '90s', 'from': 1990, 'to': 1999, 'emoji': '📼'},
    {'name': '2000s', 'from': 2000, 'to': 2009, 'emoji': '💿'},
    {'name': '2010s', 'from': 2010, 'to': 2019, 'emoji': '📱'},
    {'name': '2020s', 'from': 2020, 'to': 2025, 'emoji': '✨'},
  ];

  // Curated popular directors for quick selection
  static const List<Map<String, dynamic>> _popularDirectors = [
    {'id': 525, 'name': 'Christopher Nolan', 'emoji': '🎬'},
    {'id': 138, 'name': 'Quentin Tarantino', 'emoji': '👑'},
    {'id': 1032, 'name': 'Martin Scorsese', 'emoji': '🎭'},
    {'id': 488, 'name': 'Steven Spielberg', 'emoji': '🎥'},
    {'id': 10814, 'name': 'Alfonso Cuarón', 'emoji': '🌎'},
    {'id': 240, 'name': 'Stanley Kubrick', 'emoji': '🧠'},
    {'id': 1172821, 'name': 'S.S. Rajamouli', 'emoji': '🇮🇳'},
    {'id': 21684, 'name': 'Bong Joon-ho', 'emoji': '🇰🇷'},
  ];

  bool get _canProceed =>
      _selectedGenreId != null ||
      _selectedYearFrom != null ||
      _selectedPersonId != null;

  void _proceed() {
    if (!_canProceed) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChooseDifficultyScreen(
          challengeType: ChallengeType.custom,
          customGenreId: _selectedGenreId,
          customYearFrom: _selectedYearFrom,
          customYearTo: _selectedYearTo,
          customPersonId: _selectedPersonId,
          customLabel: _buildCustomLabel(),
        ),
      ),
    );
  }

  String _buildCustomLabel() {
    final parts = <String>[];
    if (_selectedGenreName != null) parts.add(_selectedGenreName!);
    if (_selectedEraName != null) parts.add(_selectedEraName!);
    if (_selectedPersonName != null) parts.add(_selectedPersonName!);
    return parts.isEmpty ? 'Custom' : parts.join(' · ');
  }

  @override
  void dispose() {
    _directorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09090B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFFF4F4EC), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'CUSTOM CHALLENGE',
          style: TextStyle(
            color: Color(0xFFF4F4EC),
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Genre
                  _buildSectionLabel('🎭 CHOOSE GENRE'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _genres
                        .map((g) => _buildFilterChip(
                              label: '${g['emoji']} ${g['name']}',
                              selected: _selectedGenreId == g['id'],
                              onTap: () => setState(() {
                                if (_selectedGenreId == g['id']) {
                                  _selectedGenreId = null;
                                  _selectedGenreName = null;
                                } else {
                                  _selectedGenreId = g['id'] as int;
                                  _selectedGenreName = g['name'] as String;
                                }
                              }),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 28),

                  // Era
                  _buildSectionLabel('📅 CHOOSE ERA'),
                  const SizedBox(height: 12),
                  Row(
                    children: _eras
                        .map((e) => Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  if (_selectedEraName == e['name']) {
                                    _selectedYearFrom = null;
                                    _selectedYearTo = null;
                                    _selectedEraName = null;
                                  } else {
                                    _selectedYearFrom = e['from'] as int;
                                    _selectedYearTo = e['to'] as int;
                                    _selectedEraName = e['name'] as String;
                                  }
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                      color: _selectedEraName == e['name']
                                          ? const Color(0xFFD32F2F)
                                          : const Color(0xFF141416),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: _selectedEraName == e['name']
                                            ? const Color(0xFFD32F2F)
                                            : const Color(0xFFD32F2F).withOpacity(0.2),
                                      ),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(e['emoji'] as String,
                                          style: const TextStyle(fontSize: 14)),
                                      const SizedBox(height: 3),
                                      Text(
                                        e['name'] as String,
                                        style: const TextStyle(
                                          color: Color(0xFFF4F4EC),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 28),

                  // Director
                  _buildSectionLabel('🎬 CHOOSE DIRECTOR (OPTIONAL)'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _popularDirectors
                        .map((d) => _buildFilterChip(
                              label: '${d['emoji']} ${d['name']}',
                              selected: _selectedPersonId == d['id'],
                              onTap: () => setState(() {
                                if (_selectedPersonId == d['id']) {
                                  _selectedPersonId = null;
                                  _selectedPersonName = null;
                                } else {
                                  _selectedPersonId = d['id'] as int;
                                  _selectedPersonName = d['name'] as String;
                                }
                              }),
                            ))
                        .toList(),
                  ),

                  // Summary
                  if (_canProceed) ...[
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: const Color(0xFFD32F2F).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Color(0xFFD32F2F), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Your challenge: ${_buildCustomLabel()}',
                              style: const TextStyle(
                                color: Color(0xFFF4F4EC),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          // CTA
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SizedBox(
              width: double.infinity,
              child: Material(
                color: _canProceed
                    ? const Color(0xFFD32F2F)
                    : const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: _canProceed ? _proceed : null,
                    child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      _canProceed ? 'CONTINUE →' : 'SELECT AT LEAST ONE FILTER',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _canProceed
                            ? const Color(0xFFF4F4EC)
                            : const Color(0xFF444444),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF888882),
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFD32F2F) : const Color(0xFF141416),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected
                ? const Color(0xFFD32F2F)
                : const Color(0xFFD32F2F).withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFFF4F4EC) : const Color(0xFF888882),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
