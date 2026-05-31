# 🎬 Screenique

> "Your very own gift for yourself."

Screenique is a premium, cinematic Flutter application designed for movie and series enthusiasts. It goes beyond simple tracking by offering a vintage, editorial aesthetic complete with film grain and burn effects. Discover new movies, curate your watchlist, forge custom iconic movie dialogues, and experience a unique, tactile movie-tracking journey.

## ✨ Key Features

- **Curated Watchlists & Watched History**: Easily manage what you want to watch and keep a diary of what you've already seen.
- **Cinematic UI Experience**: A custom-built vintage theme featuring dynamic film grain, scratches, and film burn animations.
- **Smart Recommendations**: Discover new movies and series tailored for you in the Recommendation Hub.
- **Shake to Recommend**: Don't know what to watch? Just shake your device, and Screenique will pick a random movie from your watchlist!
- **Custom Dialogue Forge**: Save and showcase your favorite movie quotes with custom character and poster backgrounds.
- **Rich Searching & Archival**: Search for movies, series, and directors with a robust autocomplete and history system.
- **Rate & Review**: Brutalist, straightforward UI to log your ratings and personal reviews for the movies you've watched.

## 🛠 Technology Stack

- **Framework**: [Flutter](https://flutter.dev/) (Dart)
- **Backend & Auth**: Firebase (Cloud Firestore, Firebase Auth, Google Sign-In)
- **State Management**: [Riverpod](https://riverpod.dev/)
- **Networking**: `dio` & `http` for API integrations
- **Hardware Integration**: `sensors_plus` for accelerometer-based interactions (Shake to Recommend)
- **UI & Animations**: `lottie`, `palette_generator`, `cached_network_image`
- **Utilities**: `shared_preferences`, `path_provider`, `screenshot`, `pdf`

## 🚀 Installation and Setup

Follow these steps to run Screenique locally:

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/screenique.git
   cd screenique
   ```

2. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Firebase Configuration**:
   - Create a new project on the [Firebase Console](https://console.firebase.google.com/).
   - Enable **Authentication** (Google Sign-In) and **Firestore Database**.
   - Configure Firebase for this Flutter app by running `flutterfire configure`, which will generate the `firebase_options.dart` file.

4. **Run the App**:
   ```bash
   flutter run
   ```

## 📱 Usage Instructions

1. **Sign In**: Launch the app and authenticate securely.
2. **Explore**: Browse the "Recommendation Hub" and "Series For You" sections on the home screen.
3. **Search & Add**: Tap the search icon to find specific movies, series, or directors. Add them to your Watchlist or log them as Watched.
4. **Shake to Discover**: Whenever you're feeling indecisive, physically shake your phone to randomly select a movie from your watchlist.
5. **Forge Dialogues**: Tap the central Dialogue Hero on the home screen to forge, customize, and save your own favorite movie quotes.

## 🔮 Future Improvements

- [ ] **Social Features**: Follow friends, share watchlists, and see what others are watching.
- [ ] **Offline Mode**: Local caching of watchlist and watched data for offline viewing.
- [ ] **Push Notifications**: Alerts for movie releases or availability on streaming platforms.
- [ ] **Advanced Statistics**: View detailed stats about your watch habits (e.g., favorite genres, total watch time).
- [ ] **Tablet Optimization**: Adapt the cinematic UI to fully utilize larger screen layouts.

---
*Built with passion. Good documentation demonstrates communication skills and professionalism.*
