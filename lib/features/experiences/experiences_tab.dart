import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/experience_service.dart';

class ExperiencesTab extends StatelessWidget {
  const ExperiencesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ExperienceService service = ExperienceService();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4EC),
      body: StreamBuilder<QuerySnapshot>(
        stream: service.getExperiences(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF111111)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.confirmation_number_outlined, size: 60, color: Color(0xFF454545)),
                  const SizedBox(height: 16),
                  const Text("BEST EXPERIENCE HUB IS EMPTY", 
                    style: TextStyle(color: Color(0xFF111111), letterSpacing: 4, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 100),
            physics: const BouncingScrollPhysics(),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return FlippableTicket(data: data);
            },
          );
        },
      ),
    );
  }
}

class FlippableTicket extends StatefulWidget {
  final Map<String, dynamic> data;
  const FlippableTicket({super.key, required this.data});
  @override
  State<FlippableTicket> createState() => _FlippableTicketState();
}

class _FlippableTicketState extends State<FlippableTicket> with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  final ScreenshotController _screenshotController = ScreenshotController();
  
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic));
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _toggleCard() {
    if (_isFront) _flipController.forward(); else _flipController.reverse();
    _isFront = !_isFront;
  }

  Future<void> _shareTicket() async {
    try {
      final image = await _screenshotController.capture();
      if (image != null) {
        final directory = await getTemporaryDirectory();
        final imagePath = await File('${directory.path}/movie_ticket.png').create();
        await imagePath.writeAsBytes(image);
        await Share.shareXFiles([XFile(imagePath.path)], text: 'My Cinema Memory: ${widget.data['title']} 🎬');
      }
    } catch (e) {
      debugPrint("Sharing error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color noirCrimson = Color(0xFF111111);

    return Screenshot(
      controller: _screenshotController,
      child: GestureDetector(
        onTap: _toggleCard,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 30),
          child: AnimatedBuilder(
            animation: _flipAnimation,
            builder: (context, child) {
              final angle = _flipAnimation.value * pi;
              return Transform(
                transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(angle),
                alignment: Alignment.center,
                child: angle < pi / 2 
                    ? _buildFront(noirCrimson) 
                    : Transform(
                        alignment: Alignment.center, 
                        transform: Matrix4.rotationY(pi), 
                        child: _buildBack(noirCrimson)
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFront(Color accent) {
    return ClipPath(
      clipper: TicketClipper(),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4EC),
          border: Border.all(color: const Color(0xFF111111), width: 2),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                widget.data['posterPath'] ?? '', 
                fit: BoxFit.cover,
                errorBuilder: (c,e,s) => Container(color: const Color(0xFFF4F4EC)),
              )
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFFF4F4EC).withOpacity(0.9), Colors.transparent, const Color(0xFFF4F4EC).withOpacity(0.4)],
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("ADMIT ONE", style: TextStyle(color: Color(0xFF111111), fontSize: 10, letterSpacing: 6, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text(widget.data['title']?.toString().toUpperCase() ?? 'UNTITLED', 
                    style: const TextStyle(color: Color(0xFF111111), fontWeight: FontWeight.w900, fontSize: 32, letterSpacing: -1.0, fontFamily: 'Impact', height: 1.0)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: accent, size: 12),
                      const SizedBox(width: 4),
                      Text(widget.data['cinemaName']?.toUpperCase() ?? "UNKNOWN LOCATION", 
                        style: const TextStyle(color: Color(0xFF111111), fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBack(Color accent) {
    return ClipPath(
      clipper: TicketClipper(),
      child: Container(
        height: 180,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: const Color(0xFFF4F4EC), border: Border.all(color: const Color(0xFF111111), width: 2)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("BEST EXPERIENCE HUB", 
                  style: TextStyle(color: const Color(0xFF111111), fontWeight: FontWeight.bold, fontSize: 9, letterSpacing: 2)),
                Text(
                  widget.data['timestamp'] != null 
                    ? DateFormat('MM.dd.yy').format((widget.data['timestamp'] as Timestamp).toDate()) 
                    : "--", 
                  style: const TextStyle(color: Color(0xFF111111), fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold)
                ),
              ],
            ),
            const SizedBox(height: 8),
            // MOVIE NAME ON BACK side
            Text(
              widget.data['title']?.toString().toUpperCase() ?? 'UNTITLED',
              style: const TextStyle(color: Color(0xFF111111), fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -0.5, fontFamily: 'Impact'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Divider(color: Color(0xFF111111), height: 20, thickness: 1),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.data['personalNote'] ?? "No memory logged...",
                      style: const TextStyle(color: Color(0xFF111111), fontSize: 12, height: 1.5, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 8),
                    if (widget.data['companions'] != null && widget.data['companions'].toString().isNotEmpty && widget.data['companions'] != "Watched alone")
                      Text(
                        "WITH: ${widget.data['companions']}",
                        style: const TextStyle(color: Color(0xFF111111), fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: List.generate(5, (i) {
                    final double rating = (widget.data['userRating'] ?? 0.0).toDouble();
                    final isFull = i < rating.floor();
                    final isHalf = i == rating.floor() && (rating - rating.floor()) >= 0.5;
                    return Icon(
                      isFull ? Icons.star : (isHalf ? Icons.star_half : Icons.star_border),
                      color: accent,
                      size: 16,
                    );
                  }),
                ),
                Row(
                  children: [
                    _actionBtn(Icons.share_outlined, _shareTicket),
                    const SizedBox(width: 15),
                    _actionBtn(Icons.edit_note, () => _showEditDialog(context)),
                    const SizedBox(width: 15),
                    _actionBtn(Icons.delete_outline, () => ExperienceService().deleteExperience(widget.data['id'])),
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: const Color(0xFF111111), size: 20),
    );
  }

  void _showEditDialog(BuildContext context) {
    final cinema = TextEditingController(text: widget.data['cinemaName']);
    final note = TextEditingController(text: widget.data['personalNote']);
    final people = TextEditingController(text: widget.data['companions']);
    double rating = (widget.data['userRating'] ?? 0.0).toDouble();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setST) => AlertDialog(
          backgroundColor: const Color(0xFFF4F4EC),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2), 
            side: const BorderSide(color: Color(0xFF111111), width: 2),
          ),
          title: const Text("REVISE HUB ENTRY", 
            style: TextStyle(color: Color(0xFF111111), fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _noirField(cinema, "LOCATION"),
                  _noirField(people, "COMPANIONS"),
                  _noirField(note, "WRITE YOUR MEMORY", maxLines: 3),
                  const SizedBox(height: 20),
                  FittedBox(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center, 
                        children: List.generate(5, (i) => IconButton(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            setST(() {
                              final fullValue = i + 1.0;
                              final halfValue = i + 0.5;
                              if (rating == fullValue) {
                                rating = halfValue;
                              } else if (rating == halfValue) {
                                rating = fullValue;
                              } else {
                                rating = fullValue;
                              }
                            });
                          }, 
                          icon: Icon(
                            i < rating.floor()
                                ? Icons.star
                                : (i == rating.floor() && (rating - rating.floor()) >= 0.5
                                    ? Icons.star_half
                                    : Icons.star_border),
                            color: i < rating ? const Color(0xFF111111) : const Color(0xFF454545),
                            size: 28,
                          )
                        )),
                      ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text("CANCEL", style: TextStyle(color: Color(0xFF111111), fontSize: 12))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111111),
                foregroundColor: const Color(0xFFF4F4EC),
              ), 
              onPressed: () async {
                await ExperienceService().updateExperience(
                  docId: widget.data['id'], 
                  cinema: cinema.text, 
                  note: note.text, 
                  people: people.text,
                  rating: rating
                );
                if (context.mounted) Navigator.pop(context);
              }, 
              child: const Text("UPDATE HUB", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))
            ),
          ],
        ),
      ),
    );
  }

  Widget _noirField(TextEditingController controller, String label, {int maxLines = 1}) {
    return TextField(
      controller: controller, 
      maxLines: maxLines,
      style: const TextStyle(color: Color(0xFF111111), fontSize: 13, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label, 
        labelStyle: const TextStyle(color: Color(0xFF454545), fontSize: 10, fontWeight: FontWeight.bold), 
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF111111), width: 2)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF111111), width: 2))
      ),
    );
  }
}

class TicketClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    double radius = 12;
    path.addOval(Rect.fromCircle(center: Offset(size.width, size.height / 2), radius: radius));
    path.addOval(Rect.fromCircle(center: Offset(0, size.height / 2), radius: radius));
    return path..fillType = PathFillType.evenOdd;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}