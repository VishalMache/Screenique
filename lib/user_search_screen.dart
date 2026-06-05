import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'public_profile_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  
  List<DocumentSnapshot> _searchResults = [];
  List<String> _recentSearches = [];
  bool _isSearching = false;

  final Color _bgColor = const Color(0xFFF4F4EC);
  final Color _noirColor = const Color(0xFF111111);
  final Color _accentColor = const Color(0xFFD32F2F);

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList('recentUserSearches') ?? [];
    });
  }

  Future<void> _saveRecentSearch(String term) async {
    final prefs = await SharedPreferences.getInstance();
    final searches = prefs.getStringList('recentUserSearches') ?? [];
    
    // Remove if exists to push it to the top
    searches.remove(term);
    searches.insert(0, term);
    
    // Keep only last 10 searches
    if (searches.length > 10) {
      searches.removeLast();
    }
    
    await prefs.setStringList('recentUserSearches', searches);
    if (mounted) {
      setState(() {
        _recentSearches = searches;
      });
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    final query = _searchController.text.trim();
    
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final lowerQuery = query.toLowerCase();
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: lowerQuery)
          .where('username', isLessThanOrEqualTo: lowerQuery + '\uf8ff')
          .limit(10)
          .get();

      if (mounted) {
        setState(() {
          _searchResults = snapshot.docs;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint("Error searching users: $e");
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _navigateToProfile(String uid, String displayName) {
    _saveRecentSearch(displayName);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PublicProfileScreen(uid: uid)),
    );
  }

  void _removeRecentSearch(String term) async {
    final prefs = await SharedPreferences.getInstance();
    final searches = prefs.getStringList('recentUserSearches') ?? [];
    searches.remove(term);
    await prefs.setStringList('recentUserSearches', searches);
    if (mounted) {
      setState(() {
        _recentSearches = searches;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: _noirColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(color: _noirColor, fontWeight: FontWeight.bold, fontSize: 14),
          decoration: InputDecoration(
            hintText: "SEARCH FOR CINEPHILES...",
            hintStyle: TextStyle(color: _noirColor.withOpacity(0.5), fontSize: 12, letterSpacing: 1, fontFamily: 'Impact'),
            border: InputBorder.none,
          ),
          cursorColor: _accentColor,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2.0),
          child: Container(
            color: _noirColor,
            height: 2.0,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return Center(
        child: CircularProgressIndicator(color: _noirColor),
      );
    }

    if (_searchController.text.isEmpty) {
      return _buildRecentSearches();
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 60, color: _noirColor.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(
              "NO CINEPHILES FOUND",
              style: TextStyle(
                color: _noirColor.withOpacity(0.5),
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontFamily: 'Impact',
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final doc = _searchResults[index];
        final data = doc.data() as Map<String, dynamic>? ?? {};
        
        final String displayName = data['name'] ?? 'Unknown Viewer';
        final String username = data['username'] ?? '';
        final bool isPublic = data['isPublic'] ?? true;
        final int followers = data['followersCount'] ?? 0;

        return ListTile(
          onTap: () => _navigateToProfile(doc.id, username.isNotEmpty ? '@$username' : displayName),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _noirColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Color(0xFFF4F4EC),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Impact',
                ),
              ),
            ),
          ),
          title: Text(
            displayName.toUpperCase(),
            style: TextStyle(
              color: _noirColor,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              fontFamily: 'Impact',
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (username.isNotEmpty)
                Text(
                  "@$username",
                  style: TextStyle(
                    color: _accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              const SizedBox(height: 2),
              Row(
                children: [
                  if (isPublic) ...[
                    Icon(Icons.people_alt_rounded, size: 12, color: _noirColor.withOpacity(0.6)),
                    const SizedBox(width: 4),
                    Text(
                      "$followers FOLLOWERS",
                      style: TextStyle(
                        color: _noirColor.withOpacity(0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ] else ...[
                    Icon(Icons.lock_rounded, size: 12, color: _accentColor),
                    const SizedBox(width: 4),
                    Text(
                      "CLASSIFIED DOSSIER",
                      style: TextStyle(
                        color: _accentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentSearches() {
    if (_recentSearches.isEmpty) {
      return Center(
        child: Text(
          "SEARCH HISTORY EMPTY",
          style: TextStyle(
            color: _noirColor.withOpacity(0.3),
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontFamily: 'Impact',
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Text(
            "RECENT SEARCHES",
            style: TextStyle(
              color: _noirColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _recentSearches.length,
            itemBuilder: (context, index) {
              final term = _recentSearches[index];
              return ListTile(
                onTap: () {
                  _searchController.text = term;
                  _searchController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _searchController.text.length),
                  );
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: Icon(Icons.history, color: _noirColor.withOpacity(0.5)),
                title: Text(
                  term,
                  style: TextStyle(
                    color: _noirColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.close, color: _noirColor.withOpacity(0.5), size: 16),
                  onPressed: () => _removeRecentSearch(term),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
