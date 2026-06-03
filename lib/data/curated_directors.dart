const Map<String, List<Map<String, dynamic>>> curatedDirectors = {
  'KR': [
    {'name': 'Bong Joon-ho', 'tmdbId': 21684, 'knownFor': 'Parasite', 'profilePath': '/11dOqL32aLksC2t9tqD0fP9vF1h.jpg'},
    {'name': 'Park Chan-wook', 'tmdbId': 12453, 'knownFor': 'Oldboy', 'profilePath': '/8B401y1TjR6r993U7yL62J66Y1l.jpg'},
    {'name': 'Lee Chang-dong', 'tmdbId': 41364, 'knownFor': 'Burning', 'profilePath': '/rG1OqQxZ5jS8q63nJ5W9H7L9i3Q.jpg'},
    {'name': 'Na Hong-jin', 'tmdbId': 61033, 'knownFor': 'The Wailing', 'profilePath': '/wW7qR4f13C07YyN1Y97J2M5L12R.jpg'},
  ],
  'JP': [
    {'name': 'Akira Kurosawa', 'tmdbId': 5026, 'knownFor': 'Seven Samurai', 'profilePath': '/xKkP2qB177sUaJg4tHq813Wn2Gk.jpg'},
    {'name': 'Hayao Miyazaki', 'tmdbId': 608, 'knownFor': 'Spirited Away', 'profilePath': '/70i3d1Zc7v3Pq6T1pXq2c4xZ1B.jpg'},
    {'name': 'Hirokazu Kore-eda', 'tmdbId': 17540, 'knownFor': 'Shoplifters', 'profilePath': '/5w9k3LqQv3R2g8tZ7J1B1n1K2P.jpg'},
    {'name': 'Yasujirō Ozu', 'tmdbId': 3108, 'knownFor': 'Tokyo Story', 'profilePath': '/kZ7n2r5H9y3b1X6t4M7c6H2V2T.jpg'},
  ],
  'FR': [
    {'name': 'François Truffaut', 'tmdbId': 10229, 'knownFor': 'The 400 Blows', 'profilePath': '/4pQ9K5W2k1N3r0H5g8Z7Y3m2X1L.jpg'},
    {'name': 'Jean-Luc Godard', 'tmdbId': 1709, 'knownFor': 'Breathless', 'profilePath': '/yT1w2Z9q0T7B2q4N6m8K3v2M1L.jpg'},
    {'name': 'Agnès Varda', 'tmdbId': 1145, 'knownFor': 'Cleo from 5 to 7', 'profilePath': '/6v1h1M7P8n2C8y5P6M4t4M3L2R.jpg'},
    {'name': 'Céline Sciamma', 'tmdbId': 64132, 'knownFor': 'Portrait of a Lady on Fire', 'profilePath': '/2Q1q5X7P8n9Z8t7N9M5t6V2W1L.jpg'},
  ],
  'IT': [
    {'name': 'Federico Fellini', 'tmdbId': 4385, 'knownFor': '8½', 'profilePath': '/8X9v2B5n9Z1T5M6p3Q4t9X2L1R.jpg'},
    {'name': 'Sergio Leone', 'tmdbId': 4386, 'knownFor': 'The Good, the Bad and the Ugly', 'profilePath': '/p3b8H3V8Z9N5q6T9P2Q1h7L2R.jpg'},
    {'name': 'Roberto Rossellini', 'tmdbId': 10595, 'knownFor': 'Rome, Open City', 'profilePath': '/7L2q9M4W1P8n9Z6T3X5V2B1h.jpg'},
    {'name': 'Paolo Sorrentino', 'tmdbId': 55431, 'knownFor': 'The Great Beauty', 'profilePath': '/1n8B5Z7V9X2T4Q8N3P5R9L1h.jpg'},
  ],
  'IN': [
    {'name': 'Satyajit Ray', 'tmdbId': 9458, 'knownFor': 'Pather Panchali', 'profilePath': '/1V9x2B8T9n5P4M6Z3Q1T8h2L.jpg'},
    {'name': 'Anurag Kashyap', 'tmdbId': 60074, 'knownFor': 'Gangs of Wasseypur', 'profilePath': '/5X9v2B8n9Z1T5M6p3Q4t9X2L1R.jpg'},
    {'name': 'S.S. Rajamouli', 'tmdbId': 1172821, 'knownFor': 'RRR', 'profilePath': '/2V8b5H9P7X1Z9N6M4t4M3L2R.jpg'},
    {'name': 'Mani Ratnam', 'tmdbId': 34503, 'knownFor': 'Nayakan', 'profilePath': '/3X9v2B8n9Z1T5M6p3Q4t9X2L1R.jpg'},
  ],
  'US': [
    {'name': 'Martin Scorsese', 'tmdbId': 1032, 'knownFor': 'Goodfellas', 'profilePath': '/9U9Y5GKgWX61d9a5B2B2n2Z2N1.jpg'},
    {'name': 'Quentin Tarantino', 'tmdbId': 138, 'knownFor': 'Pulp Fiction', 'profilePath': '/1n8B5Z7V9X2T4Q8N3P5R9L1h.jpg'},
    {'name': 'Stanley Kubrick', 'tmdbId': 240, 'knownFor': '2001: A Space Odyssey', 'profilePath': '/5N9Z1T5M6p3Q4t9X2L1R.jpg'},
    {'name': 'Steven Spielberg', 'tmdbId': 488, 'knownFor': 'Schindler\'s List', 'profilePath': '/p3b8H3V8Z9N5q6T9P2Q1h7L2R.jpg'},
  ],
  'GB': [
    {'name': 'Christopher Nolan', 'tmdbId': 525, 'knownFor': 'The Dark Knight', 'profilePath': '/8X9v2B5n9Z1T5M6p3Q4t9X2L1R.jpg'},
    {'name': 'Alfred Hitchcock', 'tmdbId': 2636, 'knownFor': 'Vertigo', 'profilePath': '/1V9x2B8T9n5P4M6Z3Q1T8h2L.jpg'},
    {'name': 'Ridley Scott', 'tmdbId': 578, 'knownFor': 'Alien', 'profilePath': '/7L2q9M4W1P8n9Z6T3X5V2B1h.jpg'},
    {'name': 'Danny Boyle', 'tmdbId': 2034, 'knownFor': 'Trainspotting', 'profilePath': '/5X9v2B8n9Z1T5M6p3Q4t9X2L1R.jpg'},
  ],
  'MX': [
    {'name': 'Guillermo del Toro', 'tmdbId': 10828, 'knownFor': 'Pan\'s Labyrinth', 'profilePath': '/3X9v2B8n9Z1T5M6p3Q4t9X2L1R.jpg'},
    {'name': 'Alfonso Cuarón', 'tmdbId': 10814, 'knownFor': 'Roma', 'profilePath': '/1n8B5Z7V9X2T4Q8N3P5R9L1h.jpg'},
    {'name': 'Alejandro G. Iñárritu', 'tmdbId': 60072, 'knownFor': 'Birdman', 'profilePath': '/8X9v2B5n9Z1T5M6p3Q4t9X2L1R.jpg'},
    {'name': 'Luis Buñuel', 'tmdbId': 4390, 'knownFor': 'The Exterminating Angel', 'profilePath': '/1V9x2B8T9n5P4M6Z3Q1T8h2L.jpg'},
  ]
};
