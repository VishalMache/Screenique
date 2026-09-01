import 'dart:math';

class MovieDialogue {
  final String quote;
  final String character;
  final String movieTitle;
  final String posterUrl;
  final int tmdbId;
  final String genre; // Category tag

  const MovieDialogue({
    required this.quote,
    required this.character,
    required this.movieTitle,
    required this.posterUrl,
    required this.tmdbId,
    this.genre = 'CLASSIC',
  });

  static MovieDialogue getRandom() {
    final random = Random();
    return dialogues[random.nextInt(dialogues.length)];
  }

  static const List<MovieDialogue> dialogues = [
    // ── CRIME / GANGSTER ──────────────────────────────────────
    MovieDialogue(
      quote: "I'M GONNA MAKE HIM AN OFFER HE CAN'T REFUSE.",
      character: "DON VITO CORLEONE",
      movieTitle: "THE GODFATHER",
      posterUrl: "https://image.tmdb.org/t/p/original/3bhkrj58Vtu7enYsRolD1fZdja1.jpg",
      tmdbId: 238,
      genre: 'CRIME',
    ),
    MovieDialogue(
      quote: "AS FAR BACK AS I CAN REMEMBER, I ALWAYS WANTED TO BE A GANGSTER.",
      character: "HENRY HILL",
      movieTitle: "GOODFELLAS",
      posterUrl: "https://image.tmdb.org/t/p/original/9OkCLM73MIU2CrKZbqiT8Ln1wY2.jpg",
      tmdbId: 769,
      genre: 'CRIME',
    ),
    MovieDialogue(
      quote: "SAY 'HELLO' TO MY LITTLE FRIEND!",
      character: "TONY MONTANA",
      movieTitle: "SCARFACE",
      posterUrl: "https://image.tmdb.org/t/p/original/iQ5ztdjvteGeboxtmRdXEChJOHh.jpg",
      tmdbId: 111,
      genre: 'CRIME',
    ),
    MovieDialogue(
      quote: "EVERY PASSAGE OF ONE'S LIFE MUST BE MOVED ON.",
      character: "MICHAEL CORLEONE",
      movieTitle: "THE GODFATHER: PART II",
      posterUrl: "https://image.tmdb.org/t/p/original/sSuQTCZwqKrNBNIsksO9IAUoWP9.jpg",
      tmdbId: 240,
      genre: 'CRIME',
    ),
    MovieDialogue(
      quote: "YOU COME TO ME ON MY DAUGHTER'S WEDDING DAY AND YOU ASK ME TO DO MURDER.",
      character: "VITO CORLEONE",
      movieTitle: "THE GODFATHER",
      posterUrl: "https://image.tmdb.org/t/p/original/3bhkrj58Vtu7enYsRolD1fZdja1.jpg",
      tmdbId: 238,
      genre: 'CRIME',
    ),

    // ── THRILLER / PSYCHOLOGICAL ─────────────────────────────
    MovieDialogue(
      quote: "WHY SO SERIOUS?",
      character: "THE JOKER",
      movieTitle: "THE DARK KNIGHT",
      posterUrl: "https://image.tmdb.org/t/p/original/qJ2tW6WMUDux911r6m7haRef0WH.jpg",
      tmdbId: 155,
      genre: 'THRILLER',
    ),
    MovieDialogue(
      quote: "YOU EITHER DIE A HERO, OR YOU LIVE LONG ENOUGH TO SEE YOURSELF BECOME THE VILLAIN.",
      character: "HARVEY DENT",
      movieTitle: "THE DARK KNIGHT",
      posterUrl: "https://image.tmdb.org/t/p/original/qJ2tW6WMUDux911r6m7haRef0WH.jpg",
      tmdbId: 155,
      genre: 'THRILLER',
    ),
    MovieDialogue(
      quote: "THE FIRST RULE OF FIGHT CLUB IS: YOU DO NOT TALK ABOUT FIGHT CLUB.",
      character: "TYLER DURDEN",
      movieTitle: "FIGHT CLUB",
      posterUrl: "https://image.tmdb.org/t/p/original/jSziioSwPVrOy9Yow3XhWIBDjq1.jpg",
      tmdbId: 550,
      genre: 'THRILLER',
    ),
    MovieDialogue(
      quote: "WHAT'S IN THE BOX?",
      character: "DETECTIVE MILLS",
      movieTitle: "SE7EN",
      posterUrl: "https://image.tmdb.org/t/p/original/191nKfP0ehp3uIvWqgPbFmI4lv9.jpg",
      tmdbId: 807,
      genre: 'THRILLER',
    ),
    MovieDialogue(
      quote: "THEY'LL THINK I'M NOT SERIOUS. THAT'S GOOD. I'M VERY SERIOUS.",
      character: "HANNIBAL LECTER",
      movieTitle: "THE SILENCE OF THE LAMBS",
      posterUrl: "https://image.tmdb.org/t/p/original/uS9m8OBk1A8eM9I042bx8XXpqAq.jpg",
      tmdbId: 274,
      genre: 'THRILLER',
    ),
    MovieDialogue(
      quote: "I EAT THE RUDE.",
      character: "HANNIBAL LECTER",
      movieTitle: "HANNIBAL",
      posterUrl: "https://image.tmdb.org/t/p/original/pbV2eLnKSIm1epSZt473UYfqaeZ.jpg",
      tmdbId: 2634,
      genre: 'THRILLER',
    ),

    // ── DRAMA ─────────────────────────────────────────────────
    MovieDialogue(
      quote: "HOPE IS A GOOD THING, MAYBE THE BEST OF THINGS, AND NO GOOD THING EVER DIES.",
      character: "ANDY DUFRESNE",
      movieTitle: "THE SHAWSHANK REDEMPTION",
      posterUrl: "https://image.tmdb.org/t/p/original/9cqNxx0GxF0bflZmeSMuL5tnGzr.jpg",
      tmdbId: 278,
      genre: 'DRAMA',
    ),
    MovieDialogue(
      quote: "LIFE IS LIKE A BOX OF CHOCOLATES. YOU NEVER KNOW WHAT YOU'RE GONNA GET.",
      character: "FORREST GUMP",
      movieTitle: "FORREST GUMP",
      posterUrl: "https://image.tmdb.org/t/p/original/Cw4hIUIAmSYfK9QfaUW5igp9La.jpg",
      tmdbId: 13,
      genre: 'DRAMA',
    ),
    MovieDialogue(
      quote: "WE ACCEPT THE LOVE WE THINK WE DESERVE.",
      character: "BILL ANDERSON",
      movieTitle: "THE PERKS OF BEING A WALLFLOWER",
      posterUrl: "https://image.tmdb.org/t/p/original/aKCvdFFF5n80P2VdS7d8YBwbCjh.jpg",
      tmdbId: 84892,
      genre: 'DRAMA',
    ),
    MovieDialogue(
      quote: "AFTER ALL, TOMORROW IS ANOTHER DAY!",
      character: "SCARLETT O'HARA",
      movieTitle: "GONE WITH THE WIND",
      posterUrl: "https://image.tmdb.org/t/p/original/lNz2Ow0wGCAvzckW7EOjE03KcYv.jpg",
      tmdbId: 770,
      genre: 'DRAMA',
    ),
    MovieDialogue(
      quote: "THE STUFF THAT DREAMS ARE MADE OF.",
      character: "SAM SPADE",
      movieTitle: "THE MALTESE FALCON",
      posterUrl: "https://image.tmdb.org/t/p/original/bf4o6Uzw5wqLjdKwRuiDrN1xyvl.jpg",
      tmdbId: 963,
      genre: 'DRAMA',
    ),
    MovieDialogue(
      quote: "TO INFINITY AND BEYOND.",
      character: "BUZZ LIGHTYEAR",
      movieTitle: "TOY STORY",
      posterUrl: "https://image.tmdb.org/t/p/original/sfQtVlIHljToOwYjhe21KPGzZWK.jpg",
      tmdbId: 862,
      genre: 'DRAMA',
    ),

    // ── SCI-FI ────────────────────────────────────────────────
    MovieDialogue(
      quote: "DO NOT GO GENTLE INTO THAT GOOD NIGHT.",
      character: "PROFESSOR BRAND",
      movieTitle: "INTERSTELLAR",
      posterUrl: "https://image.tmdb.org/t/p/original/yQvGrMoipbRoddT0ZR8tPoR7NfX.jpg",
      tmdbId: 157336,
      genre: 'SCI-FI',
    ),
    MovieDialogue(
      quote: "ALL THOSE MOMENTS WILL BE LOST IN TIME, LIKE TEARS IN RAIN.",
      character: "ROY BATTY",
      movieTitle: "BLADE RUNNER",
      posterUrl: "https://image.tmdb.org/t/p/original/63N9uy8nd9j7Eog2axPQ8lbr3Wj.jpg",
      tmdbId: 78,
      genre: 'SCI-FI',
    ),
    MovieDialogue(
      quote: "I'LL BE BACK.",
      character: "THE TERMINATOR",
      movieTitle: "THE TERMINATOR",
      posterUrl: "https://image.tmdb.org/t/p/original/qvktm0BHcnmDpul4Hz01GIazWPr.jpg",
      tmdbId: 218,
      genre: 'SCI-FI',
    ),
    MovieDialogue(
      quote: "YOU HAVE TO LET IT ALL GO, NEO. FEAR, DOUBT, AND DISBELIEF.",
      character: "MORPHEUS",
      movieTitle: "THE MATRIX",
      posterUrl: "https://image.tmdb.org/t/p/original/dXNAPwY7VrqMAo51EKhhCJfaGb5.jpg",
      tmdbId: 603,
      genre: 'SCI-FI',
    ),
    MovieDialogue(
      quote: "WHAT WE DO IN LIFE ECHOES IN ETERNITY.",
      character: "MAXIMUS",
      movieTitle: "GLADIATOR",
      posterUrl: "https://image.tmdb.org/t/p/original/wN2xWp1eIwCKOD0BHTcErTBv1Uq.jpg",
      tmdbId: 98,
      genre: 'SCI-FI',
    ),
    MovieDialogue(
      quote: "KEEP YOUR FRIENDS CLOSE, BUT YOUR ENEMIES CLOSER.",
      character: "MICHAEL CORLEONE",
      movieTitle: "THE GODFATHER: PART II",
      posterUrl: "https://image.tmdb.org/t/p/original/sSuQTCZwqKrNBNIsksO9IAUoWP9.jpg",
      tmdbId: 240,
      genre: 'SCI-FI',
    ),

    // ── CLASSIC ───────────────────────────────────────────────
    MovieDialogue(
      quote: "HERE'S LOOKING AT YOU, KID.",
      character: "RICK BLAINE",
      movieTitle: "CASABLANCA",
      posterUrl: "https://image.tmdb.org/t/p/original/lGCEKlJo2CnWydQj7aamY7s1S7Q.jpg",
      tmdbId: 289,
      genre: 'CLASSIC',
    ),
    MovieDialogue(
      quote: "FRANKLY, MY DEAR, I DON'T GIVE A DAMN.",
      character: "RHETT BUTLER",
      movieTitle: "GONE WITH THE WIND",
      posterUrl: "https://image.tmdb.org/t/p/original/lNz2Ow0wGCAvzckW7EOjE03KcYv.jpg",
      tmdbId: 770,
      genre: 'CLASSIC',
    ),
    MovieDialogue(
      quote: "MAY THE FORCE BE WITH YOU.",
      character: "OBI-WAN KENOBI",
      movieTitle: "STAR WARS: A NEW HOPE",
      posterUrl: "https://image.tmdb.org/t/p/original/6FfCtAuVAW8XJjZ7eWeLibRLWTw.jpg",
      tmdbId: 11,
      genre: 'CLASSIC',
    ),
    MovieDialogue(
      quote: "BOND. JAMES BOND.",
      character: "JAMES BOND",
      movieTitle: "DR. NO",
      posterUrl: "https://image.tmdb.org/t/p/original/9zCOLJmLNst0sCPZlkW1IRoH65E.jpg",
      tmdbId: 686,
      genre: 'CLASSIC',
    ),

    // ── ADVENTURE / ACTION ───────────────────────────────────
    MovieDialogue(
      quote: "WITH GREAT POWER COMES GREAT RESPONSIBILITY.",
      character: "UNCLE BEN",
      movieTitle: "SPIDER-MAN",
      posterUrl: "https://image.tmdb.org/t/p/original/iPOn6DinuVyLY17YM9mKuPofV08.jpg",
      tmdbId: 557,
      genre: 'ACTION',
    ),
    MovieDialogue(
      quote: "ROADS? WHERE WE'RE GOING WE DON'T NEED ROADS.",
      character: "DOC BROWN",
      movieTitle: "BACK TO THE FUTURE",
      posterUrl: "https://image.tmdb.org/t/p/original/vN5B5WgYscRGcQpVhHl6p9DDTP0.jpg",
      tmdbId: 105,
      genre: 'ACTION',
    ),
    MovieDialogue(
      quote: "IT'S NOT WHO I AM UNDERNEATH, BUT WHAT I DO THAT DEFINES ME.",
      character: "BRUCE WAYNE",
      movieTitle: "BATMAN BEGINS",
      posterUrl: "https://image.tmdb.org/t/p/original/sPX89Td70IDDjVr85jdSBb4rWGr.jpg",
      tmdbId: 272,
      genre: 'ACTION',
    ),
    MovieDialogue(
      quote: "I AM IRON MAN.",
      character: "TONY STARK",
      movieTitle: "IRON MAN",
      posterUrl: "https://image.tmdb.org/t/p/original/78lPtwv72eTNqFW9COBYI0dWDJa.jpg",
      tmdbId: 1726,
      genre: 'ACTION',
    ),
    MovieDialogue(
      quote: "REMEMBER. REMEMBER THE 5TH OF NOVEMBER.",
      character: "V",
      movieTitle: "V FOR VENDETTA",
      posterUrl: "https://image.tmdb.org/t/p/original/1avD1JeaRiJX5M4ahPdZPypGoGN.jpg",
      tmdbId: 752,
      genre: 'ACTION',
    ),

    // ── TV SERIES ─────────────────────────────────────────────
    MovieDialogue(
      quote: "I AM NOT IN DANGER, SKYLER. I AM THE DANGER.",
      character: "WALTER WHITE",
      movieTitle: "BREAKING BAD",
      posterUrl: "https://image.tmdb.org/t/p/original/anFx9aTOOYqgS3v7x3R84Kz67ly.jpg",
      tmdbId: 1396,
      genre: 'SERIES',
    ),
    MovieDialogue(
      quote: "SAY MY NAME.",
      character: "WALTER WHITE",
      movieTitle: "BREAKING BAD",
      posterUrl: "https://image.tmdb.org/t/p/original/anFx9aTOOYqgS3v7x3R84Kz67ly.jpg",
      tmdbId: 1396,
      genre: 'SERIES',
    ),
    MovieDialogue(
      quote: "WHEN YOU PLAY THE GAME OF THRONES, YOU WIN OR YOU DIE.",
      character: "CERSEI LANNISTER",
      movieTitle: "GAME OF THRONES",
      posterUrl: "https://image.tmdb.org/t/p/original/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg",
      tmdbId: 1399,
      genre: 'SERIES',
    ),
    MovieDialogue(
      quote: "A LION DOESN'T CONCERN HIMSELF WITH THE OPINIONS OF A SHEEP.",
      character: "TYWIN LANNISTER",
      movieTitle: "GAME OF THRONES",
      posterUrl: "https://image.tmdb.org/t/p/original/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg",
      tmdbId: 1399,
      genre: 'SERIES',
    ),
    MovieDialogue(
      quote: "BY ORDER OF THE PEAKY BLINDERS.",
      character: "TOMMY SHELBY",
      movieTitle: "PEAKY BLINDERS",
      posterUrl: "https://image.tmdb.org/t/p/original/vUUqzWa2LnHIVqkaKVlVGkVcZIW.jpg",
      tmdbId: 60574,
      genre: 'SERIES',
    ),
    MovieDialogue(
      quote: "I'M NOT IN DANGER. I'M THE ONE WHO KNOCKS.",
      character: "WALTER WHITE",
      movieTitle: "BREAKING BAD",
      posterUrl: "https://image.tmdb.org/t/p/original/anFx9aTOOYqgS3v7x3R84Kz67ly.jpg",
      tmdbId: 1396,
      genre: 'SERIES',
    ),
    MovieDialogue(
      quote: "EVERY MAN DIES. NOT EVERY MAN REALLY LIVES.",
      character: "WILLIAM WALLACE",
      movieTitle: "BRAVEHEART",
      posterUrl: "https://image.tmdb.org/t/p/original/or1gBugydmjToAEq7OZY0owwFk.jpg",
      tmdbId: 197,
      genre: 'SERIES',
    ),
    MovieDialogue(
      quote: "YOU KNOW NOTHING, JON SNOW.",
      character: "YGRITTE",
      movieTitle: "GAME OF THRONES",
      posterUrl: "https://image.tmdb.org/t/p/original/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg",
      tmdbId: 1399,
      genre: 'SERIES',
    ),

    // ── ROMANCE ───────────────────────────────────────────────
    MovieDialogue(
      quote: "YOU COMPLETE ME.",
      character: "JERRY MAGUIRE",
      movieTitle: "JERRY MAGUIRE",
      posterUrl: "https://image.tmdb.org/t/p/original/lABvGN7fDk5ifnwZoxij6G96t2w.jpg",
      tmdbId: 180,
      genre: 'ROMANCE',
    ),
    MovieDialogue(
      quote: "AFTER ALL THIS TIME? ALWAYS.",
      character: "SEVERUS SNAPE",
      movieTitle: "HARRY POTTER AND THE DEATHLY HALLOWS PT.2",
      posterUrl: "https://image.tmdb.org/t/p/original/c54HpQmuwXjHq2C9wmoACjxoom3.jpg",
      tmdbId: 12445,
      genre: 'ROMANCE',
    ),
    MovieDialogue(
      quote: "I WISH I KNEW HOW TO QUIT YOU.",
      character: "JACK TWIST",
      movieTitle: "BROKEBACK MOUNTAIN",
      posterUrl: "https://image.tmdb.org/t/p/original/aByfQOQBNa4CMFwIgq3QrqY2ZHh.jpg",
      tmdbId: 840,
      genre: 'ROMANCE',
    ),
    MovieDialogue(
      quote: "YOU HAD ME AT HELLO.",
      character: "DOROTHY BOYD",
      movieTitle: "JERRY MAGUIRE",
      posterUrl: "https://image.tmdb.org/t/p/original/lABvGN7fDk5ifnwZoxij6G96t2w.jpg",
      tmdbId: 180,
      genre: 'ROMANCE',
    ),
    MovieDialogue(
      quote: "I AM NOTHING SPECIAL, OF THIS I AM SURE. I AM A COMMON MAN WITH COMMON THOUGHTS.",
      character: "NICHOLAS SPARKS",
      movieTitle: "THE NOTEBOOK",
      posterUrl: "https://image.tmdb.org/t/p/original/rNzQyW4f8B8cQeg7Dgj3n6eT5k9.jpg",
      tmdbId: 11036,
      genre: 'ROMANCE',
    ),

    // ── HORROR ────────────────────────────────────────────────
    MovieDialogue(
      quote: "HERE'S JOHNNY!",
      character: "JACK TORRANCE",
      movieTitle: "THE SHINING",
      posterUrl: "https://image.tmdb.org/t/p/original/uAR0AWqhQL1hQa69UDEbb2rE5Wx.jpg",
      tmdbId: 694,
      genre: 'HORROR',
    ),
    MovieDialogue(
      quote: "THEY'RE ALL GONNA LAUGH AT YOU!",
      character: "MARGARET WHITE",
      movieTitle: "CARRIE",
      posterUrl: "https://image.tmdb.org/t/p/original/b7aKxwPj3QM8YHZ8uDyqr50i96D.jpg",
      tmdbId: 2976,
      genre: 'HORROR',
    ),
    MovieDialogue(
      quote: "WE ALL FLOAT DOWN HERE.",
      character: "PENNYWISE",
      movieTitle: "IT",
      posterUrl: "https://image.tmdb.org/t/p/original/4ybQ6gopB3H3cu0seVZLznDnIKo.jpg",
      tmdbId: 346364,
      genre: 'HORROR',
    ),
    MovieDialogue(
      quote: "GET OUT.",
      character: "MISSY ARMITAGE",
      movieTitle: "GET OUT",
      posterUrl: "https://image.tmdb.org/t/p/original/tFXcEccSQMf3lfhfXKSU9iRBpa3.jpg",
      tmdbId: 419430,
      genre: 'HORROR',
    ),

    // ── INSPIRATIONAL ─────────────────────────────────────────
    MovieDialogue(
      quote: "I KNOW WHAT I HAVE TO DO NOW. I'VE GOT TO KEEP BREATHING.",
      character: "CHUCK NOLAND",
      movieTitle: "CAST AWAY",
      posterUrl: "https://image.tmdb.org/t/p/original/7lLJgKnAicAcR5UEuo8xhSMj18w.jpg",
      tmdbId: 8358,
      genre: 'INSPIRE',
    ),
    MovieDialogue(
      quote: "GET BUSY LIVING, OR GET BUSY DYING.",
      character: "ANDY DUFRESNE",
      movieTitle: "THE SHAWSHANK REDEMPTION",
      posterUrl: "https://image.tmdb.org/t/p/original/9cqNxx0GxF0bflZmeSMuL5tnGzr.jpg",
      tmdbId: 278,
      genre: 'INSPIRE',
    ),
    MovieDialogue(
      quote: "NO MATTER WHAT ANYBODY TELLS YOU, WORDS AND IDEAS CAN CHANGE THE WORLD.",
      character: "JOHN KEATING",
      movieTitle: "DEAD POETS SOCIETY",
      posterUrl: "https://image.tmdb.org/t/p/original/sfQtVlIHljToOwYjhe21KPGzZWK.jpg",
      tmdbId: 207,
      genre: 'INSPIRE',
    ),
    MovieDialogue(
      quote: "YOU IS KIND. YOU IS SMART. YOU IS IMPORTANT.",
      character: "AIBILEEN CLARK",
      movieTitle: "THE HELP",
      posterUrl: "https://image.tmdb.org/t/p/original/3kmfoWWEc9Vtyuaf9v5VipRgdjx.jpg",
      tmdbId: 67962,
      genre: 'INSPIRE',
    ),
    MovieDialogue(
      quote: "CARPE DIEM. SEIZE THE DAY, BOYS.",
      character: "JOHN KEATING",
      movieTitle: "DEAD POETS SOCIETY",
      posterUrl: "https://image.tmdb.org/t/p/original/sfQtVlIHljToOwYjhe21KPGzZWK.jpg",
      tmdbId: 207,
      genre: 'INSPIRE',
    ),
    MovieDialogue(
      quote: "HAKUNA MATATA.",
      character: "TIMON",
      movieTitle: "THE LION KING",
      posterUrl: "https://image.tmdb.org/t/p/original/sKCr78MXSLixwmZ8DyJLrpMsd15.jpg",
      tmdbId: 8587,
      genre: 'INSPIRE',
    ),

    // ── INDIAN CINEMA ─────────────────────────────────────────
    MovieDialogue(
      quote: "KEHTE HAIN AGAR KISI CHEEZ KO DIL SE CHAHO TOH POORI KAYNAT USSE TUMSE MILANE KI KOSHISH MEIN LAG JAATI HAI.",
      character: "RANCHO",
      movieTitle: "3 IDIOTS",
      posterUrl: "https://image.tmdb.org/t/p/original/66A9MqXOyVFCssoloscw79z8Tew.jpg",
      tmdbId: 20453,
      genre: 'INDIAN',
    ),
    MovieDialogue(
      quote: "PICTURE ABHI BAAKI HAI MERE DOST.",
      character: "OM PRAKASH MAKHIJA",
      movieTitle: "OM SHANTI OM",
      posterUrl: "https://image.tmdb.org/t/p/original/oArsQTD4bPPMtRjqr03SO9W6phF.jpg",
      tmdbId: 13567,
      genre: 'INDIAN',
    ),
    MovieDialogue(
      quote: "RISHTE MEIN TOH HUM TUMHARE BAAP LAGTE HAIN.",
      character: "GABBAR SINGH",
      movieTitle: "SHOLAY",
      posterUrl: "https://image.tmdb.org/t/p/original/ya9bwgqA4eNl5bQ9QqS0jcmRoBS.jpg",
      tmdbId: 26030,
      genre: 'INDIAN',
    ),
    MovieDialogue(
      quote: "EK BAAR JO MAINE COMMITMENT KAR DI, TOH PHIR MAIN APNE AAP KI BHI NAHI SUNTA.",
      character: "SALMAN KHAN",
      movieTitle: "WANTED",
      posterUrl: "https://image.tmdb.org/t/p/original/ya9bwgqA4eNl5bQ9QqS0jcmRoBS.jpg",
      tmdbId: 22798,
      genre: 'INDIAN',
    ),

    // ── CULT ──────────────────────────────────────────────────
    MovieDialogue(
      quote: "SAY WHAT AGAIN! I DARE YOU!",
      character: "JULES WINNFIELD",
      movieTitle: "PULP FICTION",
      posterUrl: "https://image.tmdb.org/t/p/original/vQWk5YBFWF4bZaofAbv0tShwBvQ.jpg",
      tmdbId: 680,
      genre: 'CULT',
    ),
    MovieDialogue(
      quote: "ROYALE WITH CHEESE.",
      character: "VINCENT VEGA",
      movieTitle: "PULP FICTION",
      posterUrl: "https://image.tmdb.org/t/p/original/vQWk5YBFWF4bZaofAbv0tShwBvQ.jpg",
      tmdbId: 680,
      genre: 'CULT',
    ),
    MovieDialogue(
      quote: "I AM SERIOUS. AND DON'T CALL ME SHIRLEY.",
      character: "DR. RUMACK",
      movieTitle: "AIRPLANE!",
      posterUrl: "https://image.tmdb.org/t/p/original/7Q3efxd3AF1vQjlSxnlerSA7RzN.jpg",
      tmdbId: 813,
      genre: 'CULT',
    ),
    MovieDialogue(
      quote: "MY NAME IS INIGO MONTOYA. YOU KILLED MY FATHER. PREPARE TO DIE.",
      character: "INIGO MONTOYA",
      movieTitle: "THE PRINCESS BRIDE",
      posterUrl: "https://image.tmdb.org/t/p/original/2FC9L9MrjBoGHYjYZjdWQdopVYb.jpg",
      tmdbId: 2493,
      genre: 'CULT',
    ),

    // ── WAR ───────────────────────────────────────────────────
    MovieDialogue(
      quote: "I LOVE THE SMELL OF NAPALM IN THE MORNING.",
      character: "LT. COL. KILGORE",
      movieTitle: "APOCALYPSE NOW",
      posterUrl: "https://image.tmdb.org/t/p/original/gQB8Y5RCMkv2zwzFHbUJX3kAhvA.jpg",
      tmdbId: 28,
      genre: 'WAR',
    ),
    MovieDialogue(
      quote: "SAVING PRIVATE RYAN IS THE MOST VALUABLE SOLDIER OF THE HISTORY.",
      character: "GENERAL MARSHALL",
      movieTitle: "SAVING PRIVATE RYAN",
      posterUrl: "https://image.tmdb.org/t/p/original/uqx37cS8cpHg8U35f9U5IBlrCV3.jpg",
      tmdbId: 857,
      genre: 'WAR',
    ),
    MovieDialogue(
      quote: "TILL I WAS 25, I HAD NO IDEA WHO I WAS OR WHAT I WANTED TO DO.",
      character: "CAPTAIN MILLER",
      movieTitle: "SAVING PRIVATE RYAN",
      posterUrl: "https://image.tmdb.org/t/p/original/uqx37cS8cpHg8U35f9U5IBlrCV3.jpg",
      tmdbId: 857,
      genre: 'WAR',
    ),
  ];

  // All available genre tags
  static List<String> get genres {
    final g = dialogues.map((d) => d.genre).toSet().toList();
    g.sort();
    return g;
  }

  static List<MovieDialogue> byGenre(String genre) =>
      dialogues.where((d) => d.genre == genre).toList();
}
