import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/movie_model.dart';
import '../../services/watchlist_service.dart';
import '../../movie_details_screen.dart';
import '../../widgets/instagram_share_dialog.dart';

class WatchedTab extends StatefulWidget {
  const WatchedTab({super.key});

  @override
  State<WatchedTab> createState() => _WatchedTabState();
}

class _WatchedTabState extends State<WatchedTab> {
  double _filterRating = 0;
  String _searchQuery = "";
  String _selectedYear = "All";
  String _mediaFilter = "All"; // "All", "Movies", "Series"
  String _watchTypeFilter = "All"; // "All", "New", "Rewatch"
  bool _showAdvancedFilters = true; // Toggled by the FILTERS button
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _getUniqueYears(List<QueryDocumentSnapshot> docs) {
    Set<String> years = {"All"};
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['watchedAt'] != null) {
        try {
          years.add(DateTime.parse(data['watchedAt']).year.toString());
        } catch (_) {}
      }
    }
    List<String> sortedYears = years.toList();
    sortedYears.sort((a, b) => b.compareTo(a));
    return sortedYears;
  }

  Future<void> _updateRating(MovieModel movie, double rating) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('movies')
          .doc(movie.id.toString())
          .update({'userRating': rating});
      
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint("Error updating rating: $e");
    }
  }

  Future<void> _toggleWatchType(MovieModel movie, String currentType) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final newType = currentType == 'rewatch' ? 'new' : 'rewatch';
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('movies')
          .doc(movie.id.toString())
          .update({'watchType': newType});
      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint("Error updating watchType: $e");
    }
  }

  Future<void> _updatePersonalNote(MovieModel movie, String note) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('movies')
          .doc(movie.id.toString())
          .update({'personalNote': note});
      HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint("Error updating review note: $e");
    }
  }

  Future<void> _confirmDeletion(BuildContext context, MovieModel movie, WatchlistService service) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF4F4EC),
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: Color(0xFF111111), width: 2),
        ),
        title: const Text(
          "EXPUNGE ENTRY?",
          style: TextStyle(color: Color(0xFF111111), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'Impact'),
        ),
        content: Text("Remove ${movie.title.toUpperCase()} from your archives?", style: const TextStyle(color: Color(0xFF454545), fontSize: 11)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Color(0xFF111111), fontSize: 10, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF111111)),
            onPressed: () async {
              Navigator.pop(context);
              await service.toggleMovieStatus(movie, 'none');
              _showToast("REMOVED FROM ARCHIVES");
            },
            child: const Text("CONFIRM", style: TextStyle(color: Color(0xFFF4F4EC), fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Color(0xFFF4F4EC), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        backgroundColor: const Color(0xFF111111),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Beautiful rate & review sheet
  void _showRateReviewSheet(MovieModel movie, double currentRating, String? personalNote) {
    final TextEditingController reviewController = TextEditingController(text: personalNote ?? "");
    double tempRating = currentRating;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF4F4EC),
              border: Border(top: BorderSide(color: Color(0xFF111111), width: 3)),
            ),
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPadding),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(height: 4, width: 40, color: const Color(0xFF111111)),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "RATE & REVIEW ARCHIVE",
                    style: const TextStyle(color: Color(0xFF111111), fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 3, fontFamily: 'Impact'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    movie.title.toUpperCase(),
                    style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
                  const Divider(color: Color(0xFF111111), height: 30, thickness: 1.5),
                  
                  // STAR RATING SELECTOR
                  const Text("YOUR RATING", style: TextStyle(color: Color(0xFF111111), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ...List.generate(5, (index) {
                        final starValue = index + 1.0;
                        final isSelected = tempRating >= starValue;
                        final isHalf = tempRating >= starValue - 0.5 && tempRating < starValue;
                        return GestureDetector(
                          onTap: () {
                            setSheetState(() => tempRating = starValue);
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              isSelected
                                  ? Icons.star_rounded
                                  : (isHalf ? Icons.star_half_rounded : Icons.star_border_rounded),
                              color: const Color(0xFFC62828),
                              size: 32,
                            ),
                          ),
                        );
                      }),
                      const Spacer(),
                      Text(
                        "${tempRating.toStringAsFixed(1)} / 5",
                        style: const TextStyle(color: Color(0xFF111111), fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // REVIEW INPUT
                  const Text("PERSONAL REVIEW NOTES", style: TextStyle(color: Color(0xFF111111), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Container(
                    height: 120, // Assigned a robust fixed height to prevent collapsing during keyboard activation
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F4EC),
                      border: Border.all(color: const Color(0xFF111111), width: 2),
                    ),
                    child: TextField(
                      controller: reviewController,
                      maxLines: 4,
                      style: const TextStyle(color: Color(0xFF111111), fontSize: 12, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        hintText: "E.G. AN ABSOLUTE CINEMATIC TRIUMPH, SHATTERING NARRATIVE CONVENTIONS...",
                        hintStyle: TextStyle(color: Color(0xFF888882), fontSize: 10, letterSpacing: 1),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // SAVE BUTTON
                  GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      await _updateRating(movie, tempRating);
                      await _updatePersonalNote(movie, reviewController.text.trim());
                      _showToast("REVIEW & RATING LOGGED SUCCESSFULLY");
                    },
                    child: Container(
                      width: double.infinity,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        border: Border.all(color: const Color(0xFF111111), width: 2),
                        boxShadow: const [BoxShadow(color: Color(0xFFC62828), offset: Offset(3, 3))],
                      ),
                      child: const Center(
                        child: Text(
                          "SAVE ARCHIVAL LOG",
                          style: TextStyle(color: Color(0xFFF4F4EC), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 3, fontFamily: 'Impact'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    final WatchlistService service = WatchlistService();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('movies')
          .where('status', isEqualTo: 'watched')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF111111)));
        }

        var allDocs = snapshot.data?.docs ?? [];
        
        int movieCount = allDocs.where((d) => (d.data() as Map)['isTvShow'] != true).length;
        int tvCount = allDocs.length - movieCount;

        int newCount = allDocs.where((d) => (d.data() as Map)['watchType'] == 'new').length;
        int rewatchCount = allDocs.where((d) => (d.data() as Map)['watchType'] == 'rewatch').length;

        var displayedDocs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final title = (data['title'] ?? "").toString().toLowerCase();
          final isTv = data['isTvShow'] ?? false;
          final userRating = (data['userRating'] ?? 0.0).toDouble();
          final watchType = (data['watchType'] ?? 'new') as String;
          final personalNote = data['personalNote'] as String?;
          
          final matchesSearch = title.contains(_searchQuery.toLowerCase());
          
          // Rating quick filter: if _filterRating > 0, filter movies that match the rounded rating or exact range
          final matchesRating = _filterRating == 0 || (userRating >= _filterRating && userRating < _filterRating + 1.0);
          
          final matchesMedia = _mediaFilter == "All" || (_mediaFilter == "Movies" && !isTv) || (_mediaFilter == "Series" && isTv);
          
          // Custom sort/filter checks
          bool matchesWatchType = true;
          if (_watchTypeFilter == "New") {
            matchesWatchType = watchType == 'new';
          } else if (_watchTypeFilter == "Rewatch") {
            matchesWatchType = watchType == 'rewatch';
          } else if (_watchTypeFilter == "Reviews") {
            matchesWatchType = personalNote != null && personalNote.trim().isNotEmpty;
          }

          bool matchesYear = _selectedYear == "All";
          if (data['watchedAt'] != null) {
            try {
              matchesYear = matchesYear || DateTime.parse(data['watchedAt']).year.toString() == _selectedYear;
            } catch (_) {}
          }
          return matchesSearch && matchesRating && matchesYear && matchesMedia && matchesWatchType;
        }).toList()

        // Sort by watchedAt — newest first
        ..sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aDate = aData['watchedAt'] != null ? DateTime.tryParse(aData['watchedAt']) : null;
          final bDate = bData['watchedAt'] != null ? DateTime.tryParse(bData['watchedAt']) : null;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });

        final yearsList = _getUniqueYears(allDocs);

        return Column(
          children: [
            // 1. STATS METRICS HEADER
            _buildArchivalSummary(movieCount, tvCount, newCount, rewatchCount),
            const Divider(color: Color(0xFF111111), height: 1.5, thickness: 1.5),

            // 2. QUICK CATEGORIES TOGGLES & DROPDOWNS
            _buildFilterRow(yearsList),
            const Divider(color: Color(0xFF111111), height: 1.5, thickness: 1.5),



            // 5. MOVIES LIST
            Expanded(
              child: displayedDocs.isEmpty 
                ? const Center(
                    child: Text(
                      "NO ARCHIVAL RECORD FOUND",
                      style: TextStyle(color: Color(0xFF111111), letterSpacing: 3, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Impact'),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    physics: const BouncingScrollPhysics(),
                    itemCount: displayedDocs.length,
                    itemBuilder: (context, index) {
                      final doc = displayedDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final movie = MovieModel.fromJson(data);
                      return _buildPremiumMovieCard(movie, data, service);
                    },
                  ),
            ),
          ],
        );
      },
    );
  }

  // --- 1. ARCHIVAL SUMMARY METRICS ---
  Widget _buildArchivalSummary(int movies, int shows, int newCount, int rewatchCount) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      color: const Color(0xFFF4F4EC),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem("MOVIES", movies.toString()),
          _verticalDivider(),
          _statItem("SERIES", shows.toString()),
          _verticalDivider(),
          _statItem("TOTAL", (movies + shows).toString(), color: const Color(0xFFD32F2F)),
          _verticalDivider(),
          _statItem("NEW", newCount.toString()),
          _verticalDivider(),
          _statItem("REWATCH", rewatchCount.toString()),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, {Color color = const Color(0xFF111111)}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF111111), fontSize: 8, letterSpacing: 2, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 30, fontWeight: FontWeight.w900, fontFamily: 'Impact', height: 1.0),
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1.5,
      height: 32,
      color: const Color(0xFF111111).withOpacity(0.12),
    );
  }

  // --- 2. CATEGORIES TOGGLES & DROPDOWNS ---
  Widget _buildFilterRow(List<String> years) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: const Color(0xFFF4F4EC),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // QUICK TOGGLE CHIPS
            _buildCategoryChip("ALL", Icons.grid_view_rounded, _mediaFilter == "All"),
            const SizedBox(width: 8),
            _buildCategoryChip("MOVIES", null, _mediaFilter == "Movies"),
            const SizedBox(width: 8),
            _buildCategoryChip("SERIES", null, _mediaFilter == "Series"),

            const SizedBox(height: 25, child: VerticalDivider(color: Color(0xFF111111), thickness: 1.5, width: 24)),

            // DROPDOWN TYPE FILTER
            SizedBox(
              width: 105,
              child: _buildStyledDropdown(
                value: _watchTypeFilter == "Reviews" ? "Reviews" : _watchTypeFilter,
                hint: "TYPE",
                options: const ["All", "New", "Rewatch", "Reviews"],
                onChanged: (val) => setState(() => _watchTypeFilter = val!),
              ),
            ),
            const SizedBox(width: 8),

            // DROPDOWN YEAR FILTER
            SizedBox(
              width: 85,
              child: _buildStyledDropdown(
                value: _selectedYear,
                hint: "YEAR",
                options: years,
                onChanged: (val) => setState(() => _selectedYear = val!),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, IconData? icon, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _mediaFilter = label == "ALL" ? "All" : (label == "MOVIES" ? "Movies" : "Series")),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFC62828) : const Color(0xFFF4F4EC),
          border: Border.all(color: const Color(0xFF111111), width: 1.5),
          boxShadow: isSelected ? const [BoxShadow(color: Color(0xFF111111), offset: Offset(2, 2))] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: isSelected ? const Color(0xFFF4F4EC) : const Color(0xFF111111)),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFFF4F4EC) : const Color(0xFF111111),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyledDropdown({
    required String value,
    required String hint,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      offset: const Offset(0, 42),
      itemBuilder: (context) => options.map((option) => PopupMenuItem(
        value: option,
        child: Text(
          option.toUpperCase(),
          style: const TextStyle(color: Color(0xFF111111), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
      )).toList(),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4EC),
          border: Border.all(color: const Color(0xFF111111), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value.toUpperCase(),
              style: const TextStyle(color: Color(0xFF111111), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
            const Icon(Icons.arrow_drop_down, color: Color(0xFF111111), size: 16),
          ],
        ),
      ),
    );
  }

  // --- 3. SEARCH & ADVANCED FILTERS TOGGLE ROW ---
  Widget _buildSearchRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          // SEARCH INPUT FIELD
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4EC),
                border: Border.all(color: const Color(0xFF111111), width: 2),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Color(0xFF111111), fontSize: 12, fontWeight: FontWeight.bold),
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: const InputDecoration(
                  hintText: "FILTER WATCHED...",
                  hintStyle: TextStyle(color: Color(0xFF888882), fontSize: 10, letterSpacing: 2),
                  prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF111111), size: 16),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.only(top: 8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ADVANCED FILTERS TOGGLE BUTTON
          GestureDetector(
            onTap: () => setState(() => _showAdvancedFilters = !_showAdvancedFilters),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _showAdvancedFilters ? const Color(0xFF111111) : const Color(0xFFF4F4EC),
                border: Border.all(color: const Color(0xFF111111), width: 2),
                boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(2, 2))],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 14,
                    color: _showAdvancedFilters ? const Color(0xFFF4F4EC) : const Color(0xFF111111),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "FILTERS",
                    style: TextStyle(
                      color: _showAdvancedFilters ? const Color(0xFFF4F4EC) : const Color(0xFF111111),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. STAR RATING QUICK FILTERS BAR ---
  Widget _buildRatingQuickFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [1.0, 2.0, 3.0, 4.0, 5.0].map((val) {
          final bool isSelected = _filterRating == val;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _filterRating = isSelected ? 0 : val),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 34,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF111111) : const Color(0xFFF4F4EC),
                  border: Border.all(color: const Color(0xFF111111), width: 1.5),
                  boxShadow: isSelected ? const [BoxShadow(color: Color(0xFF111111), offset: Offset(2, 2))] : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${val.toInt()} ",
                        style: TextStyle(
                          color: isSelected ? const Color(0xFFF4F4EC) : const Color(0xFF111111),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Icon(
                        Icons.star_rounded,
                        size: 11,
                        color: isSelected ? const Color(0xFFC62828) : const Color(0xFF111111),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- 5. SORT BY / WATCH TYPE CHIPS BAR ---
  Widget _buildWatchTypeFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        children: [
          const Icon(Icons.sort_rounded, color: Color(0xFF111111), size: 14),
          const SizedBox(width: 8),
          const Text(
            "SORT BY",
            style: TextStyle(color: Color(0xFF111111), fontSize: 8, letterSpacing: 2, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildWatchTypeChip("All", Icons.format_list_bulleted_rounded),
                  const SizedBox(width: 8),
                  _buildWatchTypeChip("New", Icons.local_offer_outlined),
                  const SizedBox(width: 8),
                  _buildWatchTypeChip("Rewatch", Icons.autorenew_rounded),
                  const SizedBox(width: 8),
                  _buildWatchTypeChip("Reviews", Icons.chat_bubble_outline_rounded),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWatchTypeChip(String label, IconData icon) {
    final bool isSelected = _watchTypeFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _watchTypeFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF111111) : const Color(0xFFF4F4EC),
          border: Border.all(color: const Color(0xFF111111), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 11,
              color: isSelected ? const Color(0xFFF4F4EC) : const Color(0xFF111111),
            ),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: isSelected ? const Color(0xFFF4F4EC) : const Color(0xFF111111),
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 6. REDESIGNED HIGH-FIDELITY WATCHED MOVIE CARD ---
  Widget _buildPremiumMovieCard(MovieModel movie, Map<String, dynamic> data, WatchlistService service) {
    final String dateLabel = data['watchedAt'] != null 
        ? DateFormat('MMMM d, yyyy').format(DateTime.parse(data['watchedAt'])) 
        : "VINTAGE ENTRY";
    final double currentRating = (data['userRating'] ?? 0.0).toDouble();
    final String watchType = (data['watchType'] ?? 'new') as String;
    final bool isRewatch = watchType == 'rewatch';
    final String? personalNote = data['personalNote'] as String?;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4EC),
        border: Border.all(color: const Color(0xFF111111), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(3, 3))],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Poster Block
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MovieDetailsScreen(movie: movie))),
              child: Container(
                width: 96,
                decoration: BoxDecoration(
                  border: const Border(right: BorderSide(color: Color(0xFF111111), width: 1.5)),
                  image: DecorationImage(
                    image: NetworkImage(
                      movie.posterPath.replaceAll('image.tmdb.org', 'images.tmdb.org'),
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            // Middle Details Column
            Expanded(
              child: Stack(
                children: [
                  // HANGING RED BOOKMARK
                  Positioned(
                    top: 0,
                    left: 8,
                    child: Container(
                      width: 7,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFFC62828),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(1.5)),
                      ),
                    ),
                  ),

                  // Dedicated Top-Right Action Buttons
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => InstagramShareDialog.show(context, movie, currentRating, data['watchedAt']),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F4EC),
                              border: Border.all(color: const Color(0xFF111111), width: 1.5),
                              boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(1.5, 1.5))],
                            ),
                            child: const Icon(Icons.share_outlined, color: Color(0xFF111111), size: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _confirmDeletion(context, movie, service),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F4EC),
                              border: Border.all(color: const Color(0xFF111111), width: 1.5),
                              boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(1.5, 1.5))],
                            ),
                            child: const Icon(Icons.delete_outline_rounded, color: Color(0xFF111111), size: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // main details content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 10, 64, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MovieDetailsScreen(movie: movie))),
                          child: Text(
                            movie.title.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF111111),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Impact',
                              letterSpacing: 0.5,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),

                        // Date Logged
                        Text(
                          "LOGGED: ${dateLabel.toUpperCase()}",
                          style: const TextStyle(color: Color(0xFF888882), fontSize: 8.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 8),

                        // Watch type badge
                        GestureDetector(
                          onTap: () => _toggleWatchType(movie, watchType),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                            decoration: const BoxDecoration(
                              color: Color(0xFF111111),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isRewatch ? Icons.autorenew_rounded : Icons.local_offer_outlined,
                                  size: 7.5,
                                  color: const Color(0xFFF4F4EC),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  isRewatch ? "REWATCHED" : "NEW",
                                  style: const TextStyle(
                                    color: Color(0xFFF4F4EC),
                                    fontSize: 7.0,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),

                        // Rating Stats Section
                        const Text(
                          "YOUR RATING",
                          style: TextStyle(color: Color(0xFF888882), fontSize: 7.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 1),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              "${currentRating.toStringAsFixed(1)} ",
                              style: const TextStyle(
                                color: Color(0xFF111111),
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Impact',
                                height: 1.0,
                              ),
                            ),
                            const Text(
                              "/ 5",
                              style: TextStyle(
                                color: Color(0xFF888882),
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                height: 1.8,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Right Red Review Block
            GestureDetector(
              onTap: () => _showRateReviewSheet(movie, currentRating, personalNote),
              child: Container(
                width: 52,
                color: const Color(0xFFC62828),
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFF4F4EC), size: 14),
                    const SizedBox(height: 3),
                    const Text(
                      "REVIEW",
                      style: TextStyle(color: Color(0xFFF4F4EC), fontSize: 7.0, fontWeight: FontWeight.w900, letterSpacing: 0.5, fontFamily: 'Impact'),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      data['watchedAt'] != null 
                          ? DateFormat('MMM d').format(DateTime.parse(data['watchedAt'])) 
                          : "LOG",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFF4F4EC), fontSize: 6.0, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}