import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import '../../models/movie_model.dart';
import '../../services/movie_service.dart';
import '../../services/experience_service.dart';

class AddExperienceScreen extends StatefulWidget {
  const AddExperienceScreen({super.key});

  @override
  State<AddExperienceScreen> createState() => _AddExperienceScreenState();
}

class _AddExperienceScreenState extends State<AddExperienceScreen> {
  final MovieService _movieService = MovieService();
  final ExperienceService _expService = ExperienceService();
  
  MovieModel? _selectedMovie;
  final TextEditingController _cinemaController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _peopleController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now(); 
  double _userRating = 0.0;
  bool _isSaving = false;

  static const Color noirCrimson = Color(0xFF111111);

  static const List<String> _cinemaOptions = [
    'IMAX', 'AMC Theatres', 'Regal Cinemas', 'Cinemark', 'PVR Cinemas', 
    'INOX', 'Cineplex', 'Vue', 'Gaumont', 'Pathé', 'Dolby Cinema'
  ];

  void _selectMovie() async {
    final MovieModel? picked = await showSearch<MovieModel?>(
      context: context,
      delegate: MovieSearchDelegate(_movieService),
    );
    if (picked != null) setState(() => _selectedMovie = picked);
  }

  @override
  void dispose() {
    _cinemaController.dispose();
    _noteController.dispose();
    _peopleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4EC),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "ADD NEW EXPERIENCE", 
          style: TextStyle(color: Color(0xFF111111), letterSpacing: 2, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Impact')
        ), 
        centerTitle: true,
        backgroundColor: Colors.transparent, 
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF111111)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          if (_selectedMovie != null)
            Positioned.fill(
              child: Image.network(_selectedMovie!.posterPath, fit: BoxFit.cover),
            ),
          Positioned.fill(
            child: Container(color: const Color(0xFFF4F4EC).withOpacity(0.95)),
          ),

          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 120, 24, 50),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("SELECTED MEDIA"),
                _buildMovieSelector(),
                const SizedBox(height: 30),
                
                _buildSectionHeader("WATCHED ON"),
                _buildGlassContainer(child: _buildDateTile()),
                const SizedBox(height: 30),

                _buildSectionHeader("YOUR RATING"),
                _buildGlassContainer(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) => IconButton(
                        onPressed: () => setState(() => _userRating = index + 1.0),
                        icon: Icon(
                          index < _userRating ? Icons.star : Icons.star_border, 
                          color: index < _userRating ? noirCrimson : const Color(0xFF454545), 
                          size: 32
                        ),
                      )),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                _buildSectionHeader("VENUE & MEMORIES"),
                _buildCinemaAutocomplete(),
                _buildTextField(_peopleController, "COMPANIONS / WATCHED WITH...", Icons.people_outline),
                _buildTextField(_noteController, "WRITE YOUR MEMORY...", Icons.edit_note, maxLines: 3),
                
                const SizedBox(height: 40),
                _buildSaveButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title.toUpperCase(), style: const TextStyle(color: Color(0xFF111111), fontSize: 16, letterSpacing: 2, fontWeight: FontWeight.bold, fontFamily: 'Impact')),
    );
  }

  Widget _buildGlassContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4EC),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFF111111), width: 2),
        boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(4, 4))],
      ),
      child: child,
    );
  }

  Widget _buildCinemaAutocomplete() {
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text == '') return const Iterable<String>.empty();
        return _cinemaOptions.where((option) => 
            option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      onSelected: (selection) {
        setState(() => _cinemaController.text = selection);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return _buildTextField(
          controller, 
          "LOCATION / CINEMA NAME", 
          Icons.location_on_outlined, 
          focusNode: focusNode,
          onChanged: (val) => _cinemaController.text = val,
        );
      },
    );
  }

  Widget _buildMovieSelector() {
    return GestureDetector(
      onTap: _selectMovie,
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4EC),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: const Color(0xFF111111), width: 2),
          boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(4, 4))],
        ),
        child: _selectedMovie == null 
          ? const Center(child: Text("SELECT MOVIE / SERIES", style: TextStyle(color: Color(0xFF454545), letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold)))
          : Row(
              children: [
                Hero(
                  tag: 'movie-poster-${_selectedMovie!.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8), 
                    child: Image.network(_selectedMovie!.posterPath, width: 70, height: 100, fit: BoxFit.cover)
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _selectedMovie!.isTvShow ? Colors.blueAccent : noirCrimson,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _selectedMovie!.isTvShow ? "TV" : "MOVIE",
                              style: const TextStyle(color: Color(0xFFF4F4EC), fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(_selectedMovie!.releaseDate.split('-')[0], style: const TextStyle(color: Color(0xFF111111), fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedMovie!.title.toUpperCase(), 
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF111111), fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -0.5, fontFamily: 'Impact', height: 1.0)
                      ),
                    ],
                  )
                ),
                const Icon(Icons.search, color: noirCrimson),
              ],
            ),
      ),
    );
  }

  Widget _buildDateTile() {
    return ListTile(
      leading: const Icon(Icons.calendar_today_outlined, color: noirCrimson, size: 20),
      title: Text(DateFormat('MMMM dd, yyyy').format(_selectedDate), 
        style: const TextStyle(color: Color(0xFF111111), fontSize: 14, fontWeight: FontWeight.bold)),
      trailing: const Text("CHANGE", style: TextStyle(color: Color(0xFF111111), fontSize: 10, fontWeight: FontWeight.w900)),
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context, 
          initialDate: _selectedDate, 
          firstDate: DateTime(1900), 
          lastDate: DateTime.now(),
          builder: (context, child) => Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(primary: noirCrimson, surface: Color(0xFFF4F4EC)),
            ), 
            child: child!),
        );
        if (picked != null) setState(() => _selectedDate = picked);
      },
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {int maxLines = 1, FocusNode? focusNode, Function(String)? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: _buildGlassContainer(
        child: TextField(
          controller: controller, 
          maxLines: maxLines, 
          focusNode: focusNode,
          onChanged: onChanged,
          style: const TextStyle(color: Color(0xFF111111), fontSize: 14, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF111111), size: 20), 
            hintText: hint, 
            hintStyle: const TextStyle(color: Color(0xFF454545), fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.bold),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF111111), 
        minimumSize: const Size(double.infinity, 60),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        elevation: 0,
      ),
      onPressed: _isSaving ? null : () async {
        if (_selectedMovie == null) return;
        setState(() => _isSaving = true);
        
        await _expService.addExperience(
          movie: _selectedMovie!, 
          ticketUrl: "", 
          cinema: _cinemaController.text, 
          note: _noteController.text, 
          people: _peopleController.text, 
          customDate: _selectedDate, 
          rating: _userRating,
        );
        
        if (mounted) Navigator.pop(context);
      },
      icon: _isSaving ? const SizedBox.shrink() : const Icon(Icons.confirmation_number_outlined, size: 20, color: Color(0xFFF4F4EC)),
      label: _isSaving 
        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Color(0xFFF4F4EC), strokeWidth: 2)) 
        : const Text("SAVE TO EXPERIENCE HUB", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12, color: Color(0xFFF4F4EC))),
    );
  }
}

