import 'package:flutter/material.dart';
import '../models/movie_model.dart';
import '../movie_details_screen.dart';

class MovieGrid extends StatelessWidget {
  final List<MovieModel> movies;
  final Function(MovieModel) onLongPress;

  const MovieGrid({super.key, required this.movies, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, childAspectRatio: 0.7, crossAxisSpacing: 10, mainAxisSpacing: 10,
      ),
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final movie = movies[index];
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MovieDetailsScreen(movie: movie))),
          onLongPress: () => onLongPress(movie),
          child: Hero(
            tag: movie.id,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(movie.posterPath, fit: BoxFit.cover),
            ),
          ),
        );
      },
    );
  }
}