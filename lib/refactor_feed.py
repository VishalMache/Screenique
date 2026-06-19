import re

with open('d:/VMsProject/Creations/Screenique/screenique/lib/broadcast_wire_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# I will replace the ListView.builder's itemBuilder to use a single _buildThreadPost method.
# I will also add _buildThreadPost to the file.

new_item_builder = """          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            physics: const BouncingScrollPhysics(),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final bool isOwner = currentUserId == data['senderId'];
              final String docId = doc.id;
              
              return _buildVisibilityWrapper(docId, _buildThreadPost(context, data, docId, isOwner, currentUserId));
            },
          );"""

# Replace the old ListView.builder inside the StreamBuilder
content = re.sub(r'          return ListView\.builder\(.*?padding: const EdgeInsets\.fromLTRB\(16, 16, 16, 80\),.*?return _buildVisibilityWrapper\(docId, cardChild\);\n            },\n          \);', new_item_builder, content, flags=re.DOTALL)

# Add _buildThreadPost method
thread_post_code = """
  Widget _buildThreadPost(BuildContext context, Map<String, dynamic> data, String docId, bool isOwner, String currentUserId) {
    final String type = data['type'] ?? 'movie';
    final String senderName = data['senderName'] ?? data['broadcastSender'] ?? data['reposterName'] ?? "Anonymous";
    final int senderRankCount = data['senderRankCount'] ?? data['reposterRankCount'] ?? 0;
    final Color rankColor = ArchiveRank.getColor(senderRankCount);
    final String rankName = ArchiveRank.getTitle(senderRankCount);
    final Timestamp? timestamp = data['timestamp'] as Timestamp?;
    final String timeAgo = _formatTimeAgo(timestamp);
    final String username = data['username'] ?? senderName.toLowerCase().replaceAll(' ', '');
    final String reason = data['reason'] ?? data['broadcastReason'] ?? '';
    final bool isRepost = data['isRepost'] == true;
    final String reposterName = data['reposterName'] ?? '';

    Widget embeddedCard = const SizedBox.shrink();

    if (type == 'movie' || type == 'song') {
      final movie = MovieModel.fromJson(data);
      embeddedCard = Container(
        margin: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF15181E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
              child: Image.network(
                movie.posterPath.replaceAll('image.tmdb.org', 'images.tmdb.org'),
                width: 90,
                height: 135,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(width: 90, height: 135, color: const Color(0xFF222222)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, fontFamily: 'Impact', letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${movie.releaseDate.contains('-') ? movie.releaseDate.split('-').first : movie.releaseDate} • ${movie.isTvShow ? 'TV Series' : 'Movie'}",
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      movie.overview ?? "No description available.",
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: const Color(0xFFD32F2F).withOpacity(0.2), shape: BoxShape.circle),
                        child: const Icon(Icons.play_arrow_rounded, color: Color(0xFFD32F2F), size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else if (type == 'playlist') {
      final playlistName = data['playlistName'] ?? 'Playlist';
      final posterPaths = List<String>.from(data['posterPaths'] ?? []);
      final titles = List<String>.from(data['movieTitles'] ?? []);
      embeddedCard = GestureDetector(
        onTap: () => _showPlaylistDetailSheet(data),
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF15181E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                child: SizedBox(
                  height: 100,
                  child: Row(
                    children: List.generate(
                      posterPaths.length > 4 ? 4 : posterPaths.length,
                      (i) => Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              posterPaths[i].replaceAll('image.tmdb.org', 'images.tmdb.org'),
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(color: const Color(0xFF222222)),
                            ),
                            if (i == 3 && posterPaths.length > 4)
                              Container(
                                color: Colors.black.withOpacity(0.7),
                                child: Center(
                                  child: Text(
                                    "+${posterPaths.length - 3}\\nMORE",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFD32F2F).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.collections_bookmark_rounded, color: Color(0xFFD32F2F), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlistName.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'Impact', letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${titles.length} titles",
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      "VIEW",
                      style: TextStyle(color: Color(0xFFD32F2F), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else if (type == 'news_broadcast') {
      final headline = data['title'] ?? 'News';
      final source = data['sourceName'] ?? 'Source';
      final articleUrl = data['articleUrl'] ?? '';
      final posterPath = data['posterPath'] ?? '';
      embeddedCard = GestureDetector(
        onTap: () async {
          final uri = Uri.parse(articleUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF15181E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                child: posterPath.isNotEmpty 
                  ? Image.network(posterPath, width: 90, height: 100, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(width: 90, height: 100, color: const Color(0xFF222222)))
                  : Container(width: 90, height: 100, color: const Color(0xFF222222), child: const Icon(Icons.newspaper, color: Colors.white)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFD32F2F), borderRadius: BorderRadius.circular(4)),
                        child: const Text("NEWS", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                      const SizedBox(height: 8),
                      Text(headline, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(source.toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Avatar & Thread Line
            Column(
              children: [
                GestureDetector(
                  onTap: () {
                    final sid = data['senderId'];
                    if (sid != null && sid.toString().isNotEmpty) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(uid: sid)));
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: rankColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        senderName.isNotEmpty ? senderName[0].toUpperCase() : "A",
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Impact'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    width: 1,
                    color: Colors.white10,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            
            // Right Column: Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isRepost) ...[
                    Row(
                      children: [
                        const Icon(Icons.repeat_rounded, color: Colors.white54, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          "$reposterName reposted",
                          style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    children: [
                      Text(
                        senderName.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'Impact', letterSpacing: 0.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "@$username",
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "• $timeAgo",
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.verified_user_rounded, color: rankColor, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        rankName.toUpperCase(),
                        style: TextStyle(color: rankColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Text Content
                  if (reason.isNotEmpty)
                    Text(
                      reason,
                      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                    ),
                  
                  // Embedded Media
                  embeddedCard,
                  
                  const SizedBox(height: 8),
                  
                  // Action Bar
                  _buildPostFooter(docId, isOwner, timestamp, data, currentUserId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
"""

content = content.replace("  Widget _buildNewsFeedCard", thread_post_code + "\n  Widget _buildNewsFeedCard")

with open('d:/VMsProject/Creations/Screenique/screenique/lib/broadcast_wire_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Refactor complete.")