class MovieSearchDelegate extends SearchDelegate<MovieModel?> {
  final MovieService service;
  MovieSearchDelegate(this.service);

  @override
  ThemeData appBarTheme(BuildContext context) => ThemeData.light().copyWith(
    appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF4F4EC), elevation: 0),
    scaffoldBackgroundColor: const Color(0xFFF4F4EC),
    inputDecorationTheme: const InputDecorationTheme(
      border: InputBorder.none,
      hintStyle: TextStyle(color: Color(0xFF454545), letterSpacing: 2)
    )
  );

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = "")
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back_ios_new, size: 20), 
    onPressed: () => close(context, null)
  );

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults();

  Widget _buildSearchResults() {
    if (query.isEmpty) {
      return const Center(child: Text("SEARCH MOVIE / SERIES...", style: TextStyle(color: Color(0xFF454545), letterSpacing: 2, fontWeight: FontWeight.bold)));
    }

    return FutureBuilder<List<MovieModel>>(
      // WISE UPDATE: Calling searchAll to include TV Shows and Web Series
      future: service.searchAll(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF111111)));
        }
        final results = snapshot.data ?? [];
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final movie = results[index];
            return ListTile(
              leading: Container(
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFF111111))),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Image.network(movie.posterPath, width: 40, height: 60, fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const Icon(Icons.movie, color: Color(0xFF111111))),
                ),
              ),
              title: Row(
                children: [
                  Expanded(child: Text(movie.title.toUpperCase(), style: const TextStyle(color: Color(0xFF111111), fontSize: 13, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  if (movie.isTvShow)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(2)),
                    child: const Text("TV", style: TextStyle(color: Color(0xFFF4F4EC), fontSize: 7, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              subtitle: Text(movie.releaseDate.isNotEmpty ? movie.releaseDate.split('-')[0] : "N/A", style: const TextStyle(color: Color(0xFF454545), fontSize: 11, fontWeight: FontWeight.bold)),
              onTap: () => close(context, movie),
            );
          },
        );
      },
    );
  }
}