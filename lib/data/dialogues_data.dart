import 'dart:math';

class MovieDialogue {
  final String quote;
  final String character;
  final String movieTitle;
  final String posterUrl;
  final int tmdbId;

  const MovieDialogue({
    required this.quote,
    required this.character,
    required this.movieTitle,
    required this.posterUrl,
    required this.tmdbId,
  });

  static MovieDialogue getRandom() {
    final random = Random();
    return dialogues[random.nextInt(dialogues.length)];
  }

  static const List<MovieDialogue> dialogues = [
    MovieDialogue(
      quote: "I'M GONNA MAKE HIM AN OFFER HE CAN'T REFUSE.",
      character: "DON VITO CORLEONE",
      movieTitle: "THE GODFATHER",
      posterUrl: "https://image.tmdb.org/t/p/original/3bhkrj58Vtu7enYsRolD1fZdja1.jpg",
      tmdbId: 238,
    ),
    MovieDialogue(
      quote: "WHY SO SERIOUS?",
      character: "THE JOKER",
      movieTitle: "THE DARK KNIGHT",
      posterUrl: "https://image.tmdb.org/t/p/original/qJ2tW6WMUDux911kpUpLlmHGGKB.jpg",
      tmdbId: 155,
    ),
    MovieDialogue(
      quote: "THE FIRST RULE OF FIGHT CLUB IS: YOU DO NOT TALK ABOUT FIGHT CLUB.",
      character: "TYLER DURDEN",
      movieTitle: "FIGHT CLUB",
      posterUrl: "https://image.tmdb.org/t/p/original/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg",
      tmdbId: 550,
    ),
    MovieDialogue(
      quote: "HOPE IS A GOOD THING, MAYBE THE BEST OF THINGS, AND NO GOOD THING EVER DIES.",
      character: "ANDY DUFRESNE",
      movieTitle: "THE SHAWSHANK REDEMPTION",
      posterUrl: "https://image.tmdb.org/t/p/original/9cqNcoGLjRtCsM4YFBGcf1W0Nhi.jpg",
      tmdbId: 278,
    ),
    MovieDialogue(
      quote: "SAY 'HELLO' TO MY LITTLE FRIEND!",
      character: "TONY MONTANA",
      movieTitle: "SCARFACE",
      posterUrl: "https://image.tmdb.org/t/p/original/iQ5ztdjvteGeboXg8Aa3OkAGIum.jpg",
      tmdbId: 111,
    ),
    MovieDialogue(
      quote: "LIFE IS LIKE A BOX OF CHOCOLATES. YOU NEVER KNOW WHAT YOU'RE GONNA GET.",
      character: "FORREST GUMP",
      movieTitle: "FORREST GUMP",
      posterUrl: "https://image.tmdb.org/t/p/original/arw2vcBveWOVZr6pxd9XTd1TdQa.jpg",
      tmdbId: 13,
    ),
    MovieDialogue(
      quote: "I KNOW WHAT I HAVE TO DO NOW. I'VE GOT TO KEEP BREATHING.",
      character: "CHUCK NOLAND",
      movieTitle: "CAST AWAY",
      posterUrl: "https://image.tmdb.org/t/p/original/pvEEpaAMkMl0fSqGBry5dK33V1F.jpg",
      tmdbId: 8358,
    ),
    MovieDialogue(
      quote: "AS FAR BACK AS I CAN REMEMBER, I ALWAYS WANTED TO BE A GANGSTER.",
      character: "HENRY HILL",
      movieTitle: "GOODFELLAS",
      posterUrl: "https://image.tmdb.org/t/p/original/aKuFiU82s5ISJpGZp7YkIr3kCUd.jpg",
      tmdbId: 769,
    ),
    MovieDialogue(
      quote: "I AM NOT IN DANGER, SKYLER. I AM THE DANGER.",
      character: "WALTER WHITE",
      movieTitle: "BREAKING BAD",
      posterUrl: "https://image.tmdb.org/t/p/original/ztkUQFLlC19CCMYHW73GoXVwCpa.jpg",
      tmdbId: 1396,
    ),
    MovieDialogue(
      quote: "WE ACCEPT THE LOVE WE THINK WE DESERVE.",
      character: "BILL ANDERSON",
      movieTitle: "THE PERKS OF BEING A WALLFLOWER",
      posterUrl: "https://image.tmdb.org/t/p/original/aKIM5FqA0GqKUMNBxfjsBbLcyp9.jpg",
      tmdbId: 84892,
    ),
    MovieDialogue(
      quote: "DO NOT GO GENTLE INTO THAT GOOD NIGHT.",
      character: "PROFESSOR BRAND",
      movieTitle: "INTERSTELLAR",
      posterUrl: "https://image.tmdb.org/t/p/original/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg",
      tmdbId: 157336,
    ),
    MovieDialogue(
      quote: "YOU EITHER DIE A HERO, OR YOU LIVE LONG ENOUGH TO SEE YOURSELF BECOME THE VILLAIN.",
      character: "HARVEY DENT",
      movieTitle: "THE DARK KNIGHT",
      posterUrl: "https://image.tmdb.org/t/p/original/qJ2tW6WMUDux911kpUpLlmHGGKB.jpg",
      tmdbId: 155,
    ),
    MovieDialogue(
      quote: "AFTER ALL, TOMORROW IS ANOTHER DAY!",
      character: "SCARLETT O'HARA",
      movieTitle: "GONE WITH THE WIND",
      posterUrl: "https://image.tmdb.org/t/p/original/lTqRySUJnYMEEEOHTBTfGtGPRFp.jpg",
      tmdbId: 770,
    ),
    MovieDialogue(
      quote: "HERE'S LOOKING AT YOU, KID.",
      character: "RICK BLAINE",
      movieTitle: "CASABLANCA",
      posterUrl: "https://image.tmdb.org/t/p/original/5K7cOHoay2mZusSLezBOY0Qxh8a.jpg",
      tmdbId: 289,
    ),
    MovieDialogue(
      quote: "ALL THOSE MOMENTS WILL BE LOST IN TIME, LIKE TEARS IN RAIN.",
      character: "ROY BATTY",
      movieTitle: "BLADE RUNNER",
      posterUrl: "https://image.tmdb.org/t/p/original/63N9uy8nd9j7Eog2axPQ8lbr3Wj.jpg",
      tmdbId: 78,
    ),
  ];
}
